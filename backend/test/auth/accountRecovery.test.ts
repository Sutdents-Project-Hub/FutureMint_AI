import { createHash } from "node:crypto";
import { describe, expect, it } from "vitest";
import { InMemoryRepository } from "../../src/adapters/inMemoryRepository";
import { AuthService } from "../../src/auth/authService";
import type { AccountMailPurpose } from "../../src/auth/accountMailer";

const credentials = { email: "student@example.com", password: "futuremint2026" };
const hash = (token: string) => createHash("sha256").update(token).digest("base64url");
function fixture() {
  const repository = new InMemoryRepository();
  const mail: Array<{ to: string; purpose: AccountMailPurpose; token: string }> = [];
  let current = new Date("2026-09-01T00:00:00Z");
  const service = new AuthService(repository, () => current, {
    requireEmailVerification: true,
    mailer: { send: async (to, purpose, token) => { mail.push({ to, purpose, token }); } },
  });
  return { repository, service, mail, advance: () => { current = new Date(current.getTime() + 31 * 60_000); } };
}

describe("account recovery", () => {
  it("requires verification, persists only a token hash, and consumes links once", async () => {
    const { service, repository, mail } = fixture();
    const registered = await service.register(credentials);
    expect(registered.account).toMatchObject({ verificationRequired: true, emailVerified: false });
    expect(mail[0]).toMatchObject({ to: credentials.email, purpose: "verify-email" });
    expect(mail[0].token).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(await repository.consumeEmailVerification(mail[0].token, "2026-09-01T00:00:00Z")).toBe(false);
    await expect(service.verifyEmail(mail[0].token)).resolves.toEqual({ verified: true });
    await expect(service.verifyEmail(mail[0].token)).rejects.toMatchObject({ code: "invalid_action_token" });
    expect(await service.authenticate(registered.token)).toMatchObject({ emailVerified: true, verificationRequired: false });
    await service.requestEmailVerification(registered.account.id);
    expect(mail).toHaveLength(1);
  });

  it("invalidates older verification links on resend and rejects expired links", async () => {
    const { service, mail, advance } = fixture();
    const { account } = await service.register(credentials);
    await service.requestEmailVerification(account.id);
    await expect(service.verifyEmail(mail[0].token)).rejects.toMatchObject({ code: "invalid_action_token" });
    advance();
    await expect(service.verifyEmail(mail[1].token)).rejects.toMatchObject({ code: "invalid_action_token" });
  });

  it("reset is single-use, rotates credentials, revokes all sessions and rejects a stale login write", async () => {
    const { service, repository, mail } = fixture();
    const first = await service.register(credentials);
    const second = await service.login(credentials);
    const oldAccount = (await repository.findAccountById(first.account.id))!;
    expect(await service.requestPasswordReset({ email: "missing@example.com" })).toEqual({ accepted: true });
    expect(await service.requestPasswordReset({ email: " STUDENT@example.com " })).toEqual({ accepted: true });
    const reset = mail.at(-1)!;
    expect(reset.purpose).toBe("reset-password");
    await expect(service.verifyEmail(reset.token)).rejects.toMatchObject({ code: "invalid_action_token" });
    const attempts = await Promise.allSettled([
      service.resetPassword(reset.token, "new-password2026"),
      service.resetPassword(reset.token, "new-password2026"),
    ]);
    expect(attempts.filter((result) => result.status === "fulfilled")).toHaveLength(1);
    for (const session of [first, second]) await expect(service.authenticate(session.token)).rejects.toMatchObject({ code: "unauthorized" });
    await expect(service.login(credentials)).rejects.toMatchObject({ code: "invalid_credentials" });
    await expect(service.login({ ...credentials, password: "new-password2026" })).resolves.toHaveProperty("token");
    await expect(repository.createSession({ id: "stale", userId: first.account.id, tokenHash: hash("stale"), createdAt: "2026-09-01T00:00:00Z", expiresAt: "2026-09-08T00:00:00Z" }, oldAccount.passwordHash)).rejects.toMatchObject({ code: "invalid_credentials" });
  });

  it("preserves the new account when SMTP fails without exposing delivery errors or account existence", async () => {
    const repository = new InMemoryRepository();
    const service = new AuthService(repository, undefined, { requireEmailVerification: true,
      mailer: { send: async () => { throw new Error("secret SMTP internals"); } } });
    const registered = await service.register(credentials);
    expect(registered).toMatchObject({ emailDeliveryPending: true, account: { verificationRequired: true } });
    await expect(service.requestEmailVerification(registered.account.id)).rejects.toMatchObject({ code: "mail_unavailable" });
    expect(await service.requestPasswordReset({ email: credentials.email })).toEqual(await service.requestPasswordReset({ email: "missing@example.com" }));
    expect(await repository.deleteExpiredAccountActionTokens("2099-01-01T00:00:00Z")).toBe(0);
  });

  it("cleanup is bounded and leaves active sessions and action links intact", async () => {
    const { service, repository, mail } = fixture();
    const active = await service.register(credentials);
    for (let i = 0; i < 3; i++) await repository.createSession({ id: `${i}`, tokenHash: `${i}`, userId: active.account.id, createdAt: "2026-08-01T00:00:00Z", expiresAt: "2026-08-08T00:00:00Z" });
    expect(await repository.deleteExpiredOrRevokedSessions("2026-09-01T00:00:00Z", 2)).toBe(2);
    expect(await repository.deleteExpiredOrRevokedSessions("2026-09-01T00:00:00Z", 2)).toBe(1);
    await expect(service.authenticate(active.token)).resolves.toHaveProperty("id");
    expect(await repository.deleteExpiredAccountActionTokens("2026-09-01T00:00:00Z")).toBe(0);
    expect(await repository.consumeEmailVerification(hash(mail[0].token), "2026-09-01T00:00:00Z")).toBe(true);
  });
});
