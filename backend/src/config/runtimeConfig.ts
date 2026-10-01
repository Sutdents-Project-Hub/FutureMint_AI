export interface RuntimeProviderConfig {
  mode: "demo" | "hosted";
  aiProvider: "demo" | "liangjie" | "openai";
  dataProvider: "memory" | "postgres";
}
export const parseRuntimeConfig = (environment: Record<string, string | undefined>): RuntimeProviderConfig => {
  const aiProvider = environment.AI_PROVIDER;
  const dataProvider = environment.DATA_PROVIDER;
  if (!aiProvider || !["demo", "liangjie", "openai"].includes(aiProvider)) throw new Error("AI_PROVIDER must be demo, liangjie or openai");
  if (!dataProvider || !["memory", "postgres"].includes(dataProvider)) throw new Error("DATA_PROVIDER must be memory or postgres");
  if (environment.NODE_ENV === "production" && (aiProvider === "demo" || dataProvider !== "postgres")) {
    throw new Error("production requires AI_PROVIDER=liangjie or openai and DATA_PROVIDER=postgres");
  }
  return { mode: aiProvider !== "demo" || dataProvider === "postgres" ? "hosted" : "demo",
    aiProvider: aiProvider as RuntimeProviderConfig["aiProvider"], dataProvider: dataProvider as RuntimeProviderConfig["dataProvider"] };
};
