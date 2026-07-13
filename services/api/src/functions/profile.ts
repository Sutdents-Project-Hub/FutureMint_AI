import {
  app,
  type HttpHandler,
  type HttpRequest,
  type InvocationContext,
} from "@azure/functions";

import { getRuntime } from "../http/runtime";
import { ok, readJson, toProblem } from "../http/responses";

export const profileHandler = async (
  request: HttpRequest,
  context: InvocationContext,
) => {
  try {
    const service = getRuntime().service;
    const profile =
      request.method === "PUT"
        ? await service.updateProfile(
            "demo-user",
            (await readJson(request)) as never,
          )
        : await service.getProfile("demo-user");
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
