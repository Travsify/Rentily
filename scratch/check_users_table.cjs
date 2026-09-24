const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const SUPABASE_URL = process.env.VITE_SUPABASE_URL || process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.VITE_SUPABASE_ANON_KEY;

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function findInUsers() {
  const bvn = '22322329511';
  const nin = '65973604556';

  console.log('Searching in users table with snake_case columns...');
  const { data: users, error } = await supabase
    .from('users')
    .select('id, email, full_name, bvn, nin_number, role, is_verified, account_number, bank_name, wallet_balance')
    .or(`bvn.eq.${bvn},nin_number.eq.${nin}`);

  console.log('Found user with matching BVN/NIN:', JSON.stringify(users, null, 2));

  if (!users || users.length === 0) {
    const { data: recent } = await supabase
      .from('users')
      .select('id, email, full_name, bvn, nin_number, role, is_verified, account_number, bank_name, created_at')
      .order('created_at', { ascending: false })
      .limit(10);
    console.log('Recent 10 users:', JSON.stringify(recent, null, 2));
  }
}

findInUsers().catch(console.error);
