import AsyncStorage from '@react-native-async-storage/async-storage';

import { MAX_KG, MAX_QTY, stepKg } from '../limits';
import { CART_STORAGE_KEY, toCartItems, useCartStore } from '../store';

jest.mock('@react-native-async-storage/async-storage', () =>
  jest.requireActual('@react-native-async-storage/async-storage/jest/async-storage-mock'),
);

const large = { product_id: 'whole', size_id: 'large', qty: 1, add_on_ids: ['chop'] };
const chopped = { product_id: 'chopped', kg: 2.5 };
const store = () => useCartStore.getState();

beforeEach(() => {
  store().clear();
});

describe('cart store', () => {
  it('adds size and kilo lines', () => {
    store().addLine(large);
    store().addLine(chopped);
    expect(store().lines).toHaveLength(2);
  });

  it('merges the same size and add-ons, in any add-on order', () => {
    store().addLine({ ...large, add_on_ids: ['a', 'b'] });
    store().addLine({ ...large, qty: 2, add_on_ids: ['b', 'a'] });
    expect(store().lines).toHaveLength(1);
    expect(store().lines[0]).toMatchObject({ qty: 3 });
  });

  it('keeps the same size with different add-ons apart', () => {
    store().addLine(large);
    store().addLine({ ...large, add_on_ids: [] });
    expect(store().lines).toHaveLength(2);
  });

  it('merges kilo lines of the same product', () => {
    store().addLine(chopped);
    store().addLine({ ...chopped, kg: 1.5 });
    expect(store().lines).toHaveLength(1);
    expect(store().lines[0]).toMatchObject({ kg: 4 });
  });

  it('stops merged lines at the limits', () => {
    store().addLine({ ...large, qty: MAX_QTY });
    store().addLine(large);
    store().addLine({ ...chopped, kg: MAX_KG });
    store().addLine(chopped);
    expect(store().lines[0]).toMatchObject({ qty: MAX_QTY });
    expect(store().lines[1]).toMatchObject({ kg: MAX_KG });
  });

  it('changes and removes lines', () => {
    store().addLine(large);
    store().addLine(chopped);
    const [sizeLine, kgLine] = store().lines;
    store().setQty(sizeLine.id, 4);
    store().setKg(kgLine.id, 3);
    expect(store().lines[0]).toMatchObject({ qty: 4 });
    expect(store().lines[1]).toMatchObject({ kg: 3 });
    store().removeLine(sizeLine.id);
    expect(store().lines).toHaveLength(1);
  });

  it('keeps no prices, and sends only what quote_cart expects', () => {
    store().addLine(large);
    store().addLine(chopped);
    expect(JSON.stringify(store().lines)).not.toMatch(/price|total/);
    expect(toCartItems(store().lines)).toEqual([large, chopped]);
  });

  it('survives an app restart', async () => {
    store().addLine(chopped);
    await new Promise((resolve) => setTimeout(resolve, 0));
    const saved = await AsyncStorage.getItem(CART_STORAGE_KEY);
    expect(saved).toContain('chopped');

    // Emptying the store also saves, so put the saved copy back, as a restart would find it.
    useCartStore.setState({ lines: [] });
    await AsyncStorage.setItem(CART_STORAGE_KEY, saved as string);
    await useCartStore.persist.rehydrate();
    expect(store().lines).toHaveLength(1);
  });
});

describe('stepKg', () => {
  const rules = { min: 1, step: 0.5, max: 50 };

  it('moves by the step', () => {
    expect(stepKg(2.5, 1, rules)).toBe(3);
    expect(stepKg(2.5, -1, rules)).toBe(2);
  });

  it('stays inside the limits', () => {
    expect(stepKg(1, -1, rules)).toBe(1);
    expect(stepKg(50, 1, rules)).toBe(50);
  });

  it('has no floating point drift', () => {
    expect(stepKg(0.1, 1, { min: 0.1, step: 0.2, max: 50 })).toBe(0.3);
  });
});
