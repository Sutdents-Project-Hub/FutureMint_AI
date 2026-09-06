import { afterEach, describe, expect, it } from "vitest";
import type { FastifyInstance } from "fastify";
import { InMemoryRepository } from "../../src/adapters/inMemoryRepository";
import { DemoAiProvider } from "../../src/adapters/demoAiProvider";
import { demoCatalog } from "../../src/adapters/demoCatalog";
import { FutureMintService } from "../../src/application/futureMintService";
import { AuthService } from "../../src/auth/authService";
import type { AccountMailer } from "../../src/auth/accountMailer";
import { buildServer } from "../../src/http/server";
import { parseTrustedProxies, readPublicConfig, validatedHttpsUrl } from "../../src/config/publicConfig";

const apps: FastifyInstance[] = [];
afterEach(async () => { await Promise.all(apps.splice(0).map((app) => app.close())); });
const makeApp = async (repository = new InMemoryRepository(), mailer?: AccountMailer) => {
  const app = await buildServer({ logger: false, allowedOrigins: [], runtime: {
    mode: "demo", aiProvider: "demo", dataProvider: "memory",
    service: new FutureMintService(repository, new DemoAiProvider(), demoCatalog),
    authService: new AuthService(repository, undefined, { mailer, requireEmailVerification: Boolean(mailer) }),
    rateLimitStore: repository, healthCheck: async () => undefined, close: async () => undefined,
  }});
  apps.push(app); return app;
};
describe("production configuration and public account recovery", () => {
  it("rejects placeholder, private, insecure and credential-bearing URLs", () => {
    for (const value of ["http://liangjiewis.com/v1", "https://127.0.0.1", "https://[::1]", "https://example.com", "https://a.test", "https://a.internal", "https://api..tw", "https://live.org.", "https://name:pass@live.org", "https://live.org/path?secret=x"]) {
      expect(() => validatedHttpsUrl(value, "test")).toThrow();
    }
    expect(validatedHttpsUrl("https://fcloud.org", "test").hostname).toBe("fcloud.org");
    expect(() => validatedHttpsUrl("https://elsewhere.org/v1", "AI", { allowedHosts: ["liangjiewis.com"] })).toThrow();
  });
  it("fails closed before production without reviewed operational disclosures", () => {
    expect(() => readPublicConfig({ NODE_ENV: "production" })).toThrow("PUBLIC_BASE_URL");
    expect(() => readPublicConfig({ PRIVACY_POLICY_REVIEWED: "true" })).toThrow();
    expect(() => readPublicConfig({ NODE_ENV: "production", PUBLIC_BASE_URL: "https://live.org", SUPPORT_EMAIL: "support@live.org", SERVICE_OPERATOR: "未定" })).toThrow("SERVICE_OPERATOR");
    expect(parseTrustedProxies(undefined)).toBe(false);
    expect(parseTrustedProxies("10.0.0.2,172.18.0.0/24")).toEqual(["10.0.0.2", "172.18.0.0/24"]);
    for (const value of ["1", "true", "0.0.0.0/0", "::/0", "localhost", "10.0.0.0/33"]) expect(() => parseTrustedProxies(value)).toThrow();
  });
  it("shares IP limits across server instances and ignores spoofed forwarding headers", async () => {
    const repository = new InMemoryRepository();
    const first = await makeApp(repository); const second = await makeApp(repository);
    for (let i = 0; i < 10; i++) {
      const result = await (i % 2 ? first : second).inject({ method: "POST", url: "/api/auth/login", headers: { "x-forwarded-for": `198.51.100.${i}` }, payload: { email: `missing${i}@example.com`, password: "test-password2026" } });
      expect(result.statusCode).toBe(401);
    }
    expect((await second.inject({ method: "POST", url: "/api/auth/login", payload: { email: "another@example.com", password: "test-password2026" } })).statusCode).toBe(429);
    expect((await second.inject({ method: "GET", url: "/api/health" })).statusCode).toBe(200);
  });
  it("allows verification recovery but gates profile access until ownership is confirmed", async () => {
    let verificationToken = "";
    const app = await makeApp(undefined, { send: async (_to, purpose, token) => { if (purpose === "verify-email") verificationToken = token; } });
    const registered = await app.inject({ method: "POST", url: "/api/auth/register", payload: { email: "synthetic@example.com", password: "test-password2026" } });
    expect(registered.statusCode).toBe(201);
    const authorization = `Bearer ${registered.json().data.token}`;
    expect((await app.inject({ url: "/api/auth/me", headers: { authorization } })).statusCode).toBe(200);
    expect((await app.inject({ url: "/api/profile", headers: { authorization } })).statusCode).toBe(403);
    expect((await app.inject({ method: "POST", url: "/api/auth/email-verification/confirm", payload: { token: verificationToken } })).statusCode).toBe(200);
    expect((await app.inject({ url: "/api/money-events", headers: { authorization } })).statusCode).toBe(200);
  });
  it("serves scanner-safe recovery forms without consuming any token on GET", async () => {
    const app = await makeApp();
    const response = await app.inject({ url: "/account/reset-password" });
    expect(response.statusCode).toBe(200);
    expect(response.body).toContain('autocomplete="new-password"');
    expect(response.headers["content-security-policy"]).toContain("script-src 'self'");
    expect(response.headers["referrer-policy"]).toBe("no-referrer");
    const script = await app.inject({ url: "/account-actions.js" });
    expect(script.body).toContain("location.hash");
    expect(script.body).toContain("history.replaceState");
    expect(script.body).toContain('form.addEventListener("submit"');
    expect((await app.inject({ url: "/privacy" })).statusCode).toBe(503);
  });
  it("completes password recovery and revokes the old session without returning tokens", async () => {
    let actionToken = "";
    const app = await makeApp(undefined, { send: async (_to, purpose, token) => { if (purpose === "reset-password") actionToken = token; } });
    const registered = await app.inject({ method: "POST", url: "/api/auth/register", payload: { email: "reset@example.com", password: "test-password2026" } });
    const authorization = `Bearer ${registered.json().data.token}`;
    const accepted = await app.inject({ method: "POST", url: "/api/auth/password-reset/request", payload: { email: "reset@example.com" } });
    expect(accepted.statusCode).toBe(200);
    expect(accepted.body).not.toContain(actionToken);
    const reset = await app.inject({ method: "POST", url: "/api/auth/password-reset/confirm", payload: { token: actionToken, password: "new-password2026" } });
    expect(reset.statusCode).toBe(200);
    expect((await app.inject({ url: "/api/auth/me", headers: { authorization } })).statusCode).toBe(401);
    expect((await app.inject({ method: "POST", url: "/api/auth/login", payload: { email: "reset@example.com", password: "new-password2026" } })).statusCode).toBe(200);
    expect((await app.inject({ method: "POST", url: "/api/auth/password-reset/confirm", payload: { token: actionToken, password: "other-password2026" } })).statusCode).toBe(400);
  });

});
