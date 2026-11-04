import { useQuery } from '@tanstack/react-query';

import { supabase } from '@/lib/supabase';

import { keys } from './keys';

async function fetchStoreName(): Promise<string> {
  const { data, error } = await supabase.from('settings').select('store_name').eq('id', 1).single();
  if (error) throw new Error(error.message);
  return data.store_name;
}

export function useStoreName() {
  return useQuery({ queryKey: keys.storeName, queryFn: fetchStoreName });
}
