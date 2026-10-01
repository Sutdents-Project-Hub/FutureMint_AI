import { readFile } from "node:fs/promises";
import { join } from "node:path";
import type { FastifyInstance } from "fastify";
import type { PublicConfig } from "../config/publicConfig";

import { escapeHtml, publicLanguage, policyContent, type PublicLanguage } from "./public-page-content";
const page = (title: string, content: string, language: PublicLanguage, path: string, dark: boolean, script = false): string => {
  const en = language === "en";
  const href = (target: string, lang = language, theme = dark) => `${target}?lang=${lang}${theme ? "&amp;theme=dark" : ""}`;
  return `<!doctype html>
<html lang="${language}"${dark ? ' data-theme="dark"' : ''}><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="referrer" content="no-referrer"><meta name="color-scheme" content="${dark ? "dark" : "light"}"><title>${escapeHtml(title)} | FutureMint AI</title><link rel="stylesheet" href="/public.css">${script ? '<script src="/account-actions.js" defer></script>' : ''}</head>
<body><a class="skip" href="#content">${en ? "Skip to content" : "跳至內容"}</a><div class="layout"><header class="site-header"><a class="brand" href="${href("/support")}"><img class="brand-mark" src="/app-icon.png" width="40" height="40" alt="">FutureMint AI</a><nav aria-label="${en ? "Page settings" : "頁面設定"}"><a data-language="zh-Hant" lang="zh-Hant" href="${href(path, "zh-Hant")}"${!en ? ' aria-current="true"' : ''}>繁體中文</a><a data-language="en" lang="en" href="${href(path, "en")}"${en ? ' aria-current="true"' : ''}>English</a><a data-theme-switch href="${href(path, language, !dark)}">${dark ? (en ? "Light theme" : "淺色主題") : (en ? "Dark theme" : "深色主題")}</a></nav></header><main id="content"><p class="eyebrow">${en ? "Money choices, one step at a time" : "一步一步，練習金錢決策"}</p><h1>${escapeHtml(title)}</h1>${content}</main><footer><span>FutureMint AI</span><nav aria-label="${en ? "Helpful links" : "相關連結"}"><a href="${href("/privacy")}">${en ? "Privacy policy" : "隱私權政策"}</a><a href="${href("/support")}">${en ? "Support" : "聯絡支援"}</a></nav></footer></div></body></html>`;
};
const publicCsp = "default-src 'none'; img-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; form-action 'none'; base-uri 'none'; frame-ancestors 'none'";

export interface PublicServicePolicy { servicePolicyVersion: string; mailEnabled?: boolean; registrationEnabled?: boolean; emailVerificationRequired?: boolean; ai: { displayName: string; dataRecipients: string[]; dataTerms: string; }; }
export const registerPublicPages = (app: FastifyInstance, config?: PublicConfig, policy?: PublicServicePolicy): void => {
  const html = (path: string, title: string | ((language: PublicLanguage) => string), content: string | ((language: PublicLanguage) => string), status = 200, script = false) => {
    app.get(path, async (request, reply) => {
      const query = new URL(request.url, "http://public.local").searchParams;
      const language = publicLanguage(query, request.headers["accept-language"]);
      const localizedTitle = typeof title === "function" ? title(language) : language === "en" ? accountTranslations[title] ?? title : title;
      const localizedContent = (typeof content === "function" ? content(language) : language === "en" ? translateAccountContent(content) : content)
        .replaceAll('href="/privacy"', `href="/privacy?lang=${language}${query.get("theme") === "dark" ? "&amp;theme=dark" : ""}"`);
      const vary = reply.getHeader("vary");
      return reply.code(status).header("vary", [vary, "Accept-Language"].filter(Boolean).join(", "))
        .header("content-language", language).header("referrer-policy", "no-referrer")
        .header("content-security-policy", publicCsp).type("text/html; charset=utf-8")
        .send(page(localizedTitle, localizedContent, language, path, query.get("theme") === "dark", script));
    });
  };
  app.get("/app-icon.png", async (_request, reply) => reply.type("image/png")
    .header("cache-control", "no-cache")
    .send(await readFile(join(__dirname, "../../public/app-icon.png"))));
  app.get("/public.css", async (_request, reply) => reply.type("text/css; charset=utf-8").send(publicStyles));
  for (const kind of ["privacy", "support"] as const) {
    html(`/${kind}`, (language) => language === "en" ? (kind === "privacy" ? "Privacy policy" : "Support") : (kind === "privacy" ? "隱私權政策" : "聯絡支援"),
      (language) => config?.reviewed ? policyContent(kind, language, config, policy)
        : `<p class="lead">${language === "en" ? "This service is being prepared." : "服務準備中。"}</p><p>${language === "en" ? "Public operator, contact and privacy information have not been reviewed. Formal service is not available. Do not enter real personal information in this environment." : "營運者、客服與隱私資訊尚未完成確認，正式服務尚未開放。請勿在此環境輸入真實個人資料。"}</p>`, config?.reviewed ? 200 : 503);
  }
  const policyVersion = escapeHtml(policy?.servicePolicyVersion ?? "tw-service-age-15-v1");
  html("/account/verify", "驗證電子郵件", '<p>請點擊下方按鈕確認這是你的電子郵件地址。</p><form id="action-form" data-action="email-verification"><button type="submit">確認驗證</button></form><p id="status" role="status" aria-live="polite"></p>', 200, true);
  html("/account/reset-password", "重設密碼", '<p>設定新密碼後，其他裝置會需要重新登入。</p><form id="action-form" data-action="password-reset"><label for="password">新密碼（8 至 128 個字元，需含英文字母與數字）</label><input id="password" type="password" autocomplete="new-password" minlength="8" maxlength="128" required><label for="confirmation">再次輸入新密碼</label><input id="confirmation" type="password" autocomplete="new-password" minlength="8" maxlength="128" required><button type="submit">儲存新密碼</button></form><p id="status" role="status" aria-live="polite"></p>', 200, true);
  html("/account/guardian-consent", "監護人同意", `<p>本服務為 15 歲以上的教育性記帳與金錢決策練習。請先與信中提出申請的使用者確認身分，並閱讀<a href="/privacy">隱私權政策</a>。此同意不加入家庭、不共享交易明細，也不啟用第三方 AI。</p><p>Email 確認本身不證明法定代理人身分。</p><form id="action-form" data-action="guardian-consent" data-policy-version="${policyVersion}"><label><input id="adult" type="checkbox" required>我已滿 18 歲</label><label><input id="legal-guardian" type="checkbox" required>我是申請使用者的法定代理人，已與使用者確認這次申請</label><label><input id="accepted" type="checkbox" required>我已閱讀並同意此版本服務及隱私說明</label><button type="submit">確認同意</button></form><p id="status" role="status" aria-live="polite"></p>`, 200, true);
  html("/account/guardian-withdraw", "撤回監護人同意", `<p>撤回後停止新的正式資料輸入與外部 AI 請求；使用者仍可查看、匯出及刪除自己的資料。</p><form id="action-form" data-action="guardian-withdraw"><button type="submit">確認撤回</button></form><p id="status" role="status" aria-live="polite"></p><h2>連結已過期</h2><p>輸入原申請使用者及監護人的信箱，申請新的撤回連結；此流程需啟用寄信。</p><form id="withdrawal-request"><label for="account-email">使用者信箱</label><input id="account-email" type="email" maxlength="254" required><label for="guardian-email">監護人信箱</label><input id="guardian-email" type="email" maxlength="254" required><button type="submit">寄送撤回連結</button></form><p id="request-status" role="status" aria-live="polite"></p>`, 200, true);
  app.get("/account-actions.js", async (_request, reply) => reply.type("application/javascript; charset=utf-8").send(`
"use strict";
const token = new URLSearchParams(location.hash.slice(1)).get("token");
const english = document.documentElement.lang === "en";
const messages = ${JSON.stringify(actionMessages)};
const message = (text) => english ? messages[text] || text : text;
if (token && /^[A-Za-z0-9_-]{43}$/.test(token)) document.querySelectorAll("[data-language], [data-theme-switch]").forEach((link) => { link.hash = new URLSearchParams({token}).toString(); });
history.replaceState(null, "", location.pathname + location.search);
const form = document.getElementById("action-form");
const status = document.getElementById("status");
const button = form.querySelector("button");
if (!token || !/^[A-Za-z0-9_-]{43}$/.test(token)) { button.disabled = true; status.textContent = message("連結不完整或已過期，請重新申請並開啟最新信件。"); }
form.addEventListener("submit", async (event) => {
 event.preventDefault();
 const password = document.getElementById("password");
 const confirmation = document.getElementById("confirmation");
 if (password && password.value !== confirmation.value) { status.textContent = message("兩次輸入的密碼不一致。"); return; }
 const guardian = form.dataset.action === "guardian-consent";
 const withdraw = form.dataset.action === "guardian-withdraw";
 const url = guardian ? "/api/privacy/guardian-consent/confirm" : withdraw ? "/api/privacy/guardian-consent/withdraw" : "/api/auth/" + form.dataset.action + "/confirm";
 const input = { token, ...(password ? { password: password.value } : {}), ...(guardian ? { policyVersion: form.dataset.policyVersion, adult: document.getElementById("adult").checked, legalGuardian: document.getElementById("legal-guardian").checked, accepted: document.getElementById("accepted").checked } : {}) };
 button.disabled = true; status.textContent = message("處理中…");
 try {
  const response = await fetch(url, { method: "POST", credentials: "omit", headers: { "Content-Type": "application/json" }, body: JSON.stringify(input) });
  if (!response.ok) {
   status.textContent = response.status >= 500 ? message("服務目前無法完成，請稍後重試；這不代表連結已過期。") : response.status === 429 ? message("請求過於頻繁，請稍後重試。") : response.status === 422 ? message("請完成必填資料與確認欄位。") : response.status === 409 ? message("服務說明已更新，請回到 App 重新申請。") : message("連結可能已過期或使用過，請重新申請。");
   button.disabled = false; return;
  }
  form.hidden = true; form.reset(); status.textContent = guardian ? message("監護人同意已完成，請使用者回到 App 更新狀態。") : withdraw ? message("同意已撤回。") : password ? message("密碼已更新，請回到 App 登入。") : message("驗證完成，請回到 App 選擇我已完成驗證。");
 } catch { status.textContent = message("目前無法連線，請檢查網路後重試。"); button.disabled = false; }
});
const requestForm = document.getElementById("withdrawal-request");
if (requestForm) requestForm.addEventListener("submit", async (event) => {
 event.preventDefault(); const notice = document.getElementById("request-status"); const submit = requestForm.querySelector("button"); submit.disabled = true;
 try {
  const response = await fetch("/api/privacy/guardian-consent/withdrawal-request", { method:"POST", credentials:"omit", headers:{"Content-Type":"application/json"}, body:JSON.stringify({accountEmail:document.getElementById("account-email").value,guardianEmail:document.getElementById("guardian-email").value}) });
  notice.textContent = response.ok ? message("若資料符合有效的監護人同意，系統會寄送新的撤回連結。") : message("目前無法完成，請稍後重試。");
 } catch { notice.textContent=message("目前無法連線，請稍後重試。"); } finally { submit.disabled=false; }
});
`));
};

const publicStyles = `
:root{color-scheme:light;--bg:#F8F7FC;--surface:#fff;--ink:#1B1B2A;--muted:#625E76;--primary:#6D5BD0;--link:#4B3FA7;--soft:#E8E4FF;--line:#DEDDEC;--outline:#74728C;font-family:system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;line-height:1.75}
:root[data-theme=dark]{color-scheme:dark;--bg:#14131F;--surface:#1C1B2A;--ink:#FFF8EE;--muted:#C5C1D6;--primary:#B8AEFF;--link:#C3BCFF;--soft:#393368;--line:#464459;--outline:#AAA8C0}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink)}.layout{max-width:72rem;margin:auto;padding:0 1.5rem}a{color:var(--link);text-underline-offset:.2em;overflow-wrap:anywhere}.site-header,footer{display:flex;align-items:center;justify-content:space-between;gap:1.25rem;flex-wrap:wrap}.site-header{padding:1.5rem 0;border-bottom:1px solid var(--line)}.brand{display:flex;align-items:center;gap:.65rem;text-decoration:none;font-weight:750;color:var(--ink)}.brand-mark{display:block;width:2.5rem;height:2.5rem;flex-shrink:0;border-radius:.85rem;object-fit:cover}nav{display:flex;gap:.35rem;flex-wrap:wrap}nav a{padding:.5rem .75rem;min-height:44px;border-radius:999px;text-decoration:none;font-size:.9rem}nav a[aria-current=true]{background:var(--soft);font-weight:700}nav a:hover{background:var(--soft)}main{max-width:48rem;margin:0 auto;padding:3rem 0}h1{font-size:clamp(2rem,6vw,3rem);line-height:1.2;letter-spacing:-.035em;margin:.5rem 0 1.25rem}h2{font-size:1.25rem;line-height:1.45;margin:0 0 .75rem}h3{font-size:1rem;margin:0 0 .75rem}.eyebrow{color:var(--link);font-size:.9rem;font-weight:650;margin:0}.lead{font-size:1.125rem;color:var(--muted);margin-bottom:1.75rem}p{overflow-wrap:anywhere;margin:.75rem 0}section{padding-top:1.75rem;margin-top:1.75rem;border-top:1px solid var(--line)}.metadata{background:var(--surface);border:1px solid var(--line);border-radius:1.5rem;padding:1.25rem 1.5rem;margin:1.5rem 0 2rem}.metadata div{display:grid;grid-template-columns:7rem 1fr;gap:1rem;padding:.35rem 0}dt{color:var(--muted)}dd{margin:0;overflow-wrap:anywhere}.notice{background:var(--soft);padding:1.25rem 1.5rem;border-radius:1.5rem;margin-top:1.25rem}.declaration{white-space:pre-wrap}label{display:block;margin:1rem 0 .35rem}input:not([type=checkbox]){display:block;width:100%;padding:.8rem 1rem;border:1px solid var(--outline);border-radius:1rem;background:var(--surface);color:var(--ink);font:inherit}input[type=checkbox]{width:1.15rem;height:1.15rem;vertical-align:middle;accent-color:var(--primary);margin-right:.5rem}button{display:block;min-height:48px;padding:.8rem 1.25rem;margin-top:1.25rem;border:0;border-radius:999px;background:var(--primary);color:#fff;font:inherit;font-weight:650;cursor:pointer}:root[data-theme=dark] button{color:#14131F}button:disabled{opacity:.65;cursor:not-allowed}#status,#request-status{min-height:2em}footer{border-top:1px solid var(--line);padding:1.5rem 0 2rem;color:var(--muted);font-size:.9rem}a:focus-visible,input:focus-visible,button:focus-visible{outline:3px solid var(--link);outline-offset:4px}.skip{position:absolute;left:1rem;top:-6rem;padding:.75rem;background:var(--surface);z-index:1}.skip:focus{top:1rem}[hidden]{display:none!important}@media(max-width:600px){.layout{padding:0 1rem}.site-header{gap:.75rem;padding:1rem 0}.site-header nav{width:100%}main{padding:2rem 0}.metadata{padding:1rem}.metadata div{grid-template-columns:1fr;gap:0;padding:.5rem 0}.notice{padding:1rem}footer{align-items:flex-start}}
`;
const accountTranslations: Record<string, string> = {
  "驗證電子郵件": "Verify email", "重設密碼": "Reset password", "監護人同意": "Guardian approval", "撤回監護人同意": "Withdraw guardian approval",
  "請點擊下方按鈕確認這是你的電子郵件地址。": "Use the button below to confirm that this email address is yours.",
  "確認驗證": "Confirm verification", "設定新密碼後，其他裝置會需要重新登入。": "After changing your password, other devices must sign in again.",
  "新密碼（8 至 128 個字元，需含英文字母與數字）": "New password (8–128 characters, including a letter and a number)",
  "再次輸入新密碼": "Confirm new password", "儲存新密碼": "Save new password",
  "本服務為 15 歲以上的教育性記帳與金錢決策練習。請先與信中提出申請的使用者確認身分，並閱讀": "This service offers educational records and money decision practice for ages 15 and up. Confirm the requester’s identity with them and read the ",
  "隱私權政策": "privacy policy", "。此同意不加入家庭、不共享交易明細，也不啟用第三方 AI。": ". This approval does not join a family, share individual transactions or enable third-party AI.",
  "Email 確認本身不證明法定代理人身分。": "Email confirmation alone does not prove legal guardianship.",
  "我已滿 18 歲": "I am at least 18 years old", "我是申請使用者的法定代理人，已與使用者確認這次申請": "I am the requester’s legal guardian and have confirmed this request with them",
  "我已閱讀並同意此版本服務及隱私說明": "I have read and accept this version of the service and privacy notice", "確認同意": "Confirm approval",
  "撤回後停止新的正式資料輸入與外部 AI 請求；使用者仍可查看、匯出及刪除自己的資料。": "Withdrawal blocks new formal data entry and external AI requests. The user can still view, export and delete their own data.",
  "確認撤回": "Confirm withdrawal", "連結已過期": "If the link has expired", "輸入原申請使用者及監護人的信箱，申請新的撤回連結；此流程需啟用寄信。": "Enter the requester’s and guardian’s original email addresses to request a new withdrawal link. Email delivery must be enabled.",
  "使用者信箱": "Account email", "監護人信箱": "Guardian email", "寄送撤回連結": "Email a withdrawal link",
};
// Translate text nodes only; configuration in attributes must remain exact.
const translateAccountContent = (content: string): string => content.replace(/>([^<]+)</g, (_match, text: string) =>
  `>${Object.entries(accountTranslations).sort(([a], [b]) => b.length - a.length)
    .reduce((result, [zh, en]) => result.split(zh).join(escapeHtml(en)), text)}<`);
const actionMessages: Record<string, string> = {
  "連結不完整或已過期，請重新申請並開啟最新信件。": "The link is incomplete or expired. Request a new one and open the latest email.",
  "兩次輸入的密碼不一致。": "The passwords do not match.", "處理中…": "Processing…",
  "服務目前無法完成，請稍後重試；這不代表連結已過期。": "The service cannot complete this now. Try again later; this does not mean the link has expired.",
  "請求過於頻繁，請稍後重試。": "Too many requests. Please try again later.", "請完成必填資料與確認欄位。": "Complete the required fields and confirmations.",
  "服務說明已更新，請回到 App 重新申請。": "The service notice has changed. Return to the app and request a new link.", "連結可能已過期或使用過，請重新申請。": "The link may have expired or been used. Please request a new one.",
  "監護人同意已完成，請使用者回到 App 更新狀態。": "Guardian approval is complete. Ask the user to return to the app to refresh their status.",
  "同意已撤回。": "Approval withdrawn.", "密碼已更新，請回到 App 登入。": "Password updated. Return to the app to sign in.",
  "驗證完成，請回到 App 選擇我已完成驗證。": "Email verified. Return to the app and select the option to check verification.",
  "目前無法連線，請檢查網路後重試。": "Unable to connect. Check your connection and try again.",
  "若資料符合有效的監護人同意，系統會寄送新的撤回連結。": "If the details match valid guardian approval, a new withdrawal link will be emailed.",
  "目前無法完成，請稍後重試。": "Unable to complete this now. Please try again later.", "目前無法連線，請稍後重試。": "Unable to connect. Please try again later.",
};
