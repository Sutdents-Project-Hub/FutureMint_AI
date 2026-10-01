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
  authCredentialsSchema,
} from "../contracts/schemas";

import { InMemoryEligibilityStore, type EligibilityStore } from "../adapters/eligibilityStore";
import {
  ageDeclarationSchema, guardianRequestSchema, guardianConfirmationSchema, guardianWithdrawalSchema,
  registrationSchema, versionedAiConsentSchema, servicePolicyVersion, providerAiPolicyVersion,
  type AgeDeclarationInput, type EligibilityRecord, type GuardianActionToken, type ServiceEligibility,
} from "../contracts/servicePolicy";

const scrypt = promisify(scryptCallback);
const sessionDurationMs = 7 * 24 * 60 * 60 * 1000;
export const aiConsentPolicyVersion = providerAiPolicyVersion;

export interface AuthCredentials {
  email: string;
  password: string;
  ageDeclaration?: AgeDeclarationInput;
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

export interface AuthServiceOptions {
  mailer?: AccountMailer; requireEmailVerification?: boolean; requireEligibility?: boolean;
  eligibilityStore?: EligibilityStore; servicePolicyVersion?: string; aiPolicyVersion?: string;
  registrationEnabled?: boolean; aiPolicyReviewed?: boolean;
}

export class AuthService {
  private readonly eligibilityStore: EligibilityStore;
  private readonly eligibilityRequired: boolean;
  private readonly currentServicePolicy: string;
  private readonly currentAiPolicy: string;
  constructor(
    private readonly repository: AuthRepository,
    private readonly now: () => Date = () => new Date(),
    private readonly options: AuthServiceOptions = {},
  ) {
    this.eligibilityRequired = options.requireEligibility ?? process.env.NODE_ENV === "production";
    if (process.env.NODE_ENV === "production" && !options.eligibilityStore) throw new Error("Production requires an explicit eligibility store");
    this.eligibilityStore = options.eligibilityStore ?? new InMemoryEligibilityStore();
    this.currentServicePolicy = options.servicePolicyVersion ?? servicePolicyVersion;
    this.currentAiPolicy = options.aiPolicyVersion ?? aiConsentPolicyVersion;
    if (options.requireEmailVerification && !options.mailer && options.registrationEnabled !== false) {
      throw new Error("Email verification without a mailer requires disabled registration");
    }
  }

  async register(input: AuthCredentials): Promise<AuthResult> {
    if (this.options.registrationEnabled === false) {
      throw new DomainError("registration_disabled", "此服務尚未開放新帳號註冊，請先使用訪客模式；既有帳號仍可登入。", 503);
    }
    const parsed = registrationSchema.parse(input);
    if (this.eligibilityRequired && !parsed.ageDeclaration) {
      throw new DomainError("age_declaration_required", "請先確認年齡與服務說明。", 403);
    }
    if (parsed.ageDeclaration) this.validateAgeDeclaration(parsed.ageDeclaration);
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
    if (parsed.ageDeclaration) await this.declareAge(account.id, parsed.ageDeclaration);
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
    this.requireMailer();
    const account = await this.repository.findAccountById(userId);
    if (!account) throw unauthorized();
    if (!account.emailVerifiedAt) await this.sendAccountAction(account, "verify-email");
    return { accepted: true };
  }

  async requestPasswordReset(input: { email: string }): Promise<{ accepted: true }> {
    this.requireMailer();
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
    const mailer = this.requireMailer();
    const token = randomBytes(32).toString("base64url");
    const tokenHash = hashToken(token);
    await this.repository.saveAccountActionToken({ tokenHash, userId: account.id, purpose,
      expiresAt: new Date(this.now().getTime() + 30 * 60 * 1000).toISOString() });
    try {
      await mailer.send(account.email, purpose, token);
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
    if (consent?.policyVersion === this.currentAiPolicy) {
      if (this.options.aiPolicyReviewed === false) return { ...consent, granted: false };
      const eligibility = await this.eligibilityStore.get(userId);
      if (eligibility?.ageBand === "15-17" && (eligibility.guardianStatus !== "approved" || eligibility.aiConsentRevision !== eligibility.revision)) return { ...consent, granted: false, withdrawnAt: eligibility.guardianWithdrawnAt };
      return consent;
    }
    return {
      granted: false,
      policyVersion: this.currentAiPolicy,
      grantedAt: null,
      withdrawnAt: null,
    };
  }

  async setAiConsent(
    userId: string,
    input: { granted: boolean; policyVersion?: string },
  ): Promise<AiConsent> {
    const parsed = versionedAiConsentSchema.parse(input);
    const now = this.now().toISOString();
    const declarationAtGrant = parsed.granted ? await this.eligibilityStore.get(userId) : null;
    if (parsed.granted) {
      this.requireReviewedAiPolicy();
      if (parsed.policyVersion !== this.currentAiPolicy) throw new DomainError("ai_policy_changed", "AI 資料處理說明已更新，請重新閱讀並同意。", 409);
      await this.requireServiceEligibility(userId);
    }
    const current = await this.getAiConsent(userId);
    const consent: AiConsent = parsed.granted
      ? {
          granted: true,
          policyVersion: this.currentAiPolicy,
          grantedAt: now,
          withdrawnAt: null,
        }
      : {
          granted: false,
          policyVersion: this.currentAiPolicy,
          grantedAt: current.grantedAt,
          withdrawnAt: now,
        };
    await this.repository.saveAiConsent(userId, consent);
    if (parsed.granted && declarationAtGrant?.ageBand === "15-17") {
      await this.eligibilityStore.withUserTransaction(userId, async (store) => {
        const latest = await store.get(userId);
        if (latest?.revision === declarationAtGrant.revision && latest.guardianStatus === "approved") await store.save({ ...latest, aiConsentRevision: latest.revision });
      });
    }
    return this.getAiConsent(userId);
  }

  async requireAiConsent(userId: string): Promise<void> {
    this.requireReviewedAiPolicy();
    await this.requireServiceEligibility(userId);
    if (!(await this.getAiConsent(userId)).granted) {
      throw new DomainError(
        "ai_consent_required",
        "使用第三方 AI 前，請先同意資料處理說明。",
        403,
      );
    }
  }

  private requireMailer(): AccountMailer {
    if (!this.options.mailer) throw new DomainError("mail_disabled", "此服務未啟用寄信，無法寄送驗證、密碼重設或監護人確認信；請聯絡公開客服。", 503);
    return this.options.mailer;
  }

  private requireReviewedAiPolicy(): void {
    if (this.options.aiPolicyReviewed === false) throw new DomainError("ai_policy_unavailable", "第三方 AI 資料處理說明尚未完成，請先使用手動功能及固定教材。", 503);
  }

  private validateAgeDeclaration(input: AgeDeclarationInput): void {
    if (input.policyVersion !== this.currentServicePolicy) throw new DomainError("service_policy_changed", "服務說明已更新，請重新確認。", 409);
    if (input.ageBand === "under-15") throw new DomainError("age_not_supported", "本服務目前僅供年滿 15 歲的使用者使用。", 403);
  }

  private eligibilityFrom(record: EligibilityRecord | null): ServiceEligibility {
    let status: ServiceEligibility["status"] = "declaration-required";
    if (record?.policyVersion === this.currentServicePolicy) {
      status = record.ageBand === "under-15" ? "under-age" : record.ageBand === "18-plus" ? "eligible"
        : record.guardianStatus === "approved" ? "eligible" : record.guardianStatus === "withdrawn" ? "guardian-withdrawn" : "guardian-required";
    }
    return { status, ageBand: record?.ageBand ?? null, policyVersion: record?.policyVersion ?? null,
      currentPolicyVersion: this.currentServicePolicy, declaredAt: record?.declaredAt ?? null,
      guardianStatus: record?.guardianStatus ?? null, guardianApprovedAt: record?.guardianApprovedAt ?? null,
      guardianWithdrawnAt: record?.guardianWithdrawnAt ?? null, canWrite: status === "eligible" };
  }

  async getEligibility(userId: string): Promise<ServiceEligibility> {
    return this.eligibilityFrom(await this.eligibilityStore.get(userId));
  }

  async declareAge(userId: string, input: AgeDeclarationInput): Promise<ServiceEligibility> {
    const parsed = ageDeclarationSchema.parse(input);
    this.validateAgeDeclaration(parsed);
    return this.eligibilityStore.withUserTransaction(userId, async (store) => {
      if (!(await this.repository.findAccountById(userId))) throw unauthorized();
      const previous = await store.get(userId);
      // Self-report never upgrades an already declared minor to an adult.
      if (previous && previous.ageBand !== parsed.ageBand) throw new DomainError("age_declaration_locked", "年齡區間更正需由客服查核，不能自行變更以略過監護人同意。", 409);
      if (previous?.policyVersion === this.currentServicePolicy) return this.eligibilityFrom(previous);
      const record: EligibilityRecord = { userId, ageBand: parsed.ageBand, policyVersion: this.currentServicePolicy,
        declaredAt: this.now().toISOString(), guardianStatus: parsed.ageBand === "18-plus" ? "not-required" : "pending",
        guardianEmail: null, guardianApprovedAt: null, guardianWithdrawnAt: previous && parsed.ageBand === "15-17" ? this.now().toISOString() : null, revision: (previous?.revision ?? 0) + 1, aiConsentRevision: null };
      await store.clearTokens(userId);
      await store.save(record);
      return this.eligibilityFrom(record);
    });
  }

  async requireServiceEligibility(userId: string): Promise<void> {
    if (!this.eligibilityRequired) return;
    const eligibility = await this.getEligibility(userId);
    if (!eligibility.canWrite) throw new DomainError(eligibility.status === "declaration-required" ? "age_declaration_required" : "guardian_consent_required",
      eligibility.status === "declaration-required" ? "請先完成目前版本的年齡聲明。" : "監護人同意尚未完成或已撤回，仍可查看、匯出及刪除自己的資料。", 403);
  }

  async requestGuardian(userId: string, input: { email: string }): Promise<{ accepted: true }> {
    this.requireMailer();
    const email = normalizeEmail(guardianRequestSchema.parse(input).email);
    await this.eligibilityStore.withUserTransaction(userId, async (store) => {
      const account = await this.repository.findAccountById(userId);
      if (!account) throw unauthorized();
      const record = await store.get(userId);
      if (!record || record.policyVersion !== this.currentServicePolicy || record.ageBand !== "15-17") throw new DomainError("guardian_not_applicable", "請先確認適用的年齡與服務版本。", 409);
      if (email === account.email) throw new DomainError("guardian_email_invalid", "監護人須使用與使用者不同的電子郵件。", 400);
      if (record.guardianStatus === "approved") throw new DomainError("guardian_already_approved", "請先撤回現有同意，再申請新的監護人同意。", 409);
      const updated = { ...record, guardianStatus: "pending" as const, guardianEmail: email, revision: record.revision + 1 };
      await store.clearTokens(userId);
      await store.save(updated);
      await this.sendGuardianAction(store, updated, "guardian-approve");
    });
    return { accepted: true };
  }

  async confirmGuardian(input: { token: string; policyVersion: string; adult: true; legalGuardian: true; accepted: true }): Promise<{ approved: true; emailDeliveryPending?: boolean }> {
    const parsed = guardianConfirmationSchema.parse(input);
    if (parsed.policyVersion !== this.currentServicePolicy) throw new DomainError("service_policy_changed", "服務說明已更新，請重新申請同意。", 409);
    let deliveryPending = false;
    await this.withGuardianToken(parsed.token, "guardian-approve", async (store, record) => {
      if (record.guardianStatus !== "pending") throw this.invalidActionToken();
      const approved = { ...record, guardianStatus: "approved" as const, guardianApprovedAt: this.now().toISOString() };
      await store.save(approved);
      await store.clearTokens(record.userId);
      // Approval itself remains valid if the subsequent withdrawal email fails.
      try { await this.sendGuardianAction(store, approved, "guardian-withdraw"); } catch { deliveryPending = true; }
    });
    return deliveryPending ? { approved: true, emailDeliveryPending: true } : { approved: true };
  }

  async requestGuardianWithdrawal(input: { accountEmail: string; guardianEmail: string }): Promise<{ accepted: true }> {
    this.requireMailer();
    const accountEmail = normalizeEmail(authCredentialsSchema.shape.email.parse(input.accountEmail));
    const guardianEmail = normalizeEmail(authCredentialsSchema.shape.email.parse(input.guardianEmail));
    const account = await this.repository.findAccountByEmail(accountEmail);
    if (account) {
      try {
        await this.eligibilityStore.withUserTransaction(account.id, async (store) => {
          const record = await store.get(account.id);
          if (record?.guardianStatus === "approved" && record.guardianEmail === guardianEmail) await this.sendGuardianAction(store, record, "guardian-withdraw");
        });
      } catch { /* same response for absent account, mismatch and delivery failure */ }
    }
    return { accepted: true };
  }

  async withdrawGuardian(input: { token: string }): Promise<{ withdrawn: true }> {
    const parsed = guardianWithdrawalSchema.parse(input);
    await this.withGuardianToken(parsed.token, "guardian-withdraw", async (store, record) => {
      if (record.guardianStatus !== "approved") throw this.invalidActionToken();
      await this.withdrawRecord(store, record);
    });
    return { withdrawn: true };
  }

  async withdrawGuardianByAccount(userId: string): Promise<ServiceEligibility> {
    return this.eligibilityStore.withUserTransaction(userId, async (store) => {
      if (!(await this.repository.findAccountById(userId))) throw unauthorized();
      const record = await store.get(userId);
      if (!record || record.ageBand !== "15-17") throw new DomainError("guardian_not_applicable", "此帳號沒有適用的監護人同意。", 409);
      return this.eligibilityFrom(await this.withdrawRecord(store, record));
    });
  }

  private async withdrawRecord(store: EligibilityStore, record: EligibilityRecord): Promise<EligibilityRecord> {
    const withdrawn = { ...record, guardianStatus: "withdrawn" as const, guardianWithdrawnAt: this.now().toISOString(), revision: record.revision + 1 };
    await store.clearTokens(record.userId);
    await store.save(withdrawn);
    // getAiConsent rejects grants bound to the previous guardian revision, even after reapproval.
    return withdrawn;
  }

  private async withGuardianToken(token: string, purpose: GuardianActionToken["purpose"], operation: (store: EligibilityStore, record: EligibilityRecord) => Promise<void>): Promise<void> {
    if (!this.isActionToken(token)) throw this.invalidActionToken();
    const hash = hashToken(token);
    const initial = await this.eligibilityStore.findToken(hash);
    if (!initial) throw this.invalidActionToken();
    await this.eligibilityStore.withUserTransaction(initial.userId, async (store) => {
      const action = await store.findToken(hash);
      const record = await store.get(initial.userId);
      if (!action || !record || action.purpose !== purpose || action.revision !== record.revision || action.policyVersion !== this.currentServicePolicy
        || record.policyVersion !== this.currentServicePolicy || action.guardianEmail !== record.guardianEmail || new Date(action.expiresAt).getTime() <= this.now().getTime()) throw this.invalidActionToken();
      await store.deleteToken(hash);
      await operation(store, record);
    });
  }

  private async sendGuardianAction(store: EligibilityStore, record: EligibilityRecord, purpose: GuardianActionToken["purpose"]): Promise<void> {
    if (!this.options.mailer || !record.guardianEmail) throw new DomainError("mail_unavailable", "郵件服務暫時無法使用，請稍後再試。", 503, true);
    const account = await this.repository.findAccountById(record.userId);
    if (!account) throw unauthorized();
    const requesterEmail = normalizeEmail(authCredentialsSchema.shape.email.parse(account.email));
    const token = randomBytes(32).toString("base64url");
    const action: GuardianActionToken = { tokenHash: hashToken(token), userId: record.userId, purpose,
      policyVersion: record.policyVersion, guardianEmail: record.guardianEmail, revision: record.revision,
      expiresAt: new Date(this.now().getTime() + 30 * 60_000).toISOString() };
    await store.saveToken(action);
    try { await this.options.mailer.send(record.guardianEmail, purpose, token, { requesterEmail }); }
    catch { await store.deleteToken(action.tokenHash); throw new DomainError("mail_unavailable", "郵件服務暫時無法使用，請稍後再試。", 503, true); }
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
    await this.eligibilityStore.deleteUser(userId);
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
