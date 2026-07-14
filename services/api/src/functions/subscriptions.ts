import {
  app,
  type HttpHandler,
  type HttpRequest,
  type InvocationContext,
} from "@azure/functions";

import { getRuntime } from "../http/runtime";
import { requireAuthenticatedUser } from "../http/authentication";
import { ok, readJson, toProblem } from "../http/responses";

export const compareSubscriptionsHandler = async (
  request: HttpRequest,
  context: InvocationContext,
) => {
  try {
    const runtime = getRuntime();
    await requireAuthenticatedUser(request, runtime);
    const comparison = runtime.service.compareSubscriptions(
      (await readJson(request)) as never,
    );
    return ok(context, comparison, 200, request);
  } catch (error) {
    return toProblem(context, error, request);
  }
};

export const listSubscriptionsHandler = async (
  request: HttpRequest,
  context: InvocationContext,
) => {
  try {
    const runtime = getRuntime();
    const account = await requireAuthenticatedUser(request, runtime);
    return ok(
      context,
      await runtime.service.getSubscriptions(account.id),
      200,
      request,
    );
  } catch (error) {
    return toProblem(context, error, request);
  }
};

app.http("subscriptionCompare", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "subscriptions/compare",
  handler: compareSubscriptionsHandler as HttpHandler,
});

app.http("subscriptions", {
  methods: ["GET"],
  authLevel: "anonymous",
  route: "subscriptions",
  handler: listSubscriptionsHandler as HttpHandler,
});
