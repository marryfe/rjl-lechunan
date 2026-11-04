import { useQuery } from '@tanstack/react-query';

import { supabase } from '@/lib/supabase';
import type { AvailabilityDay, CartItem, FulfillmentType, Quote } from '@/types/api';

import { keys } from './keys';
import { unwrap } from './result';

async function fetchStoreName(): Promise<string> {
  const result = await supabase.from('settings').select('store_name').eq('id', 1).single();
  return unwrap<{ store_name: string }>(result).store_name;
}

export function useStoreName() {
  return useQuery({ queryKey: keys.storeName, queryFn: fetchStoreName });
}

export async function getAvailability(from: string, to: string): Promise<AvailabilityDay[]> {
  return unwrap(await supabase.rpc('get_availability', { p_from: from, p_to: to }));
}

export function useAvailability(from: string, to: string) {
  return useQuery({
    queryKey: keys.availability(from, to),
    queryFn: () => getAvailability(from, to),
  });
}

export async function quoteCart(
  items: CartItem[],
  fulfillment: FulfillmentType,
  date: string | null,
): Promise<Quote> {
  return unwrap(
    await supabase.rpc('quote_cart', {
      p_items: items,
      p_fulfillment: fulfillment,
      p_date: date ?? undefined,
    }),
  );
}

export function useQuote(items: CartItem[], fulfillment: FulfillmentType, date: string | null) {
  return useQuery({
    queryKey: keys.quote(items, fulfillment, date),
    queryFn: () => quoteCart(items, fulfillment, date),
    enabled: items.length > 0,
  });
}
