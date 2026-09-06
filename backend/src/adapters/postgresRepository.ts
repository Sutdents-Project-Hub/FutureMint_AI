import { createHash } from "node:crypto";

import { Pool } from "pg";

import type {
  AuthRepository,
  ConfirmedMoneyEventInput,
  EditableMoneyEventInput,
  FutureMintRepository,
  RateLimitStore,
} from "../application/ports";
import { DomainError } from "../contracts/errors";
import type {
  Account,
  AccountActionToken,
  AiConsent,
  FamilyGroupRecord,
  FamilyMemberRecord,
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
  email_verified_at: Date | string | null;
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

interface AiConsentRow extends Record<string, unknown> {
  granted: boolean;
  policy_version: string;
  granted_at: Date | string | null;
  withdrawn_at: Date | string | null;
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

interface FamilyMemberRow extends Record<string, unknown> {
  family_id: string;
  user_id: string;
  email: string;
  account_role: "child" | "parent" | null;
  joined_at: Date | string;
}

interface FamilyGroupRow extends Record<string, unknown> {
  id: string;
  created_by: string;
  invite_code_expires_at: Date | string | null;
  invite_active: boolean;
}

export interface TransactionSqlClient extends SqlClient {
  release(): void;
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
  ...(row.email_verified_at
    ? { emailVerifiedAt: isoDateTime(row.email_verified_at) }
    : {}),
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

const aiConsentFromRow = (row: AiConsentRow): AiConsent => ({
  granted: row.granted,
  policyVersion: row.policy_version,
  grantedAt: row.granted_at ? isoDateTime(row.granted_at) : null,
  withdrawnAt: row.withdrawn_at ? isoDateTime(row.withdrawn_at) : null,
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

const familyMemberFromRow = (row: FamilyMemberRow): FamilyMemberRecord => ({
  familyId: row.family_id,
  userId: row.user_id,
  email: row.email,
  role: row.account_role ?? "child",
  joinedAt: isoDateTime(row.joined_at),
});

export class PostgresRepository
  implements FutureMintRepository, AuthRepository, RateLimitStore
{
  constructor(
    private readonly client: SqlClient,
    private readonly closeClient: () => Promise<void> = async () => undefined,
    private readonly acquireClient?: () => Promise<TransactionSqlClient>,
  ) {}

  async withUsersTransaction<T>(
    userIds: string[],
    operation: (repository: FutureMintRepository) => Promise<T>,
  ): Promise<T> {
    const acquire = this.acquireClient ?? (this.client instanceof Pool
      ? async () => (await (this.client as Pool).connect()) as unknown as TransactionSqlClient
      : undefined);
    const transactionClient = acquire ? await acquire() : this.client;
    try {
      await transactionClient.query("BEGIN");
      for (const userId of [...new Set(userIds)].sort()) {
        await transactionClient.query(
          "SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
          [`futuremint:user:${userId}`],
        );
      }
      // Scoped callers may use Promise.all; serialize queries on the pinned
      // connection so transaction boundaries never race queued reads or writes.
      let pending: Promise<unknown> = Promise.resolve();
      const scoped = new PostgresRepository({
        query: <R extends Record<string, unknown>>(text: string, values?: unknown[]) => {
          const result = pending.then(() => transactionClient.query<R>(text, values));
          pending = result.catch(() => undefined);
          return result;
        },
      });
      let result: T;
      try { result = await operation(scoped); }
      finally { await pending; }
      await transactionClient.query("COMMIT");
      return result;
    } catch (error) {
      await transactionClient.query("ROLLBACK");
      throw error;
    } finally {
      if (acquire) {
        (transactionClient as TransactionSqlClient).release();
      }
    }
  }

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
    try {
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
    } catch (error) {
      if ((error as { message?: string }).message?.includes("family_role_locked")) {
        throw new DomainError(
          "family_role_locked",
          "加入家庭後不能直接更換家長／孩子角色；請先離開家庭再修改。",
          409,
        );
      }
      throw error;
    }
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

  async updateMoneyEvent(
    userId: string,
    eventId: string,
    input: EditableMoneyEventInput,
  ): Promise<MoneyEvent> {
    const { rows } = await this.client.query<MoneyEventRow>(
      `UPDATE money_events SET
        type = $3, amount_minor = $4, currency = $5, category = $6,
        merchant = $7, occurred_at = $8, recurrence = $9::jsonb,
        split = $10::jsonb, spending_intent = $11, intent_reason = $12,
        updated_at = now()
      WHERE user_id = $1 AND id = $2
      RETURNING *`,
      [
        userId,
        eventId,
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
      ],
    );
    if (!rows[0]) {
      throw new DomainError("money_event_not_found", "找不到這筆紀錄。", 404);
    }
    return moneyEventFromRow(rows[0]);
  }

  async deleteMoneyEvent(userId: string, eventId: string): Promise<void> {
    const { rowCount } = await this.client.query(
      "DELETE FROM money_events WHERE user_id = $1 AND id = $2",
      [userId, eventId],
    );
    if (rowCount !== 1) {
      throw new DomainError("money_event_not_found", "找不到這筆紀錄。", 404);
    }
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

  async getFamilyMembership(
    userId: string,
  ): Promise<FamilyMemberRecord | null> {
    const { rows } = await this.client.query<FamilyMemberRow>(
      `SELECT fm.family_id, fm.user_id, a.email,
        fm.role AS account_role, fm.joined_at
      FROM family_members fm
      JOIN accounts a ON a.user_id = fm.user_id
      WHERE fm.user_id = $1
      LIMIT 1`,
      [userId],
    );
    return rows[0] ? familyMemberFromRow(rows[0]) : null;
  }

  async getFamilyGroup(familyId: string): Promise<FamilyGroupRecord | null> {
    const { rows } = await this.client.query<FamilyGroupRow>(
      `SELECT id, created_by, invite_code_expires_at, invite_active
      FROM family_groups
      WHERE id = $1
      LIMIT 1`,
      [familyId],
    );
    const row = rows[0];
    return row
      ? {
          familyId: row.id,
          createdBy: row.created_by,
          ...(row.invite_code_expires_at
            ? { inviteCodeExpiresAt: isoDateTime(row.invite_code_expires_at) }
            : {}),
          inviteActive:
            row.invite_active &&
            !!row.invite_code_expires_at &&
            new Date(row.invite_code_expires_at).getTime() > Date.now(),
        }
      : null;
  }

  async createFamilyGroup(
    userId: string,
    familyId: string,
    inviteCodeHash: string,
    inviteCodeExpiresAt: string,
  ): Promise<FamilyGroupRecord> {
    try {
      const { rows } = await this.client.query<FamilyGroupRow>(
        `WITH inserted_group AS (
          INSERT INTO family_groups (
            id, invite_code_hash, invite_code_expires_at, invite_active,
            created_by
          ) SELECT $1, $2, $3, TRUE, $4
            FROM profiles WHERE user_id = $4 AND account_role = 'parent'
          RETURNING id, created_by, invite_code_expires_at, invite_active
        ), inserted_member AS (
          INSERT INTO family_members (family_id, user_id, role)
          SELECT inserted_group.id, $4, 'parent'
          FROM inserted_group
          JOIN profiles ON profiles.user_id = $4
          WHERE profiles.account_role = 'parent'
          RETURNING family_id
        )
        SELECT inserted_group.*
        FROM inserted_group
        JOIN inserted_member ON inserted_member.family_id = inserted_group.id`,
        [familyId, inviteCodeHash, inviteCodeExpiresAt, userId],
      );
      if (!rows[0]) {
        throw new DomainError(
          "family_parent_required",
          "只有家長帳號可以建立家庭邀請。",
          403,
        );
      }
      return {
        familyId: rows[0].id,
        createdBy: rows[0].created_by,
        inviteCodeExpiresAt: isoDateTime(rows[0].invite_code_expires_at!),
        inviteActive: rows[0].invite_active,
      };
    } catch (error) {
      if ((error as { code?: string }).code === "23505") {
        throw new DomainError(
          "family_invite_unavailable",
          "家庭邀請碼剛好重複，請再建立一次。",
          409,
          true,
        );
      }
      throw error;
    }
  }

  async rotateFamilyInvite(
    familyId: string,
    inviteCodeHash: string,
    inviteCodeExpiresAt: string,
  ): Promise<FamilyGroupRecord> {
    try {
      const { rows } = await this.client.query<FamilyGroupRow>(
        `UPDATE family_groups
        SET invite_code_hash = $2, invite_code_expires_at = $3,
          invite_active = TRUE
        WHERE id = $1
        RETURNING id, created_by, invite_code_expires_at, invite_active`,
        [familyId, inviteCodeHash, inviteCodeExpiresAt],
      );
      if (!rows[0]) {
        throw new DomainError("family_not_found", "找不到家庭關聯。", 404);
      }
      return {
        familyId: rows[0].id,
        createdBy: rows[0].created_by,
        inviteCodeExpiresAt: isoDateTime(rows[0].invite_code_expires_at!),
        inviteActive: rows[0].invite_active,
      };
    } catch (error) {
      if ((error as { code?: string }).code === "23505") {
        throw new DomainError(
          "family_invite_unavailable",
          "家庭邀請碼剛好重複，請再建立一次。",
          409,
          true,
        );
      }
      throw error;
    }
  }

  async revokeFamilyInvite(familyId: string): Promise<FamilyGroupRecord> {
    const { rows } = await this.client.query<FamilyGroupRow>(
      `UPDATE family_groups
      SET invite_code_hash = NULL, invite_code_expires_at = NULL,
        invite_active = FALSE
      WHERE id = $1
      RETURNING id, created_by, invite_code_expires_at, invite_active`,
      [familyId],
    );
    if (!rows[0]) {
      throw new DomainError("family_not_found", "找不到家庭關聯。", 404);
    }
    return {
      familyId: rows[0].id,
      createdBy: rows[0].created_by,
      inviteActive: false,
    };
  }

  async findFamilyByInviteCodeHash(
    inviteCodeHash: string,
  ): Promise<FamilyGroupRecord | null> {
    const { rows } = await this.client.query<FamilyGroupRow>(
      `SELECT id, created_by, invite_code_expires_at, invite_active
      FROM family_groups
      WHERE invite_code_hash = $1
        AND invite_active = TRUE
        AND invite_code_expires_at > NOW()
      LIMIT 1`,
      [inviteCodeHash],
    );
    const row = rows[0];
    return row
      ? {
          familyId: row.id,
          createdBy: row.created_by,
          inviteCodeExpiresAt: isoDateTime(row.invite_code_expires_at!),
          inviteActive: true,
        }
      : null;
  }

  async listFamilyMembers(familyId: string): Promise<FamilyMemberRecord[]> {
    const { rows } = await this.client.query<FamilyMemberRow>(
      `SELECT fm.family_id, fm.user_id, a.email,
        fm.role AS account_role, fm.joined_at
      FROM family_members fm
      JOIN accounts a ON a.user_id = fm.user_id
      WHERE fm.family_id = $1
      ORDER BY fm.joined_at ASC, fm.user_id ASC`,
      [familyId],
    );
    return rows.map(familyMemberFromRow);
  }

  async addFamilyMember(familyId: string, userId: string): Promise<void> {
    try {
      const { rowCount } = await this.client.query(
        `INSERT INTO family_members (family_id, user_id, role)
        SELECT $1, $2, 'child'
        FROM profiles
        WHERE user_id = $2 AND account_role = 'child'`,
        [familyId, userId],
      );
      if (rowCount !== 1) {
        throw new DomainError(
          "family_child_required",
          "只有孩子帳號可以使用家長邀請碼加入家庭。",
          403,
        );
      }
    } catch (error) {
      if ((error as { code?: string }).code === "23505") {
        throw new DomainError(
          "family_already_linked",
          "這個帳號已經加入家庭。",
          409,
        );
      }
      throw error;
    }
  }

  async removeFamilyMember(userId: string): Promise<void> {
    await this.client.query("DELETE FROM family_members WHERE user_id = $1", [
      userId,
    ]);
  }

  async deleteFamilyGroup(familyId: string): Promise<void> {
    await this.client.query("DELETE FROM family_groups WHERE id = $1", [
      familyId,
    ]);
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

  async createSession(session: SessionRecord, expectedPasswordHash?: string): Promise<void> {
    if (expectedPasswordHash) {
      return this.withUsersTransaction([session.userId], async (repository) => {
        const scoped = repository as PostgresRepository;
        const account = await scoped.findAccountById(session.userId);
        if (!account || account.passwordHash !== expectedPasswordHash) {
          throw new DomainError("invalid_credentials", "電子郵件或密碼不正確。", 401);
        }
        await scoped.createSession(session);
      });
    }
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

  async deleteExpiredOrRevokedSessions(
    cutoff: string,
    limit = 1000,
  ): Promise<number> {
    const { rowCount } = await this.client.query(
      `DELETE FROM sessions
      WHERE id IN (
        SELECT id FROM sessions
        WHERE expires_at <= $1
          OR (revoked_at IS NOT NULL AND revoked_at <= $1)
        ORDER BY expires_at ASC
        LIMIT $2
        FOR UPDATE SKIP LOCKED
      )`,
      [cutoff, limit],
    );
    return rowCount ?? 0;
  }

  async saveAccountActionToken(record: AccountActionToken): Promise<void> {
    await this.client.query(
      `INSERT INTO account_action_tokens (
        token_hash, user_id, purpose, expires_at
      ) VALUES ($1, $2, $3, $4)
      ON CONFLICT (user_id, purpose) DO UPDATE SET
        token_hash = EXCLUDED.token_hash,
        expires_at = EXCLUDED.expires_at,
        created_at = NOW()`,
      [record.tokenHash, record.userId, record.purpose, record.expiresAt],
    );
  }

  async consumeEmailVerification(tokenHash: string, now: string): Promise<boolean> {
    const { rows } = await this.client.query<{ consumed: boolean }>(
      `WITH consumed AS (
        DELETE FROM account_action_tokens
        WHERE token_hash = $1
          AND purpose = 'verify-email'
          AND expires_at > $2
        RETURNING user_id
      ), verified AS (
        UPDATE accounts
        SET email_verified_at = COALESCE(email_verified_at, $2)
        FROM consumed
        WHERE accounts.user_id = consumed.user_id
        RETURNING accounts.user_id
      )
      SELECT EXISTS(SELECT 1 FROM verified) AS consumed`,
      [tokenHash, now],
    );
    return rows[0]?.consumed ?? false;
  }

  async consumePasswordReset(
    tokenHash: string,
    now: string,
    password: { passwordHash: string; passwordSalt: string },
  ): Promise<boolean> {
    const { rows } = await this.client.query<{ user_id: string }>(
      "SELECT user_id FROM account_action_tokens WHERE token_hash = $1 AND purpose = 'reset-password'", [tokenHash]);
    if (!rows[0]) return false;
    return this.withUsersTransaction([rows[0].user_id], (repository) =>
      (repository as PostgresRepository).consumePasswordResetLocked(tokenHash, now, password));
  }

  private async consumePasswordResetLocked(
    tokenHash: string, now: string,
    password: { passwordHash: string; passwordSalt: string },
  ): Promise<boolean> {
    const { rows } = await this.client.query<{ consumed: boolean }>(
      `WITH consumed AS (
        DELETE FROM account_action_tokens
        WHERE token_hash = $1
          AND purpose = 'reset-password'
          AND expires_at > $2
        RETURNING user_id
      ), updated AS (
        UPDATE accounts
        SET password_hash = $3, password_salt = $4
        FROM consumed
        WHERE accounts.user_id = consumed.user_id
        RETURNING accounts.user_id
      ), revoked AS (
        UPDATE sessions
        SET revoked_at = COALESCE(revoked_at, $2)
        WHERE user_id IN (SELECT user_id FROM updated)
        RETURNING user_id
      )
      SELECT EXISTS(SELECT 1 FROM updated) AS consumed`,
      [tokenHash, now, password.passwordHash, password.passwordSalt],
    );
    return rows[0]?.consumed ?? false;
  }

  async deleteAccountActionToken(tokenHash: string): Promise<void> {
    await this.client.query(
      "DELETE FROM account_action_tokens WHERE token_hash = $1",
      [tokenHash],
    );
  }

  async deleteExpiredAccountActionTokens(
    cutoff: string,
    limit = 1000,
  ): Promise<number> {
    const { rowCount } = await this.client.query(
      `DELETE FROM account_action_tokens
      WHERE token_hash IN (
        SELECT token_hash FROM account_action_tokens
        WHERE expires_at <= $1
        ORDER BY expires_at ASC
        LIMIT $2
        FOR UPDATE SKIP LOCKED
      )`,
      [cutoff, limit],
    );
    return rowCount ?? 0;
  }

  async consumeRateLimit(
    key: string,
    windowMs: number,
  ): Promise<{ current: number; ttl: number }> {
    const keyHash = createHash("sha256").update(key).digest("hex");
    const { rows } = await this.client.query<{
      current: number;
      ttl: number | string;
    }>(
      `INSERT INTO rate_limit_counters (
        key_hash, current_count, expires_at
      ) VALUES (
        $1, 1, clock_timestamp() + ($2 * interval '1 millisecond')
      )
      ON CONFLICT (key_hash) DO UPDATE SET
        current_count = CASE
          WHEN rate_limit_counters.expires_at <= clock_timestamp() THEN 1
          ELSE rate_limit_counters.current_count + 1
        END,
        expires_at = CASE
          WHEN rate_limit_counters.expires_at <= clock_timestamp()
            THEN clock_timestamp() + ($2 * interval '1 millisecond')
          ELSE rate_limit_counters.expires_at
        END
      RETURNING current_count AS current,
        GREATEST(
          0,
          CEIL(EXTRACT(EPOCH FROM (expires_at - clock_timestamp())) * 1000)
        )::bigint AS ttl`,
      [keyHash, windowMs],
    );
    return { current: rows[0].current, ttl: Number(rows[0].ttl) };
  }

  async clearRateLimit(key: string): Promise<void> {
    const keyHash = createHash("sha256").update(key).digest("hex");
    await this.client.query("DELETE FROM rate_limit_counters WHERE key_hash = $1", [
      keyHash,
    ]);
  }

  async deleteExpiredRateLimits(cutoff: string, limit = 1000): Promise<number> {
    const { rowCount } = await this.client.query(
      `DELETE FROM rate_limit_counters
      WHERE key_hash IN (
        SELECT key_hash FROM rate_limit_counters
        WHERE expires_at <= $1
        ORDER BY expires_at ASC
        LIMIT $2
        FOR UPDATE SKIP LOCKED
      )`,
      [cutoff, limit],
    );
    return rowCount ?? 0;
  }

  async getAiConsent(userId: string): Promise<AiConsent | null> {
    const { rows } = await this.client.query<AiConsentRow>(
      `SELECT granted, policy_version, granted_at, withdrawn_at
      FROM ai_consents WHERE user_id = $1 LIMIT 1`,
      [userId],
    );
    return rows[0] ? aiConsentFromRow(rows[0]) : null;
  }

  async saveAiConsent(userId: string, consent: AiConsent): Promise<AiConsent> {
    const { rows } = await this.client.query<AiConsentRow>(
      `INSERT INTO ai_consents (
        user_id, policy_version, granted, granted_at, withdrawn_at, updated_at
      ) VALUES ($1, $2, $3, $4, $5, NOW())
      ON CONFLICT (user_id) DO UPDATE SET
        policy_version = EXCLUDED.policy_version,
        granted = EXCLUDED.granted,
        granted_at = EXCLUDED.granted_at,
        withdrawn_at = EXCLUDED.withdrawn_at,
        updated_at = NOW()
      RETURNING granted, policy_version, granted_at, withdrawn_at`,
      [
        userId,
        consent.policyVersion,
        consent.granted,
        consent.grantedAt,
        consent.withdrawnAt,
      ],
    );
    return aiConsentFromRow(rows[0]);
  }

  async deleteAccount(userId: string, expectedPasswordHash?: string): Promise<void> {
    const membership = await this.getFamilyMembership(userId);
    const group = membership ? await this.getFamilyGroup(membership.familyId) : null;
    return this.withUsersTransaction([userId, ...(group ? [group.createdBy] : [])], async (repository) => {
      const scoped = repository as PostgresRepository;
      if (expectedPasswordHash && (await scoped.findAccountById(userId))?.passwordHash !== expectedPasswordHash) {
        throw new DomainError("invalid_credentials", "電子郵件或密碼不正確。", 401);
      }
      await scoped.client.query("DELETE FROM accounts WHERE user_id = $1", [userId]);
    });
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
  return new PostgresRepository(
    pool,
    () => pool.end(),
    async () => (await pool.connect()) as unknown as TransactionSqlClient,
  );
};
