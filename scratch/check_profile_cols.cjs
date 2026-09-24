const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const SUPABASE_URL = process.env.VITE_SUPABASE_URL || process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.VITE_SUPABASE_ANON_KEY;
const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function checkColumns() {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('email', 'olayiwolashakirullah@gmail.com')
    .single();

  console.log('User profile in Supabase:', data);
  console.log('Available columns in profiles:', Object.keys(data || {}));
}

checkColumns().catch(console.error);
