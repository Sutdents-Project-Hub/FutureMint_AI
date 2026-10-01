import { describe,expect,it } from "vitest";
import { FutureMintService } from "../../src/application/futureMintService";
import { InMemoryRepository } from "../../src/adapters/inMemoryRepository";
import { DemoAiProvider } from "../../src/adapters/demoAiProvider";
import { EducationalMarketDataProvider } from "../../src/adapters/twseMarketDataProvider";
import { demoCatalog } from "../../src/adapters/demoCatalog";
const make=()=>{const repository=new InMemoryRepository();return {repository,service:new FutureMintService(repository,new DemoAiProvider(),demoCatalog,new EducationalMarketDataProvider())};};
const subscription={name:"年度影音",amountMinor:1200,currency:"TWD" as const,billingCycle:"yearly" as const,anchorDate:"2026-01-31",idempotencyKey:"subscription-create-key"};
const payment={type:"subscription" as const,amountMinor:1200,currency:"TWD" as const,category:"subscription" as const,occurredAt:"2026-07-01T00:00:00+08:00",confirmed:true as const,idempotencyKey:"initial-payment",source:"manual" as const};
describe("active subscriptions and actual payments",()=>{
  it("returns the same subscription and payment on concurrent retry and rejects changed create payload",async()=>{
    const {service,repository}=make();
    const input={...subscription,initialPayment:payment};
    const [first,second]=await Promise.all([service.createSubscription("demo-user",input),service.createSubscription("demo-user",input)]);
    expect(first.id).toBe(second.id);
    expect((await service.getSubscriptions("demo-user")).items).toHaveLength(1);
    expect((await repository.listMoneyEvents("demo-user")).filter((event)=>event.subscriptionId===first.id)).toHaveLength(1);
    await expect(service.createSubscription("demo-user",{...input,amountMinor:1500})).rejects.toMatchObject({code:"idempotency_conflict"});
  });
  it("adopts a selected legacy payment once and preserves its historical amount and date",async()=>{
    const {service,repository}=make();
    const legacy=(await service.getSubscriptions("demo-user")).legacyCandidates[0];
    const input={...subscription,legacyPaymentId:legacy.id};
    const item=await service.createSubscription("demo-user",input);
    expect((await service.createSubscription("demo-user",input)).id).toBe(item.id);
    const saved=(await repository.listMoneyEvents("demo-user")).find((event)=>event.id===legacy.id)!;
    expect(saved.amountMinor).toBe(legacy.amountMinor);expect(saved.occurredAt).toBe(legacy.occurredAt);expect(saved.subscriptionId).toBe(item.id);
    expect((await service.getSubscriptions("demo-user")).legacyCandidates).toHaveLength(0);
    await expect(service.createSubscription("demo-user",{...input,idempotencyKey:"second-adoption-key"})).rejects.toMatchObject({code:"invalid_legacy_subscription"});
    expect((await service.getSubscriptions("demo-user")).items).toHaveLength(1);
  });
  it("separates yearly monthly commitment from actual paid totals and preserves payments on deactivate",async()=>{
    const {service,repository}=make();
    const item=await service.createSubscription("demo-user",{...subscription,initialPayment:payment});
    expect((await service.getSubscriptions("demo-user")).monthlyCommitmentMinor).toBe(100);
    const events=await repository.listMoneyEvents("demo-user");
    expect(events.find((event)=>event.subscriptionId===item.id)?.source).toBe("manual");
    const dashboard=await service.getDashboard("demo-user",new Date("2026-07-10T00:00:00+08:00"));
    expect(dashboard.subscriptionMinor).toBe(1298);
    expect(dashboard.monthlyCommitmentMinor).toBe(100);
    const insights=await service.getInsights("demo-user",new Date("2026-07-10T00:00:00+08:00"));
    expect(insights.subscriptionMinor).toBe(1298); expect(insights.monthlyCommitmentMinor).toBe(100);
    await service.deactivateSubscription("demo-user",item.id);
    expect((await service.getSubscriptions("demo-user")).monthlyCommitmentMinor).toBe(0);
    expect(await repository.listMoneyEvents("demo-user")).toEqual(events);
  });
  it("requires explicit adoption and keeps identical merchant subscriptions distinct",async()=>{
    const {service}=make();const before=await service.getSubscriptions("demo-user");
    expect(before.items).toEqual([]);expect(before.legacyCandidates).toHaveLength(1);
    await service.createSubscription("demo-user",subscription);await service.createSubscription("demo-user",{...subscription,idempotencyKey:"distinct-subscription-key"});
    const result=await service.getSubscriptions("demo-user"); expect(new Set(result.items.map((item)=>item.id)).size).toBe(2);expect(result.legacyCandidates).toHaveLength(1);
  });
  it("preserves adopted links for older edits and retains the original retry fingerprint",async()=>{
    const {repository,service}=make();
    const original={...payment,idempotencyKey:"compat-legacy-payment",source:"openai-ai" as const,recurrence:{billingCycle:"yearly" as const}};
    const legacy=await service.saveMoneyEvent("demo-user",original);
    const contract=await service.createSubscription("demo-user",{...subscription,legacyPaymentId:legacy.id});
    const edited=await service.updateMoneyEvent("demo-user",legacy.id,{...original,amountMinor:900,currency:undefined as unknown as "TWD",source:"manual"});
    expect(edited.subscriptionId).toBe(contract.id);expect(edited.currency).toBe("TWD");expect(edited.source).toBe("manual");
    expect((await service.getSubscriptions("demo-user")).legacyCandidates.map((item)=>item.id)).not.toContain(legacy.id);
    expect((await service.saveMoneyEvent("demo-user",original)).amountMinor).toBe(900);
    const withoutRecurrence=await service.updateMoneyEvent("demo-user",legacy.id,{type:"subscription",amountMinor:800,currency:"TWD",category:"subscription",occurredAt:original.occurredAt,confirmed:true});
    expect(withoutRecurrence.subscriptionId).toBe(contract.id);expect(withoutRecurrence.source).toBe("manual");
    const other=await service.createSubscription("demo-user",{...subscription,idempotencyKey:"different-owned-contract"});
    await expect(service.updateMoneyEvent("demo-user",legacy.id,{...original,subscriptionId:other.id})).rejects.toMatchObject({code:"subscription_link_changed",status:409});
    const foreign=await service.createSubscription("other",{...subscription,idempotencyKey:"foreign-contract"});
    await expect(service.updateMoneyEvent("demo-user",legacy.id,{...original,subscriptionId:foreign.id})).rejects.toMatchObject({code:"subscription_not_found"});
    const changed=await service.updateMoneyEvent("demo-user",legacy.id,{type:"expense",amountMinor:800,currency:"TWD",category:"other",occurredAt:original.occurredAt,subscriptionId:contract.id,confirmed:true});
    expect(changed.subscriptionId).toBeUndefined();expect((await repository.listMoneyEvents("demo-user")).find((item)=>item.id===legacy.id)?.type).toBe("expense");
  });
  it("rejects cross-owner updates, deactivate and linked payments",async()=>{
    const {service}=make();const item=await service.createSubscription("owner",subscription);
    await expect(service.updateSubscription("other",item.id,{name:subscription.name,amountMinor:subscription.amountMinor,currency:subscription.currency,billingCycle:subscription.billingCycle,anchorDate:subscription.anchorDate})).rejects.toMatchObject({code:"subscription_not_found"});
    await expect(service.deactivateSubscription("other",item.id)).rejects.toMatchObject({code:"subscription_not_found"});
    await expect(service.saveMoneyEvent("other",{...payment,subscriptionId:item.id})).rejects.toMatchObject({code:"subscription_not_found"});
  });
  it("rolls back subscription creation when initial-payment persistence conflicts",async()=>{
    const {service}=make();
    await service.saveMoneyEvent("demo-user",{...payment,recurrence:{billingCycle:"yearly"}});
    await expect(service.createSubscription("demo-user",{...subscription,initialPayment:payment})).rejects.toMatchObject({code:"idempotency_conflict",status:409});
    expect((await service.getSubscriptions("demo-user")).items).toEqual([]);
  });
  it("rejects same key with changed payload even after the event is edited",async()=>{
    const {service}=make();const input={...payment,recurrence:{billingCycle:"yearly" as const}};
    const saved=await service.saveMoneyEvent("demo-user",input);
    await service.updateMoneyEvent("demo-user",saved.id,{...input,amountMinor:900});
    await expect(service.saveMoneyEvent("demo-user",{...input,amountMinor:1300})).rejects.toMatchObject({code:"idempotency_conflict",status:409});
    expect((await service.saveMoneyEvent("demo-user",input)).amountMinor).toBe(900);
  });
});
describe("keyset event pages",()=>{
  it("returns every event once for equal timestamps and ignores paging for aggregates",async()=>{
    const {service}=make();
    for(let i=0;i<105;i++) await service.saveMoneyEvent("paged",{type:"expense",amountMinor:10,currency:"TWD",category:"food",occurredAt:"2026-07-01T00:00:00Z",confirmed:true,idempotencyKey:`page-event-${i}`});
    const first=await service.listMoneyEventsPage("paged");expect(first.items).toHaveLength(50);expect(first.nextCursor).toBeTruthy();
    const second=await service.listMoneyEventsPage("paged",{cursor:first.nextCursor});const third=await service.listMoneyEventsPage("paged",{cursor:second.nextCursor});
    expect(third.items).toHaveLength(5);expect(third.nextCursor).toBeUndefined();
    expect(new Set([...first.items,...second.items,...third.items].map((item)=>item.id)).size).toBe(105);
    expect(await service.listMoneyEventsPage("other",{cursor:first.nextCursor})).toEqual({items:[]});
    expect(await service.listMoneyEvents("paged")).toHaveLength(105);
    await expect(service.listMoneyEventsPage("paged",{limit:101})).rejects.toThrow();
    await expect(service.listMoneyEventsPage("paged",{cursor:"malformed"})).rejects.toMatchObject({code:"invalid_cursor"});
  });
  it("binds order idempotency to the original request",async()=>{
    const {service,repository}=make();
    const input={symbol:"0050",side:"buy" as const,quantity:1,idempotencyKey:"order-key-01"};
    await service.placeInvestmentOrder("demo-user",input);
    await expect(service.placeInvestmentOrder("demo-user",{...input,quantity:2})).rejects.toMatchObject({code:"idempotency_conflict"});
    const orders=await repository.listInvestmentOrders("demo-user");expect(orders[0].executionSequence).toBe(1);
  });
});

describe("family snapshots and owned data export",()=>{
  it("rejects leaving when the captured family changed before lock",async()=>{
    const {repository,service}=make();
    let reads=0;
    repository.getFamilyMembership=async()=>({familyId:++reads===1 ? "old-family" : "new-family",userId:"demo-user",email:"private@example.com",role:"child",joinedAt:"2026-01-01T00:00:00Z"});
    repository.listFamilyMembers=async(familyId)=>[{familyId,userId:"demo-user",email:"private@example.com",role:"child",joinedAt:"2026-01-01T00:00:00Z"}];
    await expect(service.leaveFamily("demo-user")).rejects.toMatchObject({code:"family_changed",status:409});
  });
  it("exports all owned data and only the caller's family role",async()=>{
    const {repository,service}=make();
    await service.generateLesson("demo-user");await service.createSubscription("demo-user",subscription);
    repository.getFamilyMembership=async()=>({familyId:"test-family",userId:"demo-user",email:"private@example.com",role:"child",joinedAt:"2026-01-01T00:00:00Z"});
    const data=await service.exportUserData("demo-user");
    expect(data.moneyEvents).toHaveLength(4);expect(data.subscriptions).toHaveLength(1);expect(data.lessons).toHaveLength(1);
    expect(data.familyMembership).toEqual({familyId:"test-family",role:"child",joinedAt:"2026-01-01T00:00:00Z"});expect(JSON.stringify(data)).not.toContain("private@example.com");
  });
  it("rejects deleting an account if its family changed while acquiring locks",async()=>{
    const {repository,service}=make();
    for(const userId of ["parent-old","parent-new"]) {
      await repository.resetDemo(userId);
      await repository.saveProfile({...await repository.getProfile(userId),accountRole:"parent"});
    }
    const old=await service.createFamilyInvite("parent-old");const next=await service.createFamilyInvite("parent-new");
    await service.joinFamily("demo-user",{inviteCode:old.inviteCode!});
    const transaction=repository.withUsersTransaction.bind(repository);
    repository.withUsersTransaction=async(userIds,operation)=>{
      await repository.removeFamilyMember("demo-user");
      await repository.addFamilyMember(next.familyId,"demo-user");
      return transaction(userIds,operation);
    };
    await expect(repository.deleteAccount("demo-user")).rejects.toMatchObject({code:"family_changed",status:409});
    expect((await repository.getFamilyMembership("demo-user"))?.familyId).toBe(next.familyId);
  });
});
