import { randomUUID } from "node:crypto";

import type {
  AiProvider,
  CaptureInput,
  LessonContext,
} from "../application/ports";
import type {
  CaptureDraft,
  CaptureParseResult,
  Lesson,
} from "../contracts/models";

const chineseNumbers: Record<string, number> = {
  一: 1,
  二: 2,
  三: 3,
  四: 4,
  五: 5,
  六: 6,
};

const parseParticipants = (text: string): number | undefined => {
  const arabic = text.match(/(\d+)\s*(?:個)?(?:人|同學)?分/);
  if (arabic) return Number(arabic[1]);
  const chinese = text.match(/([一二三四五六])\s*個?(?:人|同學)?分/);
  return chinese ? chineseNumbers[chinese[1]] : undefined;
};

const classify = (text: string): CaptureDraft["category"] => {
  if (/薪水|零用錢|獎金|收入/.test(text)) return "income";
  if (/Netflix|Spotify|訂閱|扣款/.test(text)) return "subscription";
  if (/飲料|珍奶|早餐|午餐|晚餐|吃飯/.test(text)) return "food";
  if (/遊戲|點數|電影/.test(text)) return "entertainment";
  if (/車|捷運|公車|交通/.test(text)) return "transport";
  if (/課程|課本|書|文具/.test(text)) return "education";
  if (/衣服|鞋|耳機|購物/.test(text)) return "shopping";
  return "other";
};

const merchantFor = (text: string): string | undefined => {
  if (/珍奶|飲料/.test(text)) return "飲料";
  if (/Netflix/.test(text)) return "Netflix";
  if (/Spotify/.test(text)) return "Spotify";
  if (/薪水|打工/.test(text)) return "打工收入";
  return undefined;
};

const amountFor = (text: string): number | undefined => {
  const paidMatch = text.match(/(?:折扣後(?:實付)?|實付)\D{0,8}(\d[\d,]*)/);
  const match =
    paidMatch ?? text.match(/(?:NT\$|[$＄])?\s*(\d[\d,]*)\s*(?:元)?/i);
  return match ? Number(match[1].replaceAll(",", "")) : undefined;
};

const occurredAtFor = (text: string, referenceTime: string): string => {
  if (!/昨天|前天/.test(text)) return referenceTime;
  const value = new Date(referenceTime);
  const days = text.includes("前天") ? 2 : 1;
  value.setTime(value.getTime() - days * 24 * 60 * 60 * 1000);
  return value.toISOString();
};

const buildDraft = (
  text: string,
  input: CaptureInput,
  splitContext = text,
): CaptureDraft => {
  const amountMinor = amountFor(text);
  const category = classify(text);
  const type: CaptureDraft["type"] =
    category === "income"
      ? "income"
      : category === "subscription"
        ? "subscription"
        : "expense";
  const participants = parseParticipants(splitContext);
  return {
    draftId: randomUUID(),
    type,
    amountMinor,
    currency: "TWD",
    category,
    merchant: merchantFor(text),
    occurredAt: occurredAtFor(text, input.referenceTime),
    recurrence:
      type === "subscription" ? { billingCycle: "monthly" } : undefined,
    split:
      participants && amountMinor
        ? {
            participants,
            userShareMinor: Math.round(amountMinor / participants),
          }
        : undefined,
    confidence: amountMinor ? 0.94 : 0.58,
    missingFields: amountMinor ? [] : ["amountMinor"],
    needsConfirmation: true,
    source: "deterministic-demo",
  };
};

export class DemoAiProvider implements AiProvider {
  async parseCapture(input: CaptureInput): Promise<CaptureParseResult> {
    const text = input.text.trim();
    if (/沒有買|沒買|取消交易|並未購買/.test(text)) {
      return {
        drafts: [],
        rejectedReason: "文字表示交易沒有發生，因此不會建立草稿。",
      };
    }
    if (/驗證碼|廣告|優惠碼/.test(text)) {
      return { drafts: [], rejectedReason: "這段文字不像已發生的金錢事件。" };
    }
    if (
      amountFor(text) === undefined &&
      classify(text) === "other" &&
      !/買|花|付|消費|支出|收入|賣|收到|賺|訂閱|扣款/.test(text)
    ) {
      return { drafts: [], rejectedReason: "這段文字不像已發生的金錢事件。" };
    }

    const separated = /折扣後|實付/.test(text)
      ? []
      : text
          .split(/[，、；;]/)
          .map((part) => part.trim())
          .filter((part) => amountFor(part) && classify(part) !== "other");
    const drafts =
      separated.length > 1
        ? separated.slice(0, 5).map((part) => buildDraft(part, input))
        : [buildDraft(text, input, text)];
    const missingAmount = drafts.some(
      (draft) => draft.amountMinor === undefined,
    );

    return {
      drafts,
      clarificationQuestion: missingAmount
        ? `這筆${drafts[0].merchant ?? "消費"}花了多少元？`
        : undefined,
    };
  }

  async generateLesson(context: LessonContext): Promise<Lesson> {
    const subscription = context.events.find(
      (event) => event.type === "subscription",
    );
    const sourceEvents = context.events.slice(-5);
    const createdAt = new Date().toISOString();
    return {
      id: randomUUID(),
      userId: context.userId,
      title: subscription ? "固定支出，也能重新選擇" : "小額累積與機會成本",
      concept: subscription
        ? "固定支出會每月重複發生。先換算成月成本，再比較使用頻率與方案資格，比單純退訂更接近真正的選擇。"
        : "每一筆小額支出都不必被責備；把它放回預算與目標中，就能看見這次選擇放棄了什麼機會。",
      example: `以「${context.profile.goalName}」為例，先保留必要支出，再比較一個可調整項目。`,
      question: "下週你最想先嘗試哪一個小改變？",
      options: [
        "先檢查一項固定訂閱",
        "設定一個可接受的小額支出上限",
        "先維持現況並持續記錄",
      ],
      action: "選一個做得到的選項，七天後再看它是否真的幫上忙。",
      disclaimer: "內容僅供金融教育與反思，不構成投資或金融商品建議。",
      sourceEventIds: sourceEvents.map((event) => event.id),
      source: "deterministic-demo",
      createdAt,
    };
  }
}
