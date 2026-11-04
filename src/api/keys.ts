import type { CartItem, FulfillmentType } from '@/types/api';

export const keys = {
  storeName: ['settings', 'store_name'] as const,
  availability: (from: string, to: string) => ['availability', from, to] as const,
  quote: (items: CartItem[], fulfillment: FulfillmentType, date: string | null) =>
    ['quote', items, fulfillment, date] as const,
  publicOrder: (orderNo: string, mobile: string) => ['public-order', orderNo, mobile] as const,

  // Everything staff or admin screens show. Order and stock changes refresh these whole groups.
  staff: ['staff'] as const,
  admin: ['admin'] as const,
  prepSheet: (date: string) => ['staff', 'prep-sheet', date] as const,
  dashboard: (date: string) => ['admin', 'dashboard', date] as const,
  salesReport: (from: string, to: string) => ['admin', 'sales-report', from, to] as const,
};
