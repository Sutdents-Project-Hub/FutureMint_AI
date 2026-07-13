import {
  app,
  type HttpHandler,
  type HttpRequest,
  type InvocationContext,
} from "@azure/functions";

import { DomainError } from "../contracts/errors";
import { getRuntime } from "../http/runtime";
import { ok, toProblem } from "../http/responses";

export const resetDemoHandler = async (
  request: HttpRequest,
  context: InvocationContext,
) => {
  try {
    const runtime = getRuntime();
    if (!runtime.demoResetEnabled) {
      throw new DomainError(
        "demo_reset_disabled",
        "此環境未開放 Demo 重設。",
        403,
      );
    }
    await runtime.service.resetDemo("demo-user");
    return ok(context, { reset: true }, 200, request);
  } catch (error) {
    return toProblem(context, error, request);
  }
};

app.http("demoReset", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "demo/reset",
  handler: resetDemoHandler as HttpHandler,
});
