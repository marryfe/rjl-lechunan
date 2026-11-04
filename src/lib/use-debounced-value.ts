import { useEffect, useState } from 'react';

export const QUOTE_DEBOUNCE_MS = 300;

/** Returns the value once it has stopped changing for the delay. */
export function useDebouncedValue<T>(value: T, delayMs = QUOTE_DEBOUNCE_MS): T {
  const [debounced, setDebounced] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delayMs);
    return () => clearTimeout(timer);
  }, [value, delayMs]);

  return debounced;
}
