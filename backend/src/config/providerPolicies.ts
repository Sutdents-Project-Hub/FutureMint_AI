import type { AiProviderName } from "./aiConfig";

export interface ProviderDeclaration {
  recipients: string[];
  dataTerms: string;
  reviewed: boolean;
}

// 將經確認的公開供應商說明維護在此；不存放金鑰或猜測上游承諾。
// 空白條款不阻擋 API 啟動，但外部 AI 授權與請求會保持停用。
// 仍可使用既有 LIANGJIE_/OPENAI_DATA_* runtime variables 覆寫。
export const providerDeclarations: Record<Exclude<AiProviderName, "demo">, ProviderDeclaration> = {
  liangjie: { recipients: ["量界智算"], dataTerms: "", reviewed: false },
  openai: { recipients: ["OpenAI"], dataTerms: "", reviewed: false },
};
