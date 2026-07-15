import type { PublicAccount } from "../contracts/models";
import { DomainError } from "../contracts/errors";
import { getRuntime, type Runtime } from "./runtime";

interface HeaderRequest {
  headers: { authorization?: string };
}

export const bearerToken = (request: HeaderRequest): string => {
  const value = request.headers.authorization;
  const token = value?.match(/^Bearer ([A-Za-z0-9_-]{43})$/)?.[1];
  if (!token) {
    throw new DomainError("unauthorized", "請先登入後再繼續。", 401);
  }
  return token;
};

export const requireAuthenticatedUser = async (
  request: HeaderRequest,
  runtime: Runtime = getRuntime(),
): Promise<PublicAccount> => runtime.authService.authenticate(bearerToken(request));
