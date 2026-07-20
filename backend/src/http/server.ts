import rateLimit from "@fastify/rate-limit";
import Fastify, {
  type FastifyInstance,
  type FastifyReply,
  type FastifyRequest,
} from "fastify";
import { ZodError } from "zod";

import { DomainError } from "../contracts/errors";
import { lessonCompletionInputSchema } from "../contracts/schemas";
import { bearerToken, requireAuthenticatedUser } from "./authentication";
import { getRuntime, type Runtime } from "./runtime";

interface BuildServerOptions {
  runtime?: Runtime;
  allowedOrigins?: string[];
  logger?: boolean;
}

export const parseAllowedOrigins = (
  value: string | undefined,
  requireSecure = process.env.NODE_ENV === "production",
): string[] => {
  const origins = (value ?? "")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);

  if (requireSecure && origins.length === 0) {
    throw new Error("ALLOWED_ORIGINS is required in production");
  }

  return origins.map((origin) => {
    let url: URL;
    try {
      url = new URL(origin);
    } catch {
      throw new Error("ALLOWED_ORIGINS must contain valid HTTPS origin values");
    }
    const protocolAllowed = requireSecure
      ? url.protocol === "https:"
      : url.protocol === "https:" || url.protocol === "http:";
    if (!protocolAllowed || url.origin !== origin) {
      throw new Error(
        requireSecure
          ? "ALLOWED_ORIGINS must contain valid HTTPS origin values"
          : "ALLOWED_ORIGINS must contain valid HTTP(S) origin values",
      );
    }
    return origin;
  });
};

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
    // Coolify's reverse proxy is the sole trusted hop. Do not trust a client-
    // supplied X-Forwarded-For chain when enforcing per-IP rate limits.
    trustProxy: 1,
    bodyLimit: 32 * 1024,
  });

  await app.register(rateLimit, {
    global: true,
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

  app.addHook("onRequest", async (request, reply) => {
    const origin = request.headers.origin;
    const isAllowed = Boolean(origin && allowedOrigins.includes(origin));
    if (isAllowed && origin) {
      reply.header("access-control-allow-origin", origin);
      reply.header("access-control-allow-methods", "GET,POST,PUT,PATCH,OPTIONS");
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
    reply.header("content-security-policy", "default-src 'none'; frame-ancestors 'none'");
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

  app.get("/api/health", async (request, reply) => {
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
    config: { rateLimit: { max: 10, timeWindow: "1 minute" } },
  };
  const aiRateLimit = {
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
      await requireAuthenticatedUser(request, runtime),
    ),
  );
  app.post("/api/auth/logout", async (request, reply) => {
    await runtime.authService.logout(bearerToken(request));
    return success(request, reply, { loggedOut: true });
  });

  app.get("/api/profile", async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime);
    return success(request, reply, await runtime.service.getProfile(account.id));
  });
  app.put("/api/profile", async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime);
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
    const account = await requireAuthenticatedUser(request, runtime);
    return success(
      request,
      reply,
      await runtime.service.createFamilyInvite(account.id),
      201,
    );
  });
  app.post("/api/family/join", async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime);
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
      await runtime.service.parseCapture(account.id, request.body as never),
    );
  });

  app.get("/api/money-events", async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime);
    const query = request.query as { type?: string; from?: string; to?: string };
    return success(
      request,
      reply,
      await runtime.service.listMoneyEvents(account.id, query),
    );
  });
  app.post("/api/money-events", async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime);
    return success(
      request,
      reply,
      await runtime.service.saveMoneyEvent(account.id, request.body as never),
      201,
    );
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
  app.post("/api/subscriptions/compare", async (request, reply) => {
    await requireAuthenticatedUser(request, runtime);
    return success(
      request,
      reply,
      runtime.service.compareSubscriptions(request.body as never),
    );
  });

  app.post("/api/lessons/generate", aiRateLimit, async (request, reply) => {
    const account = await requireAuthenticatedUser(request, runtime);
    return success(
      request,
      reply,
      await runtime.service.generateLesson(account.id),
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
    const account = await requireAuthenticatedUser(request, runtime);
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
      await runtime.service.getLearningPlan(account.id),
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
    await requireAuthenticatedUser(request, runtime);
    return success(
      request,
      reply,
      await runtime.service.coach(request.body as never),
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
    const account = await requireAuthenticatedUser(request, runtime);
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

  app.addHook("onClose", async () => runtime.close());
  return app;
};
