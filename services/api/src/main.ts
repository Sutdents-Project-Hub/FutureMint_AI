import "dotenv/config";

import { buildServer } from "./http/server";

const main = async (): Promise<void> => {
  const app = await buildServer();
  const host = process.env.HOST || "0.0.0.0";
  const port = Number(process.env.PORT || "3000");
  if (!Number.isInteger(port) || port < 1 || port > 65_535) {
    throw new Error("PORT must be an integer between 1 and 65535");
  }

  const shutdown = async (signal: string): Promise<void> => {
    app.log.info({ signal }, "FutureMint API shutting down");
    await app.close();
    process.exit(0);
  };
  process.once("SIGTERM", () => void shutdown("SIGTERM"));
  process.once("SIGINT", () => void shutdown("SIGINT"));

  await app.listen({ host, port });
};

void main().catch((error: unknown) => {
  console.error("futuremint_api_start_failed", {
    errorType: error instanceof Error ? error.name : typeof error,
  });
  process.exitCode = 1;
});
