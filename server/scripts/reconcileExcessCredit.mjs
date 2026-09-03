import { createClient } from '@supabase/supabase-js';
import fs from 'fs';

const env = fs.readFileSync('.env', 'utf8');
const SUPABASE_URL = env.match(/SUPABASE_URL=(.*)/)[1].trim();
const SUPABASE_KEY = env.match(/SUPABASE_SERVICE_ROLE_KEY=(.*)/)[1].trim();
const sb = createClient(SUPABASE_URL, SUPABASE_KEY);

async function reconcilePickpadiExcess() {
  console.log('================================================================');
  console.log('🏦 RENTILLY FINANCIAL OPERATIONS: LEDGER REVERSAL & RECONCILIATION');
  console.log('================================================================\n');

  const targetEmail = 'pickpadigroup@gmail.com';
  const flwRef = '100004260903011905170141560098';
  const trueAmount = 2000;

  // 1. Fetch user profile
  const { data: profile, error: pErr } = await sb
    .from('profiles')
    .select('*')
    .eq('email', targetEmail)
    .single();

  if (pErr || !profile) {
    console.error('Error fetching profile:', pErr?.message);
    process.exit(1);
  }

  const currentBal = Number(profile.wallet_balance || 0);
  console.log(`User: ${profile.email} (${profile.id})`);
  console.log(`Current Balance: ₦${currentBal.toLocaleString()}`);
  console.log(`True Funded Amount: ₦${trueAmount.toLocaleString()}`);

  const excessAmount = currentBal - trueAmount;
  if (excessAmount <= 0) {
    console.log('Balance is already aligned. No adjustment needed.');
    process.exit(0);
  }

  console.log(`Excess Duplicate Credit to Reverse: ₦${excessAmount.toLocaleString()}\n`);

  // 2. Insert official reversal audit record into wallet_transactions
  const reversalRef = `REV_${Date.now()}_${flwRef.slice(-6)}`;
  const { error: txErr } = await sb.from('wallet_transactions').insert({
    user_id: profile.id,
    email: targetEmail,
    amount: excessAmount,
    type: 'debit',
    status: 'completed',
    flw_ref: reversalRef,
    tx_ref: reversalRef,
    narration: `System Reversal: Inbound Duplicate Credit Correction (Ref: ${flwRef})`,
    created_at: new Date().toISOString()
  });

  if (txErr) {
    console.error('Failed to log reversal transaction:', txErr.message);
  } else {
    console.log(`✅ [1/3] Logged reversal debit of ₦${excessAmount.toLocaleString()} in wallet_transactions`);
  }

  // 3. Update profiles table to correct true balance
  const { error: uErr } = await sb
    .from('profiles')
    .update({
      wallet_balance: trueAmount,
      updated_at: new Date().toISOString()
    })
    .eq('id', profile.id);

  if (uErr) {
    console.error('Failed to update profile balance:', uErr.message);
    process.exit(1);
  }
  console.log(`✅ [2/3] Updated profiles.wallet_balance to exactly ₦${trueAmount.toLocaleString()}`);

  // 4. Send official in-app transparency notification
  const { error: notifErr } = await sb.from('notifications').insert({
    user_id: profile.id,
    title: 'Ledger Reconciliation Notice ⚖️',
    category: 'wallet',
    message: `An automated reconciliation of ₦${excessAmount.toLocaleString()} was processed to correct duplicate inbound credit processing for transfer ${flwRef}. Your verified wallet balance is ₦${trueAmount.toLocaleString()}.`,
    metadata: {
      action: 'ledger_reversal',
      original_ref: flwRef,
      reversal_ref: reversalRef,
      reversed_amount: `₦${excessAmount.toLocaleString()}`,
      true_balance: `₦${trueAmount.toLocaleString()}`,
      timestamp: new Date().toISOString()
    },
    read: false,
    created_at: new Date().toISOString()
  });

  if (!notifErr) {
    console.log(`✅ [3/3] Dispatched audit notification to user in-app inbox`);
  }

  // 5. Update local server data cache if present
  try {
    const usersFile = 'server/data/users.json';
    if (fs.existsSync(usersFile)) {
      const users = JSON.parse(fs.readFileSync(usersFile, 'utf8'));
      const idx = users.findIndex(u => u.email.toLowerCase() === targetEmail.toLowerCase());
      if (idx >= 0) {
        users[idx].walletBalance = trueAmount;
        users[idx].updatedAt = new Date().toISOString();
        fs.writeFileSync(usersFile, JSON.stringify(users, null, 2), 'utf8');
        console.log(`✅ Synchronized local cache file server/data/users.json`);
      }
    }
  } catch (_) {}

  console.log('\n================================================================');
  console.log(`🎉 RECONCILIATION COMPLETE: Balance safely restored to ₦${trueAmount.toLocaleString()}`);
  console.log('================================================================\n');
}

reconcilePickpadiExcess().catch(e => {
  console.error('Fatal error:', e);
  process.exit(1);
});
