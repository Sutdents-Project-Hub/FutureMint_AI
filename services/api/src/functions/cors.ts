import {
  app,
  type HttpHandler,
  type HttpRequest,
  type InvocationContext,
} from "@azure/functions";

import { isAllowedOrigin, responseHeaders } from "../http/responses";

export const corsPreflightHandler = async (
  request: HttpRequest,
  _context: InvocationContext,
) => ({
  status: isAllowedOrigin(request) ? 204 : 403,
  headers: responseHeaders(request),
});

app.http("corsPreflight", {
  methods: ["OPTIONS"],
  authLevel: "anonymous",
  route: "{*path}",
  handler: corsPreflightHandler as HttpHandler,
});
