import type { FutureMintService } from "../application/futureMintService";
import { FutureMintService as Service } from "../application/futureMintService";
import { demoCatalog } from "../adapters/demoCatalog";
import { DemoAiProvider } from "../adapters/demoAiProvider";
import { InMemoryRepository } from "../adapters/inMemoryRepository";
import { createLiangjieAiProviderFromEnvironment } from "../adapters/liangjieAiProvider";
import { createOpenAiProviderFromEnvironment } from "../adapters/openAiProvider";
import { parseAiConfig, type AiPolicyMetadata } from "../config/aiConfig";
import { parseRuntimeConfig } from "../config/runtimeConfig";
import { validateStartupConfig } from "../config/startupConfig";
import { AiRequestGate, readAiLimits } from "../application/aiRequestGate";
import { InMemoryEligibilityStore, PostgresEligibilityStore } from "../adapters/eligibilityStore";
export { parseRuntimeConfig } from "../config/runtimeConfig";
import { createPostgresRepositoryFromEnvironment } from "../adapters/postgresRepository";
import { TwseMarketDataProvider } from "../adapters/twseMarketDataProvider";
import type { RateLimitStore } from "../application/ports";
import { createAccountMailer } from "../auth/accountMailer";
import { readPublicConfig, type PublicConfig } from "../config/publicConfig";
import { AuthService } from "../auth/authService";

export interface Runtime {
  mode: "demo" | "hosted";
  aiProvider: "demo" | "liangjie" | "openai";
  aiPolicy?: AiPolicyMetadata;
  aiGate?: AiRequestGate;
  eligibilityRequired?: boolean;
  dataProvider: "memory" | "postgres";
  service: FutureMintService;
  authService: AuthService;
  publicConfig?: PublicConfig;
  rateLimitStore?: RateLimitStore;
  maintenance?: () => Promise<void>;
  healthCheck: () => Promise<void>;
  close: () => Promise<void>;
}

let runtime: Runtime | undefined;

export const createRuntime = (): Runtime => {
  validateStartupConfig();
  const config = parseRuntimeConfig(process.env);
  const aiConfig = parseAiConfig(process.env);
  const publicConfig = readPublicConfig();
  const mailer = createAccountMailer();
  const postgresRepository =
    config.dataProvider === "postgres"
      ? createPostgresRepositoryFromEnvironment()
      : undefined;
  const repository = postgresRepository ?? new InMemoryRepository();
  const aiProvider = config.aiProvider === "liangjie" ? createLiangjieAiProviderFromEnvironment()
    : config.aiProvider === "openai" ? createOpenAiProviderFromEnvironment() : new DemoAiProvider();
  const eligibilityStore = postgresRepository ? new PostgresEligibilityStore(postgresRepository.getPool()) : new InMemoryEligibilityStore();
  const aiGate = new AiRequestGate(readAiLimits(), postgresRepository?.getPool());
  const marketDataProvider = new TwseMarketDataProvider();
  let pendingMaintenance: Promise<void> | undefined;
  const maintenance = (): Promise<void> => {
    if (pendingMaintenance) return pendingMaintenance;
    pendingMaintenance = (async () => {
      const cutoff = new Date().toISOString();
      await repository.deleteExpiredOrRevokedSessions(cutoff, 1000);
      await repository.deleteExpiredAccountActionTokens(cutoff, 1000);
      await repository.deleteExpiredRateLimits(cutoff, 1000);
      await aiGate.maintain();
    })().finally(() => { pendingMaintenance = undefined; });
    return pendingMaintenance;
  };
  return {
    ...config,
    publicConfig,
    aiPolicy: aiConfig.policy,
    aiGate,
    eligibilityRequired: process.env.NODE_ENV === "production",
    rateLimitStore: repository,
    maintenance,
    service: new Service(
      repository,
      aiProvider,
      demoCatalog,
      marketDataProvider,
    ),
    authService: new AuthService(repository, undefined, { mailer, requireEmailVerification: Boolean(mailer),
      eligibilityStore, requireEligibility: process.env.NODE_ENV === "production", aiPolicyVersion: aiConfig.policy.policyVersion }),
    healthCheck: postgresRepository
      ? () => postgresRepository.ping()
      : async () => undefined,
    close: async () => {
      await pendingMaintenance?.catch(() => undefined);
      mailer?.close?.();
      await postgresRepository?.close();
    },
  };
};

export const getRuntime = (): Runtime => {
  runtime ??= createRuntime();
  return runtime;
};

export const setRuntimeForTests = (value: Runtime): void => {
  runtime = value;
};
