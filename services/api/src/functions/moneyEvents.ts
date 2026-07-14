import {
  app,
  type HttpHandler,
  type HttpRequest,
  type InvocationContext,
} from "@azure/functions";

import { getRuntime } from "../http/runtime";
import { requireAuthenticatedUser } from "../http/authentication";
import { ok, readJson, toProblem } from "../http/responses";

export const listMoneyEventsHandler = async (
  request: HttpRequest,
  context: InvocationContext,
) => {
  try {
    const runtime = getRuntime();
    const account = await requireAuthenticatedUser(request, runtime);
    return ok(
      context,
      await runtime.service.listMoneyEvents(account.id, {
        type: request.query.get("type") ?? undefined,
        from: request.query.get("from") ?? undefined,
        to: request.query.get("to") ?? undefined,
      }),
      200,
      request,
    );
  } catch (error) {
    return toProblem(context, error, request);
  }
};

export const createMoneyEventHandler = async (
  request: HttpRequest,
  context: InvocationContext,
) => {
  try {
    const runtime = getRuntime();
    const account = await requireAuthenticatedUser(request, runtime);
    const event = await runtime.service.saveMoneyEvent(
      account.id,
      (await readJson(request)) as never,
    );
    return ok(context, event, 201, request);
  } catch (error) {
    return toProblem(context, error, request);
  }
};

app.http("moneyEvents", {
  methods: ["GET", "POST"],
  authLevel: "anonymous",
  route: "money-events",
  handler: (async (request, context) =>
    request.method === "POST"
      ? createMoneyEventHandler(request, context)
      : listMoneyEventsHandler(request, context)) as HttpHandler,
});
