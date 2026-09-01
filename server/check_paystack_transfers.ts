import dotenv from 'dotenv';
dotenv.config();

const PAYSTACK_SECRET = process.env.PAYSTACK_SECRET_KEY || '';

async function checkRecentPaystackTransfers() {
  console.log('====================================================');
  console.log('  CHECKING RECENT PAYSTACK TRANSFERS STATUS');
  console.log('====================================================\n');

  try {
    const res = await fetch('https://api.paystack.co/transfer', {
      headers: { Authorization: `Bearer ${PAYSTACK_SECRET}` }
    });
    const data: any = await res.json();

    if (res.ok && data.status) {
      const transfers = data.data || [];
      console.log(`Found ${transfers.length} recent Paystack transfer(s):\n`);

      transfers.slice(0, 5).forEach((t: any, idx: number) => {
        console.log(`--- Transfer #${idx + 1} ---`);
        console.log(`ID: ${t.id}`);
        console.log(`Transfer Code: ${t.transfer_code}`);
        console.log(`Amount: ₦${(t.amount / 100).toLocaleString()}`);
        console.log(`Status: [${t.status?.toUpperCase()}]`);
        console.log(`Reason: ${t.reason}`);
        console.log(`Recipient: ${t.recipient?.name} (${t.recipient?.details?.account_number} - ${t.recipient?.details?.bank_name})`);
        console.log(`Created At: ${t.createdAt}`);
        if (t.status === 'otp') {
          console.log(`⚠️ ACTION REQUIRED: Transfer requires OTP! (Paystack OTP is active on dashboard).`);
        } else if (t.status === 'pending' || t.status === 'processing') {
          console.log(`⏳ IN PROGRESS: Transfer queued at NIBSS banking switch.`);
        } else if (t.status === 'success') {
          console.log(`✅ SUCCESS: Confirmed delivered to recipient bank by NIBSS.`);
        } else if (t.status === 'failed') {
          console.log(`❌ FAILED: Reason: ${t.failures || 'Transfer rejected by recipient bank'}`);
        }
        console.log('------------------------------------\n');
      });
    } else {
      console.error('Failed to fetch transfers:', data);
    }
  } catch (err: any) {
    console.error('Exception fetching transfers:', err.message);
  }
}

checkRecentPaystackTransfers();
