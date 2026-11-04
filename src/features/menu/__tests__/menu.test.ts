import type { FreebieRule, MenuProduct } from '@/types/api';

import { currentRules, fromPrice, hasFreebie, toSections } from '../menu';

const size = (id: string, price: number) => ({
  id,
  name: id,
  approx_weight_kg: null,
  serves: null,
  price,
  is_active: true,
  sort_order: 0,
});

const product = (overrides: Partial<MenuProduct>): MenuProduct => ({
  id: 'p',
  name: 'Product',
  description: null,
  photo_path: null,
  sell_type: 'by_size',
  price_per_kg: null,
  min_kg: 1,
  kg_step: 0.5,
  is_active: true,
  sort_order: 0,
  categories: null,
  product_sizes: [],
  add_ons: [],
  ...overrides,
});

const rule = (overrides: Partial<FreebieRule>): FreebieRule => ({
  id: 'r',
  name: 'Rule',
  trigger: 'order_amount',
  size_id: null,
  start_date: null,
  end_date: null,
  is_active: true,
  ...overrides,
});

describe('toSections', () => {
  it('orders categories and products, with uncategorised items last', () => {
    const first = { id: 'a', name: 'First', sort_order: 1 };
    const second = { id: 'b', name: 'Second', sort_order: 2 };
    const sections = toSections([
      product({ id: 'loose' }),
      product({ id: 'b1', categories: second }),
      product({ id: 'a2', categories: first, sort_order: 2 }),
      product({ id: 'a1', categories: first, sort_order: 1 }),
    ]);
    expect(sections.map((section) => section.category?.name ?? null)).toEqual([
      'First',
      'Second',
      null,
    ]);
    expect(sections[0].products.map((item) => item.id)).toEqual(['a1', 'a2']);
  });
});

describe('fromPrice', () => {
  it('finds the lowest size price', () => {
    expect(fromPrice(product({ product_sizes: [size('l', 11500), size('s', 7500)] }))).toBe(7500);
  });

  it('is null without sizes', () => {
    expect(fromPrice(product({}))).toBeNull();
  });
});

describe('currentRules', () => {
  it('drops inactive and ended rules, and keeps today', () => {
    const rules = [
      rule({ id: 'open' }),
      rule({ id: 'off', is_active: false }),
      rule({ id: 'ended', end_date: '2026-11-04' }),
      rule({ id: 'today', end_date: '2026-11-05' }),
    ];
    expect(currentRules(rules, '2026-11-05').map((item) => item.id)).toEqual(['open', 'today']);
  });
});

describe('hasFreebie', () => {
  it('matches a size rule on the product with that size', () => {
    const whole = product({ product_sizes: [size('large', 11500)] });
    expect(hasFreebie(whole, [rule({ trigger: 'size', size_id: 'large' })])).toBe(true);
    expect(hasFreebie(whole, [rule({ trigger: 'size', size_id: 'other' })])).toBe(false);
  });

  it('matches a kilo rule on kilo products only', () => {
    const kiloRule = [rule({ trigger: 'kg_threshold' })];
    expect(hasFreebie(product({ sell_type: 'by_kg' }), kiloRule)).toBe(true);
    expect(hasFreebie(product({ sell_type: 'by_size' }), kiloRule)).toBe(false);
  });

  it('ignores whole-order rules, which target no product', () => {
    expect(hasFreebie(product({ sell_type: 'by_kg' }), [rule({})])).toBe(false);
  });
});
