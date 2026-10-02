import type { EmailTemplate } from "./templates";

export type EmailFailureCategory = "transient" | "permanent" | "ambiguous";
export type EmailAcceptance = Readonly<{ accepted: true; providerReference: string }>;
export type EmailFailure = Readonly<{ accepted: false; category: EmailFailureCategory }>;
export type EmailRequest = Readonly<{ to: string; idempotencyKey: string; template: EmailTemplate }>;
export interface EmailProvider {
  /** Required before retrying an ambiguous/crashed accepted request. */
  readonly supportsIdempotency: boolean;
  send(request: EmailRequest): Promise<EmailAcceptance | EmailFailure>;
}
/** No provider, SMTP setting, production credential or network send is selected. */
export function configuredEmailProvider(): EmailProvider | null { return null; }

/** Synthetic acceptance adapter, deliberately limited to reserved invalid domains.
 * It supports deterministic retries without sending email or accessing secrets.
 */
export class SyntheticEmailProvider implements EmailProvider {
  readonly supportsIdempotency = true;
  private readonly accepted = new Map<string, EmailAcceptance>();
  private readonly outcomes: EmailFailureCategory[];
  attempts = 0;
  acceptedCount = 0;
  constructor(outcomes: readonly EmailFailureCategory[] = []) { this.outcomes = [...outcomes]; }
  async send(request: EmailRequest): Promise<EmailAcceptance | EmailFailure> {
    if (!/^[^\s@]+@[^\s@]+\.invalid$/.test(request.to)) throw new Error("Synthetic delivery requires a reserved invalid destination.");
    this.attempts++;
    const prior = this.accepted.get(request.idempotencyKey);
    if (prior) return prior;
    const outcome = this.outcomes.shift();
    if (outcome) return { accepted: false, category: outcome };
    const result = { accepted: true as const, providerReference: `synthetic-${++this.acceptedCount}` };
    this.accepted.set(request.idempotencyKey, result);
    return result;
  }
}
