const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const SUPABASE_URL = process.env.VITE_SUPABASE_URL || process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.VITE_SUPABASE_ANON_KEY;
const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function verifyAndActivatePartner() {
  const email = 'olayiwolashakirullah@gmail.com';
  const bvn = '22322329511';
  const nin = '65973604556';
  const fullName = 'Shakirullah Olayiwola';
  const accountNumber = '9902329511';
  const bankName = 'Rentilly Escrow';

  console.log(`Activating partner ${email} in Supabase...`);

  // 1. Update profiles table
  const { error: pErr } = await supabase
    .from('profiles')
    .update({
      full_name: fullName,
      is_verified: true,
      bvn_verified: true,
      nin_number: nin,
      account_number: accountNumber,
      bank_name: bankName,
      updated_at: new Date().toISOString()
    })
    .eq('email', email);

  console.log('Profiles update result:', pErr ? pErr.message : 'SUCCESS ✅');

  // 2. Update auth_ config
  const { data: existingAuth } = await supabase
    .from('system_configs')
    .select('data')
    .eq('id', `auth_${email}`)
    .maybeSingle();

  const authData = existingAuth?.data || {};
  authData.fullName = fullName;
  authData.isVerified = true;
  authData.bvnVerified = true;
  authData.bvn = bvn;
  authData.ninNumber = nin;
  authData.accountNumber = accountNumber;
  authData.bankName = bankName;
  authData.rekycRequired = false;
  authData.dob = '1978-09-01';

  await supabase.from('system_configs').upsert({
    id: `auth_${email}`,
    data: authData
  });

  // 3. Update rekyc_ config
  await supabase.from('system_configs').upsert({
    id: `rekyc_${email}`,
    data: { rekycRequired: false, accountNumber, bankName, updatedAt: new Date().toISOString() }
  });

  console.log(`✅ Partner ${email} is now 100% verified with dedicated account ${accountNumber} (${bankName})!`);
}

verifyAndActivatePartner().catch(console.error);
