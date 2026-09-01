import { TransactionStore } from './services/transactionStore';
import { UserStore } from './services/userStore';
import dotenv from 'dotenv';
dotenv.config();

async function testBackendLedger() {
  const email = 'patrickachua3@gmail.com';
  console.log('Testing TransactionStore for:', email);

  const txs = await TransactionStore.getTransactionsByEmail(email);
  console.log(`Found ${txs.length} transactions in TransactionStore:`);
  for (const t of txs) {
    console.log(`- [${t.isCredit ? 'INFLOW' : 'OUTFLOW'}] ₦${t.amount} | ${t.title} | status: ${t.status} | ref: ${t.reference} | date: ${t.date}`);
  }

  const netBal = TransactionStore.computeNetBalance(email);
  console.log('Computed Net Balance:', netBal);
}

testBackendLedger();
