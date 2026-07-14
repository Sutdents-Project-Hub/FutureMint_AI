import type { FutureMintService } from "../application/futureMintService";
import { FutureMintService as Service } from "../application/futureMintService";
import { demoCatalog } from "../adapters/demoCatalog";
import { DemoAiProvider } from "../adapters/demoAiProvider";
import { InMemoryRepository } from "../adapters/inMemoryRepository";
import { createAzureOpenAiProviderFromEnvironment } from "../adapters/azureOpenAiProvider";
import { createCosmosRepositoryFromEnvironment } from "../adapters/cosmosRepository";
import { AuthService } from "../auth/authService";

export interface Runtime {
  mode: "demo" | "azure";
  aiProvider: "demo" | "azure";
  dataProvider: "memory" | "cosmos";
  service: FutureMintService;
  authService: AuthService;
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
): Omit<Runtime, "service" | "authService"> => {
  const aiProvider = requiredChoice("AI_PROVIDER", environment.AI_PROVIDER, [
    "demo",
    "azure",
  ] as const);
  const dataProvider = requiredChoice(
    "DATA_PROVIDER",
    environment.DATA_PROVIDER,
    ["memory", "cosmos"] as const,
  );
  return {
    mode:
      aiProvider === "azure" || dataProvider === "cosmos" ? "azure" : "demo",
    aiProvider,
    dataProvider,
  };
};

const createRuntime = (): Runtime => {
  const config = parseRuntimeConfig(process.env);
  const repository =
    config.dataProvider === "cosmos"
      ? createCosmosRepositoryFromEnvironment()
      : new InMemoryRepository();
  const aiProvider =
    config.aiProvider === "azure"
      ? createAzureOpenAiProviderFromEnvironment()
      : new DemoAiProvider();
  return {
    ...config,
    service: new Service(repository, aiProvider, demoCatalog),
    authService: new AuthService(repository),
  };
};

export const getRuntime = (): Runtime => {
  runtime ??= createRuntime();
  return runtime;
};

export const setRuntimeForTests = (value: Runtime): void => {
  runtime = value;
};
