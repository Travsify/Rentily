const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const SUPABASE_URL = process.env.VITE_SUPABASE_URL || process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.VITE_SUPABASE_ANON_KEY;

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function findInProfiles() {
  const bvn = '22322329511';
  const nin = '65973604556';

  console.log('Searching in profiles table...');
  const { data: profiles, error } = await supabase
    .from('profiles')
    .select('*');

  if (error) {
    console.error('Error querying profiles:', error);
    return;
  }

  console.log(`Total profiles found: ${profiles?.length || 0}`);
  
  // Search for matching BVN or NIN or recent profiles
  const match = profiles?.filter(p => 
    p.bvn === bvn || 
    p.nin_number === nin || 
    JSON.stringify(p).includes(bvn) || 
    JSON.stringify(p).includes(nin)
  );

  console.log('Matching profiles:', match);

  if (!match || match.length === 0) {
    console.log('Recent 10 profiles:');
    profiles?.slice(-10).forEach(p => {
      console.log(`- ${p.email} | Name: ${p.full_name} | Role: ${p.role} | Verified: ${p.is_verified} | BVN: ${p.bvn} | NIN: ${p.nin_number}`);
    });
  }
}

findInProfiles().catch(console.error);
