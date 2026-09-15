import { supabase } from '../supabaseClient';
import { AtomicLedgerService } from './atomicLedgerService';
import { NotificationDispatcher } from './notificationDispatcher';
import { UserStore } from './userStore';
import { TransactionStore } from './transactionStore';

export interface FailedPayoutDetails {
  reference: string;
  customerReference?: string;
  amount?: number;
  fee?: number;
  failedReason?: string;
  beneficiaryName?: string;
  accountNumber?: string;
}

export class PayoutReversalService {
  private static handledRefs = new Set<string>();

  /**
   * Handle failed payout with guaranteed idempotency and atomic wallet reversal.
   * Ensures user wallet is 100% restored if beneficiary bank rejects transfer.
   */
  static async handleFailedPayout(details: FailedPayoutDetails): Promise<{
    success: boolean;
    refunded: boolean;
    refundAmount?: number;
    reason?: string;
  }> {
    const fincraRef = String(details.reference || '').trim();
    const custRef = String(details.customerReference || '').trim();

    if (!fincraRef && !custRef) {
      return { success: false, refunded: false, reason: 'No payout reference provided' };
    }

    const primaryRef = custRef || fincraRef;
    const refundRef = `REFUND_${primaryRef}`;

    if (this.handledRefs.has(primaryRef) || (fincraRef && this.handledRefs.has(fincraRef))) {
      return { success: true, refunded: false, reason: 'Already handled in current session' };
    }

    console.log(`[PayoutReversal] 🔍 Checking reversal status for ref: ${primaryRef} (Fincra: ${fincraRef})...`);

    if (!supabase) {
      console.error('[PayoutReversal] Supabase client unavailable.');
      return { success: false, refunded: false, reason: 'Database unavailable' };
    }

    try {
      // 1. Idempotency Check: Verify if refund was already issued
      const { data: existingRefund } = await supabase
        .from('wallet_transactions')
        .select('id, amount, created_at')
        .or(`flw_ref.eq.${refundRef},tx_ref.eq.${refundRef}`)
        .maybeSingle();

      if (existingRefund) {
        this.handledRefs.add(primaryRef);
        if (fincraRef) this.handledRefs.add(fincraRef);
        console.log(`[PayoutReversal] ⚡ Idempotency hit: Payout ${primaryRef} already refunded under ${refundRef}. Skipping.`);
        return { success: true, refunded: false, reason: 'Already refunded' };
      }

      // Check in reconciled_transactions as well
      const { data: existingRec } = await supabase
        .from('reconciled_transactions')
        .select('flw_ref')
        .eq('flw_ref', refundRef)
        .maybeSingle();

      if (existingRec) {
        this.handledRefs.add(primaryRef);
        if (fincraRef) this.handledRefs.add(fincraRef);
        console.log(`[PayoutReversal] ⚡ Reconciled hit: Payout ${primaryRef} already recorded in reconciled_transactions. Skipping.`);
        return { success: true, refunded: false, reason: 'Already reconciled' };
      }

      // 2. Locate original debit transaction in wallet_transactions
      let originalDebit: any = null;
      const refFilter = [
        fincraRef ? `flw_ref.eq.${fincraRef}` : null,
        fincraRef ? `tx_ref.eq.${fincraRef}` : null,
        custRef ? `flw_ref.eq.${custRef}` : null,
        custRef ? `tx_ref.eq.${custRef}` : null,
      ].filter(Boolean).join(',');

      if (refFilter) {
        const { data: foundDebit } = await supabase
          .from('wallet_transactions')
          .select('*')
          .or(refFilter)
          .maybeSingle();
        originalDebit = foundDebit;
      }

      // 3. Determine User, Amount & Narration
      let targetUserId: string | null = originalDebit?.user_id || null;
      let targetEmail: string | null = originalDebit?.email || null;
      // Use original debit amount (which includes the withdrawal fee) so user gets back 100% of their debited funds
      let refundAmount = Number(originalDebit?.amount || details.amount || 0);

      // If user not in original debit record, attempt resolution via system configs or profile lookup
      if (!targetUserId || !targetEmail) {
        if (targetEmail) {
          const { data: prof } = await supabase.from('profiles').select('id, email, full_name').eq('email', targetEmail).maybeSingle();
          if (prof) {
            targetUserId = prof.id;
            targetEmail = prof.email;
          }
        }
      }

      if (!targetUserId || !targetEmail || refundAmount <= 0) {
        this.handledRefs.add(primaryRef);
        if (fincraRef) this.handledRefs.add(fincraRef);
        console.warn(`[PayoutReversal] ⚠️ Could not resolve target user or amount for failed payout ${primaryRef}. User: ${targetEmail || targetUserId}, Amount: ${refundAmount}`);
        return { success: false, refunded: false, reason: 'Target user or refund amount not resolved' };
      }

      const failReasonClean = details.failedReason || 'Beneficiary bank rejected payment';
      const beneficiaryDisplay = details.beneficiaryName || originalDebit?.narration?.split('Payout to ')?.[1]?.split(' •')?.[0] || 'destination account';

      console.log(`[PayoutReversal] 🔄 Reversing failed payout of ₦${refundAmount.toLocaleString()} to ${targetEmail}...`);

      // 4. Update the original debit transaction to status: 'failed'
      if (originalDebit?.id) {
        await supabase
          .from('wallet_transactions')
          .update({
            status: 'failed',
            narration: `[FAILED & REFUNDED] ${originalDebit.narration || `Payout to ${beneficiaryDisplay}`}`
          })
          .eq('id', originalDebit.id);
      }

      // 5. Atomically credit the user's wallet with the full refund
      const refundNarration = `Refund: Reversal of failed payout to ${beneficiaryDisplay} • ${failReasonClean}`;
      const creditRes = await AtomicLedgerService.creditWalletAtomic({
        userId: targetUserId,
        email: targetEmail,
        amount: refundAmount,
        flwRef: refundRef,
        txRef: refundRef,
        narration: refundNarration
      });

      if (!creditRes.success && !creditRes.alreadyProcessed) {
        console.error(`[PayoutReversal] ❌ Atomic wallet refund failed for ${targetEmail}: ${creditRes.error}`);
        return { success: false, refunded: false, reason: creditRes.error };
      }

      // 6. Update in-memory UserStore cache
      const memUser = await UserStore.findByEmail(targetEmail);
      if (memUser) {
        const updatedBal = creditRes.newBalance ?? (Number(memUser.walletBalance || 0) + refundAmount);
        UserStore.upsertUserForced({
          ...memUser,
          walletBalance: updatedBal,
          updatedAt: new Date().toISOString()
        });
      }

      // 7. Record in TransactionStore
      await TransactionStore.addTransaction({
        id: `TX_REFUND_${primaryRef}`,
        userId: targetUserId,
        email: targetEmail,
        title: `Refund: Failed Payout to ${beneficiaryDisplay} Reversed`,
        description: `Your payout was rejected by the beneficiary bank (${failReasonClean}). The full amount has been refunded to your wallet.`,
        type: 'credit',
        category: 'refund',
        amount: refundAmount,
        currency: 'NGN',
        isCredit: true,
        reference: refundRef,
        sender: 'Rentilly Instant Reversal Rail',
        beneficiary: targetEmail,
        recipientAccount: targetEmail,
        recipientBank: 'Rentilly Escrow Wallet',
        status: 'SUCCESSFUL',
        date: new Date().toISOString()
      });

      // 8. Dispatch Real-Time Push Notification & In-App Alert to the User
      const newBal = creditRes.newBalance ?? 0;
      NotificationDispatcher.dispatch({
        userId: targetUserId,
        email: targetEmail,
        userName: memUser?.fullName || 'Valued User',
        category: 'wallet',
        title: `Withdrawal Refund: ₦${refundAmount.toLocaleString()} Credited Back 🔄`,
        message: `Your withdrawal of ₦${refundAmount.toLocaleString()} to ${beneficiaryDisplay} could not be completed by the recipient bank (${failReasonClean}). The full amount has been automatically credited back to your wallet. New Balance: ₦${newBal.toLocaleString()}.`,
        metadata: {
          amount: refundAmount,
          reference: refundRef,
          reason: failReasonClean,
          date: new Date().toISOString()
        }
      }).catch(e => console.warn('[PayoutReversal] Notification dispatch error:', e.message));

      console.log(`[PayoutReversal] 🎉 Successfully refunded ₦${refundAmount.toLocaleString()} to ${targetEmail} (ref: ${refundRef})!`);

      return {
        success: true,
        refunded: true,
        refundAmount,
        reason: 'Refund issued successfully'
      };
    } catch (err: any) {
      console.error(`[PayoutReversal] Exception during failed payout handling for ${primaryRef}:`, err.message);
      return { success: false, refunded: false, reason: err.message };
    }
  }
}
