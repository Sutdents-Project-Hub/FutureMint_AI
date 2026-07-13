import {
  app,
  type HttpHandler,
  type HttpRequest,
  type InvocationContext,
} from "@azure/functions";

import { getRuntime } from "../http/runtime";
import { ok, readJson, toProblem } from "../http/responses";

export const generateLessonHandler = async (
  request: HttpRequest,
  context: InvocationContext,
) => {
  try {
    return ok(
      context,
      await getRuntime().service.generateLesson("demo-user"),
      200,
      request,
    );
  } catch (error) {
    return toProblem(context, error, request);
  }
};

export const currentLessonHandler = async (
  request: HttpRequest,
  context: InvocationContext,
) => {
  try {
    return ok(
      context,
      await getRuntime().service.getCurrentLesson("demo-user"),
      200,
      request,
    );
  } catch (error) {
    return toProblem(context, error, request);
  }
};

export const completeLessonHandler = async (
  request: HttpRequest,
  context: InvocationContext,
) => {
  try {
    const body = (await readJson(request)) as { selectedOption?: string };
    return ok(
      context,
      await getRuntime().service.completeLesson(
        "demo-user",
        request.params.lessonId,
        body.selectedOption ?? "",
      ),
      200,
      request,
    );
  } catch (error) {
    return toProblem(context, error, request);
  }
};

app.http("lessonGenerate", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "lessons/generate",
  handler: generateLessonHandler as HttpHandler,
});

app.http("lessonCurrent", {
  methods: ["GET"],
  authLevel: "anonymous",
  route: "lessons/current",
  handler: currentLessonHandler as HttpHandler,
});

app.http("lessonComplete", {
  methods: ["PATCH"],
  authLevel: "anonymous",
  route: "lessons/{lessonId}",
  handler: completeLessonHandler as HttpHandler,
});
