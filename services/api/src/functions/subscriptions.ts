import {
  app,
  type HttpHandler,
  type HttpRequest,
  type InvocationContext,
} from "@azure/functions";

import { getRuntime } from "../http/runtime";
import { ok, readJson, toProblem } from "../http/responses";

export const compareSubscriptionsHandler = async (
  request: HttpRequest,
  context: InvocationContext,
) => {
  try {
    const comparison = getRuntime().service.compareSubscriptions(
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
    return ok(
      context,
      await getRuntime().service.getSubscriptions("demo-user"),
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
