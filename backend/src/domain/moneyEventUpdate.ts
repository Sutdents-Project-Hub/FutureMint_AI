import type { EditableMoneyEventInput } from "../application/ports";
import type { MoneyEvent } from "../contracts/models";
import { DomainError } from "../contracts/errors";

// Older clients send complete payment edits without the subscription link.
// Preserve that relationship unless the payment becomes another event type.
export const resolveMoneyEventUpdate = (
  existing: MoneyEvent,
  input: EditableMoneyEventInput,
): EditableMoneyEventInput => {
  if (
    input.type === "subscription" && existing.subscriptionId &&
    input.subscriptionId && input.subscriptionId !== existing.subscriptionId
  ) {
    throw new DomainError("subscription_link_changed", "已連結的訂閱付款不能直接改掛其他訂閱。", 409);
  }
  const subscriptionId = input.type === "subscription"
    ? input.subscriptionId ?? existing.subscriptionId
    : undefined;
  if (input.type === "subscription" && !subscriptionId && !input.recurrence) {
    throw new DomainError("subscription_cycle_required", "尚未連結訂閱的付款必須確認計費週期。", 422);
  }
  return {
    ...input,
    currency: input.currency ?? existing.currency,
    source: input.source ?? existing.source,
    subscriptionId,
  };
};
