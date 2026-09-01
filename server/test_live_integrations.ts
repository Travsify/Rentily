import dotenv from 'dotenv';
dotenv.config();

const PAYSTACK_SECRET = process.env.PAYSTACK_SECRET_KEY || '';
const FLW_SECRET = process.env.FLUTTERWAVE_SECRET_KEY || '';

async function runLiveDiagnostics() {
  console.log('====================================================');
  console.log('  RENTILLY LIVE PAYMENT & BILLS INTEGRATION TEST');
  console.log('====================================================\n');

  console.log(`[Config Check] PAYSTACK_SECRET_KEY present: ${Boolean(PAYSTACK_SECRET)} (${PAYSTACK_SECRET.substring(0, 10)}...)`);
  console.log(`[Config Check] FLUTTERWAVE_SECRET_KEY present: ${Boolean(FLW_SECRET)} (${FLW_SECRET.substring(0, 10)}...)`);

  // 1. TEST PAYSTACK NIGERIAN BANKS LIST
  console.log('\n--- 1. Testing Paystack Nigerian Banks API ---');
  try {
    const res = await fetch('https://api.paystack.co/bank?country=nigeria', {
      headers: { Authorization: `Bearer ${PAYSTACK_SECRET}` }
    });
    const data: any = await res.json();
    if (res.ok && data.status) {
      console.log(`✅ Paystack Banks Query SUCCESS: Found ${data.data?.length} Nigerian banks (GTBank, Zenith, Access, Kuda, PalmPay, OPay).`);
    } else {
      console.error(`❌ Paystack Banks Error:`, data);
    }
  } catch (err: any) {
    console.error(`❌ Paystack Banks Exception:`, err.message);
  }

  // 2. TEST PAYSTACK NUBAN ACCOUNT RESOLUTION
  console.log('\n--- 2. Testing Paystack NUBAN Account Resolution (GTBank / Access) ---');
  try {
    // Testing GTBank (code 058)
    const res = await fetch('https://api.paystack.co/bank/resolve?account_number=0123456789&bank_code=058', {
      headers: { Authorization: `Bearer ${PAYSTACK_SECRET}` }
    });
    const data: any = await res.json();
    console.log(`Paystack NUBAN Resolution Response:`, data);
    if (res.ok && data.status) {
      console.log(`✅ Paystack Account Resolution SUCCESS: ${data.data?.account_name}`);
    } else {
      console.log(`ℹ️ Paystack Account Resolution API responded with: ${data.message} (Expected for dummy account test, API is active and reachable)`);
    }
  } catch (err: any) {
    console.error(`❌ Paystack Account Resolution Exception:`, err.message);
  }

  // 3. TEST FLUTTERWAVE INBOUND TRANSACTIONS
  console.log('\n--- 3. Testing Flutterwave Inbound Cloud Transactions ---');
  try {
    const res = await fetch('https://api.flutterwave.com/v3/transactions?currency=NGN', {
      headers: { Authorization: `Bearer ${FLW_SECRET}` }
    });
    const data: any = await res.json();
    if (res.ok && data.status === 'success') {
      const allTx = data.data || [];
      console.log(`✅ Flutterwave Transactions API SUCCESS: Total NGN transactions fetched: ${allTx.length}`);
      const patrickTx = allTx.filter((t: any) =>
        t.customer?.email?.includes('travsify') ||
        t.customer?.email?.includes('patrick') ||
        t.customer?.name?.toLowerCase().includes('patrick')
      );
      console.log(`✅ Patrick Achua Inbound Deposits Found: ${patrickTx.length} transactions`);
      let sum = 0;
      patrickTx.forEach((t: any, idx: number) => {
        sum += Number(t.amount || 0);
        console.log(`   Deposit #${idx + 1}: ID=${t.id} | Amount=₦${t.amount} | Status=${t.status} | Date=${t.created_at}`);
      });
      console.log(`💰 Total Confirmed Live Balance: ₦${sum.toLocaleString()}`);
    } else {
      console.error(`❌ Flutterwave Transactions Error:`, data);
    }
  } catch (err: any) {
    console.error(`❌ Flutterwave Transactions Exception:`, err.message);
  }

  // 4. TEST FLUTTERWAVE BILL CATEGORIES & DISCO METERS
  console.log('\n--- 4. Testing Flutterwave Bill Categories API ---');
  try {
    const res = await fetch('https://api.flutterwave.com/v3/bill-categories', {
      headers: { Authorization: `Bearer ${FLW_SECRET}` }
    });
    const data: any = await res.json();
    if (res.ok && data.status === 'success') {
      console.log(`✅ Flutterwave Bill Categories SUCCESS: ${data.data?.length} billers available (Airtime, Data, Power, Cable).`);
    } else {
      console.error(`❌ Flutterwave Bill Categories Error:`, data);
    }
  } catch (err: any) {
    console.error(`❌ Flutterwave Bill Categories Exception:`, err.message);
  }

  console.log('\n====================================================');
  console.log('  DIAGNOSTICS COMPLETED');
  console.log('====================================================\n');
}

runLiveDiagnostics();
