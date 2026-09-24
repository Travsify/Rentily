const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const MAPLERAD_API_KEY = process.env.MAPLERAD_API_KEY || process.env.MAPLERAD_SECRET_KEY;
const MAPLERAD_BASE_URL = 'https://sandbox.api.maplerad.com/v1'; // or live

console.log('Maplerad API Key configured:', !!MAPLERAD_API_KEY);

async function testMapleradEnroll() {
  const email = 'olayiwolashakirullah@gmail.com';
  const bvn = '22322329511';
  const nin = '65973604556';
  const dob = '01-09-1978'; // DD-MM-YYYY

  // Let's test Maplerad enrollment / customer endpoint
  const headers = {
    'Authorization': `Bearer ${MAPLERAD_API_KEY}`,
    'Accept': 'application/json',
    'Content-Type': 'application/json'
  };

  console.log('Checking existing Maplerad customers...');
  const res = await fetch(`https://api.maplerad.com/v1/customers?page=1&page_size=50`, { headers });
  const data = await res.json();
  console.log('Maplerad customers search response:', data?.status, data?.message);

  if (data?.data) {
    const match = data.data.find(c => c.email?.toLowerCase() === email);
    console.log('Matching customer on Maplerad:', match);
  }

  // Let's check Identitypass BVN/NIN verification if configured
  const IDENTITYPASS_API_KEY = process.env.IDENTITYPASS_API_KEY || process.env.PREMBLY_API_KEY;
  console.log('Identitypass API Key configured:', !!IDENTITYPASS_API_KEY);
}

testMapleradEnroll().catch(console.error);
