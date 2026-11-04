import { ApiError } from '@/lib/errors';

type Result = { data: unknown; error: { message: string } | null };

/**
 * Throws a Supabase error as an ApiError, otherwise returns the data. The type is the caller's
 * word for what the function returns, because generated types only say `Json`.
 */
export function unwrap<T>({ data, error }: Result): T {
  if (error) throw new ApiError(error.message);
  return data as T;
}
