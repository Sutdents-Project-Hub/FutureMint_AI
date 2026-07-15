import type { FastifyInstance } from "fastify";
import { afterEach, beforeEach, describe, expect, it } from "vitest";

import { demoCatalog } from "../../src/adapters/demoCatalog";
import { DemoAiProvider } from "../../src/adapters/demoAiProvider";
import { InMemoryRepository } from "../../src/adapters/inMemoryRepository";
import { EducationalMarketDataProvider } from "../../src/adapters/twseMarketDataProvider";
import { FutureMintService } from "../../src/application/futureMintService";
import { AuthService } from "../../src/auth/authService";
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
});
