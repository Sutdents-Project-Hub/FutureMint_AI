import type { FastifyInstance } from "fastify";
import type { PublicConfig } from "../config/publicConfig";

const escapeHtml = (value: string): string => value.replace(/[&<>"']/g,
  (character) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[character]!);
const page = (title: string, content: string, script = false): string => `<!doctype html>
<html lang="zh-Hant-TW"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title}｜FutureMint AI</title><link rel="stylesheet" href="/public.css">${script ? '<script src="/account-actions.js" defer></script>' : ''}</head>
<body><main><a href="/support">FutureMint AI</a><h1>${title}</h1>${content}<footer><a href="/privacy">隱私權政策</a> · <a href="/support">聯絡支援</a></footer></main></body></html>`;
const publicCsp = "default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; form-action 'none'; base-uri 'none'; frame-ancestors 'none'";

export const registerPublicPages = (app: FastifyInstance, config?: PublicConfig): void => {
  const html = (path: string, title: string, content: string, status = 200, script = false) => {
    app.get(path, async (_request, reply) => reply.code(status)
      .header("content-security-policy", publicCsp).type("text/html; charset=utf-8").send(page(title, content, script)));
  };
  app.get("/public.css", async (_request, reply) => reply.type("text/css; charset=utf-8").send(`
:root{color-scheme:light dark;font-family:system-ui,sans-serif;line-height:1.7}body{margin:0;background:#121a24;color:#f5f7fa}main{max-width:48rem;margin:auto;padding:2rem 1.25rem}h1{line-height:1.25}h2{font-size:1.25rem;margin-top:2rem}a{color:#7ce4c6}label,input,button{display:block}input{box-sizing:border-box;width:100%;padding:.8rem;margin:.5rem 0 1rem;font:inherit}button{padding:.8rem 1.2rem;background:#7ce4c6;color:#12202b;border:0;border-radius:.5rem;font:inherit;cursor:pointer}button:disabled{opacity:.6}footer{margin-top:3rem;border-top:1px solid #52606d;padding-top:1rem}#status{min-height:2em}a:focus-visible,input:focus-visible,button:focus-visible{outline:3px solid #f4bd62;outline-offset:3px}
`));
  if (!config?.reviewed) {
    html("/privacy", "隱私權政策準備中", "<p>營運資訊尚未完成確認，正式服務尚未開放。</p>", 503);
    html("/support", "服務準備中", "<p>公開客服與營運資訊尚未完成設定，請勿在此環境輸入真實個人資料。</p>", 503);
  } else {
    const e = escapeHtml;
    html("/support", "聯絡支援", `<p>營運者：${e(config.operator)}</p><p>客服信箱：<a href="mailto:${e(config.supportEmail)}">${e(config.supportEmail)}</a></p><h2>登入與帳號</h2><p>忘記密碼時，請在 App 登入畫面選擇「忘記密碼」。驗證信或重設信的連結有效期限為 30 分鐘；重新申請後請使用最新的一封。</p><h2>刪除帳號</h2><p>在 App 設定選擇刪除帳號，輸入目前密碼並確認，即可刪除帳號及其個人資料。無法登入時請先重設密碼，或聯絡客服協助確認身分。</p><p>請提供發生問題的步驟及 App 版本；請勿寄送密碼、驗證連結或完整交易明細。</p>`);
    html("/privacy", "隱私權政策", `<p>版本：${e(config.policyVersion)}</p><p>營運者：${e(config.operator)}；聯絡方式：<a href="mailto:${e(config.supportEmail)}">${e(config.supportEmail)}</a></p>
<h2>資料與用途</h2><p>帳號功能保存電子郵件、加鹽雜湊密碼、驗證狀態及登入工作階段。預算、目標、主動確認的收入／支出／訂閱、課程進度、虛擬投資資料與家庭關聯，用於提供你選擇的功能。系統不串接銀行、支付、電子發票或真實交易。</p>
<h2>AI 資料處理</h2><p>啟用第三方 AI 前會另外徵求同意。解析功能將你輸入的文字、語系及參考時間送往量界智算；教育選題只送出分類摘要與目標是否存在等資訊；陪讀選題會送出你輸入的問題及主題。請勿輸入姓名、聯絡方式或其他人的資料。</p><p>模型只為教育內容選題，畫面教學文字由受控教材提供。數值由程式計算，並非投資建議。你可在設定撤回 AI 同意；撤回後停止新的第三方 AI 請求，不影響手動記錄與已保存資料。</p><p>${e(config.aiDataTerms)}</p>
<h2>家庭分享與未成年人</h2><p>孩子使用家長分享的邀請碼加入後，該家長可讀取預算、目標、可用金額與提醒數量摘要，不會取得逐筆交易；孩子可離開家庭停止後續分享。邀請碼有效期限為 24 小時，可由家長更新或停用。</p><p>最低使用年齡：${config.minimumAge} 歲。${e(config.minorConsent)}</p>
<h2>保存與刪除</h2><p>資料存放地區：${e(config.dataRegion)}。帳號及業務資料保存至你刪除帳號；刪除後從使用中的資料庫移除，備份最多保留 ${config.backupRetentionDays} 天。登入憑證有效期限為 7 天；過期或撤回的憑證、一次性連結與限流記錄以定期維護分批清除。</p><p>原生 App 登入憑證存放於系統安全儲存空間；網頁版存於該瀏覽器。訪客模式的理財資料僅在記憶體，結束或重新整理後清除。帳號刪除亦刪除家庭關聯，家長刪除帳號時解散其家庭。</p>
<h2>安全、權利與聯絡</h2><p>傳輸使用 HTTPS，後端驗證帳號與資料權限；請求限制用雜湊識別值降低濫用。應用程式不使用廣告追蹤。你可以在 App 查看、修改或刪除自己的紀錄；其他資料請求或隱私疑問請聯絡上述客服。</p>`);
  }
  html("/account/verify", "驗證電子郵件", '<p>請點擊下方按鈕確認這是你的電子郵件地址。</p><form id="action-form" data-action="email-verification"><button type="submit">確認驗證</button></form><p id="status" role="status" aria-live="polite"></p>', 200, true);
  html("/account/reset-password", "重設密碼", '<p>設定新密碼後，其他裝置會需要重新登入。</p><form id="action-form" data-action="password-reset"><label for="password">新密碼（12 至 128 個字元，需含英文字母與數字）</label><input id="password" type="password" autocomplete="new-password" minlength="12" maxlength="128" required><label for="confirmation">再次輸入新密碼</label><input id="confirmation" type="password" autocomplete="new-password" minlength="12" maxlength="128" required><button type="submit">儲存新密碼</button></form><p id="status" role="status" aria-live="polite"></p>', 200, true);
  app.get("/account-actions.js", async (_request, reply) => reply.type("application/javascript; charset=utf-8").send(`
"use strict";
const token = new URLSearchParams(location.hash.slice(1)).get("token");
history.replaceState(null, "", location.pathname);
const form = document.getElementById("action-form");
const status = document.getElementById("status");
const button = form.querySelector("button");
if (!token || !/^[A-Za-z0-9_-]{43}$/.test(token)) { button.disabled = true; status.textContent = "連結不完整，請從 App 重新申請並開啟最新信件。"; }
form.addEventListener("submit", async (event) => {
 event.preventDefault();
 const password = document.getElementById("password");
 const confirmation = document.getElementById("confirmation");
 if (password && password.value !== confirmation.value) { status.textContent = "兩次輸入的密碼不一致。"; return; }
 button.disabled = true; status.textContent = "處理中…";
 try {
  const response = await fetch("/api/auth/" + form.dataset.action + "/confirm", { method: "POST", credentials: "omit", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ token, ...(password ? { password: password.value } : {}) }) });
  if (!response.ok) { status.textContent = response.status === 429 ? "請求過於頻繁，請稍後重試。" : response.status === 422 ? "密碼需為 12 至 128 個字元，且包含英文字母與數字。" : "連結可能已過期或使用過，請回到 App 重新申請。"; button.disabled = false; return; }
  form.hidden = true; form.reset(); status.textContent = password ? "密碼已更新，請回到 App 使用新密碼登入。" : "驗證完成，請回到 App 選擇「我已完成驗證」。";
 } catch { status.textContent = "目前無法連線，請檢查網路後重試。"; button.disabled = false; }
});
`));
};
