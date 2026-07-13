import {
  app,
  type HttpHandler,
  type HttpRequest,
  type HttpResponseInit,
  type InvocationContext,
} from "@azure/functions";

import { getRuntime } from "../http/runtime";
import { responseHeaders } from "../http/responses";

export const healthHandler = async (
  request: HttpRequest,
  context: InvocationContext,
): Promise<HttpResponseInit> => {
  const runtime = getRuntime();
  return {
    status: 200,
    headers: responseHeaders(request),
    jsonBody: {
      status: "ok",
      version: "1.0.0",
      mode: runtime.mode,
      aiProvider: runtime.aiProvider,
      dataProvider: runtime.dataProvider,
      requestId: context.invocationId,
    },
  };
};

app.http("health", {
  methods: ["GET"],
  authLevel: "anonymous",
  route: "health",
  handler: healthHandler as HttpHandler,
});
