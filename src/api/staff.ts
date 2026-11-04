import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import { supabase } from '@/lib/supabase';
import type { OrderStatus, PaymentMethod, PaymentType, PrepSheet } from '@/types/api';

import { keys } from './keys';
import { unwrap } from './result';

function useStaffMutation<Input>(mutationFn: (input: Input) => Promise<void>) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn,
    onSuccess: () =>
      Promise.all([
        queryClient.invalidateQueries({ queryKey: keys.staff }),
        queryClient.invalidateQueries({ queryKey: keys.admin }),
      ]),
  });
}

type StatusChange = { orderId: string; to: OrderStatus; note?: string };

export async function setOrderStatus({ orderId, to, note }: StatusChange) {
  unwrap(await supabase.rpc('set_order_status', { p_order_id: orderId, p_to: to, p_note: note }));
}

export function useSetOrderStatus() {
  return useStaffMutation(setOrderStatus);
}

type Payment = {
  orderId: string;
  type: PaymentType;
  amount: number;
  method: PaymentMethod;
  reference?: string;
  note?: string;
};

export async function recordPayment({ orderId, type, amount, method, reference, note }: Payment) {
  unwrap(
    await supabase.rpc('record_payment', {
      p_order_id: orderId,
      p_type: type,
      p_amount: amount,
      p_method: method,
      p_reference: reference,
      p_note: note,
    }),
  );
}

export function useRecordPayment() {
  return useStaffMutation(recordPayment);
}

type StaffMessage = { orderId: string; body: string };

export async function postStaffMessage({ orderId, body }: StaffMessage) {
  unwrap(await supabase.rpc('post_staff_message', { p_order_id: orderId, p_body: body }));
}

export function usePostStaffMessage() {
  return useStaffMutation(postStaffMessage);
}

export async function getPrepSheet(date: string): Promise<PrepSheet> {
  return unwrap(await supabase.rpc('get_prep_sheet', { p_date: date }));
}

export function usePrepSheet(date: string) {
  return useQuery({ queryKey: keys.prepSheet(date), queryFn: () => getPrepSheet(date) });
}
