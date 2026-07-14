import { HttpRequest, InvocationContext } from "@azure/functions";
import { beforeEach, describe, expect, it } from "vitest";

import { InMemoryRepository } from "../../src/adapters/inMemoryRepository";
import { demoCatalog } from "../../src/adapters/demoCatalog";
import { DemoAiProvider } from "../../src/adapters/demoAiProvider";
import { FutureMintService } from "../../src/application/futureMintService";
import { AuthService } from "../../src/auth/authService";
import {
  loginHandler,
  meHandler,
  registerHandler,
} from "../../src/functions/auth";
import {
  createMoneyEventHandler,
  listMoneyEventsHandler,
} from "../../src/functions/moneyEvents";
import { setRuntimeForTests } from "../../src/http/runtime";

const context = () =>
  new InvocationContext({
    invocationId: "auth-test-request",
    functionName: "auth-test",
    logHandler: () => undefined,
  });

const request = (
  path: string,
  method = "GET",
  body?: unknown,
  token?: string,
) =>
  new HttpRequest({
    url: `http://localhost${path}`,
    method,
    headers: {
      "content-type": "application/json",
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : { string: JSON.stringify(body) },
  });

const credentials = (email: string) => ({
  email,
  password: "futuremint2026",
});

describe("authenticated HTTP routes", () => {
  beforeEach(() => {
    const repository = new InMemoryRepository();
    setRuntimeForTests({
      mode: "demo",
      aiProvider: "demo",
      dataProvider: "memory",
      service: new FutureMintService(
        repository,
        new DemoAiProvider(),
        demoCatalog,
      ),
      authService: new AuthService(repository),
    });
  });

  it("registers an account and reads it back through a Bearer token", async () => {
    const registered = await registerHandler(
      request("/api/auth/register", "POST", credentials("student@example.com")),
      context(),
    );
    const token = (registered.jsonBody as { data: { token: string } }).data.token;

    const me = await meHandler(request("/api/auth/me", "GET", undefined, token), context());

    expect(registered.status).toBe(201);
    expect(me.status).toBe(200);
    expect(me.jsonBody).toMatchObject({
      data: { email: "student@example.com", profileComplete: false },
    });
    expect(JSON.stringify(registered.jsonBody)).not.toContain("passwordHash");
  });

  it("rejects a protected route without a Bearer token", async () => {
    const response = await listMoneyEventsHandler(
      request("/api/money-events"),
      context(),
    );

    expect(response.status).toBe(401);
    expect(response.jsonBody).toMatchObject({ code: "unauthorized" });
  });

  it("does not expose account A events to account B", async () => {
    const registeredA = await registerHandler(
      request("/api/auth/register", "POST", credentials("a@example.com")),
      context(),
    );
    const registeredB = await registerHandler(
      request("/api/auth/register", "POST", credentials("b@example.com")),
      context(),
    );
    const tokenA = (registeredA.jsonBody as { data: { token: string } }).data.token;
    const tokenB = (registeredB.jsonBody as { data: { token: string } }).data.token;

    const created = await createMoneyEventHandler(
      request(
        "/api/money-events",
        "POST",
        {
          type: "expense",
          amountMinor: 75,
          currency: "TWD",
          category: "food",
          occurredAt: "2026-07-14T12:00:00+08:00",
          confirmed: true,
          idempotencyKey: "account-a-drink",
        },
        tokenA,
      ),
      context(),
    );
    const listedByB = await listMoneyEventsHandler(
      request("/api/money-events", "GET", undefined, tokenB),
      context(),
    );

    expect(created.status).toBe(201);
    expect(listedByB.status).toBe(200);
    expect(listedByB.jsonBody).toMatchObject({ data: [] });
  });

  it("returns the same generic error for invalid login credentials", async () => {
    await registerHandler(
      request("/api/auth/register", "POST", credentials("student@example.com")),
      context(),
    );
    const unknown = await loginHandler(
      request("/api/auth/login", "POST", credentials("missing@example.com")),
      context(),
    );
    const wrong = await loginHandler(
      request(
        "/api/auth/login",
        "POST",
        { email: "student@example.com", password: "not-the-password2026" },
      ),
      context(),
    );

    expect(unknown.jsonBody).toMatchObject({
      code: "invalid_credentials",
      message: "電子郵件或密碼不正確。",
    });
    expect(wrong.jsonBody).toMatchObject({
      code: "invalid_credentials",
      message: "電子郵件或密碼不正確。",
    });
  });
});
