// Mirrors the checks in quote_cart so steppers stop at the right place.
// The database still enforces these; they are not prices or catalog data.
export const MIN_QTY = 1;
export const MAX_QTY = 10;
export const MAX_KG = 50;

type KgRules = { min: number; step: number; max: number };

/** The next weight up (1) or down (-1), kept inside the limits. */
export function stepKg(kg: number, direction: 1 | -1, { min, step, max }: KgRules): number {
  const next = Math.round((kg + direction * step) * 100) / 100;
  return Math.min(max, Math.max(min, next));
}
