import fs from 'fs';
import path from 'path';
import { supabase } from '../supabaseClient';
import { UserStore } from './userStore';

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

const VAULT_PROPERTY_ID = '00000000-0000-0000-0000-000000000000';

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

    let loaded: WalletTransaction[] = [];
    try {
      const txFile = getStoragePath();
      if (fs.existsSync(txFile)) {
        const content = fs.readFileSync(txFile, 'utf-8');
        const parsed = JSON.parse(content || '[]');
        if (Array.isArray(parsed)) {
          loaded = parsed;
        }
      }
    } catch (_) {}

    _txCache = loaded;

    // Trigger cloud sync from Supabase
    this.syncFromSupabase().catch(err => {
      console.warn('[TransactionStore] Initial Supabase sync notice:', err?.message || err);
    });

    return _txCache;
  }

  static async syncFromSupabase(): Promise<WalletTransaction[]> {
    if (!supabase) return _txCache || [];

    try {
      const { data, error } = await supabase.from('transactions').select('*');
      if (!error && data && Array.isArray(data)) {
        const users = UserStore.getAllUsers();
        const current = _txCache || [];

        for (const row of data) {
          const user = users.find(u => u.id === row.payer_id || u.id === row.owner_id);
          const email = user ? user.email : 'partner@rentilly.com';

          const mapped: WalletTransaction = {
            id: row.id,
            userId: row.payer_id,
            email,
            title: row.owner_payout_reference || (row.escrow_status === 'released_to_owner' ? 'Wallet Deposit / Credit' : 'Payment / Escrow'),
            type: row.transaction_type || 'rent',
            category: (row.payment_gateway === 'flutterwave' ? 'deposit' : (row.payment_gateway === 'paystack' ? 'withdrawal' : 'wallet_funding')),
            amount: Number(row.total_amount || 0),
            isCredit: row.escrow_status === 'released_to_owner',
            reference: row.payment_reference,
            status: 'SUCCESSFUL',
            escrowStatus: row.escrow_status,
            date: row.created_at || new Date().toISOString()
          };

          const idx = current.findIndex(t => t.id === mapped.id || (mapped.reference && t.reference === mapped.reference));
          if (idx >= 0) {
            current[idx] = { ...current[idx], ...mapped };
          } else {
            current.unshift(mapped);
          }
        }

        _txCache = current;
        this.saveTransactions(_txCache);
      }
    } catch (e: any) {
      console.error('[TransactionStore] Error syncing transactions from Supabase:', e?.message || e);
    }

    return _txCache || [];
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
    const cleanEmail = (email || '').toLowerCase().trim();
    // Ensure fresh sync from Supabase
    await this.syncFromSupabase();
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

    // Persist to Supabase Cloud
    if (supabase) {
      try {
        const users = UserStore.getAllUsers();
        let targetUser = users.find(u => u.email.toLowerCase() === tx.email.toLowerCase());
        if (!targetUser && tx.userId) {
          targetUser = users.find(u => u.id === tx.userId);
        }

        const validUserId = targetUser ? targetUser.id : (
          tx.email.toLowerCase() === 'tonerocool1@gmail.com' ? 'c0000000-0000-0000-0000-000000000001' :
          (tx.email.toLowerCase() === 'admin@myrentilly.com' ? 'a0000000-0000-0000-0000-000000000001' :
          'b0000000-0000-0000-0000-000000000001')
        );

        const gateway = (tx.category === 'withdrawal' ? 'paystack' : 'flutterwave') as any;
        const escrowStatus = tx.isCredit ? 'released_to_owner' : 'held_in_escrow';

        const { error } = await supabase.from('transactions').upsert({
          property_id: VAULT_PROPERTY_ID,
          payer_id: validUserId,
          owner_id: validUserId,
          transaction_type: 'rent',
          payment_reference: tx.reference || `REF_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
          payment_gateway: gateway,
          base_amount: Number(tx.amount || 0),
          rentilly_legal_fee: 0,
          total_amount: Number(tx.amount || 0),
          escrow_status: escrowStatus,
          owner_payout_reference: tx.title || tx.category || 'Platform Transaction',
          created_at: tx.date || new Date().toISOString()
        }, { onConflict: 'payment_reference' });

        if (error) {
          console.error('[TransactionStore] Supabase transaction write error:', error.message);
        } else {
          console.log(`[TransactionStore] Successfully recorded ₦${tx.amount} (${tx.reference}) in Supabase cloud! ☁️`);
        }
      } catch (err) {
        console.error('[TransactionStore] Supabase transaction network error:', err);
      }
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

    if (supabase) {
      supabase.from('transactions').update({
        escrow_status: escrowStatus,
        owner_payout_reference: ownerPayoutReference || all[idx].ownerPayoutReference,
        payout_released_at: new Date().toISOString()
      }).eq('id', id).then(({ error }) => {
        if (error) console.error('[TransactionStore] Supabase status update error:', error.message);
      });
    }

    return true;
  }

  static computeNetBalance(email: string): number {
    const cleanEmail = (email || '').toLowerCase().trim();
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
