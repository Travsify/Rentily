import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';
import { FlutterwaveService } from './services/flutterwaveService';
import { PaystackService } from './services/paystackService';
import { TransactionStore } from './services/transactionStore';
dotenv.config();

const DATA_DIR = path.join(process.cwd(), 'server', 'data');
const TX_FILE = path.join(DATA_DIR, 'transactions.json');

async function testStrictSync() {
  console.log('Clearing old transaction cache...');
  fs.writeFileSync(TX_FILE, '[]', 'utf-8');

  const cleanEmail = 'patrickachua3@gmail.com';
  console.log('Running strict sync for:', cleanEmail);

  // 1. Sync Flutterwave
  const liveFlwTxs = await FlutterwaveService.fetchLiveTransactions();
  console.log(`Fetched ${liveFlwTxs.length} Flutterwave records.`);
  for (const flwTx of liveFlwTxs) {
    if (flwTx.status !== 'successful' && flwTx.status !== 'success') continue;
    const txRef = (flwTx.tx_ref || flwTx.flw_ref || '').toString();
    const narration = (flwTx.narration || '').toString().toLowerCase();
    const isRentillyTx = txRef.toUpperCase().includes('RENTILLY') || 
                         txRef.toUpperCase().includes('RENTILY') || 
                         narration.includes('rentilly') || 
                         narration.includes('rentily');

    if (isRentillyTx) {
      const amount = Number(flwTx.amount || 0);
      console.log(`✅ MATCHED RENTILLY FLW TX: ID ${flwTx.id} | ₦${amount} | Ref: ${txRef}`);
      await TransactionStore.addTransaction({
        id: `FLW_TX_${flwTx.id}`,
        userId: 'usr_patrick_achua_live',
        email: cleanEmail,
        title: `Direct Inbound Transfer — ₦${amount.toLocaleString()}`,
        type: 'Electronic Bank Inbound Deposit',
        category: 'deposit',
        amount: amount,
        isCredit: true,
        reference: flwTx.flw_ref || txRef,
        sender: flwTx.narration || flwTx.customer?.name || 'Flutterwave Bank Transfer',
        beneficiary: 'Patrick Achua (9254090338)',
        status: 'SUCCESSFUL',
        date: flwTx.created_at || new Date().toISOString()
      });
    } else {
      console.log(`❌ SKIPPED NON-RENTILLY FLW TX: ID ${flwTx.id} | Ref: ${txRef}`);
    }
  }

  // 2. Sync Paystack
  const livePaystackTxs = await PaystackService.fetchLiveTransfers();
  console.log(`Fetched ${livePaystackTxs.length} Paystack records.`);
  for (const pstTx of livePaystackTxs) {
    const txRef = (pstTx.reference || pstTx.transfer_code || '').toString();
    const reason = (pstTx.reason || '').toString().toLowerCase();
    const isRentillyPayout = txRef.toUpperCase().startsWith('RENTILLY_') || 
                             txRef.toUpperCase().startsWith('RENTILY_') || 
                             reason.includes('rentilly') || 
                             reason.includes('rentily');

    if (isRentillyPayout) {
      const amount = Number(pstTx.amount || 0) / 100;
      const recipientName = pstTx.recipient?.name || 'Bank Account';
      console.log(`✅ MATCHED RENTILLY PAYSTACK PAYOUT: ID ${pstTx.id} | ₦${amount} to ${recipientName} | Ref: ${txRef}`);
      await TransactionStore.addTransaction({
        id: `PST_TX_${pstTx.id}`,
        userId: 'usr_patrick_achua_live',
        email: cleanEmail,
        title: `Bank Transfer Payout to ${recipientName}`,
        type: 'Instant Direct Bank Payout',
        category: 'withdrawal',
        amount: amount,
        isCredit: false,
        reference: txRef,
        sender: 'Patrick Achua (Rentilly Living Escrow)',
        beneficiary: recipientName,
        recipientAccount: pstTx.recipient?.details?.account_number || '',
        recipientBank: pstTx.recipient?.details?.bank_name || 'Direct Bank Payout',
        status: 'SUCCESSFUL',
        date: pstTx.createdAt || pstTx.transferred_at || new Date().toISOString()
      });
    } else {
      // Skipped non-rentilly
    }
  }

  const finalTxs = await TransactionStore.getTransactionsByEmail(cleanEmail);
  console.log(`\n========================================`);
  console.log(`FINAL CLEAN RENTILLY LEDGER (${finalTxs.length} transactions):`);
  for (const t of finalTxs) {
    console.log(`• [${t.isCredit ? 'INFLOW' : 'OUTFLOW'}] ₦${t.amount} | ${t.title} | Ref: ${t.reference} | Date: ${t.date}`);
  }
  const netBal = TransactionStore.computeNetBalance(cleanEmail);
  console.log(`NET OPERATING BALANCE: ₦${netBal.toLocaleString()}`);
  console.log(`========================================\n`);
}

testStrictSync();
