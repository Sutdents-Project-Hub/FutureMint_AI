import type { FastifyInstance } from "fastify";
import type { PublicConfig } from "../config/publicConfig";

const escapeHtml = (value: string): string => value.replace(/[&<>"']/g,
  (character) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[character]!);
const page = (title: string, content: string, script = false): string => `<!doctype html>
<html lang="zh-Hant-TW"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title}｜FutureMint AI</title><link rel="stylesheet" href="/public.css">${script ? '<script src="/account-actions.js" defer></script>' : ''}</head>
<body><main><a href="/support">FutureMint AI</a><h1>${title}</h1>${content}<footer><a href="/privacy">隱私權政策</a> · <a href="/support">聯絡支援</a></footer></main></body></html>`;
const publicCsp = "default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; form-action 'none'; base-uri 'none'; frame-ancestors 'none'";

export interface PublicServicePolicy { servicePolicyVersion: string; mailEnabled?: boolean; registrationEnabled?: boolean; ai: { displayName: string; dataRecipients: string[]; dataTerms: string; }; }
export const registerPublicPages = (app: FastifyInstance, config?: PublicConfig, policy?: PublicServicePolicy): void => {
  const providerName = escapeHtml(policy?.ai.displayName ?? "量界智算");
  const recipients = escapeHtml(policy?.ai.dataRecipients.join("、") ?? "量界智算及已揭露的上游");
  const html = (path: string, title: string, content: string, status = 200, script = false) => {
    app.get(path, async (_request, reply) => reply.code(status)
      .header("content-security-policy", publicCsp).type("text/html; charset=utf-8").send(page(title, content, script)));
  };
  app.get("/public.css", async (_request, reply) => reply.type("text/css; charset=utf-8").send(`
:root{color-scheme:light dark;font-family:system-ui,sans-serif;line-height:1.7}body{margin:0;background:#121a24;color:#f5f7fa}main{max-width:48rem;margin:auto;padding:2rem 1.25rem}h1{line-height:1.25}h2{font-size:1.25rem;margin-top:2rem}a{color:#7ce4c6}label,input,button{display:block}input[type=checkbox]{width:auto;display:inline}input:not([type=checkbox]){box-sizing:border-box;width:100%;padding:.8rem;margin:.5rem 0 1rem;font:inherit}button{padding:.8rem 1.2rem;background:#7ce4c6;color:#12202b;border:0;border-radius:.5rem;font:inherit;cursor:pointer}button:disabled{opacity:.6}footer{margin-top:3rem;border-top:1px solid #52606d;padding-top:1rem}#status{min-height:2em}a:focus-visible,input:focus-visible,button:focus-visible{outline:3px solid #f4bd62;outline-offset:3px}
`));
  if (!config?.reviewed) {
    html("/privacy", "隱私權政策準備中", "<p>營運資訊尚未完成確認，正式服務尚未開放。</p>", 503);
    html("/support", "服務準備中", "<p>公開客服與營運資訊尚未完成設定，請勿在此環境輸入真實個人資料。</p>", 503);
  } else {
    const e = escapeHtml;
    const backupDisclosure = config.backupRetentionDays > 0
      ? `備份最多保留 ${config.backupRetentionDays} 天。`
      : "此部署不建立定期資料庫備份。";
    const accountHelp = policy?.mailEnabled
      ? "忘記密碼時，請在 App 登入畫面選擇「忘記密碼」。驗證信或重設信的連結有效期限為 30 分鐘；重新申請後請使用最新的一封。"
      : "此部署未啟用寄信及新帳號註冊。可先使用訪客模式；既有帳號仍可登入，但未驗證的帳號仍須完成驗證。無法寄送新的驗證、密碼重設或監護人確認信，請聯絡客服。";
    html("/support", "聯絡支援", `<p>營運者：${e(config.operator)}</p><p>客服信箱：<a href="mailto:${e(config.supportEmail)}">${e(config.supportEmail)}</a></p><h2>登入與帳號</h2><p>${accountHelp}</p><h2>刪除帳號</h2><p>在 App 設定選擇刪除帳號，輸入目前密碼並確認，即可刪除帳號及其個人資料。無法登入時請聯絡客服協助確認身分。</p><p>請提供發生問題的步驟及 App 版本；請勿寄送密碼、驗證連結或完整交易明細。</p>`);
    html("/privacy", "隱私權政策", `<p>版本：${e(config.policyVersion)}</p><p>營運者：${e(config.operator)}；聯絡方式：<a href="mailto:${e(config.supportEmail)}">${e(config.supportEmail)}</a></p>
<h2>資料與用途</h2><p>帳號功能保存電子郵件、加鹽雜湊密碼、驗證狀態及登入工作階段。預算、目標、主動確認的收入／支出／訂閱、課程進度、虛擬投資資料與家庭關聯，用於提供你選擇的功能。系統不串接銀行、支付、電子發票或真實交易。</p>
<h2>AI 資料處理</h2><p>啟用第三方 AI 前會另外徵求同意。解析功能將你輸入的文字、語系及參考時間送往${providerName}；教育選題只送出分類摘要與目標是否存在等資訊；陪讀選題會送出你輸入的問題及主題。請勿輸入姓名、聯絡方式或其他人的資料。</p><p>模型只為教育內容選題，畫面教學文字由受控教材提供。數值由程式計算，並非投資建議。你可在設定撤回 AI 同意；撤回後停止新的第三方 AI 請求，不影響手動記錄與已保存資料。</p><p>現行資料接收者：${recipients}。</p><p>${e(policy?.ai.dataTerms ?? "")}</p><p>${e(config.aiDataTerms)}</p>
<h2>家庭分享與未成年人</h2><p>孩子使用家長分享的邀請碼加入後，該家長可讀取預算、目標、可用金額與提醒數量摘要，不會取得逐筆交易；孩子可離開家庭停止後續分享。邀請碼有效期限為 24 小時，可由家長更新或停用。</p><p>臺灣服務最低使用年齡：15 歲。15–17 歲需另外完成監護人同意；申請時會寄送使用者帳號電子郵件給指定監護人以辨識申請。監護人確認信箱控制權並聲明成年及法定代理人身分，Email 確認本身不證明合法監護身分。家庭分享與 AI 同意各自獨立。${e(config.minorConsent)}</p>
<h2>保存與刪除</h2><p>資料存放地區：${e(config.dataRegion)}。帳號及業務資料保存至你刪除帳號；刪除後從使用中的資料庫移除，${backupDisclosure}為避免舊備份還原後帳號復活，另保存不含 Email 或帳務的帳號 ID 雜湊及刪除時間，直到相關舊備份副本已銷毀。登入憑證有效期限為 7 天；過期或撤回的憑證、一次性連結與限流記錄以定期維護分批清除。</p><p>iPhone 本機續費提醒須由使用者啟用；鎖定畫面不顯示金額或交易內容。遠端變更需回到 App 同步後才更新。原生 App 登入憑證存放於系統安全儲存空間；網頁版存於該瀏覽器。為確認未收到回應的操作，裝置另保存依帳號分隔的待確認訂閱或虛擬訂單；登出保留原操作，於同帳號再次登入確認，App 內刪除帳號時清除。訪客模式的理財資料僅在記憶體，結束或重新整理後清除。帳號刪除亦刪除家庭關聯，家長刪除帳號時解散其家庭。</p>
<h2>安全、權利與聯絡</h2><p>傳輸使用 HTTPS，後端驗證帳號與資料權限；請求限制用雜湊識別值降低濫用。應用程式不使用廣告追蹤。你可以在 App 查看、修改、匯出或刪除自己的資料；未完成監護人同意仍可讀取、匯出及刪除自己的既有資料。撤回 AI 或監護人同意會阻擋新的相關請求，已開始的操作可能完成；其他資料請求或隱私疑問請聯絡上述客服。</p>`);
  }
  html("/account/verify", "驗證電子郵件", '<p>請點擊下方按鈕確認這是你的電子郵件地址。</p><form id="action-form" data-action="email-verification"><button type="submit">確認驗證</button></form><p id="status" role="status" aria-live="polite"></p>', 200, true);
  html("/account/reset-password", "重設密碼", '<p>設定新密碼後，其他裝置會需要重新登入。</p><form id="action-form" data-action="password-reset"><label for="password">新密碼（12 至 128 個字元，需含英文字母與數字）</label><input id="password" type="password" autocomplete="new-password" minlength="12" maxlength="128" required><label for="confirmation">再次輸入新密碼</label><input id="confirmation" type="password" autocomplete="new-password" minlength="12" maxlength="128" required><button type="submit">儲存新密碼</button></form><p id="status" role="status" aria-live="polite"></p>', 200, true);
  const policyVersion = escapeHtml(policy?.servicePolicyVersion ?? "tw-service-age-15-v1");
  html("/account/guardian-consent", "監護人同意", `<p>本服務為 15 歲以上的教育性記帳與金錢決策練習。請先與信中提出申請的使用者確認身分，並閱讀<a href="/privacy">隱私權政策</a>。此同意不加入家庭、不共享交易明細，也不啟用第三方 AI。</p><p>Email 確認本身不證明法定代理人身分。</p><form id="action-form" data-action="guardian-consent" data-policy-version="${policyVersion}"><label><input id="adult" type="checkbox" required>我已滿 18 歲</label><label><input id="legal-guardian" type="checkbox" required>我是申請使用者的法定代理人，已與使用者確認這次申請</label><label><input id="accepted" type="checkbox" required>我已閱讀並同意此版本服務及隱私說明</label><button type="submit">確認同意</button></form><p id="status" role="status" aria-live="polite"></p>`, 200, true);
  html("/account/guardian-withdraw", "撤回監護人同意", `<p>撤回後停止新的正式資料輸入與外部 AI 請求；使用者仍可查看、匯出及刪除自己的資料。</p><form id="action-form" data-action="guardian-withdraw"><button type="submit">確認撤回</button></form><p id="status" role="status" aria-live="polite"></p><h2>連結已過期</h2><p>輸入原申請使用者及監護人的信箱，申請新的撤回連結。</p><form id="withdrawal-request"><label for="account-email">使用者信箱</label><input id="account-email" type="email" maxlength="254" required><label for="guardian-email">監護人信箱</label><input id="guardian-email" type="email" maxlength="254" required><button type="submit">寄送撤回連結</button></form><p id="request-status" role="status" aria-live="polite"></p>`, 200, true);
  app.get("/account-actions.js", async (_request, reply) => reply.type("application/javascript; charset=utf-8").send(`
"use strict";
const token = new URLSearchParams(location.hash.slice(1)).get("token");
history.replaceState(null, "", location.pathname);
const form = document.getElementById("action-form");
const status = document.getElementById("status");
const button = form.querySelector("button");
if (!token || !/^[A-Za-z0-9_-]{43}$/.test(token)) { button.disabled = true; status.textContent = "連結不完整或已過期，請重新申請並開啟最新信件。"; }
form.addEventListener("submit", async (event) => {
 event.preventDefault();
 const password = document.getElementById("password");
 const confirmation = document.getElementById("confirmation");
 if (password && password.value !== confirmation.value) { status.textContent = "兩次輸入的密碼不一致。"; return; }
 const guardian = form.dataset.action === "guardian-consent";
 const withdraw = form.dataset.action === "guardian-withdraw";
 const url = guardian ? "/api/privacy/guardian-consent/confirm" : withdraw ? "/api/privacy/guardian-consent/withdraw" : "/api/auth/" + form.dataset.action + "/confirm";
 const input = { token, ...(password ? { password: password.value } : {}), ...(guardian ? { policyVersion: form.dataset.policyVersion, adult: document.getElementById("adult").checked, legalGuardian: document.getElementById("legal-guardian").checked, accepted: document.getElementById("accepted").checked } : {}) };
 button.disabled = true; status.textContent = "處理中…";
 try {
  const response = await fetch(url, { method: "POST", credentials: "omit", headers: { "Content-Type": "application/json" }, body: JSON.stringify(input) });
  if (!response.ok) {
   status.textContent = response.status >= 500 ? "服務目前無法完成，請稍後重試；這不代表連結已過期。" : response.status === 429 ? "請求過於頻繁，請稍後重試。" : response.status === 422 ? "請完成必填資料與確認欄位。" : response.status === 409 ? "服務說明已更新，請回到 App 重新申請。" : "連結可能已過期或使用過，請重新申請。";
   button.disabled = false; return;
  }
  form.hidden = true; form.reset(); status.textContent = guardian ? "監護人同意已完成，請使用者回到 App 更新狀態。" : withdraw ? "同意已撤回。" : password ? "密碼已更新，請回到 App 登入。" : "驗證完成，請回到 App 選擇我已完成驗證。";
 } catch { status.textContent = "目前無法連線，請檢查網路後重試。"; button.disabled = false; }
});
const requestForm = document.getElementById("withdrawal-request");
if (requestForm) requestForm.addEventListener("submit", async (event) => {
 event.preventDefault(); const notice = document.getElementById("request-status"); const submit = requestForm.querySelector("button"); submit.disabled = true;
 try {
  const response = await fetch("/api/privacy/guardian-consent/withdrawal-request", { method:"POST", credentials:"omit", headers:{"Content-Type":"application/json"}, body:JSON.stringify({accountEmail:document.getElementById("account-email").value,guardianEmail:document.getElementById("guardian-email").value}) });
  notice.textContent = response.ok ? "若資料符合有效的監護人同意，系統會寄送新的撤回連結。" : "目前無法完成，請稍後重試。";
 } catch { notice.textContent="目前無法連線，請稍後重試。"; } finally { submit.disabled=false; }
});
`));
};
