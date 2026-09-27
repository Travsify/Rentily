import { createClient } from '@supabase/supabase-js';

const getEnvVar = (key: string, fallback: string): string => {
  try {
    if (typeof import.meta !== 'undefined' && import.meta.env && import.meta.env[key]) {
      return import.meta.env[key];
    }
  } catch (_) {}
  return fallback;
};

const SUPABASE_URL = getEnvVar('VITE_SUPABASE_URL', 'https://zuxvxuqxomsxgiljykzj.supabase.co');
const SUPABASE_ANON_KEY = getEnvVar('VITE_SUPABASE_ANON_KEY', 'sb_publishable_LiVL01tqjp7jQQZwxFTayQ_TrhSswA_');

export const supabaseClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true
  },
  realtime: {
    params: {
      eventsPerSecond: 10
    }
  }
});
