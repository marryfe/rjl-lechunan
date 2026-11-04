import AsyncStorage from '@react-native-async-storage/async-storage';
import { useEffect, useState } from 'react';
import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';

import type { CartItem, CartKgItem, CartSizeItem } from '@/types/api';

import { MAX_KG, MAX_QTY } from './limits';

export const CART_STORAGE_KEY = 'rjl-cart';

// Lines hold ids and amounts only. Prices always come from quote_cart.
export type CartLine = CartItem & { id: string };

type CartState = {
  lines: CartLine[];
  addLine: (item: CartItem) => void;
  setQty: (id: string, qty: number) => void;
  setKg: (id: string, kg: number) => void;
  removeLine: (id: string) => void;
  clear: () => void;
};

export function isKgLine(item: CartItem): item is CartKgItem {
  return 'kg' in item;
}

function lineId(item: CartItem): string {
  if (isKgLine(item)) return `kg:${item.product_id}`;
  const addOns = [...(item.add_on_ids ?? [])].sort().join(',');
  return `size:${item.size_id}:${addOns}`;
}

function merge(line: CartLine, item: CartItem): CartLine {
  if (isKgLine(line)) {
    return { ...line, kg: Math.min(MAX_KG, line.kg + (item as CartKgItem).kg) };
  }
  return { ...line, qty: Math.min(MAX_QTY, line.qty + (item as CartSizeItem).qty) };
}

export const useCartStore = create<CartState>()(
  persist(
    (set) => ({
      lines: [],
      addLine: (item) =>
        set(({ lines }) => {
          const id = lineId(item);
          return lines.some((line) => line.id === id)
            ? { lines: lines.map((line) => (line.id === id ? merge(line, item) : line)) }
            : { lines: [...lines, { ...item, id }] };
        }),
      setQty: (id, qty) =>
        set(({ lines }) => ({
          lines: lines.map((line) => (line.id === id ? { ...line, qty } : line)),
        })),
      setKg: (id, kg) =>
        set(({ lines }) => ({
          lines: lines.map((line) => (line.id === id ? { ...line, kg } : line)),
        })),
      removeLine: (id) => set(({ lines }) => ({ lines: lines.filter((line) => line.id !== id) })),
      clear: () => set({ lines: [] }),
    }),
    {
      name: CART_STORAGE_KEY,
      storage: createJSONStorage(() => AsyncStorage),
      partialize: ({ lines }) => ({ lines }),
    },
  ),
);

export function toCartItems(lines: CartLine[]): CartItem[] {
  return lines.map(({ id: _id, ...item }) => item);
}

/** False until the saved cart has loaded, so an empty cart doesn't flash on screen. */
export function useCartHydrated(): boolean {
  const [hydrated, setHydrated] = useState(() => useCartStore.persist.hasHydrated());

  useEffect(() => useCartStore.persist.onFinishHydration(() => setHydrated(true)), []);

  return hydrated;
}
