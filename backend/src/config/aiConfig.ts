import { createHash } from "node:crypto";
import { validatedHttpsUrl } from "./publicConfig";

export type AiProviderName = "demo" | "liangjie" | "openai";
export interface AiPolicyMetadata {
  provider: AiProviderName;
  providerName: string;
  model: string;
  recipients: string[];
  dataTerms: string;
  reviewed: boolean;
  policyVersion: string;
}
export interface AiConfig {
  aiProvider: AiProviderName;
  model?: string;
  baseUrl?: string;
  apiKey?: string;
  totalBudgetMs: number;
  maxOutputTokens: number;
  policy: AiPolicyMetadata;
}

// Verified capability sources (2026-10-01): official Structured Outputs guide
// and https://developers.openai.com/api/docs/models/gpt-4.1-mini (also 4.1).
// New model families require explicit capability verification before addition.
export const openAiStructuredModels = [
  "gpt-4o-mini", "gpt-4o-mini-2024-07-18", "gpt-4o-2024-08-06",
  "gpt-4o-2024-11-20", "gpt-4.1", "gpt-4.1-2025-04-14",
  "gpt-4.1-mini", "gpt-4.1-mini-2025-04-14",
] as const;
export const supportsOpenAiStructuredOutput = (model: string): boolean =>
  (openAiStructuredModels as readonly string[]).includes(model);

export class AiConfigurationError extends Error {
  constructor(public readonly missingNames: string[], public readonly invalidNames: string[]) {
    super(`AI configuration invalid; missing: ${missingNames.join(", ") || "none"}; invalid: ${invalidNames.join(", ") || "none"}`);
    this.name = "AiConfigurationError";
  }
}

export const parseAiConfig = (environment: Record<string, string | undefined> = process.env): AiConfig => {
  const missing: string[] = [];
  const invalid: string[] = [];
  const choice = environment.AI_PROVIDER?.trim() || "liangjie";
  if (!["demo", "liangjie", "openai"].includes(choice)) invalid.push("AI_PROVIDER");
  const aiProvider = choice as AiProviderName;
  const production = environment.NODE_ENV === "production";
  const value = (name: string, required = false): string => {
    const text = environment[name]?.trim() ?? "";
    if (required && !text) missing.push(name);
    return text;
  };
  const boundedNumber = (name: string, fallback: number, minimum: number, maximum: number): number => {
    const text = value(name);
    const number = text ? Number(text) : fallback;
    if (!Number.isInteger(number) || number < minimum || number > maximum) invalid.push(name);
    return number;
  };
  const totalBudgetMs = boundedNumber("AI_OPERATION_TIMEOUT_MS", 12000, 1000, 15000);
  const maxOutputTokens = boundedNumber("AI_MAX_OUTPUT_TOKENS", 2048, 256, 4096);
  const prefix = aiProvider === "openai" ? "OPENAI" : "LIANGJIE";
  const live = aiProvider !== "demo";
  const model = live ? value(`${prefix}_MODEL`, true) : "deterministic-demo";
  if (model.length > 160 || /[\r\n]/u.test(model)) invalid.push(`${prefix}_MODEL`);
  if (aiProvider === "openai" && model && !supportsOpenAiStructuredOutput(model)) invalid.push("OPENAI_MODEL");
  const apiKey = live ? value(`${prefix}_API_KEY`, true) : undefined;
  let baseUrl: string | undefined;
  if (aiProvider === "openai") {
    baseUrl = "https://api.openai.com/v1";
    if (environment.OPENAI_BASE_URL && environment.OPENAI_BASE_URL !== baseUrl) invalid.push("OPENAI_BASE_URL");
  } else if (aiProvider === "liangjie") {
    const raw = value("LIANGJIE_BASE_URL") || "https://liangjiewis.com/v1";
    try { baseUrl = validatedHttpsUrl(raw, "LIANGJIE_BASE_URL", { allowedHosts: ["liangjiewis.com"], requiredPath: "/v1" }).toString().replace(/\/+$/u, ""); }
    catch { invalid.push("LIANGJIE_BASE_URL"); }
  }
  const providerName = aiProvider === "openai" ? "OpenAI" : aiProvider === "liangjie" ? "量界智算" : "離線展示";
  const recipientsText = live ? value(`${prefix}_DATA_RECIPIENTS`, production) : "";
  const recipients = live ? [...new Set([providerName, ...recipientsText.split(/[,，\n]/u).map((item) => item.trim()).filter(Boolean)])].sort() : [];
  const dataTerms = live ? value(`${prefix}_DATA_TERMS_DISCLOSURE`, production) : "資料只在本機示範處理，不傳送第三方 AI。";
  const declarationVersion = value("PRIVACY_POLICY_VERSION", production && live);
  const reviewedText = live ? value(`${prefix}_DATA_TERMS_REVIEWED`, production) : "true";
  if (reviewedText && !["true", "false"].includes(reviewedText)) invalid.push(`${prefix}_DATA_TERMS_REVIEWED`);
  const configured = Boolean(recipientsText && dataTerms && declarationVersion);
  const reviewed = !live || (reviewedText === "true" && configured);
  if (live && (production || reviewedText === "true")) {
    for (const [name, text] of [[`${prefix}_DATA_RECIPIENTS`, recipientsText], [`${prefix}_DATA_TERMS_DISCLOSURE`, dataTerms], ["PRIVACY_POLICY_VERSION", declarationVersion]]) {
      if (!text && !missing.includes(name)) missing.push(name);
      if (text && /[<>]|待定|待確認|未定|未設定|未確認|placeholder/iu.test(text)) invalid.push(name);
    }
    if (production && !reviewed) invalid.push(`${prefix}_DATA_TERMS_REVIEWED`);
  }
  if (recipients.length > 20 || recipients.some((item) => item.length > 200)) invalid.push(`${prefix}_DATA_RECIPIENTS`);
  if (dataTerms.length > 4000) invalid.push(`${prefix}_DATA_TERMS_DISCLOSURE`);
  if (missing.length || invalid.length) throw new AiConfigurationError([...new Set(missing)], [...new Set(invalid)]);
  // Only declared public policy fields participate. Never hash credentials or all env.
  const fingerprint = createHash("sha256").update(JSON.stringify({ aiProvider, model, baseUrl, recipients, dataTerms, declarationVersion })).digest("hex").slice(0, 24);
  return { aiProvider, model: live ? model : undefined, baseUrl, apiKey, totalBudgetMs, maxOutputTokens,
    policy: { provider: aiProvider, providerName, model, recipients, dataTerms, reviewed, policyVersion: `third-party-ai-v2-${fingerprint}` } };
};
