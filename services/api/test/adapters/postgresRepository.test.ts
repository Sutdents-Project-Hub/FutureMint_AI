import { describe, expect, it } from "vitest";

import {
  PostgresRepository,
  type SqlClient,
} from "../../src/adapters/postgresRepository";
import type { Account, Lesson, SessionRecord } from "../../src/contracts/models";

class FakeSqlClient implements SqlClient {
  readonly queries: Array<{ text: string; values?: unknown[] }> = [];
  private readonly results: Array<{
    rows: Array<Record<string, unknown>>;
    rowCount?: number;
  }> = [];

  enqueue(
    rows: Array<Record<string, unknown>>,
    rowCount: number = rows.length,
  ): void {
    this.results.push({ rows, rowCount });
  }

  async query<T extends Record<string, unknown>>(
    text: string,
    values?: unknown[],
  ): Promise<{ rows: T[]; rowCount?: number }> {
    this.queries.push({ text, values });
    const result = this.results.shift() ?? { rows: [], rowCount: 0 };
    return { rows: result.rows as T[], rowCount: result.rowCount };
  }
}

const account: Account = {
  id: "user-1",
  userId: "user-1",
  email: "student@example.com",
  passwordHash: "hash",
  passwordSalt: "salt",
  passwordAlgorithm: "scrypt-v1",
  profileComplete: false,
  createdAt: "2026-07-15T00:00:00.000Z",
};

const accountRow = {
  id: account.id,
  user_id: account.userId,
  email: account.email,
  password_hash: account.passwordHash,
  password_salt: account.passwordSalt,
  password_algorithm: account.passwordAlgorithm,
  profile_complete: account.profileComplete,
  created_at: new Date(account.createdAt),
};

describe("PostgresRepository", () => {
  it("maps account rows without exposing SQL column naming", async () => {
    const client = new FakeSqlClient();
    client.enqueue([accountRow]);
    const repository = new PostgresRepository(client);

    await expect(repository.findAccountByEmail(account.email)).resolves.toEqual(
      account,
    );
    expect(client.queries[0]).toMatchObject({
      values: [account.email],
    });
    expect(client.queries[0].text).toContain("FROM accounts");
  });

  it("upserts a profile and maps date and optional values", async () => {
    const client = new FakeSqlClient();
    client.enqueue([
      {
        user_id: "user-1",
        monthly_budget_minor: 6000,
        weekly_budget_minor: null,
        goal_name: "校外活動基金",
        goal_target_minor: 12000,
        goal_saved_minor: 4200,
        goal_date: "2026-10-31",
        preferred_tone: "supportive",
        account_role: "parent",
      },
    ]);
    const repository = new PostgresRepository(client);

    const profile = await repository.saveProfile({
      userId: "user-1",
      monthlyBudgetMinor: 6000,
      goalName: "校外活動基金",
      goalTargetMinor: 12000,
      goalSavedMinor: 4200,
      goalDate: "2026-10-31",
      preferredTone: "supportive",
      accountRole: "parent",
    });

    expect(profile.weeklyBudgetMinor).toBeUndefined();
    expect(profile.goalDate).toBe("2026-10-31");
    expect(profile.accountRole).toBe("parent");
    expect(client.queries[0].text).toContain("ON CONFLICT (user_id)");
  });

  it("saves idempotent money events with a database uniqueness guard", async () => {
    const client = new FakeSqlClient();
    client.enqueue([
      {
        id: "event-id",
        user_id: "user-1",
        type: "expense",
        amount_minor: 75,
        currency: "TWD",
        category: "food",
        merchant: "珍奶",
        occurred_at: new Date("2026-07-15T04:00:00.000Z"),
        recurrence: null,
        split: null,
        spending_intent: "want",
        intent_reason: "使用者確認為想要。",
        idempotency_key: "drink-20260715",
        created_at: new Date("2026-07-15T04:00:00.000Z"),
        updated_at: new Date("2026-07-15T04:00:00.000Z"),
      },
    ]);
    const repository = new PostgresRepository(client);

    const event = await repository.saveMoneyEvent("user-1", {
      type: "expense",
      amountMinor: 75,
      currency: "TWD",
      category: "food",
      merchant: "珍奶",
      occurredAt: "2026-07-15T12:00:00+08:00",
      confirmed: true,
      idempotencyKey: "drink-20260715",
      spendingIntent: "want",
      intentReason: "使用者確認為想要。",
    });

    expect(event).toMatchObject({
      userId: "user-1",
      amountMinor: 75,
      idempotencyKey: "drink-20260715",
      spendingIntent: "want",
    });
    expect(client.queries[0].text).toContain(
      "ON CONFLICT (user_id, idempotency_key)",
    );
  });

  it("includes user ownership when deriving the global event id", async () => {
    const firstClient = new FakeSqlClient();
    const secondClient = new FakeSqlClient();
    const row = {
      id: "event-id",
      user_id: "user-1",
      type: "expense",
      amount_minor: 75,
      currency: "TWD",
      category: "food",
      merchant: null,
      occurred_at: new Date("2026-07-15T04:00:00.000Z"),
      recurrence: null,
      split: null,
      spending_intent: null,
      intent_reason: null,
      idempotency_key: "shared-key",
      created_at: new Date("2026-07-15T04:00:00.000Z"),
      updated_at: new Date("2026-07-15T04:00:00.000Z"),
    };
    firstClient.enqueue([row]);
    secondClient.enqueue([{ ...row, user_id: "user-2" }]);
    const input = {
      type: "expense" as const,
      amountMinor: 75,
      currency: "TWD" as const,
      category: "food" as const,
      occurredAt: "2026-07-15T12:00:00+08:00",
      confirmed: true as const,
      idempotencyKey: "shared-key",
    };

    await new PostgresRepository(firstClient).saveMoneyEvent("user-1", input);
    await new PostgresRepository(secondClient).saveMoneyEvent("user-2", input);

    expect(firstClient.queries[0].values?.[0]).not.toBe(
      secondClient.queries[0].values?.[0],
    );
  });

  it("persists and reloads session timestamps", async () => {
    const client = new FakeSqlClient();
    const session: SessionRecord = {
      id: "session-id",
      userId: "user-1",
      tokenHash: "token-hash",
      createdAt: "2026-07-15T00:00:00.000Z",
      expiresAt: "2026-07-22T00:00:00.000Z",
    };
    client.enqueue([]);
    client.enqueue([
      {
        id: session.id,
        user_id: session.userId,
        token_hash: session.tokenHash,
        created_at: new Date(session.createdAt),
        expires_at: new Date(session.expiresAt),
        revoked_at: null,
      },
    ]);
    const repository = new PostgresRepository(client);

    await repository.createSession(session);
    await expect(
      repository.findSessionByTokenHash(session.tokenHash),
    ).resolves.toEqual(session);
  });

  it("upserts lessons with JSON arrays", async () => {
    const client = new FakeSqlClient();
    const lesson: Lesson = {
      id: "lesson-1",
      userId: "user-1",
      title: "機會成本",
      concept: "先比較選擇帶來的差異。",
      example: "在兩個日常選擇中思考。",
      question: "你會選哪一個行動？",
      options: ["先記錄", "先等待"],
      action: "完成一個小選擇。",
      disclaimer: "教育用途。",
      sourceEventIds: ["event-1"],
      source: "liangjie-ai",
      createdAt: "2026-07-15T00:00:00.000Z",
    };
    client.enqueue([
      {
        id: lesson.id,
        user_id: lesson.userId,
        title: lesson.title,
        concept: lesson.concept,
        example: lesson.example,
        question: lesson.question,
        options: lesson.options,
        action: lesson.action,
        disclaimer: lesson.disclaimer,
        source_event_ids: lesson.sourceEventIds,
        source: lesson.source,
        selected_option: null,
        completed_at: null,
        created_at: new Date(lesson.createdAt),
      },
    ]);
    const repository = new PostgresRepository(client);

    await expect(repository.saveLesson(lesson)).resolves.toEqual(lesson);
    expect(client.queries[0].values).toContain(JSON.stringify(lesson.options));
    expect(client.queries[0].values).toContain(
      JSON.stringify(lesson.sourceEventIds),
    );
  });

  it("checks database readiness and closes the pool", async () => {
    const client = new FakeSqlClient();
    client.enqueue([{ ok: 1 }]);
    let closed = false;
    const repository = new PostgresRepository(client, async () => {
      closed = true;
    });

    await repository.ping();
    await repository.close();

    expect(client.queries[0].text).toBe("SELECT 1 AS ok");
    expect(closed).toBe(true);
  });
});
