import {
  app,
  type HttpHandler,
  type HttpRequest,
  type InvocationContext,
} from "@azure/functions";

import { getRuntime } from "../http/runtime";
import { ok, readJson, toProblem } from "../http/responses";

export const captureParseHandler = async (
  request: HttpRequest,
  context: InvocationContext,
) => {
  try {
    const result = await getRuntime().service.parseCapture(
      "demo-user",
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
