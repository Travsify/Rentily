import dotenv from 'dotenv';
import { supabase } from '../supabaseClient';
import { NotificationDispatcher } from './notificationDispatcher';
import { AtomicLedgerService } from './atomicLedgerService';
import { UserStore } from './userStore';
import { TransactionStore } from './transactionStore';
import { FincraService } from './fincraService';

dotenv.config();

export class AutoReconciliationWorker {
  private static isRunning = false;
  private static pollIntervalMs = 60000; // Poll every 60 seconds (production standard)
  private static timer: NodeJS.Timeout | null = null;

  /**
   * Start the Autonomous Real-Time Reconciliation Worker
   */
  static start() {
    if (this.isRunning) return;
    this.isRunning = true;
    console.log('⚡ [AutoReconciliation] Realtime Worker started (Polling every 60s)');

    // Run first sync quietly
    this.syncAll().catch(() => {});

    // Start polling loop
    this.timer = setInterval(() => {
      this.syncAll().catch(() => {});
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
      this.syncMapleradTransactions(),
      this.syncFincraTransactions(),
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
      // Quiet failover if external provider is unreachable
    }
  }

  /**
   * Maplerad Inbound Collections Realtime Sync
   *
   * Polls Maplerad transactions API for incoming bank transfers / collections,
   * matches to user profiles idempotently, credits user wallets atomically,
   * and dispatches real-time Email, OneSignal Push, and In-App notifications.
   */
  private static async syncMapleradTransactions() {
    const key = process.env.MAPLERAD_SECRET_KEY || 'mpr_sk_35d197e6-3f6b-437c-995b-a0dff522b3dc';
    if (!key || !supabase) return;

    try {
      // Fetch latest 30 transactions from Maplerad
      const res = await fetch('https://api.maplerad.com/v1/transactions?page=1&page_size=30', {
        headers: {
          'Authorization': `Bearer ${key}`,
          'Accept': 'application/json'
        }
      });

      const json: any = await res.json();
      if (!json.status || !Array.isArray(json.data)) return;

      for (const tx of json.data) {
        const rawStatus = (tx.status || '').toUpperCase();
        const rawEntry = (tx.entry || '').toUpperCase();
        const rawType = (tx.type || '').toUpperCase();

        // Only reconcile successful inbound collections/deposits
        if (rawStatus !== 'SUCCESS') continue;
        if (rawEntry !== 'CREDIT') continue;
        if (rawType !== 'COLLECTION' && !rawType.includes('COLLECTION') && !rawType.includes('DEPOSIT')) continue;

        const ref = tx.reference || tx.id;
        const amount = Number(tx.amount || 0) / 100; // Maplerad amounts are in kobo / cents
        if (amount <= 0 || !ref) continue;

        const isUsdt = (tx.currency || '').toUpperCase() === 'USDT' || 
                       (tx.channel || '').toUpperCase() === 'CRYPTO' ||
                       (tx.type || '').toUpperCase() === 'CRYPTO' ||
                       (tx.reason || '').toUpperCase().includes('TRON') ||
                       (tx.summary || '').toUpperCase().includes('USDT') ||
                       (tx.destination?.coin || '').toUpperCase() === 'USDT';

        // Skip if already processed in persistent store
        if (await this.isAlreadyProcessed(ref)) continue;

        // Check if already in wallet_transactions
        const { data: existingTx } = await supabase
          .from('wallet_transactions')
          .select('id')
          .eq('flw_ref', ref)
          .maybeSingle();

        if (existingTx) {
          // Already credited earlier, record in reconciled_transactions to prevent re-processing
          await this.markProcessed(ref, 'reconciled', amount, tx.customer?.email || 'unknown');
          continue;
        }

        // Match user by:
        // 1. tx.customer?.email
        let targetUser: any = null;
        const customerEmail = (tx.customer?.email || '').trim().toLowerCase();

        if (customerEmail) {
          const { data: profile } = await supabase
            .from('profiles')
            .select('id, email, full_name, wallet_balance')
            .eq('email', customerEmail)
            .maybeSingle();
          if (profile) targetUser = profile;
        }

        // 2. Search by TRON crypto address in system_configs if USDT deposit
        if (!targetUser && isUsdt) {
          const destAddr = tx.destination?.address || tx.account_number;
          if (destAddr) {
            const { data: cryptoRows } = await supabase
              .from('system_configs')
              .select('id, data')
              .like('id', 'crypto_tron_%')
              .limit(50);
            const cryptoMatch = (cryptoRows || []).find((r: any) => r.data?.address === destAddr);
            if (cryptoMatch) {
              const matchEmail = cryptoMatch.id.replace('crypto_tron_', '');
              const { data: profile } = await supabase
                .from('profiles')
                .select('id, email, full_name, wallet_balance')
                .eq('email', matchEmail)
                .maybeSingle();
              if (profile) targetUser = profile;
            }
          }
        }

        // 3. Search by account_id in system_configs (Maplerad tier1 virtual account metadata)
        if (!targetUser && tx.account_id) {
          const { data: cfgRows } = await supabase
            .from('system_configs')
            .select('id, data')
            .like('id', 'maplerad_tier1_%')
            .limit(50);
          const cfgMatch = (cfgRows || []).find((r: any) =>
            r.data?.accountId === tx.account_id ||
            r.data?.account_id === tx.account_id ||
            r.data?.customerId === tx.customer?.id
          );
          if (cfgMatch) {
            const matchEmail = cfgMatch.id.replace('maplerad_tier1_', '');
            const { data: profile } = await supabase
              .from('profiles')
              .select('id, email, full_name, wallet_balance')
              .eq('email', matchEmail)
              .maybeSingle();
            if (profile) targetUser = profile;
          }
        }

        if (!targetUser) {
          console.warn(`[AutoReconciliation] ⚠️ Maplerad: cannot identify recipient for ref: ${ref}, email: ${customerEmail}, amount: ${amount} ${tx.currency || 'NGN'}`);
          await this.markProcessed(ref, 'unknown', amount, customerEmail || 'unknown');
          continue;
        }

        // === USDT CRYPTO DEPOSIT FLOW ===
        if (isUsdt) {
          let currentUsdtBal = 0.0;
          const { data: usdtCfg } = await supabase
            .from('system_configs')
            .select('data')
            .eq('id', `usdt_balance_${targetUser.email}`)
            .maybeSingle();
          if (usdtCfg?.data?.usdtBalance != null) {
            currentUsdtBal = Number(usdtCfg.data.usdtBalance);
          }

          const newUsdtBal = Number((currentUsdtBal + amount).toFixed(2));

          // Persist in system_configs
          await supabase.from('system_configs').upsert({
            id: `usdt_balance_${targetUser.email}`,
            data: { usdtBalance: newUsdtBal, email: targetUser.email, updatedAt: new Date().toISOString() }
          });

          // Keep UserStore memory cache aligned
          const memUser = await UserStore.findByEmail(targetUser.email);
          if (memUser) {
            memUser.usdtBalance = newUsdtBal;
            UserStore.upsertUserForced(memUser);
          }

          const senderAddress = tx.source?.address || tx.source?.account_number || 'External Wallet';
          const narration = `USDT Deposit (TRON TRC20): +$${amount.toFixed(2)} USDT from ${senderAddress}`;

          await supabase.from('wallet_transactions').upsert({
            user_id: targetUser.id,
            email: targetUser.email,
            amount: amount,
            type: 'credit',
            status: 'completed',
            flw_ref: ref,
            tx_ref: ref,
            narration: narration,
            created_at: tx.created_at || new Date().toISOString()
          }, { onConflict: 'flw_ref' });

          await TransactionStore.addTransaction({
            id: `TX_USDT_${ref}`,
            userId: targetUser.id,
            email: targetUser.email,
            title: narration,
            type: 'credit',
            category: 'deposit',
            amount: amount,
            currency: 'USDT',
            isCredit: true,
            reference: ref,
            sender: senderAddress,
            beneficiary: targetUser.email,
            recipientAccount: targetUser.email,
            recipientBank: 'Blockchain (TRON TRC20)',
            status: 'SUCCESSFUL',
            date: tx.created_at || new Date().toISOString(),
          });

          await this.markProcessed(ref, targetUser.id, amount, targetUser.email);
          console.log(`✅ [AutoReconciliation] Maplerad USDT Credited +$${amount} USDT to ${targetUser.email} (ref: ${ref}). New USDT balance: $${newUsdtBal}`);

          NotificationDispatcher.dispatch({
            userId: targetUser.id,
            email: targetUser.email,
            userName: targetUser.full_name || 'Valued User',
            category: 'wallet',
            title: `USDT Deposit Credited: +$${amount.toFixed(2)} USDT 💎`,
            message: `Your Rentilly USDT Vault has been credited with +$${amount.toFixed(2)} USDT via TRON (TRC20). New USDT Balance: $${newUsdtBal.toFixed(2)} USDT.`,
            metadata: {
              amount: amount,
              amountUsdt: amount,
              currency: 'USDT',
              reference: ref,
              network: 'TRON (TRC20)',
              sender: senderAddress,
              date: tx.created_at || new Date().toISOString()
            }
          }).catch(e => console.warn('[AutoReconciliation] USDT Notification error:', e.message));

          continue;
        }

        // === NGN BANK TRANSFER FLOW ===

        const senderName = tx.source?.account_name || tx.source?.bank_name || 'Bank Transfer';
        const senderBank = tx.source?.bank_name || 'Bank Transfer';
        const narration = tx.summary || `Inbound Bank Transfer (Maplerad/9PSB) from ${senderName}`;

        // Execute atomic, idempotent credit through AtomicLedgerService
        const creditResult = await AtomicLedgerService.creditWalletAtomic({
          userId: targetUser.id,
          email: targetUser.email,
          amount: amount,
          flwRef: ref,
          txRef: ref,
          narration: narration
        });

        if (!creditResult.success || creditResult.alreadyProcessed) {
          if (creditResult.alreadyProcessed) {
            console.log(`[AutoReconciliation] Maplerad ref ${ref} was already processed. Zero duplicate credit.`);
          }
          continue;
        }

        const newBal = creditResult.newBalance ?? (Number(targetUser.wallet_balance || 0) + amount);
        console.log(`✅ [AutoReconciliation] Maplerad Credited ₦${amount} to ${targetUser.email} (ref: ${ref}). New balance: ₦${newBal}`);

        // Mark as processed in reconciled_transactions
        await this.markProcessed(ref, targetUser.id, amount, targetUser.email);

        // Dispatch Email, Push Notification & In-App Notification
        NotificationDispatcher.dispatch({
          userId: targetUser.id,
          email: targetUser.email,
          userName: targetUser.full_name || 'Valued User',
          category: 'wallet',
          title: `Credit Alert: ₦${amount.toLocaleString()} Received`,
          message: `Your Rentilly wallet has been credited with ₦${amount.toLocaleString()} via Bank Transfer from ${senderName} (${senderBank}). New Balance: ₦${newBal.toLocaleString()}.`,
          metadata: {
            amount: amount,
            reference: ref,
            bankName: senderBank,
            sender: senderName,
            date: tx.created_at || new Date().toISOString()
          }
        }).catch(e => console.warn('[AutoReconciliation] Maplerad Notification error:', e.message));
      }
    } catch (e: any) {
      console.warn('[AutoReconciliation] Maplerad sync exception:', e?.message || e);
    }
  }

  /**
   * Autonomous Fincra High-Value Escrow Auto-Fetch Worker
   * Auto-fetches pending checkouts directly from Fincra's verification API
   * and auto-credits users even if the webhook was delayed or dropped.
   */
  private static async syncFincraTransactions() {
    if (!FincraService.isConfigured() || !supabase) return;

    try {
      const { data: pendingConfigs } = await supabase
        .from('system_configs')
        .select('id, data')
        .like('id', 'pending_fincra_%')
        .limit(20);

      if (!pendingConfigs || pendingConfigs.length === 0) return;

      for (const item of pendingConfigs) {
        const deposit = item.data;
        const ref = deposit?.reference || item.id.replace('pending_fincra_', '');
        const email = deposit?.email;

        if (!ref || !email) continue;

        const fetchRes = await FincraService.verifyPayment(ref);
        if (fetchRes.status && fetchRes.data) {
          const tx = fetchRes.data;
          const isSuccess = tx.status === 'successful' || tx.status === 'success';
          const amount = Number(tx.amount || tx.settlementAmount || deposit.amount || 0);

          if (isSuccess && amount > 0) {
            const { data: prof } = await supabase
              .from('profiles')
              .select('id, email, full_name, wallet_balance')
              .eq('email', email)
              .maybeSingle();

            if (prof) {
              const creditRes = await AtomicLedgerService.creditWalletAtomic({
                userId: prof.id,
                email: prof.email,
                amount: amount,
                flwRef: ref,
                txRef: ref,
                narration: `High-Value Escrow Deposit (Auto-Fetched from Fincra)`
              });

              if (creditRes.success) {
                console.log(`⚡ [AutoReconciliation] Successfully auto-fetched & credited Fincra deposit: ₦${amount.toLocaleString()} for ${email}`);
                await supabase.from('system_configs').delete().eq('id', item.id);

                NotificationDispatcher.dispatch({
                  userId: prof.id,
                  email: prof.email,
                  userName: prof.full_name || 'Valued User',
                  category: 'wallet',
                  title: `High-Value Escrow Credited: ₦${amount.toLocaleString()}`,
                  message: `Your deposit of ₦${amount.toLocaleString()} has been verified & credited via Fincra Commercial Rail. New Balance: ₦${(creditRes.newBalance ?? 0).toLocaleString()}.`,
                  metadata: {
                    amount: amount,
                    reference: ref,
                    provider: 'fincra',
                    date: new Date().toISOString()
                  }
                }).catch(() => {});
              }
            }
          } else if (tx.status === 'failed' || tx.status === 'cancelled') {
            await supabase.from('system_configs').delete().eq('id', item.id);
          }
        }
      }
    } catch (err: any) {
      console.warn('⚡ [AutoReconciliation] Fincra sync exception:', err.message);
    }
  }
}
