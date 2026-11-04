import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import { supabase } from '@/lib/supabase';
import type { Dashboard, MovementReason, SalesReport, UserRole } from '@/types/api';

import { keys } from './keys';
import { unwrap } from './result';

function useAdminMutation<Input>(mutationFn: (input: Input) => Promise<void>) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: keys.admin }),
  });
}

type StockChange = { itemId: string; change: number; reason: MovementReason; note?: string };

export async function adjustStock({ itemId, change, reason, note }: StockChange) {
  unwrap(
    await supabase.rpc('adjust_stock', {
      p_item_id: itemId,
      p_change: change,
      p_reason: reason,
      p_note: note,
    }),
  );
}

export function useAdjustStock() {
  return useAdminMutation(adjustStock);
}

type StockCount = { itemId: string; counted: number; note?: string };

export async function setStockCount({ itemId, counted, note }: StockCount) {
  unwrap(
    await supabase.rpc('set_stock_count', {
      p_item_id: itemId,
      p_counted: counted,
      p_note: note,
    }),
  );
}

export function useSetStockCount() {
  return useAdminMutation(setStockCount);
}

export async function getDashboard(date: string): Promise<Dashboard> {
  return unwrap(await supabase.rpc('get_dashboard', { p_date: date }));
}

export function useDashboard(date: string) {
  return useQuery({ queryKey: keys.dashboard(date), queryFn: () => getDashboard(date) });
}

export async function getSalesReport(from: string, to: string): Promise<SalesReport> {
  return unwrap(await supabase.rpc('report_sales', { p_from: from, p_to: to }));
}

export function useSalesReport(from: string, to: string) {
  return useQuery({
    queryKey: keys.salesReport(from, to),
    queryFn: () => getSalesReport(from, to),
  });
}

type StaffUpdate = { userId: string; fullName: string; role: UserRole; isActive: boolean };

export async function setStaff({ userId, fullName, role, isActive }: StaffUpdate) {
  unwrap(
    await supabase.rpc('set_staff', {
      p_user_id: userId,
      p_full_name: fullName,
      p_role: role,
      p_is_active: isActive,
    }),
  );
}

export function useSetStaff() {
  return useAdminMutation(setStaff);
}
