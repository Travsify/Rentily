-- ==============================================================================
-- RENTILLY DATABASE SCHEMA (SUPABASE POSTGRESQL)
-- Built for Zero-Agent Nigerian Real Estate Marketplace & KYP Verification
-- ==============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. USER PROFILES TABLE (Linked with Supabase Auth)
CREATE TYPE user_role AS ENUM ('renter', 'buyer', 'owner', 'admin', 'legal_officer');

CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    phone_number TEXT,
    role user_role DEFAULT 'renter',
    is_verified BOOLEAN DEFAULT FALSE,
    nin_number TEXT,
    bvn_verified BOOLEAN DEFAULT FALSE,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. PROPERTIES TABLE
CREATE TYPE property_purpose AS ENUM ('rent', 'sale');
CREATE TYPE property_type AS ENUM ('flat_apartment', 'duplex', 'terrace', 'semi_detached', 'fully_detached', 'commercial', 'land');
CREATE TYPE property_status AS ENUM ('draft', 'pending_kyp', 'verified', 'rejected', 'rented', 'sold', 'unlisted');

CREATE TABLE IF NOT EXISTS properties (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    purpose property_purpose NOT NULL,
    property_type property_type NOT NULL,
    
    -- Financials (in Nigerian Naira ₦)
    base_price NUMERIC(15, 2) NOT NULL, -- Rent per annum OR Sale Outright Price
    caution_fee NUMERIC(15, 2) DEFAULT 0, -- Refundable Caution Deposit (for rent)
    service_charge NUMERIC(15, 2) DEFAULT 0, -- Maintenance/Estate service charge
    rentilly_fee NUMERIC(15, 2) NOT NULL, -- 10% for Rent / 5% for Sale
    total_initial_payment NUMERIC(15, 2) NOT NULL,
    payment_frequency TEXT DEFAULT 'annually', -- annually, biannually
    
    -- Location in Nigeria
    address TEXT NOT NULL,
    state TEXT NOT NULL DEFAULT 'Lagos', -- Lagos, Abuja FCT, Rivers, Oyo, etc.
    lga TEXT NOT NULL, -- Eti-Osa, Ikeja, Abuja Municipal, etc.
    neighborhood TEXT NOT NULL, -- Lekki Phase 1, Ikoyi, Victoria Island, Maitama, Wuse 2, etc.
    
    -- Features & Specs
    bedrooms INT DEFAULT 1,
    bathrooms INT DEFAULT 1,
    toilets INT DEFAULT 1,
    furnishing TEXT DEFAULT 'unfurnished', -- unfurnished, semi-furnished, fully-furnished
    amenities TEXT[] DEFAULT '{}', -- 24/7 Power, Swimming Pool, Security, Water Treatment, etc.
    images TEXT[] DEFAULT '{}',
    video_walkthrough_url TEXT,
    
    -- Verification & Status
    status property_status DEFAULT 'pending_kyp',
    verified_at TIMESTAMP WITH TIME ZONE,
    verified_by UUID REFERENCES profiles(id),
    delisted_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. KYP (KNOW YOUR PROPERTY) VERIFICATION RECORDS
CREATE TYPE kyp_status AS ENUM ('pending', 'under_review', 'approved', 'rejected', 'more_info_required');
CREATE TYPE title_document_type AS ENUM (
    'c_of_o', 
    'governors_consent', 
    'deed_of_assignment', 
    'gazette_excision', 
    'letter_of_administration', 
    'registered_survey_plan'
);

CREATE TABLE IF NOT EXISTS kyp_verifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    
    -- Documents
    title_document_type title_document_type NOT NULL,
    title_document_number TEXT,
    title_document_urls TEXT[] NOT NULL,
    
    -- Identity Proof
    owner_id_type TEXT NOT NULL, -- NIN, International Passport, Voters Card, Drivers License
    owner_id_number TEXT NOT NULL,
    owner_id_url TEXT NOT NULL,
    
    -- Physical Possession Proof
    disco_provider TEXT, -- EKEDC, IKEDC, AEDC, PHED, IBEDC
    disco_meter_number TEXT,
    utility_bill_url TEXT,
    video_kyc_url TEXT, -- In-app video walk-through proof of possession
    
    -- Legal Audit by Rentilly Team
    land_registry_search_status TEXT DEFAULT 'pending', -- verified_alausa, verified_agis, pending, flagged
    land_registry_search_notes TEXT,
    status kyp_status DEFAULT 'pending',
    rejection_reason TEXT,
    reviewed_by UUID REFERENCES profiles(id),
    reviewed_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. PHYSICAL INSPECTION BOOKINGS
CREATE TYPE inspection_status AS ENUM ('pending_owner', 'confirmed', 'rescheduled', 'completed', 'cancelled', 'no_show');

CREATE TABLE IF NOT EXISTS inspections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    prospect_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    
    scheduled_date DATE NOT NULL,
    scheduled_time_slot TEXT NOT NULL, -- e.g. 10:00 AM - 11:00 AM
    inspection_pass_code TEXT NOT NULL, -- 6-digit security code for verification at gate
    status inspection_status DEFAULT 'pending_owner',
    
    prospect_notes TEXT,
    owner_response_notes TEXT,
    is_completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. IN-APP CHAT MESSAGES & CALL LOGS
CREATE TABLE IF NOT EXISTS chat_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    inspection_id UUID REFERENCES inspections(id) ON DELETE SET NULL,
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    
    message_type TEXT DEFAULT 'text', -- text, image, document, call_record
    content TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    call_duration_seconds INT DEFAULT 0,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 6. TRANSACTIONS & ESCROW
CREATE TYPE payment_gateway AS ENUM ('paystack', 'flutterwave', 'bank_transfer', 'monnify');
CREATE TYPE escrow_status AS ENUM ('held_in_escrow', 'released_to_owner', 'refunded', 'disputed');

CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE RESTRICT,
    payer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
    owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
    
    transaction_type property_purpose NOT NULL,
    payment_reference TEXT UNIQUE NOT NULL,
    payment_gateway payment_gateway DEFAULT 'paystack',
    
    base_amount NUMERIC(15, 2) NOT NULL,
    rentilly_legal_fee NUMERIC(15, 2) NOT NULL, -- 10% (rent) or 5% (sale)
    caution_fee NUMERIC(15, 2) DEFAULT 0,
    service_charge NUMERIC(15, 2) DEFAULT 0,
    total_amount NUMERIC(15, 2) NOT NULL,
    
    escrow_status escrow_status DEFAULT 'held_in_escrow',
    owner_payout_reference TEXT,
    payout_released_at TIMESTAMP WITH TIME ZONE,
    payout_released_by UUID REFERENCES profiles(id),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 7. LEGAL AGREEMENTS & CONTRACTS
CREATE TYPE agreement_type AS ENUM ('tenancy_agreement', 'contract_of_sale', 'deed_of_assignment_draft');
CREATE TYPE legal_contract_status AS ENUM ('drafting', 'pending_tenant_signature', 'pending_landlord_signature', 'fully_executed');

CREATE TABLE IF NOT EXISTS legal_agreements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE RESTRICT,
    transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE RESTRICT,
    landlord_id UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
    tenant_id UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
    
    agreement_type agreement_type NOT NULL,
    agreement_title TEXT NOT NULL,
    governing_law TEXT DEFAULT 'Lagos State Tenancy Law 2011', -- or Recovery of Premises Act Abuja
    
    tenancy_commencement_date DATE NOT NULL,
    tenancy_expiration_date DATE NOT NULL,
    
    landlord_signature TEXT,
    landlord_signed_at TIMESTAMP WITH TIME ZONE,
    
    tenant_signature TEXT,
    tenant_signed_at TIMESTAMP WITH TIME ZONE,
    
    legal_officer_stamp TEXT,
    legal_officer_id UUID REFERENCES profiles(id),
    
    pdf_contract_url TEXT,
    status legal_contract_status DEFAULT 'drafting',
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 8. ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE kyp_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE inspections ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE legal_agreements ENABLE ROW LEVEL SECURITY;

-- Profiles: Public read, self edit, admin all
CREATE POLICY "Public profiles are viewable by everyone" ON profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);

-- Properties: Verified properties viewable by everyone; Owners can view own; Admins view all
CREATE POLICY "Verified properties viewable by public" ON properties 
    FOR SELECT USING (status = 'verified' OR auth.uid() = owner_id);

CREATE POLICY "Owners can insert properties" ON properties 
    FOR INSERT WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Owners can update own properties" ON properties 
    FOR UPDATE USING (auth.uid() = owner_id);

-- KYP: Owner view own; Admin view all
CREATE POLICY "Owners view own KYP" ON kyp_verifications 
    FOR SELECT USING (auth.uid() = owner_id);

CREATE POLICY "Owners submit KYP" ON kyp_verifications 
    FOR INSERT WITH CHECK (auth.uid() = owner_id);

-- Inspections: Involved parties view & edit
CREATE POLICY "Users view own inspections" ON inspections 
    FOR SELECT USING (auth.uid() = prospect_id OR auth.uid() = owner_id);

CREATE POLICY "Users create inspections" ON inspections 
    FOR INSERT WITH CHECK (auth.uid() = prospect_id);

CREATE POLICY "Parties update inspections" ON inspections 
    FOR UPDATE USING (auth.uid() = prospect_id OR auth.uid() = owner_id);

-- Chat: Sender or Receiver view & insert
CREATE POLICY "Chat message participants" ON chat_messages 
    FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "Send chat messages" ON chat_messages 
    FOR INSERT WITH CHECK (auth.uid() = sender_id);
