import fs from 'fs';
import path from 'path';
import { supabase } from '../supabaseClient';

export interface WalletTransaction {
  id: string;
  userId?: string;
  email: string;
  title: string;
  type: string;
  category: 'deposit' | 'withdrawal' | 'utility' | 'rent' | 'escrow';
  amount: number;
  isCredit: boolean;
  reference: string;
  sender?: string;
  beneficiary?: string;
  recipientAccount?: string;
  recipientBank?: string;
  status: 'SUCCESSFUL' | 'PENDING' | 'FAILED';
  token?: string;
  units?: string;
  date: string;
}

const DATA_DIR = path.join(process.cwd(), 'server', 'data');
const TX_FILE = path.join(DATA_DIR, 'transactions.json');

function ensureStorage() {
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }
  if (!fs.existsSync(TX_FILE) || fs.readFileSync(TX_FILE, 'utf-8').trim() === '[]') {
    const defaultSeed: WalletTransaction[] = [
      {
        id: 'TX_DEP_100004260831215927',
        userId: 'usr_patrick_achua_live',
        email: 'patrickachua3@gmail.com',
        title: 'Direct Bank Transfer Deposit #1',
        type: 'Electronic Bank Inbound Deposit',
        category: 'deposit',
        amount: 1000.0,
        isCredit: true,
        reference: '100004260831215927169930701067',
        sender: 'TOMISIN OLAMIPO KOLAWOLE',
        beneficiary: 'Patrick Achua',
        status: 'SUCCESSFUL',
        date: '2026-08-31T21:59:27.000Z',
      },
      {
        id: 'TX_DEP_100004260831224203',
        userId: 'usr_patrick_achua_live',
        email: 'patrickachua3@gmail.com',
        title: 'Direct Bank Transfer Deposit #2',
        type: 'Electronic Bank Inbound Deposit',
        category: 'deposit',
        amount: 1000.0,
        isCredit: true,
        reference: '100004260831224203169930903410',
        sender: 'TOMISIN OLAMIPO KOLAWOLE',
        beneficiary: 'Patrick Achua',
        status: 'SUCCESSFUL',
        date: '2026-08-31T22:42:03.000Z',
      },
      {
        id: 'TX_WD_0254127724_OPAY',
        userId: 'usr_patrick_achua_live',
        email: 'patrickachua3@gmail.com',
        title: 'Bank Transfer Payout to OPay',
        type: 'Instant Direct Bank Payout',
        category: 'withdrawal',
        amount: 1000.0,
        isCredit: false,
        reference: 'TRF_PAYSTACK_938172948',
        sender: 'Patrick Achua (Rentilly Living Escrow)',
        beneficiary: 'Patrick Achua',
        recipientAccount: '0254127724',
        recipientBank: 'OPay',
        status: 'SUCCESSFUL',
        date: new Date().toISOString(),
      },
    ];
    fs.writeFileSync(TX_FILE, JSON.stringify(defaultSeed, null, 2), 'utf-8');
  }
}

export class TransactionStore {
  static getAllTransactions(): WalletTransaction[] {
    try {
      ensureStorage();
      const content = fs.readFileSync(TX_FILE, 'utf-8');
      return JSON.parse(content || '[]');
    } catch (_) {
      return [];
    }
  }

  static saveTransactions(txs: WalletTransaction[]): void {
    try {
      ensureStorage();
      fs.writeFileSync(TX_FILE, JSON.stringify(txs, null, 2), 'utf-8');
    } catch (err) {
      console.error('Failed to save transactions:', err);
    }
  }

  static async getTransactionsByEmail(email: string): Promise<WalletTransaction[]> {
    const cleanEmail = email.toLowerCase().trim();
    const all = this.getAllTransactions();
    const filtered = all.filter(t => t.email.toLowerCase() === cleanEmail);
    // Sort descending by date
    return filtered.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
  }

  static async addTransaction(tx: WalletTransaction): Promise<WalletTransaction> {
    const all = this.getAllTransactions();
    all.unshift(tx);
    this.saveTransactions(all);

    // Also persist in Supabase if available
    if (supabase) {
      try {
        await supabase.from('transactions').insert({
          user_id: tx.userId,
          total_amount: tx.amount,
          escrow_status: tx.isCredit ? 'deposit_completed' : 'payout_completed',
          payment_gateway: tx.category,
          payment_reference: tx.reference,
        });
      } catch (_) {}
    }

    return tx;
  }

  static computeNetBalance(email: string): number {
    const cleanEmail = email.toLowerCase().trim();
    const all = this.getAllTransactions();
    const userTxs = all.filter(t => t.email.toLowerCase() === cleanEmail && t.status === 'SUCCESSFUL');
    let bal = 0;
    for (const tx of userTxs) {
      if (tx.isCredit) {
        bal += tx.amount;
      } else {
        bal -= tx.amount;
      }
    }
    return Math.max(0, bal);
  }
}
