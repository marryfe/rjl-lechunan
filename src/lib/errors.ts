import { strings } from './strings';

export type ErrorCode = keyof typeof strings.errors;

// For these codes the text after the colon helps the reader, such as which item is short.
const CODES_WITH_DETAIL: readonly ErrorCode[] = [
  'INVALID_KG',
  'NOT_ENOUGH_STOCK',
  'STOCK_BELOW_RESERVED',
];

/** An error from a Postgres function, whose message reads "CODE: detail". */
export class ApiError extends Error {
  readonly code: ErrorCode | null;
  readonly detail: string | null;

  constructor(message: string) {
    super(message);
    this.name = 'ApiError';
    const match = /^([A-Z_]+)(?:: *(.*))?$/s.exec(message);
    const code = match?.[1];
    this.code = code && code in strings.errors ? (code as ErrorCode) : null;
    this.detail = this.code ? (match?.[2] ?? null) : null;
  }
}

/** Text that is safe to show a customer or staff member. Never shows a raw database error. */
export function friendlyError(error: unknown): string {
  if (!(error instanceof ApiError) || !error.code) return strings.errors.UNKNOWN;
  const text = strings.errors[error.code];
  return CODES_WITH_DETAIL.includes(error.code) && error.detail
    ? `${text} (${error.detail})`
    : text;
}
