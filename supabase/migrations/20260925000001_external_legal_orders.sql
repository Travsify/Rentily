-- ==============================================================================
-- RENTILLY MIGRATION: EXTERNAL STANDALONE LEGAL & TITLE VERIFICATION DESK
-- Date: 2026-09-25
-- ==============================================================================

-- 1. ENUMS FOR EXTERNAL LEGAL SERVICES
DO  BEGIN
    CREATE TYPE external_legal_service_type AS ENUM (
        'single_doc_50k',
        'multi_doc_100k',
        'doc_preparation_3pct'
    );
EXCEPTION WHEN duplicate_object THEN null; END ;

DO  BEGIN
    CREATE TYPE external_legal_order_status AS ENUM (
        'pending_review',
        'in_progress',
        'completed',
        'rejected'
    );
EXCEPTION WHEN duplicate_object THEN null; END ;

-- 2. CREATE EXTERNAL LEGAL ORDERS TABLE
CREATE TABLE IF NOT EXISTS external_legal_orders (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    user_email TEXT NOT NULL,
    user_name TEXT NOT NULL,
    user_phone TEXT,
    service_type TEXT NOT NULL, -- 'single_doc_50k', 'multi_doc_100k', 'doc_preparation_3pct'
    service_title TEXT NOT NULL,
    property_title TEXT NOT NULL,
    property_address TEXT NOT NULL,
    property_state TEXT NOT NULL DEFAULT 'Lagos',
    property_lga TEXT,
    property_value NUMERIC(18, 2),
    fee_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
    document_type TEXT DEFAULT 'Deed / Title Instrument',
    document_urls JSONB DEFAULT '[]'::jsonb,
    additional_notes TEXT,
    status TEXT NOT NULL DEFAULT 'pending_review', -- 'pending_review', 'in_progress', 'completed', 'rejected'
    assigned_counsel_name TEXT,
    assigned_counsel_nba TEXT,
    report_summary TEXT,
    report_pdf_url TEXT,
    certificate_hash TEXT,
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE
);

-- 3. INDEXES FOR HIGH CONCURRENCY LOOKUPS
CREATE INDEX IF NOT EXISTS idx_ext_legal_user_email ON external_legal_orders(user_email);
CREATE INDEX IF NOT EXISTS idx_ext_legal_user_id ON external_legal_orders(user_id);
CREATE INDEX IF NOT EXISTS idx_ext_legal_status ON external_legal_orders(status);
CREATE INDEX IF NOT EXISTS idx_ext_legal_created_at ON external_legal_orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ext_legal_cert_hash ON external_legal_orders(certificate_hash) WHERE certificate_hash IS NOT NULL;

-- 4. ENABLE ROW LEVEL SECURITY
ALTER TABLE external_legal_orders ENABLE ROW LEVEL SECURITY;

-- 5. RLS POLICIES
DROP POLICY IF EXISTS Users can view their own external legal orders ON external_legal_orders;
CREATE POLICY Users can view their own external legal orders
    ON external_legal_orders
    FOR SELECT
    USING (
        auth.jwt() ->> 'email' = user_email OR
        auth.uid()::text = user_id OR
        (auth.jwt() ->> 'role') IN ('admin', 'legal_counsel', 'support')
    );

DROP POLICY IF EXISTS Authenticated users can submit external legal orders ON external_legal_orders;
CREATE POLICY Authenticated users can submit external legal orders
    ON external_legal_orders
    FOR INSERT
    WITH CHECK (
        auth.uid() IS NOT NULL OR
        auth.jwt() ->> 'email' IS NOT NULL
    );

DROP POLICY IF EXISTS Admins and legal team can update orders ON external_legal_orders;
CREATE POLICY Admins and legal team can update orders
    ON external_legal_orders
    FOR UPDATE
    USING (
        (auth.jwt() ->> 'role') IN ('admin', 'legal_counsel', 'support') OR
        auth.jwt() ->> 'email' = user_email
    );
