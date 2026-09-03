import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://zuxvxuqxomsxgiljykzj.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp1eHZ4dXF4b21zeGdpbGp5a3pqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgwODAzNTMsImV4cCI6MjEwMzY1NjM1M30.4g6-vT5q7Oa6kQ-3_M76Zk-r8S26u_gM69W4G_7w6A8';

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
