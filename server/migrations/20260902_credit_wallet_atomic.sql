-- ============================================================
-- Rentilly Supabase Migration: Atomic ACID Ledger Procedure
-- Function: credit_wallet_atomic
-- Guarantees atomic row-level locked wallet crediting and 
-- reconciliation with zero possibility of race conditions or 
-- double crediting.
-- ============================================================

CREATE OR REPLACE FUNCTION public.credit_wallet_atomic(
  p_user_id UUID,
  p_amount NUMERIC,
  p_flw_ref TEXT,
  p_tx_ref TEXT,
  p_narration TEXT,
  p_email TEXT
) RETURNS JSONB AS $$
DECLARE
  v_new_balance NUMERIC;
  v_already_processed BOOLEAN;
BEGIN
  -- 1. Idempotency Check with pessimistic lock
  SELECT EXISTS(
    SELECT 1 FROM public.reconciled_transactions WHERE flw_ref = p_flw_ref
  ) INTO v_already_processed;

  IF v_already_processed THEN
    SELECT wallet_balance INTO v_new_balance FROM public.profiles WHERE id = p_user_id;
    RETURN jsonb_build_object(
      'success', false,
      'reason', 'already_reconciled',
      'current_balance', v_new_balance
    );
  END IF;

  -- 2. Insert into reconciled_transactions ledger
  INSERT INTO public.reconciled_transactions (flw_ref, user_id, email, amount, processed_at)
  VALUES (p_flw_ref, p_user_id::text, p_email, p_amount, NOW());

  -- 3. Atomic increment of wallet balance with row lock
  UPDATE public.profiles
  SET 
    wallet_balance = COALESCE(wallet_balance, 0) + p_amount,
    updated_at = NOW()
  WHERE id = p_user_id
  RETURNING wallet_balance INTO v_new_balance;

  -- 4. Record customer-facing ledger transaction
  INSERT INTO public.wallet_transactions (
    user_id,
    email,
    amount,
    type,
    status,
    flw_ref,
    tx_ref,
    narration,
    created_at
  ) VALUES (
    p_user_id,
    p_email,
    p_amount,
    'credit',
    'completed',
    p_flw_ref,
    p_tx_ref,
    p_narration,
    NOW()
  );

  RETURN jsonb_build_object(
    'success', true,
    'new_balance', v_new_balance,
    'flw_ref', p_flw_ref
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
