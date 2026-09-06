import nodemailer, { type Transporter } from "nodemailer";
import { validatedHttpsUrl } from "../config/publicConfig";

export type AccountMailPurpose = "verify-email" | "reset-password";
export interface AccountMailer {
  send(to: string, purpose: AccountMailPurpose, token: string): Promise<void>;
  close?(): void;
}

export const createAccountMailer = (env: NodeJS.ProcessEnv = process.env): AccountMailer | undefined => {
  if (env.MAIL_PROVIDER !== "smtp") {
    if (env.NODE_ENV === "production") throw new Error("Production requires MAIL_PROVIDER=smtp");
    if (env.MAIL_PROVIDER && env.MAIL_PROVIDER !== "disabled") throw new Error("Invalid MAIL_PROVIDER");
    return undefined;
  }
  for (const key of ["SMTP_HOST", "SMTP_USER", "SMTP_PASSWORD", "SMTP_FROM", "PUBLIC_BASE_URL"]) {
    if (!env[key]?.trim()) throw new Error(`${key} is required for SMTP`);
  }
  const port = Number(env.SMTP_PORT ?? 465);
  if (port !== 465 && port !== 587) throw new Error("SMTP_PORT must be 465 or 587 with TLS");
  const base = validatedHttpsUrl(env.PUBLIC_BASE_URL!, "PUBLIC_BASE_URL", { requiredPath: "" });
  if (!/^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$/.test(env.SMTP_FROM!)) throw new Error("SMTP_FROM must be an email address");
  validatedHttpsUrl(`https://${env.SMTP_FROM!.split("@")[1]}`, "SMTP_FROM domain");
  const transport: Transporter = nodemailer.createTransport({
    host: env.SMTP_HOST!, port, secure: port === 465, requireTLS: true,
    auth: { user: env.SMTP_USER!, pass: env.SMTP_PASSWORD! },
    tls: { rejectUnauthorized: true, minVersion: "TLSv1.2" },
    connectionTimeout: 8000, greetingTimeout: 8000, socketTimeout: 10000,
    logger: false, debug: false, disableFileAccess: true, disableUrlAccess: true,
  });
  return {
    async send(to, purpose, token) {
      const verification = purpose === "verify-email";
      const url = new URL(verification ? "/account/verify" : "/account/reset-password", base);
      // A fragment is not sent in GET requests or referrers. Only explicit form
      // submission consumes the token, so mail preview/scanner GETs are harmless.
      url.hash = new URLSearchParams({ token }).toString();
      await transport.sendMail({
        from: env.SMTP_FROM!, to,
        subject: verification ? "驗證你的 FutureMint AI 電子郵件" : "重設 FutureMint AI 密碼",
        text: `${verification ? "請確認這是你的電子郵件地址。" : "請設定新的密碼；完成後其他裝置將需要重新登入。"}\n\n${url.toString()}\n\n連結會在 30 分鐘後失效，且只能使用一次。若不是你提出的要求，可以忽略此信。請勿轉傳連結。`,
      });
    },
    close: () => transport.close(),
  };
};
