import { createHash } from "node:crypto";
import type { RateLimitStore } from "../application/ports";

interface Options {
  timeWindow?: number;
  routeInfo?: { method?: string | string[]; url?: string };
}

export const rateLimitKey = (scope: string, identity: string): string =>
  createHash("sha256").update(`${scope}\0${identity}`).digest("hex");

// Each instance uses the same route namespace and an atomic database counter.
// No raw IP, email or bearer token is persisted in the rate-limit table.
export const sharedRateLimitStore = (repository: RateLimitStore) => class SharedStore {
  constructor(private readonly options: Options = {}) {}

  incr(key: string, callback: (error: Error | null, result?: { current: number; ttl: number }) => void,
    timeWindow?: number): void {
    const route = this.options.routeInfo;
    const scope = route?.url ? `${route.method}:${route.url}` : "global";
    void repository.consumeRateLimit(rateLimitKey(scope, key), timeWindow ?? this.options.timeWindow ?? 60000)
      .then((result) => callback(null, result), () => callback(new Error("Rate limit storage unavailable")));
  }

  child(options: object): SharedStore { return new SharedStore(options as Options); }
};
