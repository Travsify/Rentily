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
  currency?: 'NGN' | 'USDT' | 'USD' | string;
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

  static isTreasuryTransaction(t: Partial<WalletTransaction>): boolean {
    const title = (t.title || '').toUpperCase();
    const ref = (t.reference || '').toUpperCase();
    const email = (t.email || '').toLowerCase().trim();
    const amt = Number(t.amount || 0);

    if (email === 'treasury@myrentilly.com' || email === 'admin@myrentilly.com') return true;
    if (ref.startsWith('BVNAPI-') || title.includes('BVN VERIFICATION') || (amt === 75 && title.includes('BVN'))) return true;
    if (ref.startsWith('FEE_') || title.startsWith('BANK TRANSFER PROCESSING FEE')) return true;
    if (ref.includes('TEST') || title.includes('TEST')) return true;
    if (title.includes('PAYSTACK-TITAN') || title.includes('PAYSTACK - 0000336089')) return true;
    if (title.includes('EXCHANGE FROM') || title.includes('SWAP')) return true;
    if (title.includes('TREASURY TO SPEND') || title.includes('SPEND WALLET')) return true;
    if (title.includes('FUNDING USD SPEND') || title.includes('FUNDING USDT SPEND')) return true;
    if (title.includes('USD WALLET TRANSFER') || title.includes('USDT WALLET TRANSFER')) return true;
    if (title === 'CARD ISSUANCE' && amt <= 3) return true;
    if (title.includes('GLOBALLINE LOGISTICS')) return true;
    return false;
  }

  static async syncFromSupabase(): Promise<WalletTransaction[]> {
    if (!supabase) return _txCache || [];

    try {
      // 1. Fetch wallet_transactions (primary ledger for deposits, withdrawals, cards, airtime)
      const { data: walletData } = await supabase
        .from('wallet_transactions')
        .select('*')
        .order('created_at', { ascending: false });

      // 2. Fetch property & escrow transactions
      const { data: propertyData } = await supabase
        .from('transactions')
        .select('*')
        .order('created_at', { ascending: false });

      const canonicalMap = new Map<string, WalletTransaction>();

      // Ingest wallet_transactions first (highest fidelity for live user wallets)
      if (walletData && Array.isArray(walletData)) {
        for (const row of walletData) {
          const rawNarration = (row.narration || '').toString();
          const ref = (row.flw_ref || row.tx_ref || row.id || '').toString().trim();
          const amt = Number(row.amount || 0);

          if (this.isTreasuryTransaction({
            title: rawNarration,
            reference: ref,
            email: row.email,
            amount: amt
          })) {
            continue;
          }

          const rawType = (row.type || '').toString().toLowerCase();
          const isCredit = rawType === 'credit';
          const rawStatus = (row.status || 'SUCCESSFUL').toString().toUpperCase();
          const status = (rawStatus === 'COMPLETED' || rawStatus === 'SUCCESS') ? 'SUCCESSFUL' : (rawStatus === 'FAILED' ? 'FAILED' : 'PENDING');

          let category: WalletTransaction['category'] = isCredit ? 'deposit' : 'withdrawal';
          if (rawNarration.toLowerCase().includes('card')) {
            category = 'wallet_funding';
          } else if (rawNarration.toLowerCase().includes('bill') || rawNarration.toLowerCase().includes('electricity') || rawNarration.toLowerCase().includes('airtime')) {
            category = 'utility';
          } else if (rawNarration.toLowerCase().includes('escrow') || rawNarration.toLowerCase().includes('rent')) {
            category = 'rent';
          }

          const narrationUpper = rawNarration.toUpperCase();
          let txCurrency: 'NGN' | 'USDT' | 'USD' = 'NGN';
          if (narrationUpper.includes('USDT') || narrationUpper.includes('TRC20') || narrationUpper.includes('TRON')) {
            txCurrency = 'USDT';
          } else if (narrationUpper.includes('USD') || narrationUpper.includes('DOLLAR')) {
            txCurrency = 'USD';
          }

          const mapped: WalletTransaction = {
            id: row.id,
            userId: row.user_id,
            email: (row.email || '').toLowerCase().trim(),
            title: rawNarration || (isCredit ? 'Inbound Bank Deposit' : 'Outbound Bank Transfer'),
            type: rawType || (isCredit ? 'credit' : 'debit'),
            category,
            amount: amt,
            currency: row.currency || txCurrency,
            isCredit,
            reference: ref,
            status,
            date: row.created_at || new Date().toISOString()
          };

          canonicalMap.set(ref, mapped);
          if (row.tx_ref) canonicalMap.set(row.tx_ref.trim(), mapped);
          if (row.flw_ref) canonicalMap.set(row.flw_ref.trim(), mapped);
        }
      }

      // Ingest transactions table (for property escrow or historical items not in wallet_transactions)
      if (propertyData && Array.isArray(propertyData)) {
        const users = UserStore.getAllUsers();
        for (const row of propertyData) {
          const txRef = (row.payment_reference || row.id || '').toString().trim();
          const title = (row.owner_payout_reference || row.property_title || '').toString();
          const amt = Number(row.total_amount || row.amount || 0);

          if (this.isTreasuryTransaction({
            title,
            reference: txRef,
            email: row.payer_name,
            amount: amt
          })) {
            continue;
          }

          // Skip if already captured from wallet_transactions
          if (canonicalMap.has(txRef) || (row.payment_reference && canonicalMap.has(row.payment_reference.trim()))) {
            continue;
          }

          const user = users.find(u => u.id === row.payer_id || u.id === row.owner_id);
          const email = (user?.email || row.payer_name || 'user@myrentilly.com').toLowerCase().trim();

          const isWithdrawal = row.transaction_type === 'withdrawal' || 
            (typeof txRef === 'string' && (txRef.startsWith('WD_') || txRef.startsWith('RENTILLY_WD_')));

          const mapped: WalletTransaction = {
            id: row.id,
            userId: row.payer_id || row.user_id,
            email,
            title: title || (isWithdrawal ? 'Outbound Bank Transfer' : (row.escrow_status === 'released_to_owner' ? 'Inbound Bank Deposit' : 'Property Escrow Payment')),
            type: isWithdrawal ? 'withdrawal' : (row.transaction_type || 'rent'),
            category: isWithdrawal ? 'withdrawal' : (row.payment_gateway === 'flutterwave' ? 'deposit' : 'deposit'),
            amount: amt,
            currency: row.currency || 'NGN',
            isCredit: !isWithdrawal,
            reference: txRef,
            status: (row.escrow_status === 'released_to_owner' || row.status === 'SUCCESSFUL' || isWithdrawal) ? 'SUCCESSFUL' : 'PENDING',
            escrowStatus: row.escrow_status,
            date: row.created_at || new Date().toISOString()
          };

          canonicalMap.set(txRef, mapped);
        }
      }

      // Read current disk cache to keep any genuine user offline records that aren't in Supabase yet
      const currentCache = _txCache || [];
      for (const t of currentCache) {
        if (this.isTreasuryTransaction(t)) continue;
        const ref = (t.reference || t.id).trim();
        if (!canonicalMap.has(ref)) {
          canonicalMap.set(ref, t);
        }
      }

      const deduplicated = Array.from(new Set(canonicalMap.values()));
      deduplicated.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());

      _txCache = deduplicated;
      this.saveTransactions(deduplicated);
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
    if (!cleanEmail) return [];
    // Ensure fresh sync from Supabase
    await this.syncFromSupabase();
    const all = this.getAllTransactions();
    const filtered = all.filter(t => 
      t.email.toLowerCase() === cleanEmail && !TransactionStore.isTreasuryTransaction(t)
    );
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
      // Exclude USDT and USD from Naira wallet balance calculation
      const curr = (tx.currency || '').toUpperCase();
      const title = (tx.title || '').toUpperCase();
      if (curr === 'USDT' || curr === 'USD' || title.includes('USDT') || title.includes('TRC20')) {
        continue;
      }

      if (tx.isCredit) {
        bal += tx.amount;
      } else {
        bal -= tx.amount;
      }
    }
    return Math.max(0, bal);
  }
}
