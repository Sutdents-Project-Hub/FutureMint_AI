import type {
  HttpRequest,
  HttpResponseInit,
  InvocationContext,
} from "@azure/functions";
import { ZodError } from "zod";

import { DomainError } from "../contracts/errors";

const allowedOrigins = (): string[] =>
  (process.env.ALLOWED_ORIGINS ?? "")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);

export const responseHeaders = (
  request?: Pick<HttpRequest, "headers">,
): Record<string, string> => {
  const headers: Record<string, string> = {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
  };
  const origin = request?.headers.get("origin");
  if (origin && allowedOrigins().includes(origin)) {
    headers["access-control-allow-origin"] = origin;
    headers["access-control-allow-methods"] = "GET,POST,PUT,PATCH,OPTIONS";
    headers["access-control-allow-headers"] = "content-type,authorization";
    headers.vary = "Origin";
  }
  return headers;
};

export const isAllowedOrigin = (
  request: Pick<HttpRequest, "headers">,
): boolean => {
  const origin = request.headers.get("origin");
  return Boolean(origin && allowedOrigins().includes(origin));
};

export const ok = (
  context: InvocationContext,
  data: unknown,
  status = 200,
  request?: Pick<HttpRequest, "headers">,
): HttpResponseInit => ({
  status,
  headers: responseHeaders(request),
  jsonBody: { requestId: context.invocationId, data },
});

export const toProblem = (
  context: InvocationContext,
  error: unknown,
  request?: Pick<HttpRequest, "headers">,
): HttpResponseInit => {
  if (error instanceof ZodError) {
    const fieldErrors = Object.fromEntries(
      error.issues.map((issue) => [
        issue.path.join(".") || "request",
        issue.message,
      ]),
    );
    return {
      status: 422,
      headers: responseHeaders(request),
      jsonBody: {
        code: "validation_error",
        message: "輸入內容有誤，請修正標示欄位後再試一次。",
        requestId: context.invocationId,
        retryable: false,
        fieldErrors,
      },
    };
  }

  if (error instanceof DomainError) {
    return {
      status: error.status,
      headers: responseHeaders(request),
      jsonBody: {
        code: error.code,
        message: error.message,
        requestId: context.invocationId,
        retryable: error.retryable,
        fieldErrors: error.fieldErrors,
      },
    };
  }

  context.error("Unhandled FutureMint API error", {
    requestId: context.invocationId,
    errorType: error instanceof Error ? error.name : typeof error,
  });
  return {
    status: 500,
    headers: responseHeaders(request),
    jsonBody: {
      code: "internal_error",
      message: "服務暫時無法完成請求，請稍後再試。",
      requestId: context.invocationId,
      retryable: true,
    },
  };
};

export const readJson = async (request: { json(): Promise<unknown> }) => {
  try {
    return await request.json();
  } catch {
    throw new DomainError("invalid_json", "請求內容不是有效的 JSON。", 400);
  }
};
