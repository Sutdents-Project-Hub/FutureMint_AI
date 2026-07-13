export class DomainError extends Error {
  constructor(
    public readonly code: string,
    message: string,
    public readonly status: number,
    public readonly retryable = false,
    public readonly fieldErrors?: Record<string, string>,
  ) {
    super(message);
    this.name = "DomainError";
  }
}
