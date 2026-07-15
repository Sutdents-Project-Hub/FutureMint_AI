import type { FastifyInstance } from "fastify";
import { afterEach, beforeEach, describe, expect, it } from "vitest";

import { demoCatalog } from "../../src/adapters/demoCatalog";
import { DemoAiProvider } from "../../src/adapters/demoAiProvider";
import { InMemoryRepository } from "../../src/adapters/inMemoryRepository";
import { EducationalMarketDataProvider } from "../../src/adapters/twseMarketDataProvider";
import { FutureMintService } from "../../src/application/futureMintService";
import { AuthService } from "../../src/auth/authService";
import { buildServer, parseAllowedOrigins } from "../../src/http/server";
import type { Runtime } from "../../src/http/runtime";

const createRuntime = (repository: InMemoryRepository): Runtime => ({
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
});

describe("Fastify HTTP server", () => {
  it("validates production CORS origins before the server starts", () => {
    expect(() => parseAllowedOrigins(undefined, true)).toThrow(
      "ALLOWED_ORIGINS is required",
    );
    expect(() => parseAllowedOrigins("*", true)).toThrow("valid HTTPS origin");
    expect(() => parseAllowedOrigins("https://futuremint.example/", true)).toThrow(
      "valid HTTPS origin",
    );
    expect(parseAllowedOrigins("https://futuremint.example", true)).toEqual([
      "https://futuremint.example",
    ]);
    expect(parseAllowedOrigins("http://localhost:4173", false)).toEqual([
      "http://localhost:4173",
    ]);
  });

  let app: FastifyInstance;
  let token = "";

  beforeEach(async () => {
    const repository = new InMemoryRepository();
    const runtime = createRuntime(repository);
    const registered = await runtime.authService.register({
      email: "test@example.com",
      password: "futuremint2026",
    });
    token = registered.token;
    await repository.resetDemo(registered.account.id);
    app = await buildServer({
      runtime,
      allowedOrigins: [
        "https://futuremint.example",
        "http://localhost:4173",
      ],
      logger: false,
    });
  });

  afterEach(async () => app.close());

  const authenticated = (options: Record<string, unknown>) => ({
    ...options,
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${token}`,
      ...((options.headers as Record<string, string> | undefined) ?? {}),
    },
  });

  it("reports safe provider status and database readiness", async () => {
    const response = await app.inject({
      method: "GET",
      url: "/api/health",
      headers: { origin: "http://localhost:4173" },
    });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({
      status: "ok",
      mode: "demo",
      aiProvider: "demo",
      dataProvider: "memory",
      requestId: expect.any(String),
    });
    expect(response.body).not.toContain("endpoint");
    expect(response.headers).toMatchObject({
      "access-control-allow-origin": "http://localhost:4173",
      vary: "Origin",
    });
  });

  it("returns 503 when the data dependency is unavailable", async () => {
    const repository = new InMemoryRepository();
    const runtime = createRuntime(repository);
    runtime.healthCheck = async () => {
      throw new Error("database unavailable");
    };
    const unhealthy = await buildServer({ runtime, logger: false });
    try {
      const response = await unhealthy.inject({
        method: "GET",
        url: "/api/health",
      });
      expect(response.statusCode).toBe(503);
      expect(response.json()).toMatchObject({ code: "service_not_ready" });
      expect(response.body).not.toContain("database unavailable");
    } finally {
      await unhealthy.close();
    }
  });

  it("handles allowed and denied CORS preflight requests", async () => {
    const allowed = await app.inject({
      method: "OPTIONS",
      url: "/api/captures/parse",
      headers: { origin: "https://futuremint.example" },
    });
    const denied = await app.inject({
      method: "OPTIONS",
      url: "/api/captures/parse",
      headers: { origin: "https://evil.example" },
    });

    expect(allowed.statusCode).toBe(204);
    expect(allowed.headers).toMatchObject({
      "access-control-allow-origin": "https://futuremint.example",
      "access-control-allow-methods": "GET,POST,PUT,PATCH,OPTIONS",
      "access-control-max-age": "600",
    });
    expect(denied.statusCode).toBe(403);
    expect(denied.headers).not.toHaveProperty("access-control-allow-origin");
  });

  it("parses a capture and returns a request id", async () => {
    const response = await app.inject(
      authenticated({
        method: "POST",
        url: "/api/captures/parse",
        payload: {
          text: "打工薪水 1500",
          locale: "zh-TW",
          referenceTime: "2026-07-13T12:00:00+08:00",
        },
      }),
    );

    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({
      requestId: expect.any(String),
      data: { drafts: [{ type: "income", amountMinor: 1500 }] },
    });
  });

  it("maps invalid event input to a sanitized validation problem", async () => {
    const response = await app.inject(
      authenticated({
        method: "POST",
        url: "/api/money-events",
        payload: {
          type: "expense",
          amountMinor: -75,
          currency: "TWD",
          category: "food",
          occurredAt: "2026-07-13T12:00:00+08:00",
          confirmed: true,
          idempotencyKey: "invalid-amount-case",
        },
      }),
    );

    expect(response.statusCode).toBe(422);
    expect(response.json()).toMatchObject({
      code: "validation_error",
      requestId: expect.any(String),
      retryable: false,
    });
    expect(response.body).not.toContain("stack");
  });

  it("filters events and rejects an invalid date range", async () => {
    const filtered = await app.inject(
      authenticated({
        method: "GET",
        url: "/api/money-events?type=subscription",
      }),
    );
    const invalid = await app.inject(
      authenticated({
        method: "GET",
        url: "/api/money-events?from=2026-07-14T00%3A00%3A00%2B08%3A00&to=2026-07-13T00%3A00%3A00%2B08%3A00",
      }),
    );

    expect(filtered.statusCode).toBe(200);
    expect(filtered.json().data).toEqual([
      expect.objectContaining({ type: "subscription" }),
    ]);
    expect(invalid.statusCode).toBe(422);
    expect(invalid.json()).toMatchObject({ code: "validation_error" });
  });

  it("maps malformed JSON to a safe client error", async () => {
    const response = await app.inject({
      method: "POST",
      url: "/api/captures/parse",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${token}`,
      },
      payload: '{"text":',
    });

    expect(response.statusCode).toBe(400);
    expect(response.json()).toMatchObject({
      code: "invalid_json",
      retryable: false,
      requestId: expect.any(String),
    });
  });

  it("rejects request bodies that exceed the supported input size", async () => {
    const response = await app.inject(
      authenticated({
        method: "POST",
        url: "/api/captures/parse",
        payload: JSON.stringify({ text: "a".repeat(33 * 1024) }),
      }),
    );

    expect(response.statusCode).toBe(413);
    expect(response.json()).toMatchObject({
      code: "request_too_large",
      retryable: false,
    });
  });

  it("limits AI-backed capture requests separately from general API traffic", async () => {
    const responses = [];
    for (let index = 0; index < 21; index += 1) {
      responses.push(
        await app.inject(
          authenticated({
            method: "POST",
            url: "/api/captures/parse",
            payload: {
              text: "打工薪水 1500",
              locale: "zh-TW",
              referenceTime: "2026-07-13T12:00:00+08:00",
            },
          }),
        ),
      );
    }

    expect(responses.filter((response) => response.statusCode === 200)).toHaveLength(
      20,
    );
    expect(
      responses.find((response) => response.statusCode === 429)?.json(),
    ).toMatchObject({ code: "rate_limited", retryable: true });
  });

  it("rejects a lesson answer that was not presented", async () => {
    const generated = await app.inject(
      authenticated({
        method: "POST",
        url: "/api/lessons/generate",
        payload: {},
      }),
    );
    const lesson = generated.json().data as { id: string };
    const response = await app.inject(
      authenticated({
        method: "PATCH",
        url: `/api/lessons/${lesson.id}`,
        payload: { selectedOption: "未呈現的選項" },
      }),
    );

    expect(response.statusCode).toBe(422);
    expect(response.json()).toMatchObject({
      code: "invalid_lesson_option",
      retryable: false,
    });
  });

  it("validates a missing lesson answer instead of returning an internal error", async () => {
    const generated = await app.inject(
      authenticated({
        method: "POST",
        url: "/api/lessons/generate",
        payload: {},
      }),
    );
    const lesson = generated.json().data as { id: string };
    const response = await app.inject(
      authenticated({
        method: "PATCH",
        url: `/api/lessons/${lesson.id}`,
        payload: {},
      }),
    );

    expect(response.statusCode).toBe(422);
    expect(response.json()).toMatchObject({
      code: "validation_error",
      retryable: false,
    });
  });

  it("serves dashboard, insights, learning, simulation, and coach results", async () => {
    const dashboard = await app.inject(
      authenticated({ method: "GET", url: "/api/dashboard" }),
    );
    const subscriptions = await app.inject(
      authenticated({
        method: "POST",
        url: "/api/subscriptions/compare",
        payload: {
          currentName: "影音個人方案",
          currentPriceMinor: 390,
          currentBillingCycle: "monthly",
          members: 4,
          isStudent: true,
        },
      }),
    );
    const insights = await app.inject(
      authenticated({ method: "GET", url: "/api/insights" }),
    );
    const lesson = await app.inject(
      authenticated({ method: "POST", url: "/api/lessons/generate", payload: {} }),
    );
    const currentLesson = await app.inject(
      authenticated({ method: "GET", url: "/api/lessons/current" }),
    );
    const futureSeed = await app.inject(
      authenticated({
        method: "POST",
        url: "/api/future-seed/preview",
        payload: {
          monthlyContributionMinor: 500,
          years: 5,
          annualRatePercent: 3,
        },
      }),
    );
    const learningPlan = await app.inject(
      authenticated({ method: "GET", url: "/api/learning-plan" }),
    );
    const simulation = await app.inject(
      authenticated({
        method: "POST",
        url: "/api/future-seed/simulate",
        payload: {
          initialAmountMinor: 4200,
          monthlyContributionMinor: 500,
          years: 10,
        },
      }),
    );
    const coach = await app.inject(
      authenticated({
        method: "POST",
        url: "/api/coach/chat",
        payload: {
          topic: "risk",
          question: "為什麼曲線中間掉下去？",
          scenarioId: "high-risk",
          selectedYear: 4,
        },
      }),
    );
    const subscriptionList = await app.inject(
      authenticated({ method: "GET", url: "/api/subscriptions" }),
    );

    expect(dashboard.statusCode).toBe(200);
    expect(subscriptions.statusCode).toBe(200);
    expect(insights.statusCode).toBe(200);
    expect(lesson.statusCode).toBe(200);
    expect(currentLesson.statusCode).toBe(200);
    expect(currentLesson.json()).toMatchObject({
      data: { id: lesson.json().data.id },
    });
    expect(futureSeed.json()).toMatchObject({
      data: { principalMinor: 30000 },
    });
    expect(insights.json()).toMatchObject({
      data: {
        monthlyCashflow: expect.any(Array),
        notices: expect.any(Array),
      },
    });
    expect(learningPlan.json()).toMatchObject({
      data: {
        modules: expect.arrayContaining([
          expect.objectContaining({ id: "compound" }),
        ]),
      },
    });
    expect(simulation.json()).toMatchObject({
      data: {
        scenarios: [
          expect.objectContaining({ id: "steady" }),
          expect.objectContaining({ id: "balanced" }),
          expect.objectContaining({ id: "high-risk" }),
        ],
      },
    });
    expect(coach.json()).toMatchObject({
      data: {
        answer: expect.stringContaining("下跌"),
        source: "deterministic-demo",
      },
    });
    expect(subscriptionList.json()).toMatchObject({
      data: {
        subscriptions: expect.any(Array),
        catalog: expect.arrayContaining([
          expect.objectContaining({ sourceType: "synthetic" }),
        ]),
      },
    });
  });

  it("serves public delayed quotes and authenticated virtual trading", async () => {
    const quotes = await app.inject({
      method: "GET",
      url: "/api/market/quotes",
    });
    const initial = await app.inject(
      authenticated({ method: "GET", url: "/api/investment-lab" }),
    );
    const buy = await app.inject(
      authenticated({
        method: "POST",
        url: "/api/investment-lab/orders",
        payload: {
          symbol: "0050",
          side: "buy",
          quantity: 2,
          idempotencyKey: "buy-0050-once",
        },
      }),
    );
    const repeated = await app.inject(
      authenticated({
        method: "POST",
        url: "/api/investment-lab/orders",
        payload: {
          symbol: "0050",
          side: "buy",
          quantity: 2,
          idempotencyKey: "buy-0050-once",
        },
      }),
    );
    const dice = await app.inject(
      authenticated({
        method: "POST",
        url: "/api/investment-lab/dice",
        payload: { rollIndex: 0 },
      }),
    );

    expect(quotes.statusCode).toBe(200);
    expect(quotes.json()).toMatchObject({
      data: {
        source: "educational-snapshot",
        isFallback: true,
        quotes: expect.arrayContaining([
          expect.objectContaining({ symbol: "0050" }),
        ]),
      },
    });
    expect(initial.json()).toMatchObject({
      data: { startingCashMinor: 4200, holdings: [] },
    });
    expect(buy.statusCode).toBe(201);
    expect(buy.json()).toMatchObject({
      data: {
        holdings: [expect.objectContaining({ symbol: "0050", quantity: 2 })],
        orders: [expect.objectContaining({ side: "buy", quantity: 2 })],
      },
    });
    expect(repeated.json().data.orders).toHaveLength(1);
    expect(dice.json()).toMatchObject({
      data: {
        deckVersion: "investment-lab-events-v1",
        rollIndex: 0,
      },
    });
  });
});
