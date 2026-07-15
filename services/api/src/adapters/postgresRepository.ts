import { createHash } from "node:crypto";

import { Pool } from "pg";

import type {
  AuthRepository,
  ConfirmedMoneyEventInput,
  FutureMintRepository,
} from "../application/ports";
import { DomainError } from "../contracts/errors";
import type {
  Account,
  Lesson,
  MoneyEvent,
  SaveInvestmentOrderInput,
  SessionRecord,
  UserProfile,
  VirtualInvestmentAccount,
  VirtualInvestmentOrder,
} from "../contracts/models";

export interface SqlClient {
  query<T extends Record<string, unknown>>(
    text: string,
    values?: unknown[],
  ): Promise<{ rows: T[]; rowCount?: number | null }>;
}

interface AccountRow extends Record<string, unknown> {
  id: string;
  user_id: string;
  email: string;
  password_hash: string;
  password_salt: string;
  password_algorithm: "scrypt-v1";
  profile_complete: boolean;
  created_at: Date | string;
}

interface SessionRow extends Record<string, unknown> {
  id: string;
  user_id: string;
  token_hash: string;
  created_at: Date | string;
  expires_at: Date | string;
  revoked_at: Date | string | null;
}

interface ProfileRow extends Record<string, unknown> {
  user_id: string;
  monthly_budget_minor: number;
  weekly_budget_minor: number | null;
  goal_name: string;
  goal_target_minor: number;
  goal_saved_minor: number;
  goal_date: Date | string;
  preferred_tone: "supportive" | "direct";
  account_role: UserProfile["accountRole"];
}

interface MoneyEventRow extends Record<string, unknown> {
  id: string;
  user_id: string;
  type: MoneyEvent["type"];
  amount_minor: number;
  currency: "TWD";
  category: MoneyEvent["category"];
  merchant: string | null;
  occurred_at: Date | string;
  recurrence: MoneyEvent["recurrence"] | null;
  split: MoneyEvent["split"] | null;
  spending_intent: MoneyEvent["spendingIntent"] | null;
  intent_reason: string | null;
  idempotency_key: string | null;
  created_at: Date | string;
  updated_at: Date | string;
}

interface LessonRow extends Record<string, unknown> {
  id: string;
  user_id: string;
  title: string;
  concept: string;
  example: string;
  question: string;
  options: string[];
  action: string;
  disclaimer: string;
  source_event_ids: string[];
  source: Lesson["source"];
  selected_option: string | null;
  completed_at: Date | string | null;
  created_at: Date | string;
}

interface InvestmentAccountRow extends Record<string, unknown> {
  user_id: string;
  starting_cash_minor: number;
  created_at: Date | string;
}

interface InvestmentOrderRow extends Record<string, unknown> {
  id: string;
  user_id: string;
  symbol: string;
  name: string;
  side: VirtualInvestmentOrder["side"];
  quantity: number;
  unit_price: number | string;
  total_minor: number;
  quote_as_of: Date | string;
  quote_source: VirtualInvestmentOrder["quoteSource"];
  idempotency_key: string;
  created_at: Date | string;
}

const isoDateTime = (value: Date | string): string =>
  value instanceof Date ? value.toISOString() : new Date(value).toISOString();

const dateOnly = (value: Date | string): string =>
  value instanceof Date
    ? value.toISOString().slice(0, 10)
    : String(value).slice(0, 10);

const accountFromRow = (row: AccountRow): Account => ({
  id: row.id,
  userId: row.user_id,
  email: row.email,
  passwordHash: row.password_hash,
  passwordSalt: row.password_salt,
  passwordAlgorithm: row.password_algorithm,
  profileComplete: row.profile_complete,
  createdAt: isoDateTime(row.created_at),
});

const sessionFromRow = (row: SessionRow): SessionRecord => ({
  id: row.id,
  userId: row.user_id,
  tokenHash: row.token_hash,
  createdAt: isoDateTime(row.created_at),
  expiresAt: isoDateTime(row.expires_at),
  ...(row.revoked_at ? { revokedAt: isoDateTime(row.revoked_at) } : {}),
});

const profileFromRow = (row: ProfileRow): UserProfile => ({
  userId: row.user_id,
  monthlyBudgetMinor: row.monthly_budget_minor,
  ...(row.weekly_budget_minor == null
    ? {}
    : { weeklyBudgetMinor: row.weekly_budget_minor }),
  goalName: row.goal_name,
  goalTargetMinor: row.goal_target_minor,
  goalSavedMinor: row.goal_saved_minor,
  goalDate: dateOnly(row.goal_date),
  preferredTone: row.preferred_tone,
  accountRole: row.account_role,
});

const moneyEventFromRow = (row: MoneyEventRow): MoneyEvent => ({
  id: row.id,
  userId: row.user_id,
  type: row.type,
  amountMinor: row.amount_minor,
  currency: row.currency,
  category: row.category,
  ...(row.merchant ? { merchant: row.merchant } : {}),
  occurredAt: isoDateTime(row.occurred_at),
  ...(row.recurrence ? { recurrence: row.recurrence } : {}),
  ...(row.split ? { split: row.split } : {}),
  ...(row.spending_intent
    ? { spendingIntent: row.spending_intent }
    : {}),
  ...(row.intent_reason ? { intentReason: row.intent_reason } : {}),
  ...(row.idempotency_key
    ? { idempotencyKey: row.idempotency_key }
    : {}),
  createdAt: isoDateTime(row.created_at),
  updatedAt: isoDateTime(row.updated_at),
});

const lessonFromRow = (row: LessonRow): Lesson => ({
  id: row.id,
  userId: row.user_id,
  title: row.title,
  concept: row.concept,
  example: row.example,
  question: row.question,
  options: row.options,
  action: row.action,
  disclaimer: row.disclaimer,
  sourceEventIds: row.source_event_ids,
  source: row.source,
  ...(row.selected_option ? { selectedOption: row.selected_option } : {}),
  ...(row.completed_at ? { completedAt: isoDateTime(row.completed_at) } : {}),
  createdAt: isoDateTime(row.created_at),
});

const investmentAccountFromRow = (
  row: InvestmentAccountRow,
): VirtualInvestmentAccount => ({
  userId: row.user_id,
  startingCashMinor: row.starting_cash_minor,
  createdAt: isoDateTime(row.created_at),
});

const investmentOrderFromRow = (
  row: InvestmentOrderRow,
): VirtualInvestmentOrder => ({
  id: row.id,
  userId: row.user_id,
  symbol: row.symbol,
  name: row.name,
  side: row.side,
  quantity: row.quantity,
  unitPrice: Number(row.unit_price),
  totalMinor: row.total_minor,
  quoteAsOf: dateOnly(row.quote_as_of),
  quoteSource: row.quote_source,
  idempotencyKey: row.idempotency_key,
  createdAt: isoDateTime(row.created_at),
});

export class PostgresRepository
  implements FutureMintRepository, AuthRepository
{
  constructor(
    private readonly client: SqlClient,
    private readonly closeClient: () => Promise<void> = async () => undefined,
  ) {}

  async ping(): Promise<void> {
    await this.client.query("SELECT 1 AS ok");
  }

  close(): Promise<void> {
    return this.closeClient();
  }

  async getProfile(userId: string): Promise<UserProfile> {
    const { rows } = await this.client.query<ProfileRow>(
      "SELECT * FROM profiles WHERE user_id = $1",
      [userId],
    );
    if (!rows[0]) {
      throw new DomainError("profile_not_found", "找不到使用者設定。", 404);
    }
    return profileFromRow(rows[0]);
  }

  async saveProfile(profile: UserProfile): Promise<UserProfile> {
    const { rows } = await this.client.query<ProfileRow>(
      `INSERT INTO profiles (
        user_id, monthly_budget_minor, weekly_budget_minor, goal_name,
        goal_target_minor, goal_saved_minor, goal_date, preferred_tone,
        account_role
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      ON CONFLICT (user_id) DO UPDATE SET
        monthly_budget_minor = EXCLUDED.monthly_budget_minor,
        weekly_budget_minor = EXCLUDED.weekly_budget_minor,
        goal_name = EXCLUDED.goal_name,
        goal_target_minor = EXCLUDED.goal_target_minor,
        goal_saved_minor = EXCLUDED.goal_saved_minor,
        goal_date = EXCLUDED.goal_date,
        preferred_tone = EXCLUDED.preferred_tone,
        account_role = EXCLUDED.account_role
      RETURNING *`,
      [
        profile.userId,
        profile.monthlyBudgetMinor,
        profile.weeklyBudgetMinor ?? null,
        profile.goalName,
        profile.goalTargetMinor,
        profile.goalSavedMinor,
        profile.goalDate,
        profile.preferredTone,
        profile.accountRole,
      ],
    );
    return profileFromRow(rows[0]);
  }

  async listMoneyEvents(userId: string): Promise<MoneyEvent[]> {
    const { rows } = await this.client.query<MoneyEventRow>(
      "SELECT * FROM money_events WHERE user_id = $1 ORDER BY occurred_at DESC",
      [userId],
    );
    return rows.map(moneyEventFromRow);
  }

  async saveMoneyEvent(
    userId: string,
    input: ConfirmedMoneyEventInput,
  ): Promise<MoneyEvent> {
    const id = `event-${createHash("sha256")
      .update(`${userId}:${input.idempotencyKey}`)
      .digest("hex")
      .slice(0, 32)}`;
    const { rows } = await this.client.query<MoneyEventRow>(
      `INSERT INTO money_events (
        id, user_id, type, amount_minor, currency, category, merchant,
        occurred_at, recurrence, split, spending_intent, intent_reason,
        idempotency_key
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, $9::jsonb, $10::jsonb, $11, $12,
        $13
      )
      ON CONFLICT (user_id, idempotency_key) DO UPDATE SET
        idempotency_key = EXCLUDED.idempotency_key
      RETURNING *`,
      [
        id,
        userId,
        input.type,
        input.amountMinor,
        input.currency,
        input.category,
        input.merchant ?? null,
        input.occurredAt,
        input.recurrence ? JSON.stringify(input.recurrence) : null,
        input.split ? JSON.stringify(input.split) : null,
        input.spendingIntent ?? null,
        input.intentReason ?? null,
        input.idempotencyKey,
      ],
    );
    return moneyEventFromRow(rows[0]);
  }

  async getLesson(userId: string, lessonId: string): Promise<Lesson | null> {
    const { rows } = await this.client.query<LessonRow>(
      "SELECT * FROM lessons WHERE user_id = $1 AND id = $2",
      [userId, lessonId],
    );
    return rows[0] ? lessonFromRow(rows[0]) : null;
  }

  async getLatestLesson(userId: string): Promise<Lesson | null> {
    const { rows } = await this.client.query<LessonRow>(
      "SELECT * FROM lessons WHERE user_id = $1 ORDER BY created_at DESC LIMIT 1",
      [userId],
    );
    return rows[0] ? lessonFromRow(rows[0]) : null;
  }

  async saveLesson(lesson: Lesson): Promise<Lesson> {
    const { rows } = await this.client.query<LessonRow>(
      `INSERT INTO lessons (
        id, user_id, title, concept, example, question, options, action,
        disclaimer, source_event_ids, source, selected_option, completed_at,
        created_at
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7::jsonb, $8, $9, $10::jsonb, $11, $12,
        $13, $14
      )
      ON CONFLICT (id) DO UPDATE SET
        title = EXCLUDED.title,
        concept = EXCLUDED.concept,
        example = EXCLUDED.example,
        question = EXCLUDED.question,
        options = EXCLUDED.options,
        action = EXCLUDED.action,
        disclaimer = EXCLUDED.disclaimer,
        source_event_ids = EXCLUDED.source_event_ids,
        source = EXCLUDED.source,
        selected_option = EXCLUDED.selected_option,
        completed_at = EXCLUDED.completed_at
      RETURNING *`,
      [
        lesson.id,
        lesson.userId,
        lesson.title,
        lesson.concept,
        lesson.example,
        lesson.question,
        JSON.stringify(lesson.options),
        lesson.action,
        lesson.disclaimer,
        JSON.stringify(lesson.sourceEventIds),
        lesson.source,
        lesson.selectedOption ?? null,
        lesson.completedAt ?? null,
        lesson.createdAt,
      ],
    );
    return lessonFromRow(rows[0]);
  }

  async getOrCreateInvestmentAccount(
    userId: string,
    startingCashMinor: number,
  ): Promise<VirtualInvestmentAccount> {
    const { rows } = await this.client.query<InvestmentAccountRow>(
      `INSERT INTO virtual_investment_accounts (
        user_id, starting_cash_minor
      ) VALUES ($1, $2)
      ON CONFLICT (user_id) DO UPDATE SET user_id = EXCLUDED.user_id
      RETURNING *`,
      [userId, startingCashMinor],
    );
    return investmentAccountFromRow(rows[0]);
  }

  async listInvestmentOrders(
    userId: string,
  ): Promise<VirtualInvestmentOrder[]> {
    const { rows } = await this.client.query<InvestmentOrderRow>(
      `SELECT * FROM virtual_investment_orders
      WHERE user_id = $1
      ORDER BY created_at ASC`,
      [userId],
    );
    return rows.map(investmentOrderFromRow);
  }

  async saveInvestmentOrder(
    userId: string,
    input: SaveInvestmentOrderInput,
  ): Promise<VirtualInvestmentOrder> {
    const id = `order-${createHash("sha256")
      .update(`${userId}:${input.idempotencyKey}`)
      .digest("hex")
      .slice(0, 32)}`;
    const { rows } = await this.client.query<InvestmentOrderRow>(
      `INSERT INTO virtual_investment_orders (
        id, user_id, symbol, name, side, quantity, unit_price, total_minor,
        quote_as_of, quote_source, idempotency_key
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
      ON CONFLICT (user_id, idempotency_key) DO UPDATE SET
        idempotency_key = EXCLUDED.idempotency_key
      RETURNING *`,
      [
        id,
        userId,
        input.symbol,
        input.name,
        input.side,
        input.quantity,
        input.unitPrice,
        input.totalMinor,
        input.quoteAsOf,
        input.quoteSource,
        input.idempotencyKey,
      ],
    );
    return investmentOrderFromRow(rows[0]);
  }

  async resetDemo(_userId: string): Promise<void> {
    throw new DomainError(
      "demo_reset_unsupported",
      "PostgreSQL 連線模式不支援自動重設，請使用受控合成資料程序。",
      409,
    );
  }

  async findAccountByEmail(email: string): Promise<Account | null> {
    const { rows } = await this.client.query<AccountRow>(
      "SELECT * FROM accounts WHERE email = $1 LIMIT 1",
      [email],
    );
    return rows[0] ? accountFromRow(rows[0]) : null;
  }

  async findAccountById(userId: string): Promise<Account | null> {
    const { rows } = await this.client.query<AccountRow>(
      "SELECT * FROM accounts WHERE user_id = $1 LIMIT 1",
      [userId],
    );
    return rows[0] ? accountFromRow(rows[0]) : null;
  }

  async createAccount(account: Account): Promise<Account> {
    try {
      const { rows } = await this.client.query<AccountRow>(
        `INSERT INTO accounts (
          id, user_id, email, password_hash, password_salt,
          password_algorithm, profile_complete, created_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        RETURNING *`,
        [
          account.id,
          account.userId,
          account.email,
          account.passwordHash,
          account.passwordSalt,
          account.passwordAlgorithm,
          account.profileComplete,
          account.createdAt,
        ],
      );
      return accountFromRow(rows[0]);
    } catch (error) {
      if ((error as { code?: string }).code === "23505") {
        throw new DomainError(
          "account_unavailable",
          "此電子郵件無法完成註冊。",
          409,
        );
      }
      throw error;
    }
  }

  async setProfileComplete(userId: string): Promise<void> {
    const { rowCount } = await this.client.query<AccountRow>(
      "UPDATE accounts SET profile_complete = TRUE WHERE user_id = $1 RETURNING *",
      [userId],
    );
    if (!rowCount) {
      throw new DomainError("account_not_found", "找不到登入帳號。", 404);
    }
  }

  async createSession(session: SessionRecord): Promise<void> {
    await this.client.query<SessionRow>(
      `INSERT INTO sessions (
        id, user_id, token_hash, created_at, expires_at, revoked_at
      ) VALUES ($1, $2, $3, $4, $5, $6)`,
      [
        session.id,
        session.userId,
        session.tokenHash,
        session.createdAt,
        session.expiresAt,
        session.revokedAt ?? null,
      ],
    );
  }

  async findSessionByTokenHash(
    tokenHash: string,
  ): Promise<SessionRecord | null> {
    const { rows } = await this.client.query<SessionRow>(
      "SELECT * FROM sessions WHERE token_hash = $1 LIMIT 1",
      [tokenHash],
    );
    return rows[0] ? sessionFromRow(rows[0]) : null;
  }

  async revokeSession(tokenHash: string): Promise<void> {
    await this.client.query<SessionRow>(
      `UPDATE sessions
      SET revoked_at = COALESCE(revoked_at, NOW())
      WHERE token_hash = $1`,
      [tokenHash],
    );
  }
}

export const createPostgresPoolFromEnvironment = (): Pool => {
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    throw new Error("DATABASE_URL is required when DATA_PROVIDER=postgres");
  }
  const ssl = process.env.DATABASE_SSL === "true"
    ? { rejectUnauthorized: true }
    : false;
  return new Pool({
    connectionString,
    ssl,
    max: 10,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000,
  });
};

export const createPostgresRepositoryFromEnvironment = (): PostgresRepository => {
  const pool = createPostgresPoolFromEnvironment();
  return new PostgresRepository(pool, () => pool.end());
};
