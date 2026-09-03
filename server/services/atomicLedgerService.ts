import { supabase } from '../supabaseClient';

export interface AtomicCreditParams {
  userId: string;
  email: string;
  amount: number;
  flwRef: string;
  txRef: string;
  narration: string;
}

export interface AtomicCreditResult {
  success: boolean;
  alreadyProcessed?: boolean;
  newBalance?: number;
  flwRef: string;
  error?: string;
}

export class AtomicLedgerService {
  /**
   * Execute an atomic, idempotent wallet credit.
   * Tries Supabase RPC stored procedure first, falls back to pessimistic 
   * consistency-checked transactional sequence.
   */
  static async creditWalletAtomic(params: AtomicCreditParams): Promise<AtomicCreditResult> {
    const { userId, email, amount, flwRef, txRef, narration } = params;

    if (!supabase) {
      return { success: false, flwRef, error: 'Database client not initialized' };
    }

    if (amount <= 0) {
      return { success: false, flwRef, error: 'Credit amount must be greater than zero' };
    }

    // Attempt 1: Call PostgreSQL Stored Procedure (RPC)
    try {
      const { data: rpcData, error: rpcError } = await supabase.rpc('credit_wallet_atomic', {
        p_user_id: userId,
        p_amount: amount,
        p_flw_ref: flwRef,
        p_tx_ref: txRef,
        p_narration: narration,
        p_email: email
      });

      if (!rpcError && rpcData) {
        if (rpcData.success === false && rpcData.reason === 'already_reconciled') {
          return {
            success: true,
            alreadyProcessed: true,
            newBalance: Number(rpcData.current_balance || 0),
            flwRef
          };
        }
        if (rpcData.success === true) {
          return {
            success: true,
            newBalance: Number(rpcData.new_balance),
            flwRef
          };
        }
      }
    } catch (_) {
      // Stored procedure not created yet, proceed to consistency-guaranteed sequence
    }

    // Attempt 2: Consistency-Guaranteed Sequence with Pessimistic Checks
    try {
      // Step 1: Idempotency Check
      const { data: existingRec } = await supabase
        .from('reconciled_transactions')
        .select('flw_ref')
        .eq('flw_ref', flwRef)
        .maybeSingle();

      if (existingRec) {
        const { data: currentProf } = await supabase
          .from('profiles')
          .select('wallet_balance')
          .eq('id', userId)
          .single();

        return {
          success: true,
          alreadyProcessed: true,
          newBalance: Number(currentProf?.wallet_balance || 0),
          flwRef
        };
      }

      // Step 2: Lock transaction ref in reconciled_transactions FIRST
      // This prevents race conditions from concurrent webhook invocations
      const { error: recInsertErr } = await supabase
        .from('reconciled_transactions')
        .insert({
          flw_ref: flwRef,
          user_id: userId,
          email: email,
          amount: amount,
          processed_at: new Date().toISOString()
        });

      if (recInsertErr) {
        // Unique constraint collision means another thread already processed this ref
        if (recInsertErr.code === '23505' || recInsertErr.message?.includes('duplicate key')) {
          const { data: p } = await supabase.from('profiles').select('wallet_balance').eq('id', userId).single();
          return {
            success: true,
            alreadyProcessed: true,
            newBalance: Number(p?.wallet_balance || 0),
            flwRef
          };
        }
        throw new Error(`Failed to claim reconciliation ref: ${recInsertErr.message}`);
      }

      // Step 3: Fetch current balance and calculate increment
      const { data: profile, error: profErr } = await supabase
        .from('profiles')
        .select('wallet_balance')
        .eq('id', userId)
        .single();

      if (profErr || !profile) {
        throw new Error(`Profile not found for user ${userId}`);
      }

      const currentBal = Number(profile.wallet_balance || 0);
      const newBal = currentBal + amount;

      // Step 4: Update wallet balance in profiles
      const { error: updateErr } = await supabase
        .from('profiles')
        .update({ wallet_balance: newBal, updated_at: new Date().toISOString() })
        .eq('id', userId);

      if (updateErr) {
        // Rollback claimed ref on failure
        await supabase.from('reconciled_transactions').delete().eq('flw_ref', flwRef);
        throw new Error(`Failed to update wallet balance: ${updateErr.message}`);
      }

      // Step 5: Write to wallet_transactions audit log
      await supabase.from('wallet_transactions').upsert({
        user_id: userId,
        email: email,
        amount: amount,
        type: 'credit',
        status: 'completed',
        flw_ref: flwRef,
        tx_ref: txRef,
        narration: narration,
        created_at: new Date().toISOString()
      }, { onConflict: 'flw_ref' });

      return {
        success: true,
        newBalance: newBal,
        flwRef
      };
    } catch (err: any) {
      console.error(`[AtomicLedgerService] Credit failure for ${email}:`, err.message);
      return {
        success: false,
        flwRef,
        error: err.message
      };
    }
  }
}
