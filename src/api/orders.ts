import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import { supabase } from '@/lib/supabase';
import type { PlacedOrder, PlaceOrderInput, PublicOrder } from '@/types/api';

import { keys } from './keys';
import { unwrap } from './result';

const TRACKING_REFRESH_MS = 30_000;

export async function placeOrder(order: PlaceOrderInput): Promise<PlacedOrder> {
  return unwrap(await supabase.rpc('place_order', { p_order: order }));
}

export function usePlaceOrder() {
  return useMutation({ mutationFn: placeOrder });
}

/** Null when the order number and mobile number don't match. */
export async function getPublicOrder(orderNo: string, mobile: string): Promise<PublicOrder | null> {
  return unwrap(await supabase.rpc('get_public_order', { p_order_no: orderNo, p_mobile: mobile }));
}

export function usePublicOrder(orderNo: string, mobile: string) {
  return useQuery({
    queryKey: keys.publicOrder(orderNo, mobile),
    queryFn: () => getPublicOrder(orderNo, mobile),
    enabled: Boolean(orderNo && mobile),
    refetchInterval: TRACKING_REFRESH_MS,
  });
}

type CustomerMessage = { orderNo: string; mobile: string; body: string };

export async function postCustomerMessage({ orderNo, mobile, body }: CustomerMessage) {
  unwrap(
    await supabase.rpc('post_customer_message', {
      p_order_no: orderNo,
      p_mobile: mobile,
      p_body: body,
    }),
  );
}

export function usePostCustomerMessage() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: postCustomerMessage,
    onSuccess: (_data, { orderNo, mobile }) =>
      queryClient.invalidateQueries({ queryKey: keys.publicOrder(orderNo, mobile) }),
  });
}
