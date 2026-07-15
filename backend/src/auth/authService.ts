import {
  createHash,
  randomBytes,
  randomUUID,
  scrypt as scryptCallback,
  timingSafeEqual,
} from "node:crypto";
import { promisify } from "node:util";

import type { AuthRepository } from "../application/ports";
import { DomainError } from "../contracts/errors";
import type {
  Account,
  PublicAccount,
  SessionRecord,
} from "../contracts/models";
import { authCredentialsSchema } from "../contracts/schemas";

const scrypt = promisify(scryptCallback);
const sessionDurationMs = 7 * 24 * 60 * 60 * 1000;

export interface AuthCredentials {
  email: string;
  password: string;
}

export interface AuthResult {
  account: PublicAccount;
  token: string;
}

const invalidCredentials = () =>
  new DomainError(
    "invalid_credentials",
    "電子郵件或密碼不正確。",
    401,
  );

const unauthorized = () =>
  new DomainError("unauthorized", "請先登入後再繼續。", 401);

const normalizeEmail = (email: string) => email.trim().toLowerCase();

const toPublicAccount = (account: Account): PublicAccount => ({
  id: account.id,
  email: account.email,
  profileComplete: account.profileComplete,
  createdAt: account.createdAt,
});

const hashToken = (token: string) =>
  createHash("sha256").update(token).digest("base64url");

const hashPassword = async (password: string, salt: string): Promise<string> =>
  (await scrypt(password, salt, 64) as Buffer).toString("base64url");

const passwordsMatch = async (
  password: string,
  account: Account,
): Promise<boolean> => {
  const expected = Buffer.from(account.passwordHash, "base64url");
  const actual = Buffer.from(
    await hashPassword(password, account.passwordSalt),
    "base64url",
  );
  return expected.length === actual.length && timingSafeEqual(expected, actual);
};

export class AuthService {
  constructor(
    private readonly repository: AuthRepository,
    private readonly now: () => Date = () => new Date(),
  ) {}

  async register(input: AuthCredentials): Promise<AuthResult> {
    const parsed = authCredentialsSchema.parse(input);
    const email = normalizeEmail(parsed.email);
    if (await this.repository.findAccountByEmail(email)) {
      throw new DomainError(
        "account_unavailable",
        "此電子郵件無法完成註冊。",
        409,
      );
    }
    const passwordSalt = randomBytes(16).toString("base64url");
    const createdAt = this.now().toISOString();
    const account: Account = {
      id: randomUUID(),
      userId: "",
      email,
      passwordHash: await hashPassword(parsed.password, passwordSalt),
      passwordSalt,
      passwordAlgorithm: "scrypt-v1",
      profileComplete: false,
      createdAt,
    };
    account.userId = account.id;
    await this.repository.createAccount(account);
    return this.createSession(account);
  }

  async login(input: AuthCredentials): Promise<AuthResult> {
    const parsed = authCredentialsSchema.parse(input);
    const account = await this.repository.findAccountByEmail(
      normalizeEmail(parsed.email),
    );
    if (!account || !(await passwordsMatch(parsed.password, account))) {
      throw invalidCredentials();
    }
    return this.createSession(account);
  }

  async authenticate(token: string): Promise<PublicAccount> {
    const session = await this.repository.findSessionByTokenHash(hashToken(token));
    if (
      !session ||
      session.revokedAt ||
      new Date(session.expiresAt).getTime() <= this.now().getTime()
    ) {
      throw unauthorized();
    }
    const account = await this.repository.findAccountById(session.userId);
    if (!account) throw unauthorized();
    return toPublicAccount(account);
  }

  async logout(token: string): Promise<void> {
    await this.repository.revokeSession(hashToken(token));
  }

  async markProfileComplete(userId: string): Promise<void> {
    await this.repository.setProfileComplete(userId);
  }

  private async createSession(account: Account): Promise<AuthResult> {
    const token = randomBytes(32).toString("base64url");
    const createdAt = this.now();
    const session: SessionRecord = {
      id: hashToken(token),
      userId: account.id,
      tokenHash: hashToken(token),
      createdAt: createdAt.toISOString(),
      expiresAt: new Date(createdAt.getTime() + sessionDurationMs).toISOString(),
    };
    await this.repository.createSession(session);
    return { account: toPublicAccount(account), token };
  }
}
