import dotenv from 'dotenv';
import { FlutterwaveService } from './services/flutterwaveService';
import { PaystackService } from './services/paystackService';
dotenv.config();

async function inspectRealGateways() {
  console.log('--- 1. REAL FLUTTERWAVE TRANSACTIONS ---');
  const flwTxs = await FlutterwaveService.fetchLiveTransactions();
  console.log(`Found ${flwTxs.length} real Flutterwave transactions:`);
  for (const t of flwTxs) {
    console.log(`- ID: ${t.id} | Amount: ₦${t.amount} | Status: ${t.status} | Customer: ${t.customer?.name} (${t.customer?.email}) | Ref: ${t.tx_ref || t.flw_ref} | Date: ${t.created_at}`);
  }

  console.log('\n--- 2. REAL PAYSTACK TRANSFERS (WITHDRAWALS) ---');
  const pstTxs = await PaystackService.fetchLiveTransfers();
  console.log(`Found ${pstTxs.length} real Paystack transfers:`);
  for (const t of pstTxs.slice(0, 10)) {
    console.log(`- ID: ${t.id} | Code: ${t.transfer_code} | Amount: ₦${t.amount / 100} | Status: ${t.status} | Recipient: ${t.recipient?.name} (${t.recipient?.details?.account_number} - ${t.recipient?.details?.bank_name}) | Ref: ${t.reference} | Date: ${t.createdAt}`);
  }
}

inspectRealGateways();
