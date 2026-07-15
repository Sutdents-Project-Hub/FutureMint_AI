import type { FutureMintService } from "../application/futureMintService";
import { FutureMintService as Service } from "../application/futureMintService";
import { demoCatalog } from "../adapters/demoCatalog";
import { DemoAiProvider } from "../adapters/demoAiProvider";
import { InMemoryRepository } from "../adapters/inMemoryRepository";
import { createLiangjieAiProviderFromEnvironment } from "../adapters/liangjieAiProvider";
import { createPostgresRepositoryFromEnvironment } from "../adapters/postgresRepository";
import { TwseMarketDataProvider } from "../adapters/twseMarketDataProvider";
import { AuthService } from "../auth/authService";

export interface Runtime {
  mode: "demo" | "hosted";
  aiProvider: "demo" | "liangjie";
  dataProvider: "memory" | "postgres";
  service: FutureMintService;
  authService: AuthService;
  healthCheck: () => Promise<void>;
  close: () => Promise<void>;
}

let runtime: Runtime | undefined;

const requiredChoice = <T extends string>(
  name: string,
  value: string | undefined,
  allowed: readonly T[],
): T => {
  if (!value || !allowed.includes(value as T)) {
    throw new Error(`${name} must be one of: ${allowed.join(", ")}`);
  }
  return value as T;
};

export const parseRuntimeConfig = (
  environment: Record<string, string | undefined>,
): Pick<Runtime, "mode" | "aiProvider" | "dataProvider"> => {
  const aiProvider = requiredChoice("AI_PROVIDER", environment.AI_PROVIDER, [
    "demo",
    "liangjie",
  ] as const);
  const dataProvider = requiredChoice(
    "DATA_PROVIDER",
    environment.DATA_PROVIDER,
    ["memory", "postgres"] as const,
  );
  if (
    environment.NODE_ENV === "production" &&
    (aiProvider !== "liangjie" || dataProvider !== "postgres")
  ) {
    throw new Error(
      "production requires AI_PROVIDER=liangjie and DATA_PROVIDER=postgres",
    );
  }
  return {
    mode:
      aiProvider === "liangjie" || dataProvider === "postgres"
        ? "hosted"
        : "demo",
    aiProvider,
    dataProvider,
  };
};

export const createRuntime = (): Runtime => {
  const config = parseRuntimeConfig(process.env);
  const postgresRepository =
    config.dataProvider === "postgres"
      ? createPostgresRepositoryFromEnvironment()
      : undefined;
  const repository = postgresRepository ?? new InMemoryRepository();
  const aiProvider =
    config.aiProvider === "liangjie"
      ? createLiangjieAiProviderFromEnvironment()
      : new DemoAiProvider();
  const marketDataProvider = new TwseMarketDataProvider();
  return {
    ...config,
    service: new Service(
      repository,
      aiProvider,
      demoCatalog,
      marketDataProvider,
    ),
    authService: new AuthService(repository),
    healthCheck: postgresRepository
      ? () => postgresRepository.ping()
      : async () => undefined,
    close: postgresRepository
      ? () => postgresRepository.close()
      : async () => undefined,
  };
};

export const getRuntime = (): Runtime => {
  runtime ??= createRuntime();
  return runtime;
};

export const setRuntimeForTests = (value: Runtime): void => {
  runtime = value;
};
