import rateLimit from "@fastify/rate-limit";
import Fastify, {
  type FastifyInstance,
  type FastifyReply,
  type FastifyRequest,
} from "fastify";
import { z, ZodError } from "zod";
import { parseAllowedOrigins } from "../config/httpConfig";
export { parseAllowedOrigins } from "../config/httpConfig";
import { servicePolicyVersion, providerAiPolicyVersion, guardianConfirmationSchema } from "../contracts/servicePolicy";

import { parseTrustedProxies } from "../config/publicConfig";
import { sharedRateLimitStore, rateLimitKey } from "./sharedRateLimit";
import { registerPublicPages } from "./publicPages";
import { DomainError } from "../contracts/errors";
import { catalogLesson, educationTopics } from "../adapters/educationCatalog";
import {
  authCredentialsSchema,
  lessonCompletionInputSchema,
  moneyEventIdParamsSchema,
} from "../contracts/schemas";
import { bearerToken, requireAuthenticatedUser } from "./authentication";
import { getRuntime, type Runtime } from "./runtime";

interface BuildServerOptions {
  runtime?: Runtime;
  allowedOrigins?: string[];
  logger?: boolean;
}

const configuredOrigins = (): string[] =>
  parseAllowedOrigins(process.env.ALLOWED_ORIGINS);

const success = (
  request: FastifyRequest,
  reply: FastifyReply,
  data: unknown,
  status = 200,
) => reply.code(status).send({ requestId: request.id, data });

const problem = (
  request: FastifyRequest,
  reply: FastifyReply,
  status: number,
  body: {
    code: string;
    message: string;
    retryable: boolean;
    fieldErrors?: Record<string, string>;
  },
) => reply.code(status).send({ ...body, requestId: request.id });

export const buildServer = async (
  options: BuildServerOptions = {},
): Promise<FastifyInstance> => {
  const runtime = options.runtime ?? getRuntime();
  const allowedOrigins = options.allowedOrigins ?? configuredOrigins();
  const app = Fastify({
    logger: options.logger ?? process.env.NODE_ENV !== "test",
    trustProxy: parseTrustedProxies(process.env.TRUSTED_PROXY_CIDRS),
    bodyLimit: 32 * 1024,
  });

  await app.register(rateLimit, {
    global: false,
    ...(runtime.rateLimitStore ? { store: sharedRateLimitStore(runtime.rateLimitStore) } : {}),
    max: 120,
    timeWindow: "1 minute",
    errorResponseBuilder: (request, context) => ({
      statusCode: context.statusCode,
      code: "rate_limited",
      message: "請求過於頻繁，請稍後再試。",
      requestId: request.id,
      retryable: true,
    }),
  });

  const aggregateCounters = new Map<string, { current: number; expires: number }>();
  app.addHook("onRequest", async (request) => {
    if (request.url.split("?")[0] === "/api/health") return;
    const key = rateLimitKey("aggregate-ip", request.ip);
    let current: number;
    if (runtime.rateLimitStore) current = (await runtime.rateLimitStore.consumeRateLimit(key, 60000)).current;
    else {
      const now = Date.now();
      for (const [id, value] of aggregateCounters) if (value.expires <= now) aggregateCounters.delete(id);
      const counter = aggregateCounters.get(key) ?? { current: 0, expires: now + 60000 };
      current = ++counter.current; aggregateCounters.set(key, counter);
    }
    if (current > 120) throw new DomainError("rate_limited", "請求過於頻繁，請稍後再試。", 429, true);
  });

  app.addHook("onRequest", async (request, reply) => {
    const origin = request.headers.origin;
    const isAllowed = Boolean(origin && allowedOrigins.includes(origin));
    if (isAllowed && origin) {
      reply.header("access-control-allow-origin", origin);
      reply.header(
        "access-control-allow-methods",
        "GET,POST,PUT,PATCH,DELETE,OPTIONS",
      );
      reply.header("access-control-allow-headers", "content-type,authorization");
      reply.header("access-control-max-age", "600");
      reply.header("vary", "Origin");
    }
    if (request.method === "OPTIONS") {
      if (!isAllowed) {
        return problem(request, reply, 403, {
          code: "cors_origin_denied",
          message: "不允許此網站存取 API。",
          retryable: false,
        });
      }
      return reply.code(204).send();
    }
  });

  app.addHook("onSend", async (_request, reply, payload) => {
    reply.header("cache-control", "no-store");
    reply.header("x-content-type-options", "nosniff");
    reply.header("x-frame-options", "DENY");
    reply.header("referrer-policy", "no-referrer");
    if (!reply.hasHeader("content-security-policy")) {
      reply.header("content-security-policy", "default-src 'none'; frame-ancestors 'none'");
    }
    return payload;
  });

  app.setErrorHandler((error, request, reply) => {
    if (error instanceof ZodError) {
      const fieldErrors = Object.fromEntries(
        error.issues.map((issue) => [
          issue.path.join(".") || "request",
          issue.message,
        ]),
      );
      return problem(request, reply, 422, {
        code: "validation_error",
        message: "輸入內容有誤，請修正標示欄位後再試一次。",
        retryable: false,
        fieldErrors,
      });
    }
    if (error instanceof DomainError) {
      return problem(request, reply, error.status, {
        code: error.code,
        message: error.message,
        retryable: error.retryable,
        ...(error.fieldErrors ? { fieldErrors: error.fieldErrors } : {}),
      });
    }
    const fastifyError = error as { statusCode?: number; code?: string };
    if (fastifyError.code === "rate_limited") {
      return problem(request, reply, fastifyError.statusCode ?? 429, {
        code: "rate_limited",
        message: "請求過於頻繁，請稍後再試。",
        retryable: true,
      });
    }
    if (fastifyError.statusCode === 415 || fastifyError.code === "FST_ERR_CTP_INVALID_MEDIA_TYPE") {
      return problem(request, reply, 415, { code: "unsupported_media_type", message: "請使用 JSON 格式提交資料。", retryable: false });
    }
    if (
      fastifyError.statusCode === 413 ||
      fastifyError.code === "FST_ERR_CTP_BODY_TOO_LARGE"
    ) {
      return problem(request, reply, 413, {
        code: "request_too_large",
        message: "輸入內容過長，請縮短後再試一次。",
        retryable: false,
      });
    }
    if (
      fastifyError.statusCode === 400 ||
      fastifyError.code === "FST_ERR_CTP_INVALID_JSON_BODY"
    ) {
      return problem(request, reply, 400, {
        code: "invalid_json",
        message: "請求內容不是有效的 JSON。",
        retryable: false,
      });
    }
    request.log.error(
      {
        requestId: request.id,
        errorType: error instanceof Error ? error.name : typeof error,
      },
      "Unhandled FutureMint API error",
    );
    return problem(request, reply, 500, {
      code: "internal_error",
      message: "服務暫時無法完成請求，請稍後再試。",
      retryable: true,
    });
  });

  app.setNotFoundHandler((request, reply) =>
    problem(request, reply, 404, {
      code: "route_not_found",
      message: "找不到請求的 API。",
      retryable: false,
    }),
  );

  app.get("/api/health", { config: { rateLimit: false } }, async (request, reply) => {
    try {
      await runtime.healthCheck();
      return reply.code(200).send({
        status: "ok",
        version: "1.0.0",
        mode: runtime.mode,
        aiProvider: runtime.aiProvider,
        dataProvider: runtime.dataProvider,
        requestId: request.id,
      });
    } catch (error) {
      request.log.warn(
        { requestId: request.id, errorType: error instanceof Error ? error.name : typeof error },
        "FutureMint dependency health check failed",
      );
      return problem(request, reply, 503, {
        code: "service_not_ready",
        message: "服務尚未準備完成。",
        retryable: true,
      });
    }
  });

  const authRateLimit = {
    preHandler: async (request: FastifyRequest) => {
      if (!runtime.rateLimitStore) return;
      const body = request.body as { email?: unknown } | undefined;
      const guardianBody = request.body as { accountEmail?: unknown; guardianEmail?: unknown } | undefined;
      const identity = typeof body?.email === "string" ? body.email.trim().toLowerCase()
        : typeof guardianBody?.accountEmail === "string" ? guardianBody.accountEmail.trim().toLowerCase()
        : request.headers.authorization;
      if (!identity) return;
      const result = await runtime.rateLimitStore.consumeRateLimit(rateLimitKey("auth-account", identity), 60000);
      if (result.current > 10) throw new DomainError("rate_limited", "請求過於頻繁，請稍後再試。", 429, true);
    },
    config: { rateLimit: { max: 10, timeWindow: "1 minute" } },
  };
  const aiRateLimit = {
    preHandler: async (request: FastifyRequest) => {
      const account = await requireAuthenticatedUser(request, runtime);
      if (!runtime.rateLimitStore) return;
      const result = await runtime.rateLimitStore.consumeRateLimit(rateLimitKey("ai-account", account.id), 60000);
      if (result.current > 20) throw new DomainError("rate_limited", "請求過於頻繁，請稍後再試。", 429, true);
    },
    config: { rateLimit: { max: 20, timeWindow: "1 minute" } },
  };
  const marketRateLimit = {
    config: { rateLimit: { max: 60, timeWindow: "1 minute" } },
  };

  app.post("/api/auth/register", authRateLimit, async (request, reply) =>
    success(
      request,
      reply,
      await runtime.authService.register(request.body as never),
      201,
    ),
  );
  app.post("/api/auth/login", authRateLimit, async (request, reply) =>
    success(
      request,
      reply,
      await runtime.authService.login(request.body as never),
    ),
  );
  app.get("/api/auth/me", async (request, reply) =>
    success(
      request,
      reply,
      await requireAuthenticatedUser(request, runtime, true),
    ),
  );
  app.post("/api/auth/logout", async (request, reply) => {
    await runtime.authService.logout(bearerToken(request));
    return success(request, reply, { loggedOut: true });
  });
  app.delete("/api/auth/account", authRateLimit, async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime, true);
    await runtime.authService.deleteAccount(account.id, request.body as never);
    return success(request, reply, { deleted: true });
  });

  app.post("/api/auth/email-verification/request", authRateLimit, async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime, true);
    await runtime.authService.requestEmailVerification(account.id);
    return success(request, reply, { accepted: true });
  });
  app.post("/api/auth/email-verification/confirm", authRateLimit, async (request, reply) => {
    const body = z.object({ token: z.string().regex(/^[A-Za-z0-9_-]{43}$/) }).parse(request.body);
    await runtime.authService.verifyEmail(body.token);
    return success(request, reply, { verified: true });
  });
  app.post("/api/auth/password-reset/request", authRateLimit, async (request, reply) => {
    const body = z.object({ email: z.string().trim().email().max(254) }).parse(request.body);
    await runtime.authService.requestPasswordReset(body);
    return success(request, reply, { accepted: true });
  });
  app.post("/api/auth/password-reset/confirm", authRateLimit, async (request, reply) => {
    const body = z.object({ token: z.string().regex(/^[A-Za-z0-9_-]{43}$/), password: authCredentialsSchema.shape.password }).parse(request.body);
    await runtime.authService.resetPassword(body.token, body.password);
    return success(request, reply, { reset: true });
  });
  const ai = runtime.aiPolicy;
  const servicePolicy = {
    servicePolicyVersion, minimumAge: 15, country: "TW", guardianRequiredUnder18: true, eligibilityRequired: runtime.eligibilityRequired ?? false,
    privacyPolicyVersion: runtime.publicConfig?.policyVersion ?? "",
    ai: { provider: runtime.aiProvider, displayName: ai?.providerName ?? (runtime.aiProvider === "openai" ? "OpenAI" : runtime.aiProvider === "liangjie" ? "量界智算" : "離線展示"),
      model: ai?.model ?? "", policyVersion: ai?.policyVersion ?? providerAiPolicyVersion,
      dataRecipients: ai?.recipients ?? [], dataTerms: ai?.dataTerms ?? "", reviewed: ai?.reviewed ?? false },
  };
  app.get("/api/service-policy", async (request, reply) => success(request, reply, servicePolicy));
  registerPublicPages(app, runtime.publicConfig, servicePolicy);
  const writableUser = async (request: FastifyRequest) => {
    const account = await requireAuthenticatedUser(request, runtime);
    await runtime.authService.requireServiceEligibility(account.id);
    return account;
  };
  const aiOperation = async <T>(request: FastifyRequest, operation: () => Promise<T>): Promise<T> => {
    const account = await writableUser(request);
    if (runtime.aiProvider === "demo") return operation();
    await runtime.authService.requireAiConsent(account.id);
    const release = await runtime.aiGate?.acquire(account.id);
    try { return await operation(); }
    finally { try { await release?.(); } catch { request.log.warn({ requestId: request.id }, "AI admission lease cleanup failed; lease will expire"); } }
  };
  app.get("/api/privacy/eligibility", async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime, true);
    return success(request, reply, await runtime.authService.getEligibility(account.id));
  });
  app.put("/api/privacy/age-declaration", authRateLimit, async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime, true);
    return success(request, reply, await runtime.authService.declareAge(account.id, request.body as never));
  });
  app.post("/api/privacy/guardian-consent/request", authRateLimit, async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime);
    return success(request, reply, await runtime.authService.requestGuardian(account.id, request.body as never));
  });
  app.post("/api/privacy/guardian-consent/confirm", authRateLimit, async (request, reply) =>
    success(request, reply, await runtime.authService.confirmGuardian(guardianConfirmationSchema.parse(request.body))));
  app.post("/api/privacy/guardian-consent/withdraw", authRateLimit, async (request, reply) =>
    success(request, reply, await runtime.authService.withdrawGuardian(request.body as never)));
  app.post("/api/privacy/guardian-consent/withdrawal-request", authRateLimit, async (request, reply) => {
    const input = z.object({ accountEmail: z.string().trim().email().max(254), guardianEmail: z.string().trim().email().max(254) }).parse(request.body);
    return success(request, reply, await runtime.authService.requestGuardianWithdrawal(input));
  });
  app.delete("/api/privacy/guardian-consent", authRateLimit, async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime, true);
    return success(request, reply, await runtime.authService.withdrawGuardianByAccount(account.id));
  });
  app.get("/api/privacy/export", authRateLimit, async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime, true);
    const personal = await runtime.service.exportUserData(account.id);
    return success(request, reply, { version: 1, exportedAt: new Date().toISOString(), account: { id: account.id, email: account.email, createdAt: account.createdAt, emailVerified: account.emailVerified },
      eligibility: await runtime.authService.getEligibility(account.id), aiConsent: await runtime.authService.getAiConsent(account.id), ...personal });
  });

  app.get("/api/privacy/ai-consent", async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime);
    return success(
      request,
      reply,
      await runtime.authService.getAiConsent(account.id),
    );
  });
  app.put("/api/privacy/ai-consent", async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime);
    return success(
      request,
      reply,
      await runtime.authService.setAiConsent(account.id, request.body as never),
    );
  });

  app.get("/api/profile", async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime);
    return success(request, reply, await runtime.service.getProfile(account.id));
  });
  app.put("/api/profile", async (request, reply) => {
    const account = await writableUser(request);
    const profile = await runtime.service.updateProfile(
      account.id,
      request.body as never,
    );
    await runtime.authService.markProfileComplete(account.id);
    return success(request, reply, profile);
  });

  app.get("/api/family", async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime);
    return success(
      request,
      reply,
      await runtime.service.getFamilyOverview(account.id),
    );
  });
  app.post("/api/family/invite", async (request, reply) => {
    const account = await writableUser(request);
    return success(
      request,
      reply,
      await runtime.service.createFamilyInvite(account.id),
      201,
    );
  });
  app.post("/api/family/invite/rotate", authRateLimit, async (request, reply) => {
    const account = await writableUser(request);
    return success(request, reply, await runtime.service.rotateFamilyInvite(account.id));
  });
  app.delete("/api/family/invite", authRateLimit, async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime);
    return success(request, reply, await runtime.service.revokeFamilyInvite(account.id));
  });
  app.post("/api/family/join", async (request, reply) => {
    const account = await writableUser(request);
    return success(
      request,
      reply,
      await runtime.service.joinFamily(account.id, request.body as never),
    );
  });
  app.post("/api/family/leave", async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime);
    await runtime.service.leaveFamily(account.id);
    return success(request, reply, { left: true });
  });

  app.post("/api/captures/parse", aiRateLimit, async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime);
    return success(
      request,
      reply,
      await aiOperation(request, () => runtime.service.parseCapture(account.id, request.body as never)),
    );
  });

  app.get("/api/money-events", async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime);
    const query = request.query as { type?: string; from?: string; to?: string; limit?: string; cursor?: string };
    return success(request, reply, query.limit !== undefined || query.cursor !== undefined
      ? await runtime.service.listMoneyEventsPage(account.id, query as never)
      : await runtime.service.listMoneyEvents(account.id, query));
  });
  app.post("/api/money-events", async (request, reply) => {
    const account = await writableUser(request);
    return success(
      request,
      reply,
      await runtime.service.saveMoneyEvent(account.id, request.body as never),
      201,
    );
  });
  app.put("/api/money-events/:eventId", async (request, reply) => {
    const account = await writableUser(request);
    const { eventId } = moneyEventIdParamsSchema.parse(request.params);
    return success(
      request,
      reply,
      await runtime.service.updateMoneyEvent(
        account.id,
        eventId,
        request.body as never,
      ),
    );
  });
  app.delete("/api/money-events/:eventId", async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime);
    const { eventId } = moneyEventIdParamsSchema.parse(request.params);
    await runtime.service.deleteMoneyEvent(account.id, eventId);
    return success(request, reply, { deleted: true });
  });

  app.get("/api/dashboard", async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime);
    return success(
      request,
      reply,
      await runtime.service.getDashboard(account.id),
    );
  });
  app.get("/api/insights", async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime);
    return success(
      request,
      reply,
      await runtime.service.getInsights(account.id),
    );
  });

  app.get("/api/subscriptions", async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime);
    return success(
      request,
      reply,
      await runtime.service.getSubscriptions(account.id),
    );
  });
  app.post("/api/subscriptions", async (request, reply) => {
    const account = await writableUser(request);
    return success(request, reply, await runtime.service.createSubscription(account.id, request.body as never), 201);
  });
  app.put("/api/subscriptions/:subscriptionId", async (request, reply) => {
    const account = await writableUser(request);
    const { subscriptionId } = z.object({ subscriptionId: z.string().uuid() }).parse(request.params);
    return success(request, reply, await runtime.service.updateSubscription(account.id, subscriptionId, request.body as never));
  });
  app.delete("/api/subscriptions/:subscriptionId", async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime);
    const { subscriptionId } = z.object({ subscriptionId: z.string().uuid() }).parse(request.params);
    return success(request, reply, await runtime.service.deactivateSubscription(account.id, subscriptionId));
  });

  app.post("/api/subscriptions/compare", async (request, reply) => {
    await requireAuthenticatedUser(request, runtime);
    return success(
      request,
      reply,
      runtime.service.compareSubscriptions(request.body as never),
    );
  });

  // Static reviewed education is readable without age/AI consent, accounts or
  // provider calls. Completion of catalog items stays on the client.
  app.get("/api/education/catalog", async (request, reply) => success(request, reply, {
    version: "controlled-education-2026-10-v1",
    items: educationTopics.map((topic) => ({
      ...catalogLesson(topic), id: `catalog-${topic}`, userId: "education-catalog",
      sourceEventIds: [], source: "manual", createdAt: "2026-10-01T00:00:00Z",
      disclaimer: "內容來自受控金融教育資料庫，不使用第三方 AI；不推薦投資標的，也不保證報酬。",
    })),
  }));
  app.post("/api/lessons/generate", aiRateLimit, async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime);
    return success(
      request,
      reply,
      await aiOperation(request, () => runtime.service.generateLesson(account.id)),
    );
  });
  app.get("/api/lessons/current", async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime);
    return success(
      request,
      reply,
      await runtime.service.getCurrentLesson(account.id),
    );
  });
  app.patch("/api/lessons/:lessonId", async (request, reply) => {
    const account = await writableUser(request);
    const { lessonId } = request.params as { lessonId: string };
    const body = lessonCompletionInputSchema.parse(request.body);
    return success(
      request,
      reply,
      await runtime.service.completeLesson(
        account.id,
        lessonId,
        body.selectedOption,
      ),
    );
  });
  app.get("/api/learning-plan", aiRateLimit, async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime);
    return success(
      request,
      reply,
      await aiOperation(request, () => runtime.service.getLearningPlan(account.id)),
    );
  });

  app.post("/api/future-seed/preview", async (request, reply) => {
    await requireAuthenticatedUser(request, runtime);
    return success(
      request,
      reply,
      runtime.service.previewFutureSeed(request.body as never),
    );
  });
  app.post("/api/future-seed/simulate", async (request, reply) => {
    await requireAuthenticatedUser(request, runtime);
    return success(
      request,
      reply,
      runtime.service.simulateInvestments(request.body as never),
    );
  });
  app.post("/api/coach/chat", aiRateLimit, async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime);
    return success(
      request,
      reply,
      await aiOperation(request, () => runtime.service.coach(request.body as never)),
    );
  });

  app.get("/api/market/quotes", marketRateLimit, async (request, reply) =>
    success(
      request,
      reply,
      await runtime.service.getMarketSnapshot(),
    ),
  );
  app.get("/api/investment-lab", marketRateLimit, async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime);
    return success(
      request,
      reply,
      await runtime.service.getInvestmentLab(account.id),
    );
  });
  app.post("/api/investment-lab/orders", async (request, reply) => {
    const account = await writableUser(request);
    return success(
      request,
      reply,
      await runtime.service.placeInvestmentOrder(
        account.id,
        request.body as never,
      ),
      201,
    );
  });
  app.post("/api/investment-lab/dice", async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime);
    return success(
      request,
      reply,
      runtime.service.rollInvestmentPracticeEvent(
        account.id,
        request.body as never,
      ),
    );
  });

  let maintenanceTimer: ReturnType<typeof setInterval> | undefined;
  app.addHook("onReady", async () => {
    if (!runtime.maintenance) return;
    const maintain = async () => {
      try { await runtime.maintenance!(); }
      catch { app.log.warn("FutureMint maintenance failed; will retry next interval"); }
    };
    await maintain();
    maintenanceTimer = setInterval(() => void maintain(), 60 * 60 * 1000);
    maintenanceTimer.unref();
  });
  app.addHook("onClose", async () => {
    clearInterval(maintenanceTimer);
    await runtime.close();
  });
  return app;
};
