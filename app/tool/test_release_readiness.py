"""Synthetic read-only release contract regressions; no external requests."""
import copy
import unittest

from check_release_readiness import check_readiness, public_url


class ReleaseReadinessTests(unittest.TestCase):
    def setUp(self):
        self.config = {
            'API_BASE_URL': 'https://api.synthetic-futuremint.app/api/',
            'PRIVACY_POLICY_URL': 'https://api.synthetic-futuremint.app/privacy',
            'SUPPORT_URL': 'https://api.synthetic-futuremint.app/support',
            'SERVICE_OPERATOR': 'Synthetic Operator',
            'SUPPORT_EMAIL': 'support@synthetic-futuremint.app',
        }
        self.health = {'status': 'ok', 'mode': 'hosted', 'dataProvider': 'postgres',
                       'aiProvider': 'liangjie'}
        self.policy = {
            'servicePolicyVersion': 'tw-service-age-15-v1', 'minimumAge': 15,
            'country': 'TW', 'guardianRequiredUnder18': True, 'eligibilityRequired': True,
            'privacyPolicyVersion': 'synthetic-v1', 'registrationEnabled': True,
            'mailEnabled': True, 'emailVerificationRequired': True,
            'ai': {'provider': 'liangjie', 'reviewed': True, 'model': 'synthetic-model',
                   'policyVersion': 'synthetic-ai-v1', 'dataRecipients': ['Synthetic recipient'],
                   'dataTerms': 'Synthetic terms'},
        }
        self.requests = []

    def fetch(self, url, kind):
        self.requests.append((url, kind))
        if url.endswith('/health'):
            return copy.deepcopy(self.health)
        if url.endswith('/service-policy'):
            return {'data': copy.deepcopy(self.policy)}
        language = url.split('?lang=')[1]
        return f'<html lang="{language}">Synthetic Operator support@synthetic-futuremint.app</html>'

    def blocked(self):
        return {check.name for check in check_readiness(self.config, self.fetch) if not check.passed}

    def test_complete_public_configuration_passes_using_only_public_endpoints(self):
        self.assertEqual(self.blocked(), set())
        self.assertEqual(len(self.requests), 6)
        self.assertFalse(any('/auth/' in url or '/guardian/' in url for url, _ in self.requests))

    def test_healthy_api_without_mail_still_blocks_minor_launch(self):
        self.policy['mailEnabled'] = False
        self.policy['emailVerificationRequired'] = False
        self.assertIn('新帳號與寄信功能', self.blocked())

    def test_ai_unreviewed_or_demo_cannot_pass_an_ai_release(self):
        self.policy['ai']['reviewed'] = False
        self.assertIn('外部 AI 公開政策', self.blocked())
        self.policy['ai']['reviewed'] = True
        self.policy['ai']['provider'] = 'demo'
        self.assertIn('外部 AI 公開政策', self.blocked())

    def test_disabled_registration_or_missing_eligibility_blocks(self):
        self.policy['registrationEnabled'] = False
        self.policy['eligibilityRequired'] = False
        self.assertTrue({'新帳號與寄信功能', '年齡與監護人政策'} <= self.blocked())

    def test_memory_repository_and_provider_mismatch_block(self):
        self.health['dataProvider'] = 'memory'
        self.health['aiProvider'] = 'openai'
        self.assertTrue({'持久化模式', 'AI 設定一致'} <= self.blocked())

    def test_unsafe_urls_stop_before_network_requests(self):
        for url in ('http://localhost:3000/api/', 'https://example.invalid/api/',
                    'https://127.0.0.1/api/', 'https://api.example.com/api/',
                    'https://user:synthetic@host.app/api/', 'https://host.app/api/?token=x',
                    'https://host.app/api/#x', 'https://host.app/wrong-path'):
            with self.subTest(url=url):
                self.config['API_BASE_URL'] = url
                self.assertIn('API_BASE_URL', self.blocked())
                self.assertEqual(self.requests, [])

    def test_unavailable_policy_and_pages_do_not_pass(self):
        def unavailable(_url, _kind):
            raise ValueError('HTTP 503')
        checks = check_readiness(self.config, unavailable)
        self.assertTrue(any(not check.passed for check in checks))
        self.assertEqual(len([check for check in checks if not check.passed]), 6)

    def test_invalid_service_policy_contract_is_blocked(self):
        def invalid(url, kind):
            return {'data': None} if url.endswith('/service-policy') else self.fetch(url, kind)
        checks = check_readiness(self.config, invalid)
        self.assertIn('服務政策契約', {check.name for check in checks if not check.passed})

    def test_json_null_cannot_silently_skip_required_contracts(self):
        def empty_json(url, kind):
            return None if kind == 'json' else self.fetch(url, kind)
        checks = check_readiness(self.config, empty_json)
        self.assertTrue({'持久化模式', '服務政策契約'} <= {
            check.name for check in checks if not check.passed})

    def test_wrong_ai_disclosure_types_do_not_pass(self):
        for field, value in [('model', {}), ('policyVersion', True),
                             ('dataRecipients', [123]), ('dataTerms', '   ')]:
            with self.subTest(field=field):
                original = self.policy['ai'][field]
                self.policy['ai'][field] = value
                self.assertIn('外部 AI 公開政策', self.blocked())
                self.policy['ai'][field] = original

    def test_build_operator_and_support_must_match_public_pages(self):
        self.config['SERVICE_OPERATOR'] = 'Different operator'
        self.config['SUPPORT_EMAIL'] = 'different@synthetic-futuremint.app'
        self.assertTrue(any('公開資訊' in name for name in self.blocked()))

    def test_both_languages_must_actually_be_served(self):
        def wrong_language(url, kind):
            result = self.fetch(url, kind)
            return result.replace('lang="en"', 'lang="zh-Hant"') if kind == 'html' else result
        checks = check_readiness(self.config, wrong_language)
        self.assertTrue(any(not check.passed and 'en 語系' in check.name for check in checks))

    def test_cloudflare_public_email_rewrite_preserves_contact_check(self):
        email = self.config['SUPPORT_EMAIL']
        encoded = bytes([23] + [byte ^ 23 for byte in email.encode('utf-8')]).hex()
        def rewritten(url, kind):
            value = self.fetch(url, kind)
            return value.replace(email, f'<span data-cfemail="{encoded}">[email protected]</span>') if kind == 'html' else value
        self.assertTrue(all(check.passed for check in check_readiness(self.config, rewritten)))


if __name__ == '__main__':
    unittest.main()
