import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

const DEFAULT_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp1eHZ4dXF4b21zeGdpbGp5a3pqIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODA4MDM1MywiZXhwIjoyMTAzNjU2MzUzfQ.otHBuZUThdSaLdc_WxlIXClfFnSci30i0_0VbZF5doQ';

let supabaseUrl = process.env.SUPABASE_URL || 'https://zuxvxuqxomsxgiljykzj.supabase.co';
let supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || DEFAULT_SERVICE_ROLE_KEY;

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
