import { z } from "zod";
import { authCredentialsSchema } from "./schemas";

export const servicePolicyVersion = "tw-service-age-15-in-app-v2";
export const providerAiPolicyVersion = "liangjie-ai-v2";
export const ageBands = ["under-15", "15-17", "18-plus"] as const;
export type AgeBand = (typeof ageBands)[number];
export const ageDeclarationSchema = z.object({
  ageBand: z.enum(ageBands),
  policyVersion: z.string().trim().min(1).max(120),
  accepted: z.literal(true),
});
export type AgeDeclarationInput = z.infer<typeof ageDeclarationSchema>;
export const registrationSchema = authCredentialsSchema.extend({ ageDeclaration: ageDeclarationSchema.optional() });
export const guardianRequestSchema = z.object({ email: authCredentialsSchema.shape.email });
export const guardianConfirmationSchema = z.object({
  token: z.string().regex(/^[A-Za-z0-9_-]{43}$/),
  policyVersion: z.string().trim().min(1).max(120),
  adult: z.literal(true), legalGuardian: z.literal(true), accepted: z.literal(true),
});
export const guardianWithdrawalSchema = z.object({ token: guardianConfirmationSchema.shape.token });
export const inAppGuardianConsentSchema = guardianConfirmationSchema.omit({ token: true }).strict();
export const versionedAiConsentSchema = z.object({ granted: z.boolean(), policyVersion: z.string().trim().min(1).max(120).optional() });
export interface EligibilityRecord {
  userId: string; ageBand: AgeBand; policyVersion: string; declaredAt: string;
  guardianStatus: "not-required" | "pending" | "approved" | "withdrawn";
  guardianEmail: string | null; guardianApprovedAt: string | null; guardianWithdrawnAt: string | null;
  revision: number; aiConsentRevision: number | null;
  guardianConsentMethod?: "email" | "in-app" | null;
}
export interface GuardianActionToken {
  tokenHash: string; userId: string; purpose: "guardian-approve" | "guardian-withdraw";
  policyVersion: string; guardianEmail: string; revision: number; expiresAt: string;
}
export interface ServiceEligibility {
  status: "declaration-required" | "under-age" | "guardian-required" | "eligible" | "guardian-withdrawn";
  ageBand: AgeBand | null; policyVersion: string | null; currentPolicyVersion: string; declaredAt: string | null;
  guardianStatus: EligibilityRecord["guardianStatus"] | null;
  guardianApprovedAt: string | null; guardianWithdrawnAt: string | null; canWrite: boolean;
  guardianConsentMethod: "email" | "in-app" | null;
}
