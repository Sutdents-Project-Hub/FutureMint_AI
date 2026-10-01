export const readAllowedOrigins = (env: NodeJS.ProcessEnv = process.env): string[] =>
  parseAllowedOrigins(env.ALLOWED_ORIGINS?.trim() || env.PUBLIC_BASE_URL?.trim(), env.NODE_ENV === "production");

export const parseAllowedOrigins = (value: string | undefined, requireSecure = process.env.NODE_ENV === "production"): string[] => {
  const origins = (value ?? "").split(",").map((origin) => origin.trim()).filter(Boolean);
  if (requireSecure && !origins.length) throw new Error("ALLOWED_ORIGINS is required in production");
  return origins.map((origin) => {
    let url: URL;
    try { url = new URL(origin); } catch { throw new Error(requireSecure ? "ALLOWED_ORIGINS must contain valid HTTPS origin values" : "ALLOWED_ORIGINS must contain valid HTTP(S) origin values"); }
    if ((requireSecure ? url.protocol !== "https:" : !["https:", "http:"].includes(url.protocol)) || url.origin !== origin) {
      throw new Error(requireSecure ? "ALLOWED_ORIGINS must contain valid HTTPS origin values" : "ALLOWED_ORIGINS must contain valid HTTP(S) origin values");
    }
    return origin;
  });
};
