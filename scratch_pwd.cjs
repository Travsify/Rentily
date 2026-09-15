const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: '/var/www/rentilly/.env' });

const sb = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY);

async function check() {
  const { data } = await sb.from('system_configs').select('id, data').like('id', 'pwd_%');
  console.log('Password configs:', data);
}

check();
