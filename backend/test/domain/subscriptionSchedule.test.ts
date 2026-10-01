import { describe,expect,it } from "vitest";
import { nextSubscriptionBillingDate } from "../../src/domain/subscriptionSchedule";
import { calculateFutureSeed } from "../../src/domain/futureSeed";

const monthly={anchorDate:"2024-01-31",billingCycle:"monthly" as const,originalBillingDay:31,originalBillingMonth:1};
describe("subscription calendar schedule",()=>{
  it("clamps February and restores the original day in March without a payment",()=>{
    expect(nextSubscriptionBillingDate(monthly,new Date("2024-02-01T00:00:00+08:00"))).toBe("2024-02-29");
    expect(nextSubscriptionBillingDate(monthly,new Date("2025-02-01T00:00:00+08:00"))).toBe("2025-02-28");
    expect(nextSubscriptionBillingDate(monthly,new Date("2025-03-01T00:00:00+08:00"))).toBe("2025-03-31");
    expect(nextSubscriptionBillingDate(monthly,new Date("2025-12-31T23:00:00+08:00"))).toBe("2025-12-31");
  });
  it("preserves February 29 annual anniversaries across leap years",()=>{
    const yearly={anchorDate:"2024-02-29",billingCycle:"yearly" as const,originalBillingDay:29,originalBillingMonth:2};
    expect(nextSubscriptionBillingDate(yearly,new Date("2025-03-01T00:00:00+08:00"))).toBe("2026-02-28");
    expect(nextSubscriptionBillingDate(yearly,new Date("2028-02-01T00:00:00+08:00"))).toBe("2028-02-29");
  });
  it("returns stable principal at near-zero rates",()=>{
    const result=calculateFutureSeed({monthlyContributionMinor:1000,years:50,annualRatePercent:1e-15});
    expect(result.endingBalanceMinor).toBe(600000);
    expect(result.growthMinor).toBe(0);
    expect(Number.isFinite(result.endingBalanceMinor)).toBe(true);
  });
});
