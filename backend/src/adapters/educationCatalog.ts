import type { CoachReply, CoachRequest, LearningPlan, Lesson } from "../contracts/models";

export const educationTopics = ["need-want", "subscription", "compound", "risk"] as const;
export type EducationTopic = typeof educationTopics[number];
export const educationDisclaimer = "內容由受控金融教育資料庫提供，AI 僅協助選題；不推薦投資標的，也不保證報酬。";

// Only these reviewed strings are rendered as AI educational prose. A model
// chooses topic IDs; its arbitrary text, URLs and financial claims never render.
const topics: Record<EducationTopic, {
  title: string; concept: string; example: string; question: string;
  options: string[]; action: string; takeaway: string;
}> = {
  "need-want": {
    title: "辨認需要，也尊重想要",
    concept: "需要與想要會隨情境改變。先看用途、替代選擇與預算，再決定是否保留這筆支出。",
    example: "同樣是搭車，趕去上課與休閒出遊的目的可能不同；分類是幫助理解選擇，不是評分。",
    question: "面對想購買的東西，你想先確認什麼？",
    options: ["它的用途", "可替代的選擇", "是否影響原本目標"],
    action: "選一筆紀錄，寫下當時的用途；有新的理解時，可以重新分類。",
    takeaway: "分類是理解自己，不是責備自己。",
  },
  subscription: {
    title: "讓訂閱配合實際需要",
    concept: "檢查使用頻率、續訂時間、方案資格與取消條件，再決定要保留、調整或取消。",
    example: "共享方案看起來划算，仍需要確認是否符合服務條款，以及分帳是否清楚。",
    question: "下一次續訂前，你想先檢查哪一項？",
    options: ["最近的使用頻率", "方案的使用資格", "取消與續訂條件"],
    action: "打開一項訂閱的管理頁，確認續訂資訊後再做決定。",
    takeaway: "提醒是重新檢查的機會，不代表這筆支出一定浪費。",
  },
  compound: {
    title: "看懂時間與累積",
    concept: "複利是讓累積成果繼續參與計算。試算會受到投入、期間與假設影響，不能當成未來結果。",
    example: "在教育試算中，每次只調整一個條件，再比較曲線差異，能看出不同假設的影響。",
    question: "你想先比較哪一個試算條件？",
    options: ["持續投入的差異", "期間的差異", "假設改變的差異"],
    action: "使用試算工具比較不同條件，並讀取畫面列出的假設與風險。",
    takeaway: "試算是理解假設的工具，不能預告報酬。",
  },
  risk: {
    title: "辨認波動與集中風險",
    concept: "集中於單一來源可能放大波動。分散也不能消除損失，應先理解用途、期限及可承受的風險。",
    example: "教育曲線可能先上升再回落；只看終點會忽略過程中的壓力與不確定性。",
    question: "觀察虛擬情境時，你想先注意什麼？",
    options: ["過程中的回落", "是否過度集中", "假設與資料日期"],
    action: "比較曲線回落與配置分布；涉及真實投資時，先與可信任的成年人或合格專業人士討論。",
    takeaway: "理解風險比追逐單一結果更有幫助。",
  },
};

export const catalogLesson = (topic: EducationTopic): Pick<Lesson,
  "title" | "concept" | "example" | "question" | "options" | "action" | "disclaimer"
> => {
  const { takeaway: _takeaway, ...lesson } = topics[topic];
  return { ...lesson, options: [...lesson.options], disclaimer: educationDisclaimer };
};

export const catalogLearningPlan = (order: EducationTopic[]): LearningPlan => ({
  title: "你的金融學習路線",
  summary: "AI 依分類摘要安排主題順序，教學文字來自受控資料庫。你可以按照自己的步調學習。",
  modules: order.map((id, index) => ({
    id, title: topics[id].title, reason: topics[id].concept,
    nextAction: topics[id].action, status: index === 0 ? "next" : "queued",
  })),
  disclaimer: educationDisclaimer,
  source: "liangjie-ai",
});

export const catalogCoach = (topic: EducationTopic, style: CoachRequest["style"]): CoachReply => {
  const item = topics[topic];
  return {
    answer: style === "brief" ? item.concept
      : style === "steps" ? `${item.concept}\n${item.action}`
      : `${item.concept}\n${item.example}`,
    takeaway: item.takeaway,
    suggestions: [item.action, "也可以換個主題，或使用畫面中的試算與紀錄工具。"],
    disclaimer: educationDisclaimer,
    source: "liangjie-ai",
  };
};
