import type {
  CaptureParseResult,
  Lesson,
  MoneyEvent,
  UserProfile,
} from "../contracts/models";

export interface CaptureInput {
  text: string;
  locale: "zh-TW";
  referenceTime: string;
}

export interface LessonContext {
  userId: string;
  profile: UserProfile;
  events: MoneyEvent[];
}

export interface AiProvider {
  parseCapture(input: CaptureInput): Promise<CaptureParseResult>;
  generateLesson(context: LessonContext): Promise<Lesson>;
}

export interface ConfirmedMoneyEventInput {
  type: MoneyEvent["type"];
  amountMinor: number;
  currency: "TWD";
  category: MoneyEvent["category"];
  merchant?: string;
  occurredAt: string;
  recurrence?: MoneyEvent["recurrence"];
  split?: MoneyEvent["split"];
  confirmed: true;
  idempotencyKey: string;
}

export interface FutureMintRepository {
  getProfile(userId: string): Promise<UserProfile>;
  saveProfile(profile: UserProfile): Promise<UserProfile>;
  listMoneyEvents(userId: string): Promise<MoneyEvent[]>;
  saveMoneyEvent(
    userId: string,
    input: ConfirmedMoneyEventInput,
  ): Promise<MoneyEvent>;
  getLesson(userId: string, lessonId: string): Promise<Lesson | null>;
  getLatestLesson(userId: string): Promise<Lesson | null>;
  saveLesson(lesson: Lesson): Promise<Lesson>;
  resetDemo(userId: string): Promise<void>;
}
