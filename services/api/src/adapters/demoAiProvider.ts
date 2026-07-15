import { randomUUID } from "node:crypto";

import type {
  AiProvider,
  CaptureInput,
  LessonContext,
  LearningPlanContext,
} from "../application/ports";
import type {
  CoachReply,
  CoachRequest,
  CaptureDraft,
  CaptureParseResult,
  Lesson,
  LearningPlan,
  SpendingIntent,
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

const intentFor = (
  category: CaptureDraft["category"],
  type: CaptureDraft["type"],
): { intent?: SpendingIntent; reason?: string } => {
  if (type === "income") return {};
  if (category === "transport" || category === "education") {
    return {
      intent: "need",
      reason: "依分類看起來較接近日常必要支出，但仍要由你確認當時情境。",
    };
  }
  if (category === "entertainment" || category === "shopping") {
    return {
      intent: "want",
      reason: "依分類看起來較接近提升體驗的選擇，不代表這筆支出不好。",
    };
  }
  return {
    intent: "uncertain",
    reason: "同一類支出可能是需要也可能是想要，AI 沒有足夠情境替你決定。",
  };
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
  const intent = intentFor(category, type);
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
    spendingIntent: intent.intent,
    intentReason: intent.reason,
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

  async generateLearningPlan(
    context: LearningPlanContext,
  ): Promise<LearningPlan> {
    const ordered = [
      {
        id: "need-want" as const,
        title: "需要、想要與灰色地帶",
        reason:
          context.insights.uncertainMinor > 0
            ? "你有尚未分類的支出，先練習補足情境。"
            : "用自己的紀錄觀察選擇，而不是套用別人的標準。",
        nextAction: "挑一筆支出，寫下當時不買會發生什麼。",
      },
      {
        id: "subscription" as const,
        title: "固定支出健康檢查",
        reason:
          context.insights.subscriptionMinor > 0
            ? "目前紀錄中有訂閱，可以從使用頻率與續訂日開始。"
            : "先學會辨認重複扣款與月成本。",
        nextAction: "選一項訂閱，確認最近一次使用時間。",
      },
      {
        id: "compound" as const,
        title: "時間與持續投入",
        reason: `把「${context.profile.goalName}」放進試算，看本金和假設成長的差別。`,
        nextAction: "用已存金額比較三條教育情境曲線。",
      },
      {
        id: "risk" as const,
        title: "報酬、波動與分散",
        reason: "較高假設報酬不會消除中途下跌，先理解風險再談選擇。",
        nextAction: "找出曲線下跌的一年，請 AI 陪讀員解釋。",
      },
    ];
    return {
      title:
        context.profile.accountRole === "parent"
          ? "親子共學規劃"
          : "我的金錢學習路線",
      summary: "先從自己的紀錄出發，再進到時間、複利與風險，不追求一次學完。",
      modules: ordered.map((module, index) => ({
        ...module,
        status: index === 0 ? "next" : "queued",
      })),
      source: "deterministic-demo",
      disclaimer: "規劃只用於金融教育，不取代家長、教師或合格專業人員建議。",
    };
  }

  async coach(request: CoachRequest): Promise<CoachReply> {
    const scenario = request.scenarioId === "steady"
      ? "穩穩存"
      : request.scenarioId === "balanced"
        ? "慢慢長"
        : request.scenarioId === "high-risk"
          ? "高風險資產"
          : "這個情境";
    const answer = switchCoachAnswer(request, scenario);
    return {
      answer,
      takeaway: "先分清楚已知事實、教育假設與你能承受的風險，再做下一步。",
      suggestions: ["為什麼曲線會下跌？", "持續投入有什麼作用？", "分散風險是什麼？"],
      source: "deterministic-demo",
      disclaimer: "AI 陪讀只解釋教育情境，不推薦標的，也不保證任何報酬。",
    };
  }
}

const switchCoachAnswer = (request: CoachRequest, scenario: string): string => {
  if (request.topic === "compound") {
    return "複利是讓先前累積的成果也一起參與後續變化；時間越長差異越容易看見，但實際結果仍取決於報酬與風險。";
  }
  if (request.topic === "subscription") {
    return "先看最近使用時間、下次續訂日和每月成本。資料不足時只能提醒檢查，不能直接說它是浪費。";
  }
  if (request.topic === "spending") {
    return "需要與想要不是道德分數。同一筆餐費在不同情境可能不同，最後判斷應由你根據當時需要確認。";
  }
  if (request.topic === "risk" || request.scenarioId) {
    const year = request.selectedYear ? `第 ${request.selectedYear} 年` : "途中";
    return `${scenario}在${year}出現下跌，代表高報酬假設仍可能伴隨明顯波動。持續投入能維持紀律，但不能保證避開虧損。`;
  }
  return "我可以用制式方式說明需要與想要、訂閱、複利和風險；金額與曲線則交給程式計算。";
};
