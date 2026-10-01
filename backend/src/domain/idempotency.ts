import { createHash } from "node:crypto";
import type { ConfirmedMoneyEventInput } from "../application/ports";
import type { InvestmentOrderInput, MoneyEvent } from "../contracts/models";
import { DomainError } from "../contracts/errors";

export const moneyRequestFingerprint = (input: ConfirmedMoneyEventInput | MoneyEvent): string =>
  createHash("sha256").update(JSON.stringify([
    input.type,input.amountMinor,input.currency,input.category,input.merchant ?? null,
    new Date(input.occurredAt).toISOString(),input.subscriptionId ?? null,
    input.recurrence ? [input.recurrence.billingCycle,input.recurrence.nextBillingAt ? new Date(input.recurrence.nextBillingAt).toISOString() : null] : null,
    input.split ? [input.split.participants,input.split.userShareMinor] : null,input.spendingIntent ?? null,input.intentReason ?? null,input.source ?? null,
  ])).digest("hex");

export const assertSameOrderRequest = (existing: InvestmentOrderInput, input: InvestmentOrderInput): void => {
  if (existing.symbol !== input.symbol || existing.side !== input.side || existing.quantity !== input.quantity) throw idempotencyConflict();
};
export const idempotencyConflict = () => new DomainError("idempotency_conflict", "此重試識別碼已用於不同內容，請重新確認。",409);
