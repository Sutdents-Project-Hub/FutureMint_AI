import type { FastifyInstance } from "fastify";
import { afterEach, beforeEach, describe, expect, it } from "vitest";

import { demoCatalog } from "../../src/adapters/demoCatalog";
import { DemoAiProvider } from "../../src/adapters/demoAiProvider";
import { InMemoryRepository } from "../../src/adapters/inMemoryRepository";
import { EducationalMarketDataProvider } from "../../src/adapters/twseMarketDataProvider";
import { FutureMintService } from "../../src/application/futureMintService";
import type { AiProvider } from "../../src/application/ports";
import { AuthService, aiConsentPolicyVersion } from "../../src/auth/authService";
import { buildServer } from "../../src/http/server";
import type { Runtime } from "../../src/http/runtime";

const credentials = (email: string) => ({
  email,
  password: "futuremint2026",
});

describe("authenticated HTTP routes", () => {
  let app: FastifyInstance;

  beforeEach(async () => {
    const repository = new InMemoryRepository();
    const runtime: Runtime = {
      mode: "demo",
      aiProvider: "demo",
      dataProvider: "memory",
      service: new FutureMintService(
        repository,
        new DemoAiProvider(),
        demoCatalog,
        new EducationalMarketDataProvider(),
      ),
      authService: new AuthService(repository),
      healthCheck: async () => undefined,
      close: async () => undefined,
    };
    app = await buildServer({ runtime, logger: false });
  });

  afterEach(async () => app.close());

  const register = async (email: string) =>
    app.inject({
      method: "POST",
      url: "/api/auth/register",
      payload: credentials(email),
    });

  it("registers an account and reads it through a Bearer token", async () => {
    const registered = await register("student@example.com");
    const token = registered.json().data.token as string;
    const me = await app.inject({
      method: "GET",
      url: "/api/auth/me",
      headers: { authorization: `Bearer ${token}` },
    });

    expect(registered.statusCode).toBe(201);
    expect(me.statusCode).toBe(200);
    expect(me.json()).toMatchObject({
      data: { email: "student@example.com", profileComplete: false },
    });
    expect(registered.body).not.toContain("passwordHash");
  });

  it("rejects a protected route without a Bearer token", async () => {
    const response = await app.inject({
      method: "GET",
      url: "/api/money-events",
    });

    expect(response.statusCode).toBe(401);
    expect(response.json()).toMatchObject({ code: "unauthorized" });
  });

  it("does not expose account A events to account B", async () => {
    const registeredA = await register("a@example.com");
    const registeredB = await register("b@example.com");
    const tokenA = registeredA.json().data.token as string;
    const tokenB = registeredB.json().data.token as string;

    const created = await app.inject({
      method: "POST",
      url: "/api/money-events",
      headers: { authorization: `Bearer ${tokenA}` },
      payload: {
        type: "expense",
        amountMinor: 75,
        currency: "TWD",
        category: "food",
        occurredAt: "2026-07-14T12:00:00+08:00",
        confirmed: true,
        idempotencyKey: "account-a-drink",
      },
    });
    const listedByB = await app.inject({
      method: "GET",
      url: "/api/money-events",
      headers: { authorization: `Bearer ${tokenB}` },
    });

    expect(created.statusCode).toBe(201);
    expect(listedByB.statusCode).toBe(200);
    expect(listedByB.json()).toMatchObject({ data: [] });
  });

  it("does not let account B update or delete account A events", async () => {
    const registeredA = await register("a@example.com");
    const registeredB = await register("b@example.com");
    const tokenA = registeredA.json().data.token as string;
    const tokenB = registeredB.json().data.token as string;
    const created = await app.inject({
      method: "POST",
      url: "/api/money-events",
      headers: { authorization: `Bearer ${tokenA}` },
      payload: {
        type: "expense",
        amountMinor: 75,
        currency: "TWD",
        category: "food",
        occurredAt: "2026-07-14T12:00:00+08:00",
        confirmed: true,
        idempotencyKey: "account-a-editable-drink",
      },
    });
    const eventId = created.json().data.id as string;
    const updateByB = await app.inject({
      method: "PUT",
      url: `/api/money-events/${eventId}`,
      headers: { authorization: `Bearer ${tokenB}` },
      payload: {
        type: "expense",
        amountMinor: 30,
        currency: "TWD",
        category: "food",
        occurredAt: "2026-07-14T12:00:00+08:00",
        confirmed: true,
      },
    });
    const deleteByB = await app.inject({
      method: "DELETE",
      url: `/api/money-events/${eventId}`,
      headers: { authorization: `Bearer ${tokenB}` },
    });

    expect(updateByB.statusCode).toBe(404);
    expect(deleteByB.statusCode).toBe(404);
  });

  it("returns the same generic error for invalid login credentials", async () => {
    await register("student@example.com");
    const unknown = await app.inject({
      method: "POST",
      url: "/api/auth/login",
      payload: credentials("missing@example.com"),
    });
    const wrong = await app.inject({
      method: "POST",
      url: "/api/auth/login",
      payload: {
        email: "student@example.com",
        password: "not-the-password2026",
      },
    });

    expect(unknown.json()).toMatchObject({
      code: "invalid_credentials",
      message: "電子郵件或密碼不正確。",
    });
    expect(wrong.json()).toMatchObject({
      code: "invalid_credentials",
      message: "電子郵件或密碼不正確。",
    });
  });

  it("reads and updates the current third-party AI consent", async () => {
    const registered = await register("student@example.com");
    const token = registered.json().data.token as string;
    const headers = { authorization: `Bearer ${token}` };

    const initial = await app.inject({
      method: "GET",
      url: "/api/privacy/ai-consent",
      headers,
    });
    const granted = await app.inject({
      method: "PUT",
      url: "/api/privacy/ai-consent",
      headers,
      payload: { granted: true, policyVersion: aiConsentPolicyVersion },
    });
    const withdrawn = await app.inject({
      method: "PUT",
      url: "/api/privacy/ai-consent",
      headers,
      payload: { granted: false },
    });

    expect(initial.json()).toMatchObject({
      data: {
        granted: false,
        policyVersion: aiConsentPolicyVersion,
        grantedAt: null,
        withdrawnAt: null,
      },
    });
    expect(granted.json().data).toMatchObject({
      granted: true,
      grantedAt: expect.any(String),
      withdrawnAt: null,
    });
    expect(withdrawn.json().data).toMatchObject({
      granted: false,
      grantedAt: expect.any(String),
      withdrawnAt: expect.any(String),
    });
  });

  it("blocks Liangjie-like capture before upstream use until consent is granted", async () => {
    const repository = new InMemoryRepository();
    let providerCalls = 0;
    const provider = {
      parseCapture: async () => {
        providerCalls += 1;
        return { drafts: [] };
      },
    } as AiProvider;
    const runtime: Runtime = {
      mode: "hosted",
      aiProvider: "liangjie",
      dataProvider: "postgres",
      service: new FutureMintService(
        repository,
        provider,
        demoCatalog,
        new EducationalMarketDataProvider(),
      ),
      authService: new AuthService(repository),
      healthCheck: async () => undefined,
      close: async () => undefined,
    };
    const liangjieApp = await buildServer({ runtime, logger: false });
    try {
      const registered = await liangjieApp.inject({
        method: "POST",
        url: "/api/auth/register",
        payload: credentials("student@example.com"),
      });
      const token = registered.json().data.token as string;
      const headers = { authorization: `Bearer ${token}` };
      const payload = {
        text: "今天買珍奶 75",
        locale: "zh-TW",
        referenceTime: "2026-08-30T12:00:00+08:00",
      };

      const blocked = await liangjieApp.inject({
        method: "POST",
        url: "/api/captures/parse",
        headers,
        payload,
      });
      expect(blocked.statusCode).toBe(403);
      expect(blocked.json()).toMatchObject({ code: "ai_consent_required" });
      const blockedLesson = await liangjieApp.inject({
        method: "POST",
        url: "/api/lessons/generate",
        headers,
      });
      const blockedPlan = await liangjieApp.inject({
        method: "GET",
        url: "/api/learning-plan",
        headers,
      });
      const blockedCoach = await liangjieApp.inject({
        method: "POST",
        url: "/api/coach/chat",
        headers,
        payload: { topic: "general", question: "怎麼開始記帳？" },
      });
      for (const response of [blockedLesson, blockedPlan, blockedCoach]) {
        expect(response.statusCode).toBe(403);
        expect(response.json()).toMatchObject({ code: "ai_consent_required" });
      }
      expect(providerCalls).toBe(0);

      const consent = await liangjieApp.inject({
        method: "PUT",
        url: "/api/privacy/ai-consent",
        headers,
        payload: { granted: true, policyVersion: aiConsentPolicyVersion },
      });
      const allowed = await liangjieApp.inject({
        method: "POST",
        url: "/api/captures/parse",
        headers,
        payload,
      });
      expect(consent.statusCode).toBe(200);
      expect(allowed.statusCode).toBe(200);
      expect(providerCalls).toBe(1);
    } finally {
      await liangjieApp.close();
    }
  });

  it("deletes an account only after password verification and invalidates its session", async () => {
    const registered = await register("student@example.com");
    const token = registered.json().data.token as string;
    const headers = { authorization: `Bearer ${token}` };
    const wrongPassword = await app.inject({
      method: "DELETE",
      url: "/api/auth/account",
      headers,
      payload: { password: "wrong-password2026" },
    });
    const deleted = await app.inject({
      method: "DELETE",
      url: "/api/auth/account",
      headers,
      payload: { password: "futuremint2026" },
    });
    const after = await app.inject({
      method: "GET",
      url: "/api/auth/me",
      headers,
    });

    expect(wrongPassword.statusCode).toBe(401);
    expect(wrongPassword.json()).toMatchObject({ code: "invalid_credentials" });
    expect(deleted.json()).toMatchObject({ data: { deleted: true } });
    expect(after.statusCode).toBe(401);
    const reRegistered = await register("student@example.com");
    expect(reRegistered.statusCode).toBe(201);
  });
});
