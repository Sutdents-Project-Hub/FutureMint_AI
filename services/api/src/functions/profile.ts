import {
  app,
  type HttpHandler,
  type HttpRequest,
  type InvocationContext,
} from "@azure/functions";

import { getRuntime } from "../http/runtime";
import { requireAuthenticatedUser } from "../http/authentication";
import { ok, readJson, toProblem } from "../http/responses";

export const profileHandler = async (
  request: HttpRequest,
  context: InvocationContext,
) => {
  try {
    const runtime = getRuntime();
    const account = await requireAuthenticatedUser(request, runtime);
    const profile =
      request.method === "PUT"
        ? await runtime.service.updateProfile(
            account.id,
            (await readJson(request)) as never,
          )
        : await runtime.service.getProfile(account.id);
    if (request.method === "PUT") {
      await runtime.authService.markProfileComplete(account.id);
    }
    return ok(context, profile, 200, request);
  } catch (error) {
    return toProblem(context, error, request);
  }
};

app.http("profile", {
  methods: ["GET", "PUT"],
  authLevel: "anonymous",
  route: "profile",
  handler: profileHandler as HttpHandler,
});
