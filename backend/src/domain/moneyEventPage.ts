import type { MoneyEvent, MoneyEventPage, MoneyEventPageQuery } from "../contracts/models";
import { DomainError } from "../contracts/errors";

export const decodeMoneyEventCursor = (cursor?: string): {occurredAt: string; id: string} | undefined => {
  if (!cursor) return undefined;
  try {
    const item = JSON.parse(Buffer.from(cursor,"base64url").toString("utf8"));
    if (typeof item.id !== "string" || !item.id || item.id.length > 120 || typeof item.occurredAt !== "string" || !Number.isFinite(new Date(item.occurredAt).getTime())) throw new Error();
    return {id: item.id, occurredAt: new Date(item.occurredAt).toISOString()};
  } catch { throw new DomainError("invalid_cursor","分頁識別碼無效，請重新載入。",422); }
};
export const moneyEventPage = (events: MoneyEvent[], limit: number): MoneyEventPage => ({
  items: events.slice(0,limit),
  ...(events.length > limit ? {nextCursor: Buffer.from(JSON.stringify({occurredAt: events[limit-1].occurredAt,id: events[limit-1].id})).toString("base64url")} : {}),
});
export const filterMoneyEventPage = (events: MoneyEvent[], query: MoneyEventPageQuery): MoneyEventPage => {
  const cursor=decodeMoneyEventCursor(query.cursor);
  const items=events.filter((item) => (!query.type || item.type===query.type) && (!query.from || new Date(item.occurredAt)>=new Date(query.from)) && (!query.to || new Date(item.occurredAt)<=new Date(query.to)) && (!cursor || new Date(item.occurredAt)<new Date(cursor.occurredAt) || (new Date(item.occurredAt).getTime()===new Date(cursor.occurredAt).getTime() && item.id<cursor.id))).sort((a,b)=>new Date(b.occurredAt).getTime()-new Date(a.occurredAt).getTime() || b.id.localeCompare(a.id));
  return moneyEventPage(items,query.limit ?? 50);
};
