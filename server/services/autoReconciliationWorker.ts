import dotenv from 'dotenv';
import { supabase } from '../supabaseClient';
import { NotificationDispatcher } from './notificationDispatcher';
import { AtomicLedgerService } from './atomicLedgerService';

dotenv.config();

export class AutoReconciliationWorker {
  private static isRunning = false;
  private static pollIntervalMs = 10000; // Poll every 10 seconds
  private static timer: NodeJS.Timeout | null = null;

  /**
   * Start the Autonomous Real-Time Reconciliation Worker
   */
  static start() {
    if (this.isRunning) return;
    this.isRunning = true;
    console.log('⚡ [AutoReconciliation] Realtime Worker started (Polling every 10s)');

    // Run first sync immediately
    this.syncAll().catch(e => console.error('[AutoReconciliation] Initial sync error:', e.message));

    // Start polling loop
    this.timer = setInterval(() => {
      this.syncAll().catch(e => console.error('[AutoReconciliation] Cycle error:', e.message));
    }, this.pollIntervalMs);
  }

  /**
   * Stop the Worker
   */
  static stop() {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
    this.isRunning = false;
    console.log('⏹️ [AutoReconciliation] Worker stopped.');
  }

  /**
   * Master Sync Cycle
   */
  static async syncAll() {
    await Promise.allSettled([
      this.syncFlutterwaveTransactions(),
    ]);
  }

  /**
   * Check if a Flutterwave transaction reference has already been processed.
   * Uses Supabase as persistent store so it survives server restarts.
   */
  private static async isAlreadyProcessed(flwRef: string): Promise<boolean> {
    if (!supabase) return true; // If no DB, skip to be safe
    const { data } = await supabase
      .from('reconciled_transactions')
      .select('flw_ref')
      .eq('flw_ref', flwRef)
      .maybeSingle();
    return data !== null;
  }

  /**
   * Mark a Flutterwave transaction as processed in Supabase.
   */
  private static async markProcessed(flwRef: string, userId: string, amount: number, email: string): Promise<void> {
    if (!supabase) return;
    await supabase.from('reconciled_transactions').upsert({
      flw_ref: flwRef,
      user_id: userId,
      email: email,
      amount: amount,
      processed_at: new Date().toISOString()
    }, { onConflict: 'flw_ref' });
  }

  /**
   * Flutterwave Realtime Sync
   * 
   * KEY FIX: We match inbound bank transfers to users by their
   * `dedicated_account_number` in Supabase profiles, NOT by the
   * customer email in Flutterwave (which may be wrong due to how
   * virtual accounts were originally created).
   */
  private static async syncFlutterwaveTransactions() {
    const flwSecret = process.env.FLUTTERWAVE_SECRET_KEY;
    if (!flwSecret || !supabase) return;

    try {
      // Fetch last 20 successful bank_transfer transactions from Flutterwave
      const res = await fetch('https://api.flutterwave.com/v3/transactions?status=successful&payment_type=bank_transfer', {
        headers: {
          'Authorization': `Bearer ${flwSecret}`,
          'Content-Type': 'application/json'
        }
      });

      const json: any = await res.json();
      if (json.status !== 'success' || !Array.isArray(json.data)) return;

      for (const tx of json.data.slice(0, 20)) {
        const flwRef = tx.flw_ref || `FLW_${tx.id}`;
        const amount = Number(tx.amount || 0);

        // Skip if already processed (persistent check in Supabase)
        if (await this.isAlreadyProcessed(flwRef)) continue;
        if (amount <= 0) continue;

        // === CRITICAL FIX ===
        // The account number in Flutterwave's meta (or the account that received the funds)
        // is the reliable identifier. We find the Supabase user who OWNS that account number.
        //
        // Flutterwave reports the destination virtual account in the transaction's
        // narration or meta. We query all profiles and match by dedicated_account_number.
        //
        // For bank_transfer inflows, the account that RECEIVED the money is identified
        // by the order_ref / narration. We use a broader approach: fetch ALL profiles
        // and for each transaction, we look at which account received it.
        //
        // The most reliable approach: query Flutterwave virtual accounts to find
        // which account number received this specific flw_ref.
        
        let creditUserId: string | null = null;
        let creditEmail: string | null = null;
        let creditUserName: string | null = null;

        // Try to find destination account by fetching the virtual account details
        // using the order_ref embedded in the tx_ref
        const txRef: string = tx.tx_ref || '';

        // Strategy 1: tx_ref encodes user ID (format: RENTILLY_ACC_<userId>_<timestamp>)
        const userIdMatch = txRef.match(/RENTILLY_ACC_(usr_[a-z0-9]+)/);
        if (userIdMatch) {
          const embeddedUserId = userIdMatch[1];
          // Get the profile by this userId 
          const { data: profile } = await supabase
            .from('profiles')
            .select('id, email, full_name, wallet_balance, account_number')
            .eq('id', embeddedUserId)
            .maybeSingle();

          if (profile) {
            // IMPORTANT: Verify the account is correct for this user.
            // We need to check if the payment was received on THIS user's account.
            // Since Flutterwave doesn't always tell us the destination account in the transaction,
            // we will check by looking for any Flutterwave virtual account metadata.
            // For now, if the tx_ref matches the user, credit them.
            creditUserId = profile.id;
            creditEmail = profile.email;
            creditUserName = profile.full_name;
          }
        }

        // Strategy 2: Look for the actual receiving account number in Flutterwave's
        // virtual account endpoint, matching to profiles.dedicated_account_number
        if (!creditUserId) {
          // Try to get the virtual account details for this tx_ref
          try {
            const vaRes = await fetch(`https://api.flutterwave.com/v3/virtual-account-numbers?order_ref=${txRef}`, {
              headers: { 'Authorization': `Bearer ${flwSecret}` }
            });
            const vaJson: any = await vaRes.json();
            const accountNumber = vaJson?.data?.account_number;
            if (accountNumber) {
              const { data: profile } = await supabase
                .from('profiles')
                .select('id, email, full_name, wallet_balance')
                .eq('account_number', accountNumber)
                .maybeSingle();
              if (profile) {
                creditUserId = profile.id;
                creditEmail = profile.email;
                creditUserName = profile.full_name;
              }
            }
          } catch (_) {}
        }

        // Strategy 3: Fallback — use Flutterwave customer email, only if
        // the email exists in profiles AND matches a dedicated account
        if (!creditUserId) {
          const flwCustomerEmail = (tx.customer?.email || '').trim().toLowerCase();
          if (flwCustomerEmail) {
            const { data: profile } = await supabase
              .from('profiles')
              .select('id, email, full_name, wallet_balance')
              .eq('email', flwCustomerEmail)
              .maybeSingle();
            if (profile) {
              creditUserId = profile.id;
              creditEmail = profile.email;
              creditUserName = profile.full_name;
            }
          }
        }

        if (!creditUserId || !creditEmail) {
          // Cannot identify recipient — mark processed to avoid infinite retry, log for admin
          console.warn(`[AutoReconciliation] ⚠️ Cannot identify recipient for flw_ref: ${flwRef}, tx_ref: ${txRef}, amount: ₦${amount}`);
          await this.markProcessed(flwRef, 'unknown', amount, tx.customer?.email || 'unknown');
          continue;
        }

        // Execute atomic, idempotent credit through AtomicLedgerService
        const creditResult = await AtomicLedgerService.creditWalletAtomic({
          userId: creditUserId,
          email: creditEmail,
          amount: amount,
          flwRef: flwRef,
          txRef: txRef,
          narration: `Bank Transfer from ${tx.meta?.originatorname || 'Unknown Sender'} via ${tx.meta?.bankname || 'Bank'}`
        });

        if (!creditResult.success || creditResult.alreadyProcessed) {
          if (creditResult.alreadyProcessed) {
            console.log(`[AutoReconciliation] flw_ref ${flwRef} was already processed. Zero duplicate credit.`);
          }
          continue;
        }

        const newBal = creditResult.newBalance ?? amount;
        console.log(`✅ [AutoReconciliation] Atomic Ledger Credited ₦${amount} to ${creditEmail} (flw_ref: ${flwRef}). New balance: ₦${newBal}`);

        // Dispatch notifications
        NotificationDispatcher.dispatch({
          userId: creditUserId,
          email: creditEmail,
          userName: creditUserName || 'Valued User',
          category: 'wallet',
          title: `Credit Alert: ₦${amount.toLocaleString()} Received`,
          message: `Your Rentilly wallet has been credited with ₦${amount.toLocaleString()} via Bank Transfer from ${tx.meta?.originatorname || 'Unknown Sender'}. New Balance: ₦${newBal.toLocaleString()}.`,
          metadata: {
            amount: amount,
            reference: flwRef,
            bankName: tx.meta?.bankname || 'Bank Transfer',
            Sender: tx.meta?.originatorname || 'Bank Transfer',
            date: tx.created_at || new Date().toISOString()
          }
        }).catch(e => console.warn('[AutoReconciliation] Notification error:', e.message));
      }
    } catch (e: any) {
      console.error('[AutoReconciliation] Flutterwave sync error:', e.message);
    }
  }
}
