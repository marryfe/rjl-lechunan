import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient } from '@supabase/supabase-js';
import Constants from 'expo-constants';
import { AppState, Platform } from 'react-native';

import { resolveSupabaseUrl } from './supabase-url';

const url = process.env.EXPO_PUBLIC_SUPABASE_URL;
const anonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;

if (!url || !anonKey) {
  throw new Error(
    'Missing EXPO_PUBLIC_SUPABASE_URL or EXPO_PUBLIC_SUPABASE_ANON_KEY. Copy .env.example to .env and fill it in.',
  );
}

const isNative = Platform.OS !== 'web';
const devHostUri = isNative && __DEV__ ? Constants.expoConfig?.hostUri : null;

export const supabase = createClient(resolveSupabaseUrl(url, devHostUri), anonKey, {
  auth: {
    // Web falls back to localStorage, the supabase-js default.
    storage: isNative ? AsyncStorage : undefined,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: !isNative,
  },
});

if (isNative) {
  // Native apps have no tab-visibility event, so refresh the session only while in the foreground.
  AppState.addEventListener('change', (state) => {
    if (state === 'active') {
      supabase.auth.startAutoRefresh();
    } else {
      supabase.auth.stopAutoRefresh();
    }
  });
}
