import type { FreebieRule, MenuCategory, MenuProduct } from '@/types/api';

export type MenuSection = { category: MenuCategory | null; products: MenuProduct[] };

/** Groups products by category. Products without a category come last. */
export function toSections(products: MenuProduct[]): MenuSection[] {
  const sections = new Map<string | null, MenuSection>();
  for (const product of products) {
    const key = product.categories?.id ?? null;
    const section = sections.get(key) ?? { category: product.categories, products: [] };
    section.products.push(product);
    sections.set(key, section);
  }
  return [...sections.values()]
    .map((section) => ({
      ...section,
      products: [...section.products].sort((a, b) => a.sort_order - b.sort_order),
    }))
    .sort(
      (a, b) =>
        (a.category?.sort_order ?? Number.MAX_SAFE_INTEGER) -
        (b.category?.sort_order ?? Number.MAX_SAFE_INTEGER),
    );
}

/** The lowest price among the product's sizes, or null if it has none. */
export function fromPrice(product: MenuProduct): number | null {
  const prices = product.product_sizes.map((size) => size.price);
  return prices.length ? Math.min(...prices) : null;
}

/** Rules that can still apply: active and not past their end date. */
export function currentRules(rules: FreebieRule[], today: string): FreebieRule[] {
  return rules.filter((rule) => rule.is_active && (!rule.end_date || rule.end_date >= today));
}

export function hasFreebie(product: MenuProduct, rules: FreebieRule[]): boolean {
  return rules.some((rule) => {
    if (rule.trigger === 'size') {
      return product.product_sizes.some((size) => size.id === rule.size_id);
    }
    return rule.trigger === 'kg_threshold' && product.sell_type === 'by_kg';
  });
}
