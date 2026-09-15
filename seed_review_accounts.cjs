const { createClient } = require('@supabase/supabase-js');
const crypto = require('crypto');
require('dotenv').config({ path: '/var/www/rentilly/.env' });

const sb = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY);

function hashPassword(password) {
  return crypto.createHash('sha256').update(password + '_rentilly_salt_2026').digest('hex');
}

async function seedReviewAccounts() {
  const accounts = [
    {
      id: 'e0000000-0000-0000-0000-000000000001',
      email: 'googleplay@myrentilly.com',
      full_name: 'Google Play App Reviewer',
      phone_number: '+2348030000000',
      role: 'renter',
      is_verified: true,
      account_number: '1000877301',
      bank_name: 'Wema Bank (Rentilly Escrow)',
      state: 'Lagos',
      wallet_balance: 500000,
      created_at: new Date().toISOString()
    },
    {
      id: 'd0000000-0000-0000-0000-000000000001',
      email: 'demo@myrentilly.com',
      full_name: 'Rentilly Demo User',
      phone_number: '+2348030000001',
      role: 'renter',
      is_verified: true,
      account_number: '1000877302',
      bank_name: 'Wema Bank (Rentilly Escrow)',
      state: 'Lagos',
      wallet_balance: 500000,
      created_at: new Date().toISOString()
    },
    {
      id: 'f0000000-0000-0000-0000-000000000001',
      email: 'review@myrentilly.com',
      full_name: 'Play Store Reviewer',
      phone_number: '+2348030000002',
      role: 'renter',
      is_verified: true,
      account_number: '1000877303',
      bank_name: 'Wema Bank (Rentilly Escrow)',
      state: 'Lagos',
      wallet_balance: 500000,
      created_at: new Date().toISOString()
    }
  ];

  for (const acc of accounts) {
    const { data: prof, error: pErr } = await sb.from('profiles').upsert(acc, { onConflict: 'email' }).select();
    if (pErr) console.error(`Error saving profile ${acc.email}:`, pErr);
    else console.log(`✅ Saved profile for ${acc.email}:`, prof?.[0]?.email);

    const pwdHash = hashPassword('RentillyReview2026!');
    await sb.from('system_configs').upsert({
      id: `auth_${acc.email}`,
      data: {
        email: acc.email,
        passwordHash: pwdHash,
        updatedAt: new Date().toISOString()
      }
    });
    console.log(`✅ Saved auth credentials for ${acc.email}`);
  }

  console.log('ALL REVIEW ACCOUNTS SEEDED IN SUPABASE!');
}

seedReviewAccounts();
