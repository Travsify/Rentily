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
  category: 'deposit' | 'withdrawal' | 'utility' | 'rent' | 'escrow' | 'wallet_funding' | 'swap' | string;
  amount: number;
  currency?: 'NGN' | 'USDT' | 'USD' | string;
  isCredit: boolean;
  reference: string;
  sender?: string;
  beneficiary?: string;
  recipientAccount?: string;
  recipientBank?: string;
  status: 'SUCCESSFUL' | 'PENDING' | 'FAILED' | 'PROCESSING' | string;
  escrowStatus?: 'held_in_escrow' | 'released_to_owner' | 'refunded' | 'disputed';
  ownerPayoutReference?: string;
  payoutReleasedAt?: string;
  token?: string;
  units?: string;
  date?: string;
  createdAt?: string;
  userEmail?: string;
  user_email?: string;
  description?: string;
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

          let txBeneficiary: string | undefined;
          let txRecipientAccount: string | undefined;
          let txRecipientBank: string | undefined;
          if (category === 'withdrawal') {
            const m1 = rawNarration.match(/Payout to ([A-Za-z\s]+?)\s*\((\d{10})\)/i);
            if (m1) {
              txBeneficiary = m1[1].trim();
              txRecipientAccount = m1[2].trim();
            }
          }

          const matchRemark = rawNarration.match(/^\[(.*?)\]\s*(.*)$/);
          let txTitle = rawNarration;
          let txDesc: string | undefined = row.description || undefined;
          if (matchRemark) {
            txDesc = matchRemark[1].trim();
            txTitle = matchRemark[2].trim();
          }

          const mapped: WalletTransaction = {
            id: row.id,
            userId: row.user_id,
            email: (row.email || '').toLowerCase().trim(),
            title: txTitle || (isCredit ? 'Inbound Bank Deposit' : 'Outbound Bank Transfer'),
            description: txDesc,
            type: rawType || (isCredit ? 'credit' : 'debit'),
            category,
            amount: amt,
            currency: row.currency || txCurrency,
            isCredit,
            reference: ref,
            beneficiary: txBeneficiary,
            recipientAccount: txRecipientAccount,
            recipientBank: txRecipientBank,
            status,
            date: row.created_at || new Date().toISOString()
          };

          canonicalMap.set(ref, mapped);
          if (row.tx_ref) canonicalMap.set(row.tx_ref.trim(), mapped);
          if (row.flw_ref) canonicalMap.set(row.flw_ref.trim(), mapped);
        }
      }

      // Ingest transactions table (for property escrow or genuine leases, NOT synthetic wallet ledger mirrors)
      if (propertyData && Array.isArray(propertyData)) {
        const users = UserStore.getAllUsers();
        for (const row of propertyData) {
          // Strictly skip synthetic vault mirrors created by legacy addTransaction
          if (row.property_id === VAULT_PROPERTY_ID) {
            continue;
          }

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

          // Only match on payer_id (the person who actually performed/initiated this tx).
          // Never match on owner_id alone — that is the recipient (landlord/owner), not the sender.
          const user = users.find(u => u.id === row.payer_id);
          // If we can't identify the payer user, skip — don't guess by owner
          if (!user) continue;
          const email = user.email.toLowerCase().trim();

          const isDebit = row.transaction_type === 'withdrawal' || 
            row.transaction_type === 'utility' ||
            row.transaction_type === 'debit' ||
            row.escrow_status === 'bill_paid' ||
            row.payment_gateway === 'flutterwave_bills' ||
            (typeof row.owner_payout_reference === 'string' && (
              row.owner_payout_reference.toLowerCase().includes('utility') ||
              row.owner_payout_reference.toLowerCase().includes('bill') ||
              row.owner_payout_reference.toLowerCase().includes('airtime') ||
              row.owner_payout_reference.toLowerCase().includes('electricity') ||
              row.owner_payout_reference.toLowerCase().includes('token')
            )) ||
            (typeof txRef === 'string' && (
              txRef.startsWith('WD_') || 
              txRef.startsWith('RENTILLY_WD_') ||
              txRef.startsWith('RNT_PWR_') ||
              txRef.startsWith('RNT_AIR_') ||
              txRef.startsWith('RNT_DAT_') ||
              txRef.startsWith('RNT_CBL_') ||
              txRef.startsWith('UTIL_')
            ));

          const isUtility = row.transaction_type === 'utility' ||
            row.escrow_status === 'bill_paid' ||
            row.payment_gateway === 'flutterwave_bills' ||
            (typeof row.owner_payout_reference === 'string' && (
              row.owner_payout_reference.toLowerCase().includes('utility') ||
              row.owner_payout_reference.toLowerCase().includes('bill') ||
              row.owner_payout_reference.toLowerCase().includes('airtime') ||
              row.owner_payout_reference.toLowerCase().includes('electricity') ||
              row.owner_payout_reference.toLowerCase().includes('token')
            )) ||
            (typeof txRef === 'string' && (
              txRef.startsWith('RNT_PWR_') ||
              txRef.startsWith('RNT_AIR_') ||
              txRef.startsWith('RNT_DAT_') ||
              txRef.startsWith('RNT_CBL_') ||
              txRef.startsWith('UTIL_')
            ));

          const mappedCategory = isUtility ? 'utility' : (isDebit ? 'withdrawal' : 'deposit');
          const isCredit = !isDebit;

          const mapped: WalletTransaction = {
            id: row.id,
            userId: row.payer_id || row.user_id,
            email,
            title: title || (isUtility ? 'Utility Bill Payment' : (isDebit ? 'Outbound Bank Transfer' : (row.escrow_status === 'released_to_owner' ? 'Inbound Bank Deposit' : 'Property Escrow Payment'))),
            type: isUtility ? 'Utility Payment' : (isDebit ? 'withdrawal' : (row.transaction_type || 'rent')),
            category: mappedCategory,
            amount: amt,
            currency: row.currency || 'NGN',
            isCredit: isCredit,
            reference: txRef,
            status: (row.escrow_status === 'released_to_owner' || row.escrow_status === 'bill_paid' || row.status === 'SUCCESSFUL' || isDebit) ? 'SUCCESSFUL' : 'PENDING',
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
      deduplicated.sort((a, b) => new Date(b.date || b.createdAt || 0).getTime() - new Date(a.date || a.createdAt || 0).getTime());

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
    const user = await UserStore.findByEmail(cleanEmail);
    const userFullName = (user?.fullName || '').toLowerCase().trim();
    const userBusinessName = (user?.businessName || '').toLowerCase().trim();

    // 1. Strict user-only filter: only include transactions that strictly belong to THIS user
    const filtered = all.filter(t => {
      if ((t.email || '').toLowerCase().trim() !== cleanEmail) return false;
      if (TransactionStore.isTreasuryTransaction(t)) return false;

      // Filter out collections performed by other unrelated users that were erroneously stamped
      const titleLower = (t.title || '').toLowerCase();
      if (titleLower.startsWith('virtual account collection -') || titleLower.startsWith('account funding -')) {
        // Extract the name if present (e.g. "Virtual Account Collection - TOMISIN OLAMIPO KOLAWOLE - 8026990956")
        const parts = titleLower.split(' - ');
        if (parts.length >= 2) {
          const senderInTitle = parts[1].trim();
          if (userFullName && senderInTitle && !senderInTitle.includes(userFullName) && !userFullName.includes(senderInTitle)) {
            // Also check first or last name
            const userWords = userFullName.split(/\s+/).filter(w => w.length > 2);
            const matchesUser = userWords.some(w => senderInTitle.includes(w));
            if (!matchesUser && (!userBusinessName || !senderInTitle.includes(userBusinessName))) {
              return false;
            }
          }
        }
      }

      return true;
    });

    // 2. Strict Deduplication: capture once, never repeat
    const seenRefs = new Set<string>();
    const seenSignatures = new Set<string>();
    const withdrawalSignatures = new Set<string>(); // Tracks withdrawals: amt + timeMinute
    const deduped: WalletTransaction[] = [];

    // First pass: identify real withdrawals to block any mirror ghost deposits
    for (const t of filtered) {
      if (!t.isCredit) {
        const timeMs = new Date(t.date || t.createdAt || 0).getTime();
        const timeMinute = Math.floor(timeMs / 60000);
        if (timeMinute > 0) {
          withdrawalSignatures.add(`${t.amount}_${timeMinute}`);
          withdrawalSignatures.add(`${t.amount}_${timeMinute - 1}`);
          withdrawalSignatures.add(`${t.amount}_${timeMinute + 1}`);
        }
      }
    }

    for (const t of filtered) {
      const ref = (t.reference || t.id || '').trim();
      if (ref && seenRefs.has(ref)) continue;

      const timeMs = new Date(t.date || t.createdAt || 0).getTime();
      const timeMinute = Math.floor(timeMs / 60000);

      // Block ghost deposit that mirrors an identical withdrawal at the same time
      if (t.isCredit && timeMinute > 0 && withdrawalSignatures.has(`${t.amount}_${timeMinute}`)) {
        const titleLower = (t.title || '').toLowerCase();
        if (titleLower.includes('payout') || titleLower.includes('withdrawal') || t.category === 'rent') {
          continue; // Suppress duplicate ghost deposit record
        }
      }

      // Deduplicate identical transactions occurring in the same minute
      const sig = `${t.isCredit ? 'CR' : 'DR'}_${t.amount}_${timeMinute}_${t.title?.substring(0, 15)}`;
      if (timeMinute > 0 && seenSignatures.has(sig)) {
        continue;
      }

      if (ref) seenRefs.add(ref);
      if (timeMinute > 0) seenSignatures.add(sig);
      deduped.push(t);
    }

    return deduped.sort((a, b) => new Date(b.date || b.createdAt || 0).getTime() - new Date(a.date || a.createdAt || 0).getTime());
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

        // Store in wallet_transactions (the true single source of truth for user ledger)
        const cleanRef = tx.reference || `TX_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
        const finalNarration = tx.description && !tx.description.toLowerCase().includes('rentilly payout')
          ? `[${tx.description}] ${tx.title || (tx.isCredit ? 'Inbound Bank Deposit' : 'Outbound Bank Transfer')}`
          : (tx.title || (tx.isCredit ? 'Inbound Bank Deposit' : 'Outbound Bank Transfer'));

        const { error } = await supabase.from('wallet_transactions').upsert({
          user_id: validUserId,
          email: tx.email.toLowerCase().trim(),
          amount: Number(tx.amount || 0),
          type: tx.isCredit ? 'credit' : 'debit',
          status: (tx.status === 'SUCCESSFUL' || tx.status === 'COMPLETED') ? 'completed' : 'pending',
          flw_ref: cleanRef,
          tx_ref: cleanRef,
          narration: finalNarration,
          created_at: tx.date || new Date().toISOString()
        }, { onConflict: 'flw_ref' });

        if (error) {
          console.error('[TransactionStore] Supabase wallet_transactions write error:', error.message);
        } else {
          console.log(`[TransactionStore] Successfully recorded ₦${tx.amount} (${cleanRef}) in Supabase wallet_transactions! ☁️`);
        }
      } catch (err) {
        console.error('[TransactionStore] Supabase transaction network error:', err);
      }
    }

    return tx;
  }

  static recordTransaction = TransactionStore.addTransaction;

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
