-- ==============================================================================
-- RENTILLY PRODUCTION SECURITY & ROW-LEVEL SECURITY (RLS) HARDENING
-- Migration: 20260927000002_harden_rls_and_security.sql
-- ==============================================================================

-- 1. HARDEN SYSTEM_CONFIGS (CRITICAL: Block Anonymous Credential Leakage)
ALTER TABLE IF EXISTS system_configs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read system_configs" ON system_configs;
DROP POLICY IF EXISTS "Allow public write system_configs" ON system_configs;
DROP POLICY IF EXISTS "Service role full access to system_configs" ON system_configs;
DROP POLICY IF EXISTS "Admins full access to system_configs" ON system_configs;

CREATE POLICY "Service role full access to system_configs"
    ON system_configs
    FOR ALL
    USING (
        auth.jwt() ->> 'role' = 'service_role' OR
        current_setting('request.jwt.claim.role', true) = 'service_role'
    )
    WITH CHECK (
        auth.jwt() ->> 'role' = 'service_role' OR
        current_setting('request.jwt.claim.role', true) = 'service_role'
    );

-- 2. HARDEN VIRTUAL_CARDS (CRITICAL: Block Anonymous Card Dumps & Balance Mutation)
CREATE TABLE IF NOT EXISTS virtual_cards (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    card_id TEXT UNIQUE NOT NULL,
    account_id TEXT,
    currency TEXT DEFAULT 'USD',
    card_type TEXT DEFAULT 'virtual',
    brand TEXT DEFAULT 'Mastercard',
    masked_pan TEXT,
    expiry_month TEXT,
    expiry_year TEXT,
    status TEXT DEFAULT 'active',
    balance NUMERIC(15, 2) DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_virtual_cards_user ON virtual_cards(user_id);
CREATE INDEX IF NOT EXISTS idx_virtual_cards_card_id ON virtual_cards(card_id);

ALTER TABLE virtual_cards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own cards" ON virtual_cards;
DROP POLICY IF EXISTS "Service role full access to virtual_cards" ON virtual_cards;
DROP POLICY IF EXISTS "Admins view all cards" ON virtual_cards;

CREATE POLICY "Users can view their own cards"
    ON virtual_cards
    FOR SELECT
    USING (
        auth.uid()::text = user_id OR
        auth.jwt() ->> 'email' IN (SELECT email FROM profiles WHERE id::text = virtual_cards.user_id) OR
        auth.jwt() ->> 'role' = 'service_role' OR
        current_setting('request.jwt.claim.role', true) = 'service_role'
    );

CREATE POLICY "Service role full access to virtual_cards"
    ON virtual_cards
    FOR ALL
    USING (
        auth.jwt() ->> 'role' = 'service_role' OR
        current_setting('request.jwt.claim.role', true) = 'service_role'
    )
    WITH CHECK (
        auth.jwt() ->> 'role' = 'service_role' OR
        current_setting('request.jwt.claim.role', true) = 'service_role'
    );

-- 3. HARDEN WALLET TRANSACTIONS & RECONCILIATIONS
ALTER TABLE IF EXISTS wallet_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own wallet transactions" ON wallet_transactions;
DROP POLICY IF EXISTS "Service role full access to wallet_transactions" ON wallet_transactions;

CREATE POLICY "Users can view their own wallet transactions"
    ON wallet_transactions
    FOR SELECT
    USING (
        auth.uid()::text = user_id OR
        auth.jwt() ->> 'role' = 'service_role' OR
        current_setting('request.jwt.claim.role', true) = 'service_role'
    );

CREATE POLICY "Service role full access to wallet_transactions"
    ON wallet_transactions
    FOR ALL
    USING (
        auth.jwt() ->> 'role' = 'service_role' OR
        current_setting('request.jwt.claim.role', true) = 'service_role'
    )
    WITH CHECK (
        auth.jwt() ->> 'role' = 'service_role' OR
        current_setting('request.jwt.claim.role', true) = 'service_role'
    );

ALTER TABLE IF EXISTS reconciled_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role full access to reconciled_transactions" ON reconciled_transactions;
CREATE POLICY "Service role full access to reconciled_transactions"
    ON reconciled_transactions
    FOR ALL
    USING (
        auth.jwt() ->> 'role' = 'service_role' OR
        current_setting('request.jwt.claim.role', true) = 'service_role'
    )
    WITH CHECK (
        auth.jwt() ->> 'role' = 'service_role' OR
        current_setting('request.jwt.claim.role', true) = 'service_role'
    );

-- 4. HARDEN PROFILES (Protect BVN, NIN, and Balances from Anonymous Scrapers)
ALTER TABLE IF EXISTS profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON profiles;
DROP POLICY IF EXISTS "Profiles are viewable by users and service role" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Service role full access to profiles" ON profiles;

CREATE POLICY "Profiles are viewable by users and service role"
    ON profiles
    FOR SELECT
    USING (
        auth.uid()::text = id::text OR
        auth.jwt() ->> 'role' = 'service_role' OR
        current_setting('request.jwt.claim.role', true) = 'service_role'
    );

CREATE POLICY "Users can update own profile"
    ON profiles
    FOR UPDATE
    USING (
        auth.uid()::text = id::text OR
        auth.jwt() ->> 'role' = 'service_role' OR
        current_setting('request.jwt.claim.role', true) = 'service_role'
    )
    WITH CHECK (
        auth.uid()::text = id::text OR
        auth.jwt() ->> 'role' = 'service_role' OR
        current_setting('request.jwt.claim.role', true) = 'service_role'
    );

CREATE POLICY "Service role full access to profiles"
    ON profiles
    FOR ALL
    USING (
        auth.jwt() ->> 'role' = 'service_role' OR
        current_setting('request.jwt.claim.role', true) = 'service_role'
    )
    WITH CHECK (
        auth.jwt() ->> 'role' = 'service_role' OR
        current_setting('request.jwt.claim.role', true) = 'service_role'
    );

-- 5. ROBUST ATOMIC CREDIT STORED PROCEDURE (Supporting both UUID and String User IDs)
CREATE OR REPLACE FUNCTION credit_wallet_atomic(
    p_user_id TEXT,
    p_amount NUMERIC,
    p_reference TEXT,
    p_description TEXT DEFAULT 'Wallet Credit',
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_new_bal NUMERIC(15, 2);
    v_user_found BOOLEAN := FALSE;
BEGIN
    -- Check if reference already exists to enforce idempotency
    IF EXISTS (SELECT 1 FROM wallet_transactions WHERE reference = p_reference AND status = 'completed') THEN
        SELECT wallet_balance INTO v_new_bal FROM profiles WHERE id::text = p_user_id;
        RETURN jsonb_build_object(
            'success', true,
            'idempotent', true,
            'message', 'Transaction already processed',
            'balance', v_new_bal
        );
    END IF;

    -- Lock and update profile balance
    UPDATE profiles
    SET wallet_balance = COALESCE(wallet_balance, 0) + p_amount,
        updated_at = timezone('utc'::text, now())
    WHERE id::text = p_user_id
    RETURNING wallet_balance INTO v_new_bal;

    IF FOUND THEN
        v_user_found := TRUE;
    END IF;

    IF NOT v_user_found THEN
        RAISE EXCEPTION 'User profile not found for user ID %', p_user_id;
    END IF;

    -- Insert completed transaction ledger row
    INSERT INTO wallet_transactions (
        user_id,
        amount,
        type,
        status,
        reference,
        description,
        metadata,
        created_at
    )
    VALUES (
        p_user_id,
        p_amount,
        'credit',
        'completed',
        p_reference,
        p_description,
        p_metadata,
        timezone('utc'::text, now())
    )
    ON CONFLICT (reference) DO UPDATE
    SET status = 'completed',
        amount = EXCLUDED.amount,
        description = EXCLUDED.description;

    RETURN jsonb_build_object(
        'success', true,
        'idempotent', false,
        'reference', p_reference,
        'amount', p_amount,
        'balance', v_new_bal
    );
END;
$$;
