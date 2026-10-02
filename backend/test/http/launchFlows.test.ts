import { afterEach, describe, expect, it } from "vitest";
import type { FastifyInstance } from "fastify";
import { InMemoryRepository } from "../../src/adapters/inMemoryRepository";
import { DemoAiProvider } from "../../src/adapters/demoAiProvider";
import { InMemoryEligibilityStore } from "../../src/adapters/eligibilityStore";
import { demoCatalog } from "../../src/adapters/demoCatalog";
import { EducationalMarketDataProvider } from "../../src/adapters/twseMarketDataProvider";
import { FutureMintService } from "../../src/application/futureMintService";
import { AuthService } from "../../src/auth/authService";
import { AiRequestGate } from "../../src/application/aiRequestGate";
import { servicePolicyVersion } from "../../src/contracts/servicePolicy";
import { buildServer } from "../../src/http/server";
const apps: FastifyInstance[] = [];
afterEach(async () => { await Promise.all(apps.splice(0).map((app) => app.close())); });
const credentials = (email: string, ageBand = "18-plus") => ({ email, password: "synthetic-test-2026", ageDeclaration: { ageBand, policyVersion: servicePolicyVersion, accepted: true } });
const make = async ({ mailEnabled = true, requireEmailVerification = false } = {}) => {
  const repository = new InMemoryRepository(); const tokens = new Map<string, string>();
  const policy = { provider: "openai" as const, providerName: "OpenAI", model: "gpt-4.1-mini", recipients: ["OpenAI"], dataTerms: "合成測試條款", reviewed: true, policyVersion: "openai-test-policy-v1" };
  const app = await buildServer({ logger: false, allowedOrigins: [], runtime: { mode: "hosted", aiProvider: "openai", dataProvider: "memory", aiPolicy: policy, eligibilityRequired: true,
    aiGate: new AiRequestGate({ dailyUser: 2, dailyGlobal: 5, concurrency: 1, leaseMs: 17000 }),
    service: new FutureMintService(repository, new DemoAiProvider(), demoCatalog, new EducationalMarketDataProvider()),
    authService: new AuthService(repository, undefined, { eligibilityStore: new InMemoryEligibilityStore(), requireEligibility: true, aiPolicyVersion: policy.policyVersion,
      requireEmailVerification,
      mailer: mailEnabled ? { send: async (_to, purpose, token) => { tokens.set(purpose, token); } } : undefined }), rateLimitStore: repository, healthCheck: async () => undefined, close: async () => undefined } });
  apps.push(app); return { app, tokens, policy };
};
const registration = async (app: FastifyInstance, email: string, ageBand = "18-plus") => {
  const response = await app.inject({ method: "POST", url: "/api/auth/register", payload: credentials(email, ageBand), remoteAddress: "127.0.0.2" });
  expect(response.statusCode).toBe(201); return { authorization: "Bearer " + response.json().data.token };
};
describe("launch API integration", () => {
  it("completes verified parent and minor lifecycle while keeping consent, sharing and recovery independent", async () => {
    const { app, tokens } = await make({ requireEmailVerification: true });
    const profile = (accountRole: "parent" | "child") => ({
      accountRole, monthlyBudgetMinor: 600000, goalName: "合成目標", goalTargetMinor: 1000000,
      goalSavedMinor: 0, goalDate: "2027-01-01", preferredTone: "supportive",
    });
    const verify = async () => {
      expect((await app.inject({ method: "POST", url: "/api/auth/email-verification/confirm", payload: { token: tokens.get("verify-email") } })).statusCode).toBe(200);
    };
    const parent = await registration(app, "parent-lifecycle@example.com");
    await verify();
    expect((await app.inject({ method: "PUT", url: "/api/profile", headers: parent, payload: profile("parent") })).statusCode).toBe(200);
    const invite = await app.inject({ method: "POST", url: "/api/family/invite", headers: parent });
    expect(invite.statusCode).toBe(201);
    const inviteCode = invite.json().data.inviteCode;
    const child = await registration(app, "child-lifecycle@example.com", "15-17");
    expect((await app.inject({ method: "PUT", url: "/api/profile", headers: child, payload: profile("child") })).json().code).toBe("email_verification_required");
    await verify();
    expect((await app.inject({ method: "POST", url: "/api/family/join", headers: child, payload: { inviteCode } })).json().code).toBe("guardian_consent_required");
    expect((await app.inject({ method: "POST", url: "/api/privacy/guardian-consent/request", headers: child, payload: { email: "guardian-lifecycle@example.com" } })).statusCode).toBe(200);
    expect((await app.inject({ method: "POST", url: "/api/privacy/guardian-consent/confirm", payload: { token: tokens.get("guardian-approve"), policyVersion: servicePolicyVersion, adult: true, legalGuardian: true, accepted: true } })).statusCode).toBe(200);
    // Approval permits own setup, but neither joins a family nor enables AI.
    expect((await app.inject({ method: "GET", url: "/api/family", headers: child })).json().data).toBeNull();
    expect((await app.inject({ method: "GET", url: "/api/privacy/ai-consent", headers: child })).json().data.granted).toBe(false);
    expect((await app.inject({ method: "PUT", url: "/api/profile", headers: child, payload: profile("child") })).statusCode).toBe(200);
    expect((await app.inject({ method: "POST", url: "/api/family/join", headers: child, payload: { inviteCode } })).statusCode).toBe(200);
    const overview = (await app.inject({ method: "GET", url: "/api/family", headers: parent })).json().data;
    expect(overview.childSummaries).toHaveLength(1);
    expect(overview.childSummaries[0].monthlyBudgetMinor).toBe(600000);
    expect(JSON.stringify(overview)).not.toMatch(/child-lifecycle|guardian-lifecycle|moneyEvents|password|token/);
    expect((await app.inject({ method: "GET", url: "/api/family", headers: child })).json().data.childSummaries).toEqual([]);
    expect((await app.inject({ method: "POST", url: "/api/family/leave", headers: parent })).statusCode).toBe(409);
    expect((await app.inject({ method: "DELETE", url: "/api/privacy/guardian-consent", headers: child })).statusCode).toBe(200);
    expect((await app.inject({ method: "PUT", url: "/api/profile", headers: child, payload: profile("child") })).json().code).toBe("guardian_consent_required");
    expect((await app.inject({ method: "POST", url: "/api/family/leave", headers: child })).statusCode).toBe(200);
    expect((await app.inject({ method: "GET", url: "/api/family", headers: parent })).json().data.childSummaries).toEqual([]);
    expect((await app.inject({ method: "GET", url: "/api/privacy/export", headers: child })).statusCode).toBe(200);
    expect((await app.inject({ method: "DELETE", url: "/api/family/invite", headers: parent })).statusCode).toBe(200);
    expect((await app.inject({ method: "POST", url: "/api/auth/password-reset/request", payload: { email: "parent-lifecycle@example.com" } })).statusCode).toBe(200);
    expect((await app.inject({ method: "POST", url: "/api/auth/password-reset/confirm", payload: { token: tokens.get("reset-password"), password: "synthetic-new-2026" } })).statusCode).toBe(200);
    expect((await app.inject({ method: "GET", url: "/api/auth/me", headers: parent })).statusCode).toBe(401);
    const renewed = await app.inject({ method: "POST", url: "/api/auth/login", payload: { email: "parent-lifecycle@example.com", password: "synthetic-new-2026" } });
    expect(renewed.statusCode).toBe(200);
    expect((await app.inject({ method: "DELETE", url: "/api/auth/account", headers: child, payload: { password: "synthetic-test-2026" } })).statusCode).toBe(200);
    expect((await app.inject({ method: "GET", url: "/api/auth/me", headers: child })).statusCode).toBe(401);
    expect((await app.inject({ method: "GET", url: "/api/auth/me", headers: { authorization: "Bearer " + renewed.json().data.token } })).statusCode).toBe(200);
  });

  it("disabled mail permits adult setup but cannot bypass new minor consent or offer recovery", async () => {
    const { app } = await make({ mailEnabled: false });
    const policy = (await app.inject({ method: "GET", url: "/api/service-policy" })).json().data;
    expect(policy).toMatchObject({ mailEnabled: false, registrationEnabled: true, emailVerificationRequired: false });
    const child = await registration(app, "minor-disabled@example.com", "15-17");
    expect((await app.inject({ method: "POST", url: "/api/privacy/guardian-consent/request", headers: child, payload: { email: "guardian@example.com" } })).json().code).toBe("mail_disabled");
    expect((await app.inject({ method: "POST", url: "/api/family/join", headers: child, payload: { inviteCode: "aBcDeF0123456789_-AbCdEf" } })).json().code).toBe("guardian_consent_required");
    expect((await app.inject({ method: "POST", url: "/api/auth/password-reset/request", payload: { email: "minor-disabled@example.com" } })).json().code).toBe("mail_disabled");
    const adult = await registration(app, "adult-disabled@example.com");
    expect((await app.inject({ method: "PUT", url: "/api/profile", headers: adult, payload: { accountRole: "parent", monthlyBudgetMinor: 600000, goalName: "合成目標", goalTargetMinor: 1000000, goalSavedMinor: 0, goalDate: "2027-01-01", preferredTone: "supportive" } })).statusCode).toBe(200);
    expect((await app.inject({ method: "POST", url: "/api/family/invite", headers: adult })).statusCode).toBe(201);
  });
  it("serves static controlled education without account, AI consent or provider attribution", async () => {
    const { app } = await make();
    const response = await app.inject({ method: "GET", url: "/api/education/catalog" });
    expect(response.statusCode).toBe(200);
    expect(response.json().data.items).toHaveLength(4);
    for (const item of response.json().data.items) {
      expect(item).toMatchObject({ userId: "education-catalog", source: "manual", sourceEventIds: [] });
      expect(item.id).toMatch(/^catalog-/); expect(item.disclaimer).toContain("不使用第三方 AI");
      expect(item).not.toHaveProperty("provider"); expect(item).not.toHaveProperty("model");
    }
    expect(JSON.stringify(response.json())).not.toMatch(/password|token|email/);
  });
  it("requires age before account creation and publishes provider-specific policy without secrets", async () => {
    const { app } = await make();
    expect((await app.inject({ method: "POST", url: "/api/auth/register", payload: credentials("young@example.com", "under-15") })).statusCode).toBe(403);
    const policy = (await app.inject({ method: "GET", url: "/api/service-policy" })).json().data;
    expect(policy).toMatchObject({ minimumAge: 15, eligibilityRequired: true, ai: { displayName: "OpenAI", policyVersion: "openai-test-policy-v1" } });
    expect(JSON.stringify(policy)).not.toMatch(/apiKey|password|token/);
    expect((await app.inject({ method: "POST", url: "/api/auth/login", payload: { email: "young@example.com", password: "synthetic-test-2026" } })).statusCode).toBe(401);
  });
  it("guards all real AI providers, needs guardian and fresh policy, and preserves read/export/delete after withdrawal", async () => {
    const { app, tokens, policy } = await make(); const headers = await registration(app, "minor@example.com", "15-17");
    const event = { type: "expense", amountMinor: 7500, currency: "TWD", category: "food", occurredAt: "2026-10-01T01:00:00Z", confirmed: true, idempotencyKey: "test-payment" };
    expect((await app.inject({ method: "POST", url: "/api/money-events", headers, payload: event })).json().code).toBe("guardian_consent_required");
    expect((await app.inject({ method: "POST", url: "/api/privacy/guardian-consent/request", headers, payload: { email: "guardian@example.com" } })).statusCode).toBe(200);
    const confirmation = { token: tokens.get("guardian-approve"), policyVersion: servicePolicyVersion, adult: true, legalGuardian: true, accepted: true };
    expect((await app.inject({ method: "POST", url: "/api/privacy/guardian-consent/confirm", payload: confirmation })).statusCode).toBe(200);
    expect((await app.inject({ method: "POST", url: "/api/privacy/guardian-consent/confirm", payload: confirmation })).statusCode).toBe(400);
    const saved = await app.inject({ method: "POST", url: "/api/money-events", headers, payload: event }); expect(saved.statusCode).toBe(201); const eventId = saved.json().data.id;
    const capture = { text: "今天珍奶75", locale: "zh-TW", referenceTime: "2026-10-01T01:00:00Z" };
    expect((await app.inject({ method: "POST", url: "/api/captures/parse", headers, payload: capture })).json().code).toBe("ai_consent_required");
    expect((await app.inject({ method: "PUT", url: "/api/privacy/ai-consent", headers, payload: { granted: true, policyVersion: "old-provider" } })).statusCode).toBe(409);
    expect((await app.inject({ method: "PUT", url: "/api/privacy/ai-consent", headers, payload: { granted: true, policyVersion: policy.policyVersion } })).statusCode).toBe(200);
    expect((await app.inject({ method: "POST", url: "/api/captures/parse", headers, payload: capture })).statusCode).toBe(200);
    expect((await app.inject({ method: "DELETE", url: "/api/privacy/guardian-consent", headers })).statusCode).toBe(200);
    expect((await app.inject({ method: "POST", url: "/api/money-events", headers, payload: { ...event, idempotencyKey: "blocked" } })).statusCode).toBe(403);
    expect((await app.inject({ method: "GET", url: "/api/money-events?limit=50", headers })).json().data.items).toHaveLength(1);
    const exportResponse = await app.inject({ method: "GET", url: "/api/privacy/export", headers });
    expect(exportResponse.statusCode).toBe(200); const exported = exportResponse.json().data;
    expect(exported.profile).toBeNull();
    expect(exported.moneyEvents).toHaveLength(1); expect(JSON.stringify(exported)).not.toMatch(/passwordHash|passwordSalt|tokenHash|guardianEmail/);
    expect((await app.inject({ method: "DELETE", url: "/api/money-events/" + eventId, headers })).statusCode).toBe(200);
  });
  it("provides contract CRUD with repeat-safe creation and separate commitment", async () => {
    const { app } = await make(); const headers = await registration(app, "adult@example.com");
    const input = { name: "Synthetic yearly", amountMinor: 240000, currency: "TWD", billingCycle: "yearly", anchorDate: "2027-01-31", idempotencyKey: "contract-one" };
    const first = await app.inject({ method: "POST", url: "/api/subscriptions", headers, payload: input }); expect(first.statusCode).toBe(201); const id = first.json().data.id;
    expect((await app.inject({ method: "POST", url: "/api/subscriptions", headers, payload: input })).json().data.id).toBe(id);
    expect((await app.inject({ method: "POST", url: "/api/subscriptions", headers, payload: { ...input, amountMinor: 1 } })).statusCode).toBe(409);
    const list = (await app.inject({ method: "GET", url: "/api/subscriptions", headers })).json().data;
    expect(list.items).toHaveLength(1); expect(list.monthlyCommitmentMinor).toBe(20000); expect(list.subscriptions).toHaveLength(0);
    expect((await app.inject({ method: "DELETE", url: "/api/subscriptions/" + id, headers })).statusCode).toBe(200);
    expect((await app.inject({ method: "GET", url: "/api/subscriptions", headers })).json().data.monthlyCommitmentMinor).toBe(0);
  });
  it("enforces aggregate IP budget across route-specific counters and maps unsupported media", async () => {
    const { app } = await make(); const headers = await registration(app, "limits@example.com");
    for (let i = 0; i < 120; i++) {
      const result = await app.inject({ method: "GET", url: i < 60 ? "/api/money-events?limit=50" : "/api/market/quotes", headers, remoteAddress: "127.0.0.3" });
      expect(result.statusCode).toBe(200);
    }
    expect((await app.inject({ method: "GET", url: "/api/profile", headers, remoteAddress: "127.0.0.3" })).statusCode).toBe(429);
    const unsupported = await app.inject({ method: "POST", url: "/api/auth/login", headers: { "content-type": "application/octet-stream" }, payload: "x", remoteAddress: "127.0.0.4" });
    expect(unsupported.statusCode).toBe(415); expect(unsupported.json()).toMatchObject({ code: "unsupported_media_type", retryable: false });
  });
});
