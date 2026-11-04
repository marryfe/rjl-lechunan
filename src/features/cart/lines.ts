import type { MenuProduct } from '@/types/api';

import { isKgLine, type CartLine } from './store';

function stepFits(kg: number, step: number): boolean {
  // In whole hundredths, so 2.5 / 0.5 isn't thrown off by floating point.
  return Math.round(kg * 100) % Math.round(step * 100) === 0;
}

function isAvailable(line: CartLine, products: MenuProduct[]): boolean {
  const product = products.find((item) => item.id === line.product_id);
  if (!product) return false;

  if (isKgLine(line)) {
    return (
      product.sell_type === 'by_kg' &&
      line.kg >= product.min_kg &&
      stepFits(line.kg, product.kg_step)
    );
  }

  return (
    product.product_sizes.some((size) => size.id === line.size_id) &&
    (line.add_on_ids ?? []).every((id) => product.add_ons.some((addOn) => addOn.id === id))
  );
}

/**
 * One item leaving the menu makes quote_cart refuse the whole cart, so saved lines are checked
 * against the menu first and only the available ones are quoted.
 */
export function splitLines(lines: CartLine[], products: MenuProduct[]) {
  return {
    available: lines.filter((line) => isAvailable(line, products)),
    gone: lines.filter((line) => !isAvailable(line, products)),
  };
}

export type LineDescription = {
  name: string | null;
  detail: string | null;
  addOns: string[];
  product: MenuProduct | null;
};

export function describeLine(line: CartLine, products: MenuProduct[]): LineDescription {
  const product = products.find((item) => item.id === line.product_id) ?? null;
  if (!product) return { name: null, detail: null, addOns: [], product: null };

  if (isKgLine(line)) return { name: product.name, detail: null, addOns: [], product };

  return {
    name: product.name,
    detail: product.product_sizes.find((size) => size.id === line.size_id)?.name ?? null,
    addOns: product.add_ons
      .filter((addOn) => line.add_on_ids?.includes(addOn.id))
      .map((addOn) => addOn.name),
    product,
  };
}
