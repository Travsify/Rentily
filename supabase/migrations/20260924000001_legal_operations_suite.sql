-- ==============================================================================
-- RENTILLY MIGRATION: LEGAL OPERATIONS, CONVEYANCE, DISPUTES & ESCROW MILESTONES
-- Date: 2026-09-24
-- ==============================================================================

-- 1. ENUMS
DO $$ BEGIN
    CREATE TYPE title_audit_verdict AS ENUM ('pending', 'approved', 'conditional', 'flagged', 'rejected');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE dispute_category AS ENUM (
        'breach_of_covenant', 'unlawful_eviction', 'caution_deposit_retention',
        'title_defect', 'rent_default', 'damage_claim', 'misrepresentation', 'other'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE dispute_status AS ENUM (
        'filed', 'under_review', 'mediation', 'arbitration', 'resolved', 'dismissed', 'escalated_to_court'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE milestone_status AS ENUM (
        'pending_clearance', 'legal_cleared', 'rejected', 'executed', 'disbursed'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE legal_dispatch_status AS ENUM (
        'drafting', 'prepared', 'sealed', 'in_transit', 'out_for_delivery', 'delivered', 'failed'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- 2. ENHANCE OR CREATE LEGAL AGREEMENTS TABLE
CREATE TABLE IF NOT EXISTS legal_agreements (
    id TEXT PRIMARY KEY,
    property_id TEXT NOT NULL,
    property_title TEXT,
    property_address TEXT,
    property_state TEXT,
    transaction_id TEXT,
    landlord_id TEXT,
    landlord_name TEXT,
    tenant_id TEXT,
    tenant_name TEXT,
    agreement_type TEXT NOT NULL DEFAULT 'tenancy_agreement', -- 'tenancy_agreement', 'contract_of_sale', 'deed_of_assignment', 'power_of_attorney'
    agreement_title TEXT NOT NULL,
    governing_law TEXT DEFAULT 'Laws of the Federal Republic of Nigeria',
    jurisdiction TEXT DEFAULT 'Lagos State High Court',
    tenancy_commencement_date DATE,
    tenancy_expiration_date DATE,
    annual_rent NUMERIC(15, 2) DEFAULT 0,
    caution_deposit NUMERIC(15, 2) DEFAULT 0,
    consideration_amount NUMERIC(15, 2) DEFAULT 0,
    landlord_signed BOOLEAN DEFAULT FALSE,
    landlord_signed_at TIMESTAMP WITH TIME ZONE,
    tenant_signed BOOLEAN DEFAULT FALSE,
    tenant_signed_at TIMESTAMP WITH TIME ZONE,
    legal_officer_stamp BOOLEAN DEFAULT FALSE,
    legal_officer_id TEXT,
    legal_officer_name TEXT,
    stamped_at TIMESTAMP WITH TIME ZONE,
    pdf_contract_url TEXT,
    status TEXT DEFAULT 'drafting',
    notes TEXT,
    legal_hash VARCHAR(64) UNIQUE,
    canonical_metadata JSONB,
    stamp_serial VARCHAR(64),
    digital_signature TEXT,
    signature_algorithm VARCHAR(32) DEFAULT 'RSA-SHA256-4096',
    sealed_at TIMESTAMP WITH TIME ZONE,
    qr_verification_url TEXT,
    evidence_act_compliance BOOLEAN DEFAULT TRUE,
    custody_transferred_at TIMESTAMP WITH TIME ZONE,
    custody_holder_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. LEGAL TITLE AUDITS TABLE (Due Diligence & Registry Search)
CREATE TABLE IF NOT EXISTS legal_title_audits (
    id TEXT PRIMARY KEY,
    property_id TEXT NOT NULL,
    kyp_id TEXT,
    property_title TEXT,
    property_location TEXT,
    title_document_type TEXT NOT NULL,
    title_document_number TEXT NOT NULL,
    land_registry TEXT NOT NULL,
    cadastral_survey_no TEXT,
    survey_beacons JSONB DEFAULT '[]'::jsonb,
    encumbrance_status TEXT DEFAULT 'unencumbered',
    lis_pendens_details TEXT,
    gazette_page_ref TEXT,
    title_health_score NUMERIC(5, 2) DEFAULT 100.00,
    findings TEXT NOT NULL,
    recommendations TEXT,
    verdict title_audit_verdict DEFAULT 'pending',
    legal_officer_id TEXT NOT NULL,
    legal_officer_name TEXT NOT NULL,
    audit_date TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. LEGAL DISPATCHES TABLE (Physical Stamped Deeds & Secure Waybills)
CREATE TABLE IF NOT EXISTS legal_dispatches (
    id TEXT PRIMARY KEY,
    agreement_id TEXT NOT NULL,
    property_id TEXT,
    property_title TEXT NOT NULL,
    property_address TEXT NOT NULL,
    recipient_id TEXT,
    recipient_name TEXT NOT NULL,
    recipient_email TEXT NOT NULL,
    recipient_phone TEXT NOT NULL,
    delivery_address TEXT NOT NULL,
    delivery_city TEXT NOT NULL,
    delivery_state TEXT NOT NULL,
    delivery_country TEXT NOT NULL DEFAULT 'Nigeria',
    is_diaspora BOOLEAN DEFAULT FALSE,
    courier_partner TEXT NOT NULL DEFAULT 'GIG Logistics',
    waybill_number TEXT,
    tracking_url TEXT,
    security_pouch_serial VARCHAR(64),
    package_photo_urls JSONB DEFAULT '[]'::jsonb,
    package_photo_hash VARCHAR(64),
    delivery_otp_hash VARCHAR(128),
    delivery_otp_plain VARCHAR(10),
    delivery_otp_expires_at TIMESTAMP WITH TIME ZONE,
    delivery_otp_attempts INT DEFAULT 0,
    delivery_otp_verified_at TIMESTAMP WITH TIME ZONE,
    status legal_dispatch_status DEFAULT 'prepared',
    estimated_delivery_date TEXT DEFAULT '2-4 Business Days',
    dispatched_at TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE,
    recipient_confirmed BOOLEAN DEFAULT FALSE,
    recipient_confirmed_at TIMESTAMP WITH TIME ZONE,
    custody_certificate_url TEXT,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. LEGAL DISPUTES & ARBITRATION TABLE
CREATE TABLE IF NOT EXISTS legal_disputes (
    id TEXT PRIMARY KEY,
    agreement_id TEXT,
    property_id TEXT,
    property_title TEXT,
    complainant_id TEXT NOT NULL,
    complainant_name TEXT NOT NULL,
    complainant_email TEXT NOT NULL,
    complainant_role TEXT NOT NULL,
    respondent_id TEXT NOT NULL,
    respondent_name TEXT NOT NULL,
    respondent_email TEXT NOT NULL,
    respondent_role TEXT NOT NULL,
    dispute_category dispute_category NOT NULL,
    dispute_title TEXT NOT NULL,
    claim_amount NUMERIC(15, 2) DEFAULT 0,
    description TEXT NOT NULL,
    evidence_urls JSONB DEFAULT '[]'::jsonb,
    status dispute_status DEFAULT 'filed',
    statutory_notice_type TEXT,
    statutory_notice_date DATE,
    emergency_intervention_active BOOLEAN DEFAULT FALSE,
    mediation_notes TEXT,
    arbitration_award_summary TEXT,
    msa_settlement_url TEXT,
    assigned_legal_officer_id TEXT,
    assigned_legal_officer_name TEXT,
    resolved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 6. LEGAL ESCROW MILESTONES TABLE (Multi-Tranche Sales/Tenancy Releases)
CREATE TABLE IF NOT EXISTS legal_escrow_milestones (
    id TEXT PRIMARY KEY,
    agreement_id TEXT,
    property_id TEXT NOT NULL,
    transaction_id TEXT NOT NULL,
    milestone_number INTEGER NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    release_percentage NUMERIC(5, 2) NOT NULL,
    release_amount_ngn NUMERIC(15, 2) NOT NULL,
    status milestone_status DEFAULT 'pending_clearance',
    conditions JSONB DEFAULT '[]'::jsonb,
    cleared_by_officer_id TEXT,
    cleared_by_officer_name TEXT,
    cleared_at TIMESTAMP WITH TIME ZONE,
    executed_by_officer_id TEXT,
    executed_by_officer_name TEXT,
    payout_tx_reference TEXT,
    executed_at TIMESTAMP WITH TIME ZONE,
    execution_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 7. LEGAL OFFICER CREDENTIALS & CERTIFICATES TABLE
CREATE TABLE IF NOT EXISTS legal_officer_certificates (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    full_legal_name TEXT NOT NULL,
    nba_enrolment_number VARCHAR(64) UNIQUE NOT NULL,
    bar_call_year INTEGER NOT NULL,
    law_firm_name TEXT,
    seal_serial_prefix VARCHAR(32) DEFAULT 'RNT-SEAL',
    public_key_pem TEXT,
    certificate_fingerprint VARCHAR(64),
    is_active BOOLEAN DEFAULT TRUE,
    issued_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 8. IMMUTABLE LEGAL AUDIT LOGS TABLE
CREATE TABLE IF NOT EXISTS legal_audit_logs (
    id TEXT PRIMARY KEY,
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    action TEXT NOT NULL,
    actor_id TEXT NOT NULL,
    actor_email TEXT NOT NULL,
    actor_role TEXT NOT NULL,
    ip_address TEXT,
    user_agent TEXT,
    changes JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 9. DEED VERIFICATION LOGS TABLE (Public / QR Scan Audits)
CREATE TABLE IF NOT EXISTS deed_verification_logs (
    id TEXT PRIMARY KEY,
    legal_hash VARCHAR(64) NOT NULL,
    agreement_id TEXT,
    ip_address TEXT,
    user_agent TEXT,
    source VARCHAR(32) DEFAULT 'qr_scan',
    verified_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 10. INDEXES & RLS
CREATE INDEX IF NOT EXISTS idx_legal_agreements_property ON legal_agreements(property_id);
CREATE INDEX IF NOT EXISTS idx_legal_agreements_status ON legal_agreements(status);
CREATE INDEX IF NOT EXISTS idx_legal_agreements_hash ON legal_agreements(legal_hash);
CREATE INDEX IF NOT EXISTS idx_legal_title_audits_property ON legal_title_audits(property_id);
CREATE INDEX IF NOT EXISTS idx_legal_dispatches_agreement ON legal_dispatches(agreement_id);
CREATE INDEX IF NOT EXISTS idx_legal_dispatches_status ON legal_dispatches(status);
CREATE INDEX IF NOT EXISTS idx_legal_disputes_status ON legal_disputes(status);
CREATE INDEX IF NOT EXISTS idx_legal_escrow_milestones_tx ON legal_escrow_milestones(transaction_id);
CREATE INDEX IF NOT EXISTS idx_legal_audit_logs_entity ON legal_audit_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_deed_verification_logs_hash ON deed_verification_logs(legal_hash);

ALTER TABLE legal_agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE legal_title_audits ENABLE ROW LEVEL SECURITY;
ALTER TABLE legal_dispatches ENABLE ROW LEVEL SECURITY;
ALTER TABLE legal_disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE legal_escrow_milestones ENABLE ROW LEVEL SECURITY;
ALTER TABLE legal_officer_certificates ENABLE ROW LEVEL SECURITY;
ALTER TABLE legal_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE deed_verification_logs ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "Full access to legal_agreements" ON legal_agreements FOR ALL USING (true);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Full access to legal_title_audits" ON legal_title_audits FOR ALL USING (true);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Full access to legal_dispatches" ON legal_dispatches FOR ALL USING (true);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Full access to legal_disputes" ON legal_disputes FOR ALL USING (true);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Full access to legal_escrow_milestones" ON legal_escrow_milestones FOR ALL USING (true);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Full access to legal_officer_certificates" ON legal_officer_certificates FOR ALL USING (true);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Full access to legal_audit_logs" ON legal_audit_logs FOR ALL USING (true);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Full access to deed_verification_logs" ON deed_verification_logs FOR ALL USING (true);
EXCEPTION WHEN duplicate_object THEN null; END $$;
