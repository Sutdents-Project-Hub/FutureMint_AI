import {
  app,
  type HttpHandler,
  type HttpRequest,
  type InvocationContext,
} from "@azure/functions";

import { getRuntime } from "../http/runtime";
import { ok, toProblem } from "../http/responses";

export const dashboardHandler = async (
  request: HttpRequest,
  context: InvocationContext,
) => {
  try {
    return ok(
      context,
      await getRuntime().service.getDashboard("demo-user"),
      200,
      request,
    );
  } catch (error) {
    return toProblem(context, error, request);
  }
};

app.http("dashboard", {
  methods: ["GET"],
  authLevel: "anonymous",
  route: "dashboard",
  handler: dashboardHandler as HttpHandler,
});
