import { createHash, randomUUID } from "node:crypto";

import { CosmosClient, type SqlQuerySpec } from "@azure/cosmos";
import { DefaultAzureCredential } from "@azure/identity";

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
  SessionRecord,
  UserProfile,
} from "../contracts/models";

export interface CosmosQuery {
  query: string;
  parameters: Array<{ name: string; value: unknown }>;
}

export interface CosmosGateway {
  read<T>(
    container: string,
    id: string,
    partitionKey: string,
  ): Promise<T | null>;
  upsert<T extends { id: string; userId: string }>(
    container: string,
    document: T,
  ): Promise<T>;
  create<T extends { id: string; userId: string }>(
    container: string,
    document: T,
  ): Promise<T>;
  query<T>(container: string, query: CosmosQuery): Promise<T[]>;
}

class AzureCosmosGateway implements CosmosGateway {
  constructor(
    private readonly client: CosmosClient,
    private readonly databaseName: string,
  ) {}

  private container(name: string) {
    return this.client.database(this.databaseName).container(name);
  }

  async read<T>(
    container: string,
    id: string,
    partitionKey: string,
  ): Promise<T | null> {
    try {
      const { resource } = await this.container(container)
        .item(id, partitionKey)
        .read<T>();
      return resource ?? null;
    } catch (error) {
      if ((error as { code?: number }).code === 404) return null;
      throw error;
    }
  }

  async upsert<T extends { id: string; userId: string }>(
    container: string,
    document: T,
  ): Promise<T> {
    const { resource } = await this.container(container).items.upsert(document);
    if (!resource) throw new Error("Cosmos upsert returned no resource");
    return resource as unknown as T;
  }

  async create<T extends { id: string; userId: string }>(
    container: string,
    document: T,
  ): Promise<T> {
    const { resource } = await this.container(container).items.create(document);
    if (!resource) throw new Error("Cosmos create returned no resource");
    return resource as unknown as T;
  }

  async query<T>(container: string, query: CosmosQuery): Promise<T[]> {
    const { resources } = await this.container(container)
      .items.query<T>(query as SqlQuerySpec)
      .fetchAll();
    return resources;
  }
}

interface ProfileDocument extends UserProfile {
  id: "profile";
}

export class CosmosRepository
  implements FutureMintRepository, AuthRepository
{
  constructor(private readonly gateway: CosmosGateway) {}

  async getProfile(userId: string): Promise<UserProfile> {
    const document = await this.gateway.read<ProfileDocument>(
      "profiles",
      "profile",
      userId,
    );
    if (!document)
      throw new DomainError("profile_not_found", "找不到使用者設定。", 404);
    const { id: _id, ...profile } = document;
    return profile;
  }

  async saveProfile(profile: UserProfile): Promise<UserProfile> {
    const document: ProfileDocument = { id: "profile", ...profile };
    await this.gateway.upsert("profiles", document);
    return profile;
  }

  async listMoneyEvents(userId: string): Promise<MoneyEvent[]> {
    return this.gateway.query<MoneyEvent>("moneyEvents", {
      query:
        "SELECT * FROM c WHERE c.userId = @userId ORDER BY c.occurredAt DESC",
      parameters: [{ name: "@userId", value: userId }],
    });
  }

  async saveMoneyEvent(
    userId: string,
    input: ConfirmedMoneyEventInput,
  ): Promise<MoneyEvent> {
    const id = `event-${createHash("sha256").update(input.idempotencyKey).digest("hex").slice(0, 32)}`;
    const existing = await this.gateway.read<MoneyEvent>(
      "moneyEvents",
      id,
      userId,
    );
    if (existing) return existing;

    const now = new Date().toISOString();
    const event: MoneyEvent = {
      id,
      userId,
      type: input.type,
      amountMinor: input.amountMinor,
      currency: input.currency,
      category: input.category,
      merchant: input.merchant,
      occurredAt: input.occurredAt,
      recurrence: input.recurrence,
      split: input.split,
      idempotencyKey: input.idempotencyKey,
      createdAt: now,
      updatedAt: now,
    };
    try {
      return await this.gateway.create("moneyEvents", event);
    } catch (error) {
      if ((error as { code?: number }).code === 409) {
        const winner = await this.gateway.read<MoneyEvent>(
          "moneyEvents",
          id,
          userId,
        );
        if (winner) return winner;
      }
      throw error;
    }
  }

  getLesson(userId: string, lessonId: string): Promise<Lesson | null> {
    return this.gateway.read<Lesson>("learning", lessonId, userId);
  }

  async getLatestLesson(userId: string): Promise<Lesson | null> {
    const lessons = await this.gateway.query<Lesson>("learning", {
      query:
        "SELECT TOP 1 * FROM c WHERE c.userId = @userId ORDER BY c.createdAt DESC",
      parameters: [{ name: "@userId", value: userId }],
    });
    return lessons[0] ?? null;
  }

  saveLesson(lesson: Lesson): Promise<Lesson> {
    return this.gateway.upsert("learning", lesson);
  }

  async resetDemo(_userId: string): Promise<void> {
    throw new DomainError(
      "demo_reset_unsupported",
      "Cosmos 連線模式不支援自動重設，請使用專用合成資料程序。",
      409,
    );
  }

  async findAccountByEmail(email: string): Promise<Account | null> {
    const accounts = await this.gateway.query<Account>("accounts", {
      query: "SELECT TOP 1 * FROM c WHERE c.email = @email",
      parameters: [{ name: "@email", value: email }],
    });
    return accounts[0] ?? null;
  }

  findAccountById(userId: string): Promise<Account | null> {
    return this.gateway.read<Account>("accounts", userId, userId);
  }

  async createAccount(account: Account): Promise<Account> {
    return this.gateway.create("accounts", account);
  }

  async setProfileComplete(userId: string): Promise<void> {
    const account = await this.findAccountById(userId);
    if (!account) {
      throw new DomainError("account_not_found", "找不到登入帳號。", 404);
    }
    await this.gateway.upsert("accounts", {
      ...account,
      profileComplete: true,
    });
  }

  async createSession(session: SessionRecord): Promise<void> {
    await this.gateway.upsert("sessions", session);
  }

  async findSessionByTokenHash(
    tokenHash: string,
  ): Promise<SessionRecord | null> {
    const sessions = await this.gateway.query<SessionRecord>("sessions", {
      query: "SELECT TOP 1 * FROM c WHERE c.tokenHash = @tokenHash",
      parameters: [{ name: "@tokenHash", value: tokenHash }],
    });
    return sessions[0] ?? null;
  }

  async revokeSession(tokenHash: string): Promise<void> {
    const session = await this.findSessionByTokenHash(tokenHash);
    if (!session) return;
    await this.gateway.upsert("sessions", {
      ...session,
      revokedAt: new Date().toISOString(),
    });
  }
}

export const createCosmosRepositoryFromEnvironment = (): CosmosRepository => {
  const endpoint = process.env.COSMOS_ENDPOINT;
  const databaseName = process.env.COSMOS_DATABASE_NAME;
  if (!endpoint || !databaseName) {
    throw new Error("COSMOS_ENDPOINT and COSMOS_DATABASE_NAME are required");
  }
  const client = new CosmosClient({
    endpoint,
    aadCredentials: new DefaultAzureCredential(),
  });
  return new CosmosRepository(new AzureCosmosGateway(client, databaseName));
};
