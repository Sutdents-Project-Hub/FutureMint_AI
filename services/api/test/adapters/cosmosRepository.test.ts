import { describe, expect, it } from "vitest";

import {
  CosmosRepository,
  type CosmosGateway,
  type CosmosQuery,
} from "../../src/adapters/cosmosRepository";
import type { Account, SessionRecord } from "../../src/contracts/models";

class FakeGateway implements CosmosGateway {
  readonly documents = new Map<string, unknown>();
  readonly queries: Array<{ container: string; query: CosmosQuery }> = [];
  createCount = 0;
  conflictOnNextCreate = false;

  private key(container: string, id: string, partitionKey: string) {
    return `${container}:${partitionKey}:${id}`;
  }

  async read<T>(container: string, id: string, partitionKey: string) {
    return (
      (this.documents.get(this.key(container, id, partitionKey)) as T) ?? null
    );
  }

  async upsert<T extends { id: string; userId: string }>(
    container: string,
    document: T,
  ) {
    this.documents.set(
      this.key(container, document.id, document.userId),
      document,
    );
    return document;
  }

  async create<T extends { id: string; userId: string }>(
    container: string,
    document: T,
  ) {
    this.createCount += 1;
    this.documents.set(
      this.key(container, document.id, document.userId),
      document,
    );
    if (this.conflictOnNextCreate) {
      this.conflictOnNextCreate = false;
      throw Object.assign(new Error("conflict"), { code: 409 });
    }
    return document;
  }

  async query<T>(container: string, query: CosmosQuery) {
    this.queries.push({ container, query });
    if (container === "accounts") {
      const email = query.parameters.find(
        (parameter) => parameter.name === "@email",
      )?.value;
      return [...this.documents.entries()]
        .filter(([key]) => key.startsWith("accounts:"))
        .map(([, value]) => value as Account)
        .filter((account) => account.email === email) as T[];
    }
    if (container === "sessions") {
      const tokenHash = query.parameters.find(
        (parameter) => parameter.name === "@tokenHash",
      )?.value;
      return [...this.documents.entries()]
        .filter(([key]) => key.startsWith("sessions:"))
        .map(([, value]) => value as SessionRecord)
        .filter((session) => session.tokenHash === tokenHash) as T[];
    }
    return [...this.documents.entries()]
      .filter(([key]) => key.startsWith(`${container}:demo-user:`))
      .map(([, value]) => value as T);
  }
}

describe("CosmosRepository", () => {
  it("uses userId as the partition value for profile reads and writes", async () => {
    const gateway = new FakeGateway();
    const repository = new CosmosRepository(gateway);
    const profile = {
      userId: "demo-user",
      monthlyBudgetMinor: 6000,
      goalName: "校外活動基金",
      goalTargetMinor: 12000,
      goalSavedMinor: 4200,
      goalDate: "2026-10-31",
      preferredTone: "supportive" as const,
    };

    await repository.saveProfile(profile);
    await expect(repository.getProfile("demo-user")).resolves.toEqual(profile);
  });

  it("creates one event for repeated idempotency keys", async () => {
    const gateway = new FakeGateway();
    const repository = new CosmosRepository(gateway);
    const input = {
      type: "expense" as const,
      amountMinor: 75,
      currency: "TWD" as const,
      category: "food" as const,
      occurredAt: "2026-07-13T12:00:00+08:00",
      confirmed: true as const,
      idempotencyKey: "same-capture-key",
    };

    const first = await repository.saveMoneyEvent("demo-user", input);
    const second = await repository.saveMoneyEvent("demo-user", input);

    expect(second.id).toBe(first.id);
    expect(gateway.createCount).toBe(1);
  });

  it("parameterizes event queries with the requested userId", async () => {
    const gateway = new FakeGateway();
    const repository = new CosmosRepository(gateway);

    await repository.listMoneyEvents("demo-user");

    expect(gateway.queries[0]).toMatchObject({
      container: "moneyEvents",
      query: {
        parameters: [{ name: "@userId", value: "demo-user" }],
      },
    });
  });

  it("returns the winning event when a concurrent create reports conflict", async () => {
    const gateway = new FakeGateway();
    gateway.conflictOnNextCreate = true;
    const repository = new CosmosRepository(gateway);

    const event = await repository.saveMoneyEvent("demo-user", {
      type: "expense",
      amountMinor: 75,
      currency: "TWD",
      category: "food",
      occurredAt: "2026-07-13T12:00:00+08:00",
      confirmed: true,
      idempotencyKey: "concurrent-capture-key",
    });

    expect(event.id).toMatch(/^event-/);
    expect(gateway.createCount).toBe(1);
  });

  it("stores an account and its session without mixing their partitions", async () => {
    const gateway = new FakeGateway();
    const repository = new CosmosRepository(gateway);
    const account: Account = {
      id: "account-a",
      userId: "account-a",
      email: "student@example.com",
      passwordHash: "hash",
      passwordSalt: "salt",
      passwordAlgorithm: "scrypt-v1",
      profileComplete: false,
      createdAt: "2026-07-14T00:00:00.000Z",
    };
    const session: SessionRecord = {
      id: "token-hash",
      userId: "account-a",
      tokenHash: "token-hash",
      createdAt: "2026-07-14T00:00:00.000Z",
      expiresAt: "2026-07-21T00:00:00.000Z",
    };

    await repository.createAccount(account);
    await repository.createSession(session);

    await expect(
      repository.findAccountByEmail("student@example.com"),
    ).resolves.toMatchObject({ id: "account-a" });
    await expect(
      repository.findSessionByTokenHash("token-hash"),
    ).resolves.toEqual(session);
  });
});
