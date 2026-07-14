import {
  app,
  type HttpHandler,
  type HttpRequest,
  type InvocationContext,
} from "@azure/functions";

import { bearerToken, requireAuthenticatedUser } from "../http/authentication";
import { getRuntime } from "../http/runtime";
import { ok, readJson, toProblem } from "../http/responses";

export const registerHandler = async (
  request: HttpRequest,
  context: InvocationContext,
) => {
  try {
    const result = await getRuntime().authService.register(
      (await readJson(request)) as never,
    );
    return ok(context, result, 201, request);
  } catch (error) {
    return toProblem(context, error, request);
  }
};

export const loginHandler = async (
  request: HttpRequest,
  context: InvocationContext,
) => {
  try {
    const result = await getRuntime().authService.login(
      (await readJson(request)) as never,
    );
    return ok(context, result, 200, request);
  } catch (error) {
    return toProblem(context, error, request);
  }
};

export const meHandler = async (
  request: HttpRequest,
  context: InvocationContext,
) => {
  try {
    return ok(context, await requireAuthenticatedUser(request), 200, request);
  } catch (error) {
    return toProblem(context, error, request);
  }
};

export const logoutHandler = async (
  request: HttpRequest,
  context: InvocationContext,
) => {
  try {
    const runtime = getRuntime();
    await runtime.authService.logout(bearerToken(request));
    return ok(context, { loggedOut: true }, 200, request);
  } catch (error) {
    return toProblem(context, error, request);
  }
};

app.http("authRegister", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "auth/register",
  handler: registerHandler as HttpHandler,
});

app.http("authLogin", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "auth/login",
  handler: loginHandler as HttpHandler,
});

app.http("authMe", {
  methods: ["GET"],
  authLevel: "anonymous",
  route: "auth/me",
  handler: meHandler as HttpHandler,
});

app.http("authLogout", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "auth/logout",
  handler: logoutHandler as HttpHandler,
});
