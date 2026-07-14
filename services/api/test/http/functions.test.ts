import { HttpRequest, InvocationContext } from "@azure/functions";
import { beforeEach, describe, expect, it } from "vitest";

import { FutureMintService } from "../../src/application/futureMintService";
import { demoCatalog } from "../../src/adapters/demoCatalog";
import { DemoAiProvider } from "../../src/adapters/demoAiProvider";
import { InMemoryRepository } from "../../src/adapters/inMemoryRepository";
import { AuthService } from "../../src/auth/authService";
import { setRuntimeForTests } from "../../src/http/runtime";
import { healthHandler } from "../../src/functions/health";
import { captureParseHandler } from "../../src/functions/captures";
import {
  createMoneyEventHandler,
  listMoneyEventsHandler,
} from "../../src/functions/moneyEvents";
import { dashboardHandler } from "../../src/functions/dashboard";
import { compareSubscriptionsHandler } from "../../src/functions/subscriptions";
import { listSubscriptionsHandler } from "../../src/functions/subscriptions";
import {
  completeLessonHandler,
  currentLessonHandler,
  generateLessonHandler,
} from "../../src/functions/lessons";
import { futureSeedHandler } from "../../src/functions/futureSeed";
import { corsPreflightHandler } from "../../src/functions/cors";

const context = () =>
  new InvocationContext({
    invocationId: "test-request-id",
    functionName: "test",
    logHandler: () => undefined,
  });

const request = (
  path: string,
  method = "GET",
  body?: unknown,
  origin?: string,
): HttpRequest =>
  new HttpRequest({
    url: `http://localhost${path}`,
    method,
    headers: {
      "content-type": "application/json",
      ...(authenticatedToken
          ? { authorization: `Bearer ${authenticatedToken}` }
          : {}),
      ...(origin ? { origin } : {}),
    },
    body: body === undefined ? undefined : { string: JSON.stringify(body) },
  });

let authenticatedToken = "";

describe("Functions HTTP handlers", () => {
  beforeEach(async () => {
    process.env.ALLOWED_ORIGINS =
      "https://futuremint.example,http://localhost:4173";
    const repository = new InMemoryRepository();
    const authService = new AuthService(repository);
    const registered = await authService.register({
      email: "test@example.com",
      password: "futuremint2026",
    });
    authenticatedToken = registered.token;
    await repository.resetDemo(registered.account.id);
    setRuntimeForTests({
      mode: "demo",
      aiProvider: "demo",
      dataProvider: "memory",
      service: new FutureMintService(
        repository,
        new DemoAiProvider(),
        demoCatalog,
      ),
      authService,
    });
  });

  it("reports safe provider status without resource identifiers", async () => {
    const response = await healthHandler(
      request("/api/health", "GET", undefined, "http://localhost:4173"),
      context(),
    );

    expect(response.status).toBe(200);
    expect(response.jsonBody).toMatchObject({
      status: "ok",
      mode: "demo",
      aiProvider: "demo",
      dataProvider: "memory",
    });
    expect(JSON.stringify(response.jsonBody)).not.toContain("endpoint");
    expect(response.headers).toMatchObject({
      "access-control-allow-origin": "http://localhost:4173",
      vary: "Origin",
    });
  });

  it("handles an allowed preflight without reflecting an unknown origin", async () => {
    const allowed = await corsPreflightHandler(
      request(
        "/api/captures/parse",
        "OPTIONS",
        undefined,
        "https://futuremint.example",
      ),
      context(),
    );
    const denied = await corsPreflightHandler(
      request(
        "/api/captures/parse",
        "OPTIONS",
        undefined,
        "https://evil.example",
      ),
      context(),
    );

    expect(allowed.status).toBe(204);
    expect(allowed.headers).toMatchObject({
      "access-control-allow-origin": "https://futuremint.example",
      "access-control-allow-methods": "GET,POST,PUT,PATCH,OPTIONS",
    });
    expect(denied.status).toBe(403);
    expect(denied.headers).not.toHaveProperty("access-control-allow-origin");
  });

  it("parses a capture and returns a request id", async () => {
    const response = await captureParseHandler(
      request("/api/captures/parse", "POST", {
        text: "打工薪水 1500",
        locale: "zh-TW",
        referenceTime: "2026-07-13T12:00:00+08:00",
      }),
      context(),
    );

    expect(response.status).toBe(200);
    expect(response.jsonBody).toMatchObject({
      requestId: "test-request-id",
      data: { drafts: [{ type: "income", amountMinor: 1500 }] },
    });
  });

  it("maps invalid event input to a sanitized validation problem", async () => {
    const response = await createMoneyEventHandler(
      request("/api/money-events", "POST", {
        type: "expense",
        amountMinor: -75,
        currency: "TWD",
        category: "food",
        occurredAt: "2026-07-13T12:00:00+08:00",
        confirmed: true,
        idempotencyKey: "invalid-amount-case",
      }),
      context(),
    );

    expect(response.status).toBe(422);
    expect(response.jsonBody).toMatchObject({
      code: "validation_error",
      requestId: "test-request-id",
      retryable: false,
    });
    expect(JSON.stringify(response.jsonBody)).not.toContain("stack");
  });

  it("rejects contradictory event type and category combinations", async () => {
    const response = await createMoneyEventHandler(
      request("/api/money-events", "POST", {
        type: "expense",
        amountMinor: 1500,
        currency: "TWD",
        category: "income",
        occurredAt: "2026-07-13T12:00:00+08:00",
        confirmed: true,
        idempotencyKey: "contradictory-event",
      }),
      context(),
    );

    expect(response.status).toBe(422);
    expect(response.jsonBody).toMatchObject({
      code: "validation_error",
      fieldErrors: { category: expect.any(String) },
    });
  });

  it("filters money events by type and rejects an invalid date range", async () => {
    const filtered = await listMoneyEventsHandler(
      new HttpRequest({
        url: "http://localhost/api/money-events?type=subscription",
        method: "GET",
        query: { type: "subscription" },
        headers: { authorization: `Bearer ${authenticatedToken}` },
      }),
      context(),
    );
    const invalid = await listMoneyEventsHandler(
      new HttpRequest({
        url: "http://localhost/api/money-events",
        method: "GET",
        query: {
          from: "2026-07-14T00:00:00+08:00",
          to: "2026-07-13T00:00:00+08:00",
        },
        headers: { authorization: `Bearer ${authenticatedToken}` },
      }),
      context(),
    );

    expect(filtered.status).toBe(200);
    expect(
      (filtered.jsonBody as { data: Array<{ type: string }> }).data,
    ).toEqual([expect.objectContaining({ type: "subscription" })]);
    expect(invalid.status).toBe(422);
    expect(invalid.jsonBody).toMatchObject({ code: "validation_error" });
  });

  it("maps malformed JSON to a safe client error", async () => {
    const malformed = new HttpRequest({
      url: "http://localhost/api/captures/parse",
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${authenticatedToken}`,
      },
      body: { string: '{"text":' },
    });

    const response = await captureParseHandler(malformed, context());

    expect(response.status).toBe(400);
    expect(response.jsonBody).toMatchObject({
      code: "invalid_json",
      retryable: false,
      requestId: "test-request-id",
    });
  });

  it("rejects a lesson answer that was not presented", async () => {
    const generated = await generateLessonHandler(
      request("/api/lessons/generate", "POST", {}),
      context(),
    );
    const lesson = (generated.jsonBody as { data: { id: string } }).data;

    const response = await completeLessonHandler(
      new HttpRequest({
        url: `http://localhost/api/lessons/${lesson.id}`,
        method: "PATCH",
        headers: {
          "content-type": "application/json",
          authorization: `Bearer ${authenticatedToken}`,
        },
        params: { lessonId: lesson.id },
        body: {
          string: JSON.stringify({ selectedOption: "未呈現的選項" }),
        },
      }),
      context(),
    );

    expect(response.status).toBe(422);
    expect(response.jsonBody).toMatchObject({
      code: "invalid_lesson_option",
      retryable: false,
    });
  });

  it("serves dashboard, subscription, lesson, and FutureSeed results", async () => {
    const dashboard = await dashboardHandler(
      request("/api/dashboard"),
      context(),
    );
    const subscriptions = await compareSubscriptionsHandler(
      request("/api/subscriptions/compare", "POST", {
        currentName: "影音個人方案",
        currentPriceMinor: 390,
        currentBillingCycle: "monthly",
        members: 4,
        isStudent: true,
      }),
      context(),
    );
    const lesson = await generateLessonHandler(
      request("/api/lessons/generate", "POST", {}),
      context(),
    );
    const currentLesson = await currentLessonHandler(
      request("/api/lessons/current"),
      context(),
    );
    const futureSeed = await futureSeedHandler(
      request("/api/future-seed/preview", "POST", {
        monthlyContributionMinor: 500,
        years: 5,
        annualRatePercent: 3,
      }),
      context(),
    );
    const subscriptionList = await listSubscriptionsHandler(
      request("/api/subscriptions"),
      context(),
    );

    expect(dashboard.status).toBe(200);
    expect(subscriptions.status).toBe(200);
    expect(lesson.status).toBe(200);
    expect(currentLesson.status).toBe(200);
    expect(currentLesson.jsonBody).toMatchObject({
      data: { id: (lesson.jsonBody as { data: { id: string } }).data.id },
    });
    expect(futureSeed.status).toBe(200);
    expect(subscriptionList.status).toBe(200);
    expect(subscriptionList.jsonBody).toMatchObject({
      data: {
        subscriptions: expect.any(Array),
        catalog: expect.arrayContaining([
          expect.objectContaining({ sourceType: "synthetic" }),
        ]),
      },
    });
    expect(futureSeed.jsonBody).toMatchObject({
      data: { principalMinor: 30000 },
    });
  });
});
