-- ==============================================================================
-- RENTILLY MIGRATION 003: IDENTITYPASS, FLUTTERWAVE VIRTUAL ACCOUNTS & FRAUD BLACKLIST
-- ==============================================================================

-- 1. IDENTITY VERIFICATIONS LOG TABLE (Prembly / Identitypass)
CREATE TYPE id_verification_type AS ENUM ('nin', 'bvn', 'cac', 'drivers_license', 'passport', 'utility_meter');
CREATE TYPE id_verification_status AS ENUM ('verified', 'failed', 'mismatch', 'pending');

CREATE TABLE IF NOT EXISTS identity_verifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID,
    property_id UUID REFERENCES properties(id) ON DELETE SET NULL,
    verification_type id_verification_type NOT NULL,
    id_number TEXT NOT NULL,
    full_name_returned TEXT,
    date_of_birth TEXT,
    phone_number_returned TEXT,
    photo_url TEXT,
    raw_response JSONB,
    status id_verification_status DEFAULT 'pending',
    verified_by_admin TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. FLUTTERWAVE DEDICATED VIRTUAL ACCOUNTS TABLE
CREATE TABLE IF NOT EXISTS virtual_bank_accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    property_id UUID REFERENCES properties(id) ON DELETE CASCADE,
    tenant_id UUID,
    transaction_id UUID,
    bank_name TEXT NOT NULL, -- e.g. 'Wema Bank', 'Sterling Bank', 'Providus Bank'
    account_number TEXT UNIQUE NOT NULL,
    account_reference TEXT UNIQUE NOT NULL,
    flw_order_ref TEXT,
    expected_amount NUMERIC(15, 2) NOT NULL,
    amount_paid NUMERIC(15, 2) DEFAULT 0,
    currency TEXT DEFAULT 'NGN',
    status TEXT DEFAULT 'active', -- active, paid, expired
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. FRAUD & ROGUE AGENT BLACKLIST TABLE
CREATE TYPE risk_severity AS ENUM ('low', 'medium', 'high', 'critical');

CREATE TABLE IF NOT EXISTS fraud_blacklist (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    full_name TEXT NOT NULL,
    phone_number TEXT UNIQUE,
    bvn TEXT,
    nin TEXT,
    bank_account_number TEXT,
    bank_name TEXT,
    flag_reason TEXT NOT NULL, -- e.g. 'Impersonated owner in Lekki Phase 1', 'Fake C of O deed'
    severity risk_severity DEFAULT 'high',
    flagged_by TEXT DEFAULT 'Rentilly Security Automated Scanner',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE identity_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE virtual_bank_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE fraud_blacklist ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins full access identity_verifications" ON identity_verifications FOR ALL USING (true);
CREATE POLICY "Admins full access virtual_bank_accounts" ON virtual_bank_accounts FOR ALL USING (true);
CREATE POLICY "Admins full access fraud_blacklist" ON fraud_blacklist FOR ALL USING (true);
