import nodemailer, { type Transporter } from "nodemailer";
import { authCredentialsSchema } from "../contracts/schemas";
import { validatedHttpsUrl } from "../config/publicConfig";

export type AccountMailPurpose = "verify-email" | "reset-password";
export type MailPurpose = AccountMailPurpose | "guardian-approve" | "guardian-withdraw";
export interface GuardianMailContext { requesterEmail: string; }
export interface AccountMailer {
  send(to: string, purpose: MailPurpose, token: string, context?: GuardianMailContext): Promise<void>;
  close?(): void;
}

export const validateMailerConfig = (env: NodeJS.ProcessEnv = process.env): void => {
  if (env.MAIL_PROVIDER !== "smtp") {
    if (env.MAIL_PROVIDER && env.MAIL_PROVIDER !== "disabled") throw new Error("Invalid MAIL_PROVIDER");
    return;
  }
  for (const key of ["SMTP_HOST", "SMTP_USER", "SMTP_PASSWORD", "SMTP_FROM", "PUBLIC_BASE_URL"]) {
    if (!env[key]?.trim()) throw new Error(`${key} is required for SMTP`);
  }
  const port = Number(env.SMTP_PORT ?? 465);
  if (port !== 465 && port !== 587) throw new Error("SMTP_PORT must be 465 or 587 with TLS");
  validatedHttpsUrl(env.PUBLIC_BASE_URL!, "PUBLIC_BASE_URL", { requiredPath: "" });
  if (!/^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$/.test(env.SMTP_FROM!)) throw new Error("SMTP_FROM must be an email address");
  validatedHttpsUrl(`https://${env.SMTP_FROM!.split("@")[1]}`, "SMTP_FROM domain");

};

export const createAccountMailer = (env: NodeJS.ProcessEnv = process.env): AccountMailer | undefined => {
  validateMailerConfig(env);
  if (env.MAIL_PROVIDER !== "smtp") return undefined;
  const port = Number(env.SMTP_PORT ?? 465);
  const base = validatedHttpsUrl(env.PUBLIC_BASE_URL!, "PUBLIC_BASE_URL", { requiredPath: "" });
  const transport: Transporter = nodemailer.createTransport({
    host: env.SMTP_HOST!, port, secure: port === 465, requireTLS: true,
    auth: { user: env.SMTP_USER!, pass: env.SMTP_PASSWORD! },
    tls: { rejectUnauthorized: true, minVersion: "TLSv1.2" },
    connectionTimeout: 8000, greetingTimeout: 8000, socketTimeout: 10000,
    logger: false, debug: false, disableFileAccess: true, disableUrlAccess: true,
  });
  return {
    async send(to, purpose, token, context) {
      const verification = purpose === "verify-email";
      const guardian = purpose === "guardian-approve" || purpose === "guardian-withdraw";
      const requesterEmail = guardian ? authCredentialsSchema.shape.email.parse(context?.requesterEmail) : undefined;
      const guardianAccount = guardian ? `申請使用服務的帳號：${requesterEmail}。請先與該帳號使用者確認申請及你的法定代理人關係；不認識此帳號請忽略此信。\n\n` : "";
      const url = new URL(guardian ? (purpose === "guardian-approve" ? "/account/guardian-consent" : "/account/guardian-withdraw") : verification ? "/account/verify" : "/account/reset-password", base);
      // A fragment is not sent in GET requests or referrers. Only explicit form
      // submission consumes the token, so mail preview/scanner GETs are harmless.
      url.hash = new URLSearchParams({ token }).toString();
      await transport.sendMail({
        from: env.SMTP_FROM!, to,
        subject: guardian ? (purpose === "guardian-approve" ? "確認 FutureMint AI 監護人同意" : "FutureMint AI 監護人同意撤回入口") : verification ? "驗證你的 FutureMint AI 電子郵件" : "重設 FutureMint AI 密碼",
        text: `${guardianAccount}${guardian ? (purpose === "guardian-approve" ? "請閱讀服務與隱私說明；確認已成年且為法定代理人後，可同意使用服務。此流程不分享交易明細、不加入家庭，也不授權第三方 AI。電子郵件確認本身不證明法定代理人身分。" : "你可撤回使用服務的監護人同意。若連結過期，可在同頁以使用者及監護人電子郵件重新申請連結。") : verification ? "請確認這是你的電子郵件地址。" : "請設定新的密碼；完成後其他裝置將需要重新登入。"}\n\n${url.toString()}\n\n連結會在 30 分鐘後失效，且只能使用一次。若不是你提出的要求，可以忽略此信。請勿轉傳連結。`,
      });
    },
    close: () => transport.close(),
  };
};
