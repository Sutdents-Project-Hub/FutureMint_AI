import {
  createHash,
  randomBytes,
  randomUUID,
  scrypt as scryptCallback,
  timingSafeEqual,
} from "node:crypto";
import { promisify } from "node:util";

import type { AccountMailer, AccountMailPurpose } from "./accountMailer";

import type { AuthRepository } from "../application/ports";
import { DomainError } from "../contracts/errors";
import type {
  Account,
  AiConsent,
  PublicAccount,
  SessionRecord,
} from "../contracts/models";
import {
  accountDeletionSchema,
  aiConsentInputSchema,
  authCredentialsSchema,
} from "../contracts/schemas";

const scrypt = promisify(scryptCallback);
const sessionDurationMs = 7 * 24 * 60 * 60 * 1000;
export const aiConsentPolicyVersion = "third-party-ai-v1";

export interface AuthCredentials {
  email: string;
  password: string;
}

export interface AuthResult {
  account: PublicAccount;
  token: string;
  emailDeliveryPending?: boolean;
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

const toPublicAccount = (account: Account, requireVerification = false): PublicAccount => ({
  id: account.id,
  email: account.email,
  profileComplete: account.profileComplete,
  createdAt: account.createdAt,
  emailVerified: Boolean(account.emailVerifiedAt),
  verificationRequired: requireVerification && !account.emailVerifiedAt,
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
    private readonly options: { mailer?: AccountMailer; requireEmailVerification?: boolean } = {},
  ) {
    if (options.requireEmailVerification && !options.mailer) {
      throw new Error("Email verification requires an account mailer");
    }
  }

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
    const session = await this.createSession(account);
    if (this.options.mailer) {
      try {
        await this.requestEmailVerification(account.id);
      } catch {
        return { ...session, emailDeliveryPending: true };
      }
    }
    return session;
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

  async requestEmailVerification(userId: string): Promise<{ accepted: true }> {
    const account = await this.repository.findAccountById(userId);
    if (!account) throw unauthorized();
    if (!account.emailVerifiedAt) await this.sendAccountAction(account, "verify-email");
    return { accepted: true };
  }

  async requestPasswordReset(input: { email: string }): Promise<{ accepted: true }> {
    const email = authCredentialsSchema.shape.email.parse(input.email);
    const account = await this.repository.findAccountByEmail(normalizeEmail(email));
    // Both delivery failures and unknown addresses have the same public result.
    if (account) {
      try { await this.sendAccountAction(account, "reset-password"); } catch { /* no account enumeration */ }
    }
    return { accepted: true };
  }

  async verifyEmail(token: string): Promise<{ verified: true }> {
    if (!this.isActionToken(token) || !(await this.repository.consumeEmailVerification(hashToken(token), this.now().toISOString()))) {
      throw this.invalidActionToken();
    }
    return { verified: true };
  }

  async resetPassword(token: string, password: string): Promise<{ reset: true }> {
    const parsed = authCredentialsSchema.shape.password.parse(password);
    if (!this.isActionToken(token)) throw this.invalidActionToken();
    const passwordSalt = randomBytes(16).toString("base64url");
    const passwordHash = await hashPassword(parsed, passwordSalt);
    if (!(await this.repository.consumePasswordReset(hashToken(token), this.now().toISOString(), { passwordSalt, passwordHash }))) {
      throw this.invalidActionToken();
    }
    return { reset: true };
  }

  private isActionToken(token: string): boolean {
    return typeof token === "string" && /^[A-Za-z0-9_-]{43}$/.test(token);
  }

  private invalidActionToken(): DomainError {
    return new DomainError("invalid_action_token", "連結已失效或已使用，請重新提出要求。", 400);
  }

  private async sendAccountAction(account: Account, purpose: AccountMailPurpose): Promise<void> {
    if (!this.options.mailer) {
      throw new DomainError("mail_unavailable", "郵件服務暫時無法使用，請稍後再試。", 503, true);
    }
    const token = randomBytes(32).toString("base64url");
    const tokenHash = hashToken(token);
    await this.repository.saveAccountActionToken({ tokenHash, userId: account.id, purpose,
      expiresAt: new Date(this.now().getTime() + 30 * 60 * 1000).toISOString() });
    try {
      await this.options.mailer.send(account.email, purpose, token);
    } catch {
      await this.repository.deleteAccountActionToken(tokenHash);
      throw new DomainError("mail_unavailable", "郵件服務暫時無法使用，請稍後再試。", 503, true);
    }
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
    return toPublicAccount(account, this.options.requireEmailVerification);
  }

  async logout(token: string): Promise<void> {
    await this.repository.revokeSession(hashToken(token));
  }

  async getAiConsent(userId: string): Promise<AiConsent> {
    const consent = await this.repository.getAiConsent(userId);
    if (consent?.policyVersion === aiConsentPolicyVersion) return consent;
    return {
      granted: false,
      policyVersion: aiConsentPolicyVersion,
      grantedAt: null,
      withdrawnAt: null,
    };
  }

  async setAiConsent(
    userId: string,
    input: { granted: boolean },
  ): Promise<AiConsent> {
    const parsed = aiConsentInputSchema.parse(input);
    const now = this.now().toISOString();
    const current = await this.getAiConsent(userId);
    const consent: AiConsent = parsed.granted
      ? {
          granted: true,
          policyVersion: aiConsentPolicyVersion,
          grantedAt: now,
          withdrawnAt: null,
        }
      : {
          granted: false,
          policyVersion: aiConsentPolicyVersion,
          grantedAt: current.grantedAt,
          withdrawnAt: now,
        };
    return this.repository.saveAiConsent(userId, consent);
  }

  async requireAiConsent(userId: string): Promise<void> {
    if (!(await this.getAiConsent(userId)).granted) {
      throw new DomainError(
        "ai_consent_required",
        "使用第三方 AI 前，請先同意資料處理說明。",
        403,
      );
    }
  }

  async deleteAccount(
    userId: string,
    input: { password: string },
  ): Promise<void> {
    const parsed = accountDeletionSchema.parse(input);
    const account = await this.repository.findAccountById(userId);
    if (!account || !(await passwordsMatch(parsed.password, account))) {
      throw invalidCredentials();
    }
    await this.repository.deleteAccount(userId, account.passwordHash);
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
    await this.repository.createSession(session, account.passwordHash);
    return { account: toPublicAccount(account, this.options.requireEmailVerification), token };
  }
}
