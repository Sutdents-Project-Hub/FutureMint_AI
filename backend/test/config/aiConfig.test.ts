import { describe, expect, it } from "vitest";
import { AiConfigurationError, parseAiConfig } from "../../src/config/aiConfig";

const liangjie = { LIANGJIE_MODEL: "operator-configured-model", LIANGJIE_API_KEY: "synthetic-test-only" };
const openai = { AI_PROVIDER: "openai", OPENAI_MODEL: "gpt-4.1-mini", OPENAI_API_KEY: "synthetic-test-only" };
const terms = { PRIVACY_POLICY_VERSION: "2026-10-v1", OPENAI_DATA_RECIPIENTS: "OpenAI", OPENAI_DATA_TERMS_DISCLOSURE: "設定所用帳號的保存、訓練與區域條款。", OPENAI_DATA_TERMS_REVIEWED: "true" };

describe("AI configuration and consent policy identity", () => {
  it("defaults to Liangjie while requiring its operator-provided model and key", () => {
    expect(parseAiConfig(liangjie)).toMatchObject({ aiProvider: "liangjie", model: liangjie.LIANGJIE_MODEL, baseUrl: "https://liangjiewis.com/v1", totalBudgetMs: 12000, maxOutputTokens: 2048, policy: { provider: "liangjie", providerName: "量界智算", reviewed: false } });
    expect(() => parseAiConfig({})).toThrow("LIANGJIE_MODEL");
  });
  it("permits explicit offline demo without external model or key", () => {
    expect(parseAiConfig({ AI_PROVIDER: "demo" })).toMatchObject({ aiProvider: "demo", policy: { provider: "demo", reviewed: true, recipients: [] } });
  });
  it("reports typed variable names without echoing malformed values or secrets", () => {
    try { parseAiConfig({ ...liangjie, LIANGJIE_BASE_URL: "https://secret-user:private-pass@private-host.example/v1", LIANGJIE_API_KEY: "private-key-value", AI_MAX_OUTPUT_TOKENS: "private-number" }); }
    catch (error) {
      expect(error).toBeInstanceOf(AiConfigurationError);
      expect((error as AiConfigurationError).invalidNames).toEqual(expect.arrayContaining(["LIANGJIE_BASE_URL", "AI_MAX_OUTPUT_TOKENS"]));
      expect(String(error)).not.toMatch(/private-|secret-user/u);
      return;
    }
    throw new Error("expected configuration rejection");
  });
  it.each(["https://relay.example/v1", "http://api.openai.com/v1"])("refuses OpenAI endpoint overrides: %s", (OPENAI_BASE_URL) => {
    expect(() => parseAiConfig({ ...openai, OPENAI_BASE_URL })).toThrow("OPENAI_BASE_URL");
  });
  it("requires reviewed provider-specific recipient and terms declarations in production", () => {
    expect(() => parseAiConfig({ ...openai, NODE_ENV: "production", AI_DATA_TERMS_DISCLOSURE: "generic text" })).toThrow("OPENAI_DATA_RECIPIENTS");
    expect(parseAiConfig({ ...openai, ...terms, NODE_ENV: "production" }).policy.reviewed).toBe(true);
    expect(() => parseAiConfig({ ...openai, ...terms, NODE_ENV: "production", OPENAI_DATA_TERMS_REVIEWED: "false" })).toThrow("OPENAI_DATA_TERMS_REVIEWED");
    expect(() => parseAiConfig({ ...openai, ...terms, NODE_ENV: "production", OPENAI_DATA_TERMS_DISCLOSURE: "待確認" })).toThrow("OPENAI_DATA_TERMS_DISCLOSURE");
  });
  it("rotates policy identity for provider, model, recipients, data terms and privacy version changes", () => {
    const original = parseAiConfig({ ...openai, ...terms }).policy.policyVersion;
    const changes = [
      { ...openai, ...terms, OPENAI_MODEL: "gpt-4o-mini" },
      { ...openai, ...terms, OPENAI_DATA_RECIPIENTS: "OpenAI, declared subprocessors" },
      { ...openai, ...terms, OPENAI_DATA_TERMS_DISCLOSURE: "修改後的資料政策。" },
      { ...openai, ...terms, PRIVACY_POLICY_VERSION: "2026-10-v2" },
      { ...liangjie, PRIVACY_POLICY_VERSION: terms.PRIVACY_POLICY_VERSION },
    ];
    for (const environment of changes) expect(parseAiConfig(environment).policy.policyVersion).not.toBe(original);
    expect(parseAiConfig({ ...openai, ...terms, OPENAI_API_KEY: "another-secret" }).policy.policyVersion).toBe(original);
  });
  it("always includes the selected actual provider in displayed recipients", () => {
    expect(parseAiConfig({ ...openai, ...terms, OPENAI_DATA_RECIPIENTS: "declared subprocessors" }).policy.recipients).toContain("OpenAI");
    expect(parseAiConfig(liangjie).policy.recipients).toContain("量界智算");
  });
  it("canonicalizes recipient order without falsely invalidating unchanged consent", () => {
    expect(parseAiConfig({ ...openai, ...terms, OPENAI_DATA_RECIPIENTS: "OpenAI, declared subprocessors" }).policy.policyVersion)
      .toBe(parseAiConfig({ ...openai, ...terms, OPENAI_DATA_RECIPIENTS: "declared subprocessors, OpenAI, OpenAI" }).policy.policyVersion);
  });
  it.each([{ AI_OPERATION_TIMEOUT_MS: "999" }, { AI_OPERATION_TIMEOUT_MS: "15001" }, { AI_MAX_OUTPUT_TOKENS: "4097" }, { AI_MAX_OUTPUT_TOKENS: "255" }])("rejects unbounded timeout or token settings %j", (settings) => {
    expect(() => parseAiConfig({ ...openai, ...settings })).toThrow(AiConfigurationError);
  });
  it("fails unsupported provider and model explicitly without fallback", () => {
    expect(() => parseAiConfig({ AI_PROVIDER: "github-models" })).toThrow("AI_PROVIDER");
    expect(() => parseAiConfig({ ...openai, OPENAI_MODEL: "gpt-4o-2024-05-13" })).toThrow("OPENAI_MODEL");
  });
});
