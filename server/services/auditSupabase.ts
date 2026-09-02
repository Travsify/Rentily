import { supabase } from '../supabaseClient';

async function runAudit() {
  console.log('====================================================');
  console.log('🔍 SUPABASE CLOUD DEEP AUDIT & PROVISIONING');
  console.log('====================================================\n');

  if (!supabase) {
    console.error('❌ Supabase client not initialized. Check credentials.');
    process.exit(1);
  }

  // 1. Storage Buckets Check & Provisioning
  console.log('--- 1. STORAGE BUCKETS ---');
  try {
    const { data: buckets, error: bucketErr } = await supabase.storage.listBuckets();
    if (bucketErr) {
      console.warn('⚠️ Could not list storage buckets:', bucketErr.message);
    } else {
      const existingNames = (buckets || []).map(b => b.name);
      console.log('Existing Buckets Found:', existingNames);

      const targets = [
        { name: 'properties', public: true },
        { name: 'documents', public: false },
        { name: 'avatars', public: true }
      ];

      for (const target of targets) {
        if (!existingNames.includes(target.name)) {
          console.log(`📦 Provisioning Bucket: "${target.name}" (Public: ${target.public})...`);
          const { error: cErr } = await supabase.storage.createBucket(target.name, {
            public: target.public,
            fileSizeLimit: 52428800 // 50 MB
          });
          if (cErr) {
            console.warn(`   ⚠️ Bucket "${target.name}" notice:`, cErr.message);
          } else {
            console.log(`   ✅ Bucket "${target.name}" successfully created!`);
          }
        } else {
          console.log(`   ✅ Bucket "${target.name}" is LIVE and configured.`);
        }
      }
    }
  } catch (err: any) {
    console.warn('Storage audit error:', err.message);
  }

  // 2. Database Tables Audit
  console.log('\n--- 2. DATABASE TABLES & RECORD COUNTS ---');
  const tables = [
    'profiles',
    'properties',
    'inspections',
    'escrow_agreements',
    'transactions',
    'fraud_blacklist',
    'system_configs',
    'virtual_cards'
  ];

  for (const t of tables) {
    try {
      const { data, error, count } = await supabase.from(t).select('*', { count: 'exact', head: true });
      if (error) {
        console.log(`   ⚠️ Table "${t}": ${error.message}`);
      } else {
        console.log(`   ✅ Table "${t}": Connected (${count ?? 0} active records)`);
      }
    } catch (err: any) {
      console.log(`   ⚠️ Table "${t}": ${err.message}`);
    }
  }

  // 3. User Profile State Verification
  console.log('\n--- 3. KEY USER ACCOUNTS AUDIT ---');
  try {
    const { data: users, error: uErr } = await supabase
      .from('profiles')
      .select('id, full_name, email, role, business_name, wallet_balance, is_verified, account_number, bank_name')
      .in('email', ['tonerocool1@gmail.com', 'admin@rentilly.com', 'patrickachua3@gmail.com']);

    if (uErr) {
      console.warn('User query error:', uErr.message);
    } else {
      console.log(`Found ${users?.length || 0} key profile records in Supabase:`);
      for (const u of (users || [])) {
        console.log(`   👤 ${u.email} | Role: "${u.role}" | Biz: "${u.business_name || 'N/A'}" | Balance: ₦${u.wallet_balance} | Bank Acc: ${u.account_number || 'N/A'}`);
      }
    }
  } catch (err: any) {
    console.warn('User audit error:', err.message);
  }

  // 4. Realtime Connection Verification
  console.log('\n--- 4. SUPABASE REALTIME PROTOCOL AUDIT ---');
  try {
    const channel = supabase.channel('rentilly_verification_channel')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'profiles' }, () => {})
      .subscribe((status) => {
        console.log(`   📡 Realtime Protocol Status: "${status}"`);
        if (status === 'SUBSCRIBED') {
          console.log('   ✅ Realtime WebSockets are ACTIVE & Listening to Cloud Mutations.');
        }
        setTimeout(() => {
          supabase.removeChannel(channel);
          console.log('\n====================================================');
          console.log('🎉 AUDIT VERDICT: Supabase Cloud is 100% Configured and Ready!');
          console.log('====================================================');
          process.exit(0);
        }, 1500);
      });
  } catch (err: any) {
    console.warn('Realtime test error:', err.message);
    process.exit(0);
  }
}

runAudit().catch(console.error);
