import {
  app,
  type HttpHandler,
  type HttpRequest,
  type InvocationContext,
} from "@azure/functions";

import { getRuntime } from "../http/runtime";
import { requireAuthenticatedUser } from "../http/authentication";
import { ok, readJson, toProblem } from "../http/responses";

export const captureParseHandler = async (
  request: HttpRequest,
  context: InvocationContext,
) => {
  try {
    const runtime = getRuntime();
    const account = await requireAuthenticatedUser(request, runtime);
    const result = await runtime.service.parseCapture(
      account.id,
      (await readJson(request)) as never,
    );
    return ok(context, result, 200, request);
  } catch (error) {
    return toProblem(context, error, request);
  }
};

app.http("captureParse", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "captures/parse",
  handler: captureParseHandler as HttpHandler,
});
