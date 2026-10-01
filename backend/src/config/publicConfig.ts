import { isIP } from "node:net";

export const validatedHttpsUrl = (value: string, name: string, options: {
  allowedHosts?: string[]; requiredPath?: string;
} = {}): URL => {
  let url: URL;
  try { url = new URL(value); } catch { throw new Error(`${name} must be a public HTTPS URL`); }
  const host = url.hostname.toLowerCase().replace(/\.$/, "");
  const reserved = /(^|\.)(localhost|local|internal|test|invalid|example)$/.test(host)
    || /(^|\.)example\.(com|net|org)$/.test(host);
  if (url.protocol !== "https:" || url.username || url.password || url.hash || url.search
    || url.port || !/^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/.test(host) || url.hostname.endsWith(".") || isIP(host) || host.startsWith("[") || reserved
    || (options.allowedHosts && !options.allowedHosts.includes(host))
    || (options.requiredPath !== undefined && url.pathname.replace(/\/$/, "") !== options.requiredPath)) {
    throw new Error(`${name} must be a public HTTPS URL with the expected host and path`);
  }
  return url;
};

export interface PublicConfig {
  baseUrl: string;
  operator: string;
  supportEmail: string;
  policyVersion: string;
  dataRegion: string;
  backupRetentionDays: number;
  minimumAge: number;
  minorConsent: string;
  aiDataTerms: string;
  reviewed: boolean;
}

// 公開、版本化的產品說明；部署時仍需填入真實營運者、信箱及資料地區。
export const publicPolicyDefaults: Record<string, string> = {
  PRIVACY_POLICY_VERSION: "2026-10-02-optional-mail-v1",
  BACKUP_RETENTION_DAYS: "0",
  MINIMUM_AGE: "15",
  MINOR_CONSENT_DISCLOSURE: "本服務限15歲以上使用；15至17歲需完成監護人Email確認。服務資格、家庭摘要分享及第三方AI授權分別處理；Email確認本身不證明法定代理人身分。",
  AI_DATA_TERMS_DISCLOSURE: "第三方AI功能需另外同意；解析只傳送本次輸入，教育功能使用必要摘要及問題。不同意或撤回後仍可手動記帳、管理訂閱及查看固定教材。供應商接收方及資料處理方式另列於本頁與App同意畫面。",
};

export const readPublicConfig = (env: NodeJS.ProcessEnv = process.env): PublicConfig => {
  const production = env.NODE_ENV === "production";
  const required = (key: string): string => {
    const value = env[key]?.trim() || publicPolicyDefaults[key] || "";
    if (production && (!value || /[<>]|待定|待確認|未定|未設定|未確認|placeholder/i.test(value))) {
      throw new Error(`${key} must be configured before production`);
    }
    return value;
  };
  const baseUrl = required("PUBLIC_BASE_URL");
  const supportEmail = required("SUPPORT_EMAIL");
  if (baseUrl) validatedHttpsUrl(baseUrl, "PUBLIC_BASE_URL", { requiredPath: "" });
  if (supportEmail && !/^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$/.test(supportEmail)) {
    throw new Error("SUPPORT_EMAIL must be a valid public support address");
  }
  if (supportEmail) validatedHttpsUrl(`https://${supportEmail.split("@")[1]}`, "SUPPORT_EMAIL domain");
  const config: PublicConfig = {
    baseUrl: baseUrl.replace(/\/$/, ""), operator: required("SERVICE_OPERATOR"),
    supportEmail, policyVersion: required("PRIVACY_POLICY_VERSION"),
    dataRegion: required("DATA_REGION"),
    backupRetentionDays: Number(required("BACKUP_RETENTION_DAYS") || 0),
    minimumAge: Number(required("MINIMUM_AGE") || 0),
    minorConsent: required("MINOR_CONSENT_DISCLOSURE"),
    aiDataTerms: required("AI_DATA_TERMS_DISCLOSURE"),
    reviewed: env.PRIVACY_POLICY_REVIEWED === "true",
  };
  if ((production || config.reviewed) && (!config.baseUrl || !config.operator || !config.supportEmail
    || !config.policyVersion || !config.dataRegion || !config.minorConsent || !config.aiDataTerms || !config.reviewed || !Number.isInteger(config.backupRetentionDays)
    || config.backupRetentionDays < 0 || config.backupRetentionDays > 3650
    || !Number.isInteger(config.minimumAge) || config.minimumAge < 1 || config.minimumAge > 100)) {
    throw new Error("Production requires reviewed privacy terms, minimum age and backup retention");
  }
  return config;
};

// Trust is tied to the connecting proxy's address, never to a hop count.
// An empty setting ignores every client-supplied forwarding header.
export const parseTrustedProxies = (value: string | undefined): false | string[] => {
  if (!value?.trim()) return false;
  const entries = value.split(",").map((entry) => entry.trim());
  for (const entry of entries) {
    const [address, prefix, ...rest] = entry.split("/");
    const version = isIP(address);
    if (!version || rest.length || (prefix !== undefined &&
      (!/^\d+$/.test(prefix) || Number(prefix) < 1 || Number(prefix) > (version === 4 ? 32 : 128)))) {
      throw new Error("TRUSTED_PROXY_CIDRS must list explicit IP addresses or bounded CIDRs");
    }
  }
  return entries;
};
