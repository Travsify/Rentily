import fs from 'fs';
import path from 'path';
import { supabase } from '../supabaseClient';

export interface WalletTransaction {
  id: string;
  userId?: string;
  email: string;
  title: string;
  type: string;
  category: 'deposit' | 'withdrawal' | 'utility' | 'rent' | 'escrow' | 'wallet_funding';
  amount: number;
  isCredit: boolean;
  reference: string;
  sender?: string;
  beneficiary?: string;
  recipientAccount?: string;
  recipientBank?: string;
  status: 'SUCCESSFUL' | 'PENDING' | 'FAILED';
  escrowStatus?: 'held_in_escrow' | 'released_to_owner' | 'refunded' | 'disputed';
  ownerPayoutReference?: string;
  payoutReleasedAt?: string;
  token?: string;
  units?: string;
  date: string;
}

function getDataDir(): string {
  const candidates = [
    path.join(process.cwd(), 'server', 'data'),
    path.join('/opt/render/project/src', 'server', 'data'),
    path.join('/tmp', 'rentilly-data'),
  ];
  for (const dir of candidates) {
    try {
      if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
      fs.writeFileSync(path.join(dir, '.write_test_tx'), 'ok', 'utf-8');
      fs.unlinkSync(path.join(dir, '.write_test_tx'));
      return dir;
    } catch { continue; }
  }
  return '/tmp';
}

let _DATA_DIR: string | null = null;
function getStoragePath(): string {
  if (!_DATA_DIR) _DATA_DIR = getDataDir();
  return path.join(_DATA_DIR, 'transactions.json');
}

// In-memory transaction cache
let _txCache: WalletTransaction[] | null = null;

export class TransactionStore {
  static getAllTransactions(): WalletTransaction[] {
    if (_txCache !== null) {
      return _txCache;
    }
    try {
      const txFile = getStoragePath();
      if (fs.existsSync(txFile)) {
        const content = fs.readFileSync(txFile, 'utf-8');
        const parsed = JSON.parse(content || '[]');
        if (Array.isArray(parsed)) {
          _txCache = parsed;
          return _txCache;
        }
      }
    } catch (_) {}
    _txCache = [];
    return _txCache;
  }

  static saveTransactions(txs: WalletTransaction[]): void {
    _txCache = txs;
    try {
      const txFile = getStoragePath();
      fs.writeFileSync(txFile, JSON.stringify(txs, null, 2), 'utf-8');
    } catch (err) {
      console.error('Failed to save transactions to disk:', err);
    }
  }

  static async getTransactionsByEmail(email: string): Promise<WalletTransaction[]> {
    const cleanEmail = email.toLowerCase().trim();
    const all = this.getAllTransactions();
    const filtered = all.filter(t => t.email.toLowerCase() === cleanEmail);
    return filtered.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
  }

  static async addTransaction(tx: WalletTransaction): Promise<WalletTransaction> {
    const all = this.getAllTransactions();
    const existingIdx = all.findIndex(t => t.id === tx.id || (tx.reference && t.reference === tx.reference));
    if (existingIdx >= 0) {
      all[existingIdx] = { ...all[existingIdx], ...tx };
    } else {
      all.unshift(tx);
    }
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

  static updateTransactionStatus(
    id: string,
    escrowStatus: 'held_in_escrow' | 'released_to_owner' | 'refunded' | 'disputed',
    ownerPayoutReference?: string
  ): boolean {
    const all = this.getAllTransactions();
    const idx = all.findIndex(t => t.id === id);
    if (idx === -1) return false;
    all[idx] = {
      ...all[idx],
      escrowStatus,
      ownerPayoutReference: ownerPayoutReference || all[idx].ownerPayoutReference,
      payoutReleasedAt: new Date().toISOString()
    };
    this.saveTransactions(all);
    return true;
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
