const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const SUPABASE_URL = process.env.VITE_SUPABASE_URL || process.env.SUPABASE_URL || 'https://yhgehscuhcddghikvhbd.supabase.co';
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InloZ2Voc2N1aGNkZGdoaWt2aGJkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDM1OTU0NDgsImV4cCI6MjA1OTE3MTQ0OH0.j-fR5g_hUffHj7wG278-u_B_11M7lR0N61d4qXN976s';

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function findPartner() {
  const bvn = '22322329511';
  const nin = '65973604556';

  console.log('Searching for partner with BVN/NIN...', { bvn, nin });

  const { data: byBvn, error: err1 } = await supabase
    .from('profiles')
    .select('*')
    .or(`bvn.eq.${bvn},nin_number.eq.${nin}`);

  if (byBvn && byBvn.length > 0) {
    console.log('Found profile by BVN/NIN:', JSON.stringify(byBvn, null, 2));
    return;
  }

  const { data: allUsers } = await supabase
    .from('profiles')
    .select('id, email, full_name, phone_number, bvn, nin_number, role, is_verified, account_number, bank_name')
    .limit(10);

  console.log('Sample profiles:', allUsers);
}

findPartner().catch(console.error);
