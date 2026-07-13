import { createCosmosRepositoryFromEnvironment } from "../src/adapters/cosmosRepository";
import type { ConfirmedMoneyEventInput } from "../src/application/ports";

const userId = "demo-user";

const events: ConfirmedMoneyEventInput[] = [
  {
    type: "income",
    amountMinor: 1500,
    currency: "TWD",
    category: "income",
    merchant: "合成打工收入",
    occurredAt: "2026-07-05T18:00:00+08:00",
    confirmed: true,
    idempotencyKey: "cosmos-demo-seed-income-v1",
  },
  {
    type: "expense",
    amountMinor: 75,
    currency: "TWD",
    category: "food",
    merchant: "合成飲料",
    occurredAt: "2026-07-08T16:30:00+08:00",
    confirmed: true,
    idempotencyKey: "cosmos-demo-seed-drink-v1",
  },
  {
    type: "expense",
    amountMinor: 450,
    currency: "TWD",
    category: "entertainment",
    merchant: "合成遊戲點數",
    occurredAt: "2026-07-09T20:10:00+08:00",
    confirmed: true,
    idempotencyKey: "cosmos-demo-seed-game-v1",
  },
  {
    type: "subscription",
    amountMinor: 390,
    currency: "TWD",
    category: "subscription",
    merchant: "合成影音訂閱",
    occurredAt: "2026-07-01T08:00:00+08:00",
    recurrence: {
      billingCycle: "monthly",
      nextBillingAt: "2026-08-01T08:00:00+08:00",
    },
    split: { participants: 4, userShareMinor: 98 },
    confirmed: true,
    idempotencyKey: "cosmos-demo-seed-subscription-v1",
  },
];

const run = async (): Promise<void> => {
  if (process.env.ALLOW_DEMO_SEED !== "true") {
    console.error("futuremint_cosmos_demo_seed_refused", {
      reason: "ALLOW_DEMO_SEED_not_true",
    });
    process.exitCode = 1;
    return;
  }

  const repository = createCosmosRepositoryFromEnvironment();
  await repository.saveProfile({
    userId,
    monthlyBudgetMinor: 6000,
    weeklyBudgetMinor: 1500,
    goalName: "合成校外活動基金",
    goalTargetMinor: 12000,
    goalSavedMinor: 4200,
    goalDate: "2026-10-31",
    preferredTone: "supportive",
  });
  for (const event of events) {
    await repository.saveMoneyEvent(userId, event);
  }

  console.info("futuremint_cosmos_demo_seed_complete", {
    userId,
    syntheticEventCount: events.length,
  });
};

void run().catch((error: unknown) => {
  console.error("futuremint_cosmos_demo_seed_failed", {
    errorType: error instanceof Error ? error.name : typeof error,
  });
  process.exitCode = 1;
});
