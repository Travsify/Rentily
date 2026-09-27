import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

function getAuthoritativeServiceKey(): string {
  const envKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_KEY;
  if (envKey && envKey.startsWith('eyJ') && envKey.includes('.')) {
    try {
      const payload = JSON.parse(Buffer.from(envKey.split('.')[1], 'base64').toString());
      if (payload.role === 'service_role') return envKey;
    } catch (_) {}
  }
  if (!envKey) {
    console.warn('[SECURITY WARNING] Neither SUPABASE_SERVICE_ROLE_KEY nor SUPABASE_KEY is set in environment.');
  }
  return envKey || '';
}

let supabaseUrl = process.env.SUPABASE_URL || 'https://zuxvxuqxomsxgiljykzj.supabase.co';
let supabaseKey = getAuthoritativeServiceKey();

export const isSupabaseConfigured = () => {
  return Boolean(
    supabaseUrl && 
    supabaseUrl.startsWith('https://') && 
    supabaseKey && 
    supabaseKey.length > 20
  );
};

export let supabase = isSupabaseConfigured()
  ? createClient(supabaseUrl, supabaseKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    })
  : null;

export function reconfigureSupabase(url: string, key: string): boolean {
  if (url && url.startsWith('https://') && key && key.length > 20) {
    supabaseUrl = url;
    supabaseKey = key;
    supabase = createClient(url, key, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    });
    return true;
  }
  return false;
}
