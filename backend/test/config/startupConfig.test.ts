import { describe, expect, it } from "vitest";
import { ConfigurationError, summarizeStartupError, validateStartupConfig } from "../../src/config/startupConfig";
const valid = (): NodeJS.ProcessEnv => ({ NODE_ENV: "production", AI_PROVIDER: "liangjie", DATA_PROVIDER: "postgres",
  DATABASE_URL: "postgresql://test:synthetic@127.0.0.1/futuremint_test", DATABASE_SSL: "false", LIANGJIE_MODEL: "synthetic-model", LIANGJIE_API_KEY: "synthetic-key",
  LIANGJIE_DATA_RECIPIENTS: "量界智算,已確認上游", LIANGJIE_DATA_TERMS_DISCLOSURE: "合成測試條款", LIANGJIE_DATA_TERMS_REVIEWED: "true",
  PUBLIC_BASE_URL: "https://fcloud.org", SERVICE_OPERATOR: "Synthetic Test", SUPPORT_EMAIL: "support@fcloud.org", PRIVACY_POLICY_VERSION: "test-v1",
  DATA_REGION: "合成測試地區", BACKUP_RETENTION_DAYS: "30", MINIMUM_AGE: "15", MINOR_CONSENT_DISCLOSURE: "合成監護人條款",
  AI_DATA_TERMS_DISCLOSURE: "合成 AI 條款", PRIVACY_POLICY_REVIEWED: "true", ALLOWED_ORIGINS: "https://fcloud.org", MAIL_PROVIDER: "smtp",
  SMTP_HOST: "mail.fcloud.org", SMTP_PORT: "465", SMTP_USER: "synthetic", SMTP_PASSWORD: "synthetic", SMTP_FROM: "support@fcloud.org" });
describe("pure startup preflight", () => {
  it("validates demo without allocating network resources", () => expect(() => validateStartupConfig({ AI_PROVIDER: "demo", DATA_PROVIDER: "memory" })).not.toThrow());
  it("validates complete production declarations", () => expect(() => validateStartupConfig(valid())).not.toThrow());
  it("requires Taiwan age 15 and no demo production bypass", () => {
    for (const changes of [{ MINIMUM_AGE: "13" }, { AI_PROVIDER: "demo" }, { DATA_PROVIDER: "memory" }, { MAIL_PROVIDER: "disabled" }]) expect(() => validateStartupConfig({ ...valid(), ...changes })).toThrow(ConfigurationError);
  });
  it("aggregates missing names and never logs values", () => {
    try { validateStartupConfig({ NODE_ENV: "production", AI_PROVIDER: "openai", DATA_PROVIDER: "postgres", DATABASE_URL: "secret-sentinel" }); throw new Error("expected rejection"); }
    catch (error) {
      expect(error).toBeInstanceOf(ConfigurationError);
      const summary = summarizeStartupError(error); const names = (error as ConfigurationError).issues.map((issue) => issue.name);
      expect(names).toEqual(expect.arrayContaining(["OPENAI_API_KEY", "OPENAI_MODEL", "DATABASE_URL", "SMTP_PASSWORD", "PUBLIC_BASE_URL"]));
      expect(JSON.stringify(summary)).not.toContain("secret-sentinel");
      expect(summary).toMatchObject({ phase: "configuration", errorType: "ConfigurationError" });
    }
  });
  it("only logs type and phase for unexpected SDK/DB errors", () => expect(JSON.stringify(summarizeStartupError(new Error("secret-value")))).not.toContain("secret-value"));
});
