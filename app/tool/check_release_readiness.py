#!/usr/bin/env python3
"""Read-only checks of the public backend used by an App Store archive.

No login, mail, AI request, or database mutation is performed. Successful
checks establish public configuration only, not end-to-end release acceptance.
"""
import argparse
from dataclasses import dataclass
import html
import ipaddress
import json
import os
import re
import urllib.error
import urllib.parse
import urllib.request


@dataclass(frozen=True)
class Check:
    name: str
    passed: bool
    detail: str


def public_url(value):
    try:
        url = urllib.parse.urlsplit(value)
        host = (url.hostname or '').lower().rstrip('.')
        if (url.scheme != 'https' or not host or url.username or url.password
                or url.query or url.fragment or url.port not in (None, 443)):
            return False
        if host == 'localhost' or '.' not in host or any(
                host == suffix or host.endswith('.' + suffix)
                for suffix in ('localhost', 'local', 'invalid', 'test', 'example')):
            return False
        if any(host == suffix or host.endswith('.' + suffix)
               for suffix in ('example.com', 'example.org', 'example.net')):
            return False
        try:
            return ipaddress.ip_address(host).is_global
        except ValueError:
            return True
    except ValueError:
        return False


def fetch_public(url, kind):
    request = urllib.request.Request(url, headers={
        'Accept': 'application/json' if kind == 'json' else 'text/html',
        'User-Agent': 'FutureMint-release-readiness/1',
    })
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            if response.status != 200 or not public_url(response.geturl().split('?')[0]):
                raise ValueError('HTTP 狀態或重新導向不符合公開 HTTPS 契約')
            expected = 'application/json' if kind == 'json' else 'text/html'
            if response.headers.get_content_type() != expected:
                raise ValueError('回應格式不符')
            body = response.read(1_048_577)
            if len(body) > 1_048_576:
                raise ValueError('回應超過檢查大小限制')
            text = body.decode('utf-8')
            return json.loads(text) if kind == 'json' else text
    except urllib.error.HTTPError as error:
        raise ValueError(f'HTTP {error.code}') from None
    except (urllib.error.URLError, TimeoutError, OSError):
        raise ValueError('連線或 TLS 驗證失敗') from None
    except (UnicodeError, json.JSONDecodeError):
        raise ValueError('回應內容無法解析') from None


def contains_contact(page, email):
    if email in html.unescape(page):
        return True
    # Cloudflare may rewrite the public mailto link. Decode its bounded public
    # email representation locally; never execute injected page scripts.
    for encoded in re.findall(r'data-cfemail=[\"\']([0-9a-fA-F]{4,512})[\"\']', page):
        try:
            value = bytes.fromhex(encoded)
            decoded = bytes(byte ^ value[0] for byte in value[1:]).decode('utf-8')
            if decoded == email:
                return True
        except (ValueError, UnicodeError):
            continue
    return False


def check_readiness(config, fetch=fetch_public):
    checks = []
    failed = object()

    def nonempty_text(value):
        return isinstance(value, str) and bool(value.strip())

    def record(name, passed, detail):
        checks.append(Check(name, passed, detail))

    for key in ('API_BASE_URL', 'PRIVACY_POLICY_URL', 'SUPPORT_URL'):
        valid = public_url(config.get(key, ''))
        if key == 'API_BASE_URL':
            valid = valid and urllib.parse.urlsplit(config[key]).path.endswith('/api/')
        record(key, valid, '需設定正式 HTTPS URL；API 路徑須以 /api/ 結尾。')
    operator = config.get('SERVICE_OPERATOR', '').strip()
    email = config.get('SUPPORT_EMAIL', '').strip()
    record('SERVICE_OPERATOR', bool(operator) and not re.search(
        r'[<>]|placeholder|未定', operator, flags=re.IGNORECASE),
        '檢查營運者欄位已填；真實身分需人工核對。')
    record('SUPPORT_EMAIL', bool(re.fullmatch(r'[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+', email))
           and public_url('https://' + email.split('@')[-1]),
           '檢查公開客服 Email 格式；收信能力需人工驗收。')
    if not all(check.passed for check in checks):
        return checks

    def probe(name, url, kind):
        try:
            value = fetch(url, kind)
            record(name, True, '公開端點可讀取。')
            return value
        except ValueError as error:
            record(name, False, str(error))
            return failed

    base = config['API_BASE_URL']
    health = probe('API health', base + 'health', 'json')
    if health is not failed:
        record('持久化模式', isinstance(health, dict) and health.get('status') == 'ok'
               and health.get('mode') == 'hosted' and health.get('dataProvider') == 'postgres',
               '正式 API 需使用 hosted／postgres 並回報健康；仍須另外驗收重啟後資料。')
    envelope = probe('服務政策', base + 'service-policy', 'json')
    if envelope is not failed:
        policy = envelope.get('data') if isinstance(envelope, dict) else None
        if not isinstance(policy, dict):
            record('服務政策契約', False, 'API 未回傳有效的服務政策。')
        else:
            record('年齡與監護人政策', policy.get('minimumAge') == 15
                   and policy.get('country') == 'TW'
                   and policy.get('servicePolicyVersion') == 'tw-service-age-15-in-app-v2'
                   and policy.get('guardianRequiredUnder18') is True
                   and policy.get('guardianConsentMethod') == 'in-app'
                   and policy.get('eligibilityRequired') is True,
                   '此版 Client 採臺灣 15+；15–17 歲須可在 App 內完成監護人聲明。')
            record('新帳號與寄信功能', policy.get('registrationEnabled') is True
                   and isinstance(policy.get('mailEnabled'), bool)
                   and isinstance(policy.get('emailVerificationRequired'), bool)
                   and (policy['mailEnabled'] or not policy['emailVerificationRequired']),
                   '需開放註冊；寄信可停用，但不可在沒有寄信服務時要求 Email 驗證。監護人確認獨立採 App 內聲明。')
            record('公開隱私版本', nonempty_text(policy.get('privacyPolicyVersion')),
                   '需有已確認的公開隱私版本。')
            ai = policy.get('ai')
            record('外部 AI 公開政策', isinstance(ai, dict)
                   and ai.get('provider') in ('liangjie', 'openai')
                   and ai.get('reviewed') is True
                   and nonempty_text(ai.get('model')) and nonempty_text(ai.get('policyVersion'))
                   and isinstance(ai.get('dataRecipients'), list)
                   and bool(ai.get('dataRecipients'))
                   and all(nonempty_text(recipient) for recipient in ai.get('dataRecipients'))
                   and nonempty_text(ai.get('dataTerms')),
                   '此版含 AI 功能，需核准供應商及完整資料處理說明；不以修改 reviewed 取代查核。')
            if isinstance(health, dict) and isinstance(ai, dict):
                record('AI 設定一致', health.get('aiProvider') == ai.get('provider'),
                       'health 與公開服務政策的 AI 供應商須一致。')

    for key in ('PRIVACY_POLICY_URL', 'SUPPORT_URL'):
        for language in ('zh-Hant', 'en'):
            page = probe(f'{key} {language}', config[key] + '?lang=' + language, 'html')
            if page is not failed:
                if not isinstance(page, str):
                    record(f'{key} {language} 內容格式', False, '需回傳公開 HTML。')
                    continue
                plain = html.unescape(page)
                record(f'{key} {language} 公開資訊', operator in plain and contains_contact(page, email),
                       '頁面需包含與 App build 一致的營運者及客服資訊。')
                record(f'{key} {language} 語系', bool(re.search(
                    r'<html\b[^>]*\blang=[\"\']' + re.escape(language) + r'[\"\']', page,
                    flags=re.IGNORECASE)), '頁面需提供實際的繁中／英文版本。')
    return checks


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('API_BASE_URL', 'PRIVACY_POLICY_URL', 'SUPPORT_URL',
                 'SUPPORT_EMAIL', 'SERVICE_OPERATOR'):
        parser.add_argument('--' + name.lower().replace('_', '-'),
                            default=os.environ.get(name, ''), dest=name)
    config = vars(parser.parse_args())
    checks = check_readiness(config)
    for check in checks:
        print(f'{"PASS" if check.passed else "BLOCK"} {check.name}: {check.detail}')
    print('此檢查只讀公開端點；真實寄信、親子操作、密碼復原、資料持久化、AI 連線及 Apple 簽章／TestFlight 仍需另驗收。')
    return 0 if all(check.passed for check in checks) else 1


if __name__ == '__main__':
    raise SystemExit(main())
