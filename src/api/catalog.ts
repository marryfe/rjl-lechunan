import { keepPreviousData, useQuery } from '@tanstack/react-query';

import { supabase } from '@/lib/supabase';
import type {
  AvailabilityDay,
  CartItem,
  FreebieRule,
  FulfillmentType,
  MenuProduct,
  Quote,
  ShopInfo,
} from '@/types/api';

import { keys } from './keys';
import { unwrap } from './result';

const PHOTO_BUCKET = 'product-photos';

async function fetchShopInfo(): Promise<ShopInfo> {
  return unwrap(
    await supabase
      .from('settings')
      .select('store_name, contact_mobile, messenger_url, pickup_address')
      .eq('id', 1)
      .single(),
  );
}

export function useShopInfo() {
  return useQuery({ queryKey: keys.shopInfo, queryFn: fetchShopInfo });
}

export type Menu = { products: MenuProduct[]; rules: FreebieRule[] };

async function fetchMenu(): Promise<Menu> {
  const [products, rules] = await Promise.all([
    supabase
      .from('products')
      .select(
        `id, name, description, photo_path, sell_type, price_per_kg, min_kg, kg_step, is_active, sort_order,
         categories (id, name, sort_order),
         product_sizes (id, name, approx_weight_kg, serves, price, is_active, sort_order),
         add_ons (id, name, price, is_active)`,
      )
      .eq('is_active', true),
    supabase
      .from('freebie_rules')
      .select('id, name, trigger, size_id, start_date, end_date, is_active')
      .eq('is_active', true),
  ]);

  // Signed-in staff can read inactive rows too, so these are filtered for everyone.
  return {
    products: unwrap<MenuProduct[]>(products).map((product) => ({
      ...product,
      product_sizes: product.product_sizes
        .filter((size) => size.is_active)
        .sort((a, b) => a.sort_order - b.sort_order),
      add_ons: product.add_ons.filter((addOn) => addOn.is_active),
    })),
    rules: unwrap<FreebieRule[]>(rules),
  };
}

export function useMenu() {
  return useQuery({ queryKey: keys.menu, queryFn: fetchMenu });
}

export function useProduct(id: string) {
  return useQuery({
    queryKey: keys.menu,
    queryFn: fetchMenu,
    select: (menu) => menu.products.find((product) => product.id === id) ?? null,
  });
}

export function photoUrl(path: string): string {
  return supabase.storage.from(PHOTO_BUCKET).getPublicUrl(path).data.publicUrl;
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
    // Keeps the last price on screen while the new one loads, so totals don't flash.
    placeholderData: keepPreviousData,
  });
}
