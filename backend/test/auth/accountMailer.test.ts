import nodemailer from "nodemailer";
import { describe, expect, it, vi } from "vitest";
import { createAccountMailer, validateMailerConfig } from "../../src/auth/accountMailer";
const env = { NODE_ENV: "test", MAIL_PROVIDER: "smtp", SMTP_HOST: "synthetic.mail.local", SMTP_USER: "synthetic", SMTP_PASSWORD: "synthetic-only", SMTP_FROM: "synthetic@futuremint.ai", PUBLIC_BASE_URL: "https://futuremint.ai" };
describe("guardian mail", () => {
  it("validates SMTP configuration without allocating a transport", () => {
    const transport = vi.spyOn(nodemailer, "createTransport");
    try { validateMailerConfig(env); expect(transport).not.toHaveBeenCalled(); }
    finally { transport.mockRestore(); }
  });
  it("identifies the requesting account and asks guardians to check the relationship, using a fragment token", async () => {
    const sendMail = vi.fn().mockResolvedValue({});
    const transport = vi.spyOn(nodemailer, "createTransport").mockReturnValue({ sendMail, close: vi.fn() } as never);
    try {
      const mailer = createAccountMailer(env)!;
      await mailer.send("guardian@example.invalid", "guardian-approve", "synthetic-token", { requesterEmail: "minor@example.invalid" });
      const message = sendMail.mock.calls[0][0];
      expect(message.text).toContain("申請使用服務的帳號：minor@example.invalid");
      expect(message.text).toContain("請先與該帳號使用者確認申請及你的法定代理人關係");
      expect(message.text).toContain("/account/guardian-consent#token=synthetic-token");
      expect(message).not.toHaveProperty("html");
      await mailer.send("guardian@example.invalid", "guardian-withdraw", "synthetic-withdraw", { requesterEmail: "minor@example.invalid" });
      expect(sendMail.mock.calls[1][0].text).toContain("申請使用服務的帳號：minor@example.invalid");
      expect(sendMail.mock.calls[1][0].text).toContain("/account/guardian-withdraw#token=synthetic-withdraw");
      await expect(mailer.send("guardian@example.invalid", "guardian-approve", "synthetic-token")).rejects.toHaveProperty("issues");
      expect(sendMail).toHaveBeenCalledTimes(2);
    } finally { transport.mockRestore(); }
  });
});
