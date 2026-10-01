import OpenAI from "openai";
import { parseAiConfig, supportsOpenAiStructuredOutput } from "../config/aiConfig";
import { StructuredAiProvider, type ChatClient, type ProviderOptions } from "./liangjieAiProvider";

export class OpenAiProvider extends StructuredAiProvider {
  constructor(options: Omit<ProviderOptions, "provider" | "strictStructuredOutput">) {
    if (!supportsOpenAiStructuredOutput(options.model)) throw new Error("OPENAI_MODEL must support verified strict Structured Outputs");
    super({ ...options, provider: "openai", strictStructuredOutput: true });
  }
}

export const createOpenAiProviderFromEnvironment = (
  environment: Record<string, string | undefined> = process.env,
  options: { fetch?: typeof globalThis.fetch; logger?: ProviderOptions["logger"] } = {},
): OpenAiProvider => {
  const config = parseAiConfig({ ...environment, AI_PROVIDER: "openai" });
  const client = new OpenAI({
    baseURL: "https://api.openai.com/v1", apiKey: config.apiKey!, maxRetries: 0,
    ...(options.fetch ? { fetch: options.fetch } : {}),
  });
  return new OpenAiProvider({ client: client as unknown as ChatClient, model: config.model!,
    totalBudgetMs: config.totalBudgetMs, maxOutputTokens: config.maxOutputTokens, policy: config.policy,
    logger: options.logger ?? ((event) => console.info("futuremint_ai_provider", event)) });
};
