-- ==============================================================================
-- RENTILLY GLOBAL PAY: CROSS-BORDER DISBURSEMENT & ATOMIC SETTLEMENT PROTOCOL
-- Migration: 20260927000001_rentilly_global_pay.sql
-- ==============================================================================

-- 1. SYSTEM CONFIGURATIONS TABLE (for Admin-Configurable Pricing & Corridor Fees)
CREATE TABLE IF NOT EXISTS system_configs (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    description TEXT,
    updated_by TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Seed Default Global Pay Pricing Configuration
INSERT INTO system_configs (key, value, description)
VALUES (
    'global_pay_config',
    '{
        "fxSpreadPercent": 1.20,
        "corridorFeesNgn": {
            "gbpFpsNgn": 3000,
            "eurSepaNgn": 5000,
            "usdWireNgn": 7500,
            "usdSwiftNgn": 15000,
            "cadEftNgn": 5000
        },
        "tuitionSemesterLimitUsd": 25000,
        "supplierInvoiceLimitUsd": 100000,
        "featureEnabled": true,
        "supportedCurrencies": ["USD", "GBP", "EUR", "CAD"]
    }'::jsonb,
    'Rentilly Global Pay Pricing, FX Spreads and Corridor Fees'
)
ON CONFLICT (key) DO UPDATE
SET updated_at = timezone('utc'::text, now());

-- 2. WALLET PRE-AUTH HOLDS TABLE (Zero-Risk Double-Entry Invariants)
CREATE TABLE IF NOT EXISTS wallet_holds (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    reference TEXT UNIQUE NOT NULL,
    amount_held_ngn NUMERIC(15, 2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'HELD', -- 'HELD', 'SETTLED', 'REVERSED'
    metadata JSONB DEFAULT '{}'::jsonb,
    settled_at TIMESTAMP WITH TIME ZONE,
    reversed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_wallet_holds_user ON wallet_holds(user_id);
CREATE INDEX IF NOT EXISTS idx_wallet_holds_ref ON wallet_holds(reference);

-- 3. GLOBAL BENEFICIARIES TABLE (Tuition Schools & Overseas B2B Suppliers)
CREATE TABLE IF NOT EXISTS global_beneficiaries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    beneficiary_type TEXT NOT NULL, -- 'tuition_institution' | 'supplier_vendor'
    name TEXT NOT NULL,
    email TEXT,
    country_code TEXT NOT NULL, -- e.g. 'GB', 'US', 'CA', 'DE', 'CN', 'AE', 'TR'
    currency TEXT NOT NULL, -- 'GBP', 'USD', 'EUR', 'CAD'
    bank_name TEXT NOT NULL,
    bank_address TEXT,
    account_number_or_iban TEXT NOT NULL,
    routing_code TEXT, -- Sort code (UK), ABA routing (US), Transit (CA)
    swift_bic TEXT,
    institution_student_id TEXT,
    vendor_tax_id TEXT,
    status TEXT DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_global_ben_user ON global_beneficiaries(user_id);

-- 4. GLOBAL PAYOUT ORDERS TABLE
CREATE TABLE IF NOT EXISTS global_payout_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    reference TEXT UNIQUE NOT NULL,
    order_type TEXT NOT NULL, -- 'tuition' | 'supplier'
    beneficiary_id UUID REFERENCES global_beneficiaries(id) ON DELETE SET NULL,
    beneficiary_snapshot JSONB NOT NULL,
    source_currency TEXT DEFAULT 'NGN',
    destination_currency TEXT NOT NULL, -- 'GBP', 'USD', 'EUR', 'CAD'
    destination_amount NUMERIC(15, 2) NOT NULL,
    source_amount_ngn NUMERIC(15, 2) NOT NULL,
    exchange_rate NUMERIC(15, 4) NOT NULL,
    wholesale_rate NUMERIC(15, 4),
    fx_spread_percent NUMERIC(5, 2) NOT NULL,
    corridor_fee_ngn NUMERIC(15, 2) NOT NULL,
    total_debited_ngn NUMERIC(15, 2) NOT NULL,
    fincra_quote_reference TEXT,
    fincra_payout_reference TEXT,
    fincra_payout_id TEXT,
    payment_scheme TEXT NOT NULL, -- 'fps', 'sepa', 'fedwire', 'swift', 'eft'
    student_name TEXT,
    student_matric_id TEXT,
    institution_name TEXT,
    semester_session TEXT,
    invoice_number TEXT,
    document_url TEXT,
    status TEXT NOT NULL DEFAULT 'SUBMITTED', -- 'SUBMITTED', 'PROCESSING', 'COMPLETED', 'FAILED_REFUNDED'
    failure_reason TEXT,
    timeline JSONB DEFAULT '[]'::jsonb,
    wallet_hold_id UUID REFERENCES wallet_holds(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_global_orders_user ON global_payout_orders(user_id);
CREATE INDEX IF NOT EXISTS idx_global_orders_ref ON global_payout_orders(reference);
CREATE INDEX IF NOT EXISTS idx_global_orders_fincra_ref ON global_payout_orders(fincra_payout_reference);

-- 5. ATOMIC STORED PROCEDURES (Zero-Risk Double-Entry Protocol)

-- 5A: ATOMIC WALLET PRE-AUTH HOLD
CREATE OR REPLACE FUNCTION fn_hold_wallet_funds_atomic(
    p_user_id UUID,
    p_amount NUMERIC(15, 2),
    p_reference TEXT,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_bal NUMERIC(15, 2);
    v_hold_id UUID;
BEGIN
    -- Row-level lock on user profile to prevent race conditions
    SELECT COALESCE(wallet_balance, 0)
    INTO v_current_bal
    FROM profiles
    WHERE id = p_user_id
    FOR UPDATE;

    IF v_current_bal IS NULL THEN
        RAISE EXCEPTION 'User profile not found for user ID %', p_user_id;
    END IF;

    IF v_current_bal < p_amount THEN
        RAISE EXCEPTION 'Insufficient balance: required %, available %', p_amount, v_current_bal;
    END IF;

    -- Debit user wallet
    UPDATE profiles
    SET wallet_balance = wallet_balance - p_amount,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_user_id;

    -- Record pre-auth hold
    INSERT INTO wallet_holds (user_id, reference, amount_held_ngn, status, metadata)
    VALUES (p_user_id, p_reference, p_amount, 'HELD', p_metadata)
    RETURNING id INTO v_hold_id;

    -- Record in transactions ledger if table exists
    BEGIN
        INSERT INTO transactions (
            user_id,
            amount,
            type,
            status,
            reference,
            description,
            created_at
        )
        VALUES (
            p_user_id,
            p_amount,
            'debit',
            'pending',
            p_reference,
            'Rentilly Global Pay pre-auth hold: ' || COALESCE(p_metadata->>'purpose', 'Cross-border payout'),
            timezone('utc'::text, now())
        );
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RETURN v_hold_id;
END;
$$;

-- 5B: ATOMIC SETTLEMENT (Disbursement Confirmed by Fincra Rail)
CREATE OR REPLACE FUNCTION fn_settle_wallet_hold_atomic(
    p_reference TEXT,
    p_fincra_ref TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_hold wallet_holds%ROWTYPE;
BEGIN
    SELECT * INTO v_hold
    FROM wallet_holds
    WHERE reference = p_reference
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Wallet hold reference % not found', p_reference;
    END IF;

    IF v_hold.status = 'SETTLED' THEN
        RETURN TRUE;
    END IF;

    IF v_hold.status <> 'HELD' THEN
        RAISE EXCEPTION 'Cannot settle hold in status %', v_hold.status;
    END IF;

    UPDATE wallet_holds
    SET status = 'SETTLED',
        settled_at = timezone('utc'::text, now())
    WHERE id = v_hold.id;

    UPDATE global_payout_orders
    SET status = 'COMPLETED',
        updated_at = timezone('utc'::text, now())
    WHERE reference = p_reference;

    BEGIN
        UPDATE transactions
        SET status = 'completed',
            description = description || ' [Settled by International Rail]'
        WHERE reference = p_reference;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RETURN TRUE;
END;
$$;

-- 5C: ATOMIC REVERSAL / INSTANT REFUND (Disbursement Rejected or Failed)
CREATE OR REPLACE FUNCTION fn_reverse_wallet_hold_atomic(
    p_reference TEXT,
    p_reason TEXT DEFAULT 'Disbursement rejected by international rail'
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_hold wallet_holds%ROWTYPE;
BEGIN
    SELECT * INTO v_hold
    FROM wallet_holds
    WHERE reference = p_reference
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Wallet hold reference % not found', p_reference;
    END IF;

    IF v_hold.status = 'REVERSED' THEN
        RETURN TRUE;
    END IF;

    IF v_hold.status <> 'HELD' THEN
        RAISE EXCEPTION 'Cannot reverse hold in status %', v_hold.status;
    END IF;

    -- Return 100% of held funds to user balance with zero slippage
    UPDATE profiles
    SET wallet_balance = wallet_balance + v_hold.amount_held_ngn,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_hold.user_id;

    UPDATE wallet_holds
    SET status = 'REVERSED',
        reversed_at = timezone('utc'::text, now()),
        metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object('reversal_reason', p_reason)
    WHERE id = v_hold.id;

    UPDATE global_payout_orders
    SET status = 'FAILED_REFUNDED',
        failure_reason = p_reason,
        updated_at = timezone('utc'::text, now())
    WHERE reference = p_reference;

    BEGIN
        UPDATE transactions
        SET status = 'refunded',
            description = description || ' [Refunded: ' || p_reason || ']'
        WHERE reference = p_reference;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RETURN TRUE;
END;
$$;
