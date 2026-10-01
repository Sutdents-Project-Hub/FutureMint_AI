import { parseAiConfig, AiConfigurationError } from "./aiConfig";
import { readPublicConfig, parseTrustedProxies } from "./publicConfig";
import { parseRuntimeConfig } from "./runtimeConfig";
import { parseAllowedOrigins } from "./httpConfig";
import { validateMailerConfig } from "../auth/accountMailer";
import { readAiLimits } from "../application/aiRequestGate";

export interface ConfigurationIssue { name: string; reason: "missing" | "invalid"; }
export class ConfigurationError extends Error {
  constructor(public readonly issues: ConfigurationIssue[]) {
    super("Startup configuration is incomplete or invalid");
    this.name = "ConfigurationError";
  }
}
// A pure preflight: no sockets, transports, database queries or migrations.
export const validateStartupConfig = (env: NodeJS.ProcessEnv = process.env): void => {
  const issues: ConfigurationIssue[] = [];
  const add = (name: string, reason: ConfigurationIssue["reason"] = "invalid") => {
    if (!issues.some((issue) => issue.name === name)) issues.push({ name, reason });
  };
  const inspect = (fallback: string, operation: () => unknown) => {
    try { operation(); } catch (error) {
      if (error instanceof AiConfigurationError) {
        error.missingNames.forEach((name) => add(name, "missing"));
        error.invalidNames.forEach((name) => add(name));
      } else {
        const names = error instanceof Error ? error.message.match(/\b[A-Z][A-Z_]{2,}\b/gu)?.filter((name) => name.includes("_") || name === "PORT" || name === "HOST") : null;
        for (const name of names?.length ? names : [fallback]) add(name, env[name]?.trim() ? "invalid" : "missing");
      }
    }
  };
  inspect("PROVIDERS", () => parseRuntimeConfig(env));
  inspect("AI_CONFIGURATION", () => parseAiConfig(env));
  if (env.NODE_ENV === "production") {
    for (const name of ["PUBLIC_BASE_URL", "SERVICE_OPERATOR", "SUPPORT_EMAIL", "PRIVACY_POLICY_VERSION", "DATA_REGION", "BACKUP_RETENTION_DAYS", "MINIMUM_AGE", "MINOR_CONSENT_DISCLOSURE", "AI_DATA_TERMS_DISCLOSURE", "ALLOWED_ORIGINS"]) {
      if (!env[name]?.trim()) add(name, "missing");
    }
    const retention = Number(env.BACKUP_RETENTION_DAYS);
    if (!Number.isInteger(retention) || retention < 1 || retention > 3650) add("BACKUP_RETENTION_DAYS");
    if (env.MINIMUM_AGE !== "15") add("MINIMUM_AGE");
    if (env.PRIVACY_POLICY_REVIEWED !== "true") add("PRIVACY_POLICY_REVIEWED");
    if (env.MAIL_PROVIDER !== "smtp") add("MAIL_PROVIDER");
    for (const name of ["SMTP_HOST", "SMTP_USER", "SMTP_PASSWORD", "SMTP_FROM"]) if (!env[name]?.trim()) add(name, "missing");
  }
  inspect("PUBLIC_POLICY_CONFIGURATION", () => readPublicConfig(env));
  inspect("MAIL_CONFIGURATION", () => validateMailerConfig(env));
  inspect("ALLOWED_ORIGINS", () => parseAllowedOrigins(env.ALLOWED_ORIGINS, env.NODE_ENV === "production"));
  inspect("TRUSTED_PROXY_CIDRS", () => parseTrustedProxies(env.TRUSTED_PROXY_CIDRS));
  inspect("AI_LIMITS", () => readAiLimits(env));
  const port = Number(env.PORT || 3000);
  if (!Number.isInteger(port) || port < 1 || port > 65535) add("PORT");
  if (env.DATA_PROVIDER === "postgres") {
    if (!env.DATABASE_URL) add("DATABASE_URL", "missing");
    else {
      try {
        const url = new URL(env.DATABASE_URL);
        if (!["postgres:", "postgresql:"].includes(url.protocol) || !url.hostname || !url.pathname.slice(1)) add("DATABASE_URL");
      } catch { add("DATABASE_URL"); }
    }
    if (env.DATABASE_SSL && !["true", "false"].includes(env.DATABASE_SSL)) add("DATABASE_SSL");
  }
  if (issues.length) throw new ConfigurationError(issues);
};
export const summarizeStartupError = (error: unknown): Record<string, unknown> => ({
  errorType: error instanceof Error ? error.name : typeof error,
  ...(error instanceof ConfigurationError ? { phase: "configuration", issues: error.issues } : { phase: "startup" }),
});
