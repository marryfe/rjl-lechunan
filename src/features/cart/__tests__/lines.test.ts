import type { MenuProduct } from '@/types/api';

import { describeLine, splitLines } from '../lines';
import type { CartLine } from '../store';

jest.mock('@react-native-async-storage/async-storage', () =>
  jest.requireActual('@react-native-async-storage/async-storage/jest/async-storage-mock'),
);

const whole: MenuProduct = {
  id: 'whole',
  name: 'Whole Lechon',
  description: null,
  photo_path: null,
  sell_type: 'by_size',
  price_per_kg: null,
  min_kg: 1,
  kg_step: 0.5,
  is_active: true,
  sort_order: 1,
  categories: null,
  product_sizes: [
    {
      id: 'large',
      name: 'Large',
      approx_weight_kg: 25,
      serves: null,
      price: 11500,
      is_active: true,
      sort_order: 1,
    },
  ],
  add_ons: [{ id: 'chop', name: 'Chopping service', price: 200, is_active: true }],
};

const chopped: MenuProduct = {
  ...whole,
  id: 'chopped',
  name: 'Chopped Lechon',
  sell_type: 'by_kg',
  price_per_kg: 750,
  min_kg: 1,
  kg_step: 0.5,
  product_sizes: [],
  add_ons: [],
};

const sizeLine: CartLine = {
  id: 'a',
  product_id: 'whole',
  size_id: 'large',
  qty: 1,
  add_on_ids: ['chop'],
};
const kgLine: CartLine = { id: 'b', product_id: 'chopped', kg: 2.5 };

describe('splitLines', () => {
  it('keeps lines still on the menu', () => {
    const { available, gone } = splitLines([sizeLine, kgLine], [whole, chopped]);
    expect(available).toEqual([sizeLine, kgLine]);
    expect(gone).toEqual([]);
  });

  it('sets aside a line whose product left the menu', () => {
    const { available, gone } = splitLines([sizeLine, kgLine], [whole]);
    expect(available).toEqual([sizeLine]);
    expect(gone).toEqual([kgLine]);
  });

  it('sets aside a line whose size is gone', () => {
    const { gone } = splitLines([sizeLine], [{ ...whole, product_sizes: [] }]);
    expect(gone).toEqual([sizeLine]);
  });

  it('sets aside a line whose add-on is gone', () => {
    const { gone } = splitLines([sizeLine], [{ ...whole, add_ons: [] }]);
    expect(gone).toEqual([sizeLine]);
  });

  it('sets aside a kilo line if the product now sells by size', () => {
    const { gone } = splitLines([kgLine], [{ ...chopped, sell_type: 'by_size' }]);
    expect(gone).toEqual([kgLine]);
  });

  it('sets aside a kilo line that no longer fits the minimum or step', () => {
    expect(splitLines([kgLine], [{ ...chopped, min_kg: 3 }]).gone).toEqual([kgLine]);
    expect(splitLines([kgLine], [{ ...chopped, kg_step: 1 }]).gone).toEqual([kgLine]);
  });
});

describe('describeLine', () => {
  it('names a size line with its add-ons', () => {
    expect(describeLine(sizeLine, [whole])).toEqual({
      name: 'Whole Lechon',
      detail: 'Large',
      addOns: ['Chopping service'],
      product: whole,
    });
  });

  it('names a kilo line', () => {
    expect(describeLine(kgLine, [chopped])).toMatchObject({ name: 'Chopped Lechon', addOns: [] });
  });

  it('copes with a line that left the menu', () => {
    expect(describeLine(kgLine, [])).toMatchObject({ name: null, product: null });
  });
});
