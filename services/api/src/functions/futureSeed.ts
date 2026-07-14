import {
  app,
  type HttpHandler,
  type HttpRequest,
  type InvocationContext,
} from "@azure/functions";

import { getRuntime } from "../http/runtime";
import { requireAuthenticatedUser } from "../http/authentication";
import { ok, readJson, toProblem } from "../http/responses";

export const futureSeedHandler = async (
  request: HttpRequest,
  context: InvocationContext,
) => {
  try {
    const runtime = getRuntime();
    await requireAuthenticatedUser(request, runtime);
    return ok(
      context,
      runtime.service.previewFutureSeed(
        (await readJson(request)) as never,
      ),
      200,
      request,
    );
  } catch (error) {
    return toProblem(context, error, request);
  }
};

app.http("futureSeedPreview", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "future-seed/preview",
  handler: futureSeedHandler as HttpHandler,
});
