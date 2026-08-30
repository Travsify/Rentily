-- ==============================================================================
-- RENTILLY SEED DATA (AUTHENTIC NIGERIAN REAL ESTATE MARKETPLACE DATA)
-- ==============================================================================

-- Note: When running in Supabase, replace the static user IDs with real auth user UUIDs if needed.

-- Sample Profiles
INSERT INTO profiles (id, email, full_name, phone_number, role, is_verified, nin_number, bvn_verified)
VALUES 
  ('11111111-1111-1111-1111-111111111111', 'admin@rentilly.ng', 'Barrister Chijioke Okonkwo (Rentilly Legal Lead)', '+2348031234567', 'admin', true, '89201928374', true),
  ('22222222-2222-2222-2222-222222222222', 'adebayo.falana@gmail.com', 'Chief Adebayo Falana (Property Owner)', '+2348029876543', 'owner', true, '57291830492', true),
  ('33333333-3333-3333-3333-333333333333', 'hajiya.amina@danladi.com', 'Hajiya Amina Danladi (Property Owner)', '+2348098765432', 'owner', true, '48291039485', true),
  ('44444444-4444-4444-4444-444444444444', 'femi.adesanya@techcorp.ng', 'Femi Adesanya (Verified Renter)', '+2348123456789', 'renter', true, '19283746501', true),
  ('55555555-5555-5555-5555-555555555555', 'dr.somto.chukwu@medlife.org', 'Dr. Somtochukwu Eze (Verified Buyer)', '+2348187654321', 'buyer', true, '91827364502', true)
ON CONFLICT (id) DO NOTHING;

-- Sample Properties
INSERT INTO properties (
    id, owner_id, title, description, purpose, property_type, 
    base_price, caution_fee, service_charge, rentilly_fee, total_initial_payment, payment_frequency,
    address, state, lga, neighborhood, bedrooms, bathrooms, toilets, furnishing, amenities, images, status
)
VALUES
(
    'a1111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222222',
    'Luxury 3-Bedroom Serviced Apartment in Lekki Phase 1',
    'Direct from verified owner: Ultra-modern 3-bedroom luxury flat with fully fitted kitchen, swimming pool, treated water plant, 24/7 power via dedicated transformer and soundproof generator. Gated compound with uniform security. No agency, no agreement fee markup!',
    'rent',
    'flat_apartment',
    4500000.00, -- ₦4,500,000 / year
    400000.00,  -- ₦400,000 caution fee
    500000.00,  -- ₦500,000 service charge
    450000.00,  -- 10% Rentilly Legal & Platform Fee
    5850000.00, -- Total initial payment
    'annually',
    'Plot 14, Block 88, Admiralty Way',
    'Lagos',
    'Eti-Osa',
    'Lekki Phase 1',
    3, 3, 4,
    'semi-furnished',
    ARRAY['24/7 Electricity', 'Swimming Pool', 'Fitted Kitchen', 'Security Guards', 'Water Treatment', 'Prepaid Meter'],
    ARRAY[
        'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=1200&q=80'
    ],
    'verified'
),
(
    'a2222222-2222-2222-2222-222222222222',
    '33333333-3333-3333-3333-333333333333',
    'Contemporary 5-Bedroom Fully Detached Duplex + BQ',
    'Magnificent contemporary mansion on a 650sqm plot in prime Maitama. Title is Federal C of O with all approvals. Features private cinema, smart home automation, CCTV, borehole, and expansive parking for 6 cars. Outright sale directly from original family title holder.',
    'sale',
    'fully_detached',
    380000000.00, -- ₦380,000,000 Outright Sale
    0.00,
    0.00,
    19000000.00, -- 5% Rentilly Legal, Title Search & Escrow Fee
    399000000.00,
    'outright',
    '12 Gana Street, near Transcorp',
    'Abuja FCT',
    'Abuja Municipal',
    'Maitama',
    5, 6, 7,
    'fully-furnished',
    ARRAY['Governor''s Consent / Federal C of O', 'Smart Home Automation', 'Cinema Room', 'Solar Inverter System', 'Private Swimming Pool', 'Boys Quarters'],
    ARRAY[
        'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?auto=format&fit=crop&w=1200&q=80'
    ],
    'verified'
),
(
    'a3333333-3333-3333-3333-333333333333',
    '22222222-2222-2222-2222-222222222222',
    'Brand New 2-Bedroom Apartment in Old Ikoyi',
    'Newly finished 2-bedroom executive apartment in a peaceful, secure close in Old Ikoyi. Elevators, gym, concierge desk, dedicated parking. Ready for immediate move-in.',
    'rent',
    'flat_apartment',
    7000000.00, -- ₦7,000,000 / year
    500000.00,  -- ₦500,000 caution
    1200000.00, -- ₦1,200,000 service charge
    700000.00,  -- 10% Rentilly Legal Fee
    9400000.00,
    'annually',
    '8 Bourdillon Road, Old Ikoyi',
    'Lagos',
    'Ikoyi-Obalende',
    'Ikoyi',
    2, 2, 3,
    'unfurnished',
    ARRAY['Gym', 'Elevator', '24/7 Security', 'Concierge', 'Treated Water', 'Standby Power'],
    ARRAY[
        'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?auto=format&fit=crop&w=1200&q=80'
    ],
    'pending_kyp'
);

-- Sample KYP Verification Records
INSERT INTO kyp_verifications (
    id, property_id, owner_id, title_document_type, title_document_number,
    title_document_urls, owner_id_type, owner_id_number, owner_id_url,
    disco_provider, disco_meter_number, utility_bill_url, land_registry_search_status, status
)
VALUES
(
    'b1111111-1111-1111-1111-111111111111',
    'a1111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222222',
    'governors_consent',
    'VOL-42/PAGE-109/LAGOS-LANDS-2018',
    ARRAY['https://storage.rentilly.ng/docs/governors_consent_lekki_p1.pdf'],
    'NIN',
    '57291830492',
    'https://storage.rentilly.ng/docs/nin_slip_falana.jpg',
    'EKEDC',
    '04192837461',
    'https://storage.rentilly.ng/docs/ekedc_bill_aug2026.pdf',
    'verified_alausa',
    'approved'
),
(
    'b2222222-2222-2222-2222-222222222222',
    'a2222222-2222-2222-2222-222222222222',
    '33333333-3333-3333-3333-333333333333',
    'c_of_o',
    'FCT/AGIS/CO-2014-9982',
    ARRAY['https://storage.rentilly.ng/docs/agis_c_of_o_maitama.pdf'],
    'International Passport',
    'A10928374',
    'https://storage.rentilly.ng/docs/passport_danladi.jpg',
    'AEDC',
    '01928374652',
    'https://storage.rentilly.ng/docs/aedc_bill_maitama.pdf',
    'verified_agis',
    'approved'
),
(
    'b3333333-3333-3333-3333-333333333333',
    'a3333333-3333-3333-3333-333333333333',
    '22222222-2222-2222-2222-222222222222',
    'deed_of_assignment',
    'IKY/DEED/2021/045',
    ARRAY['https://storage.rentilly.ng/docs/deed_bourdillon_ikoyi.pdf'],
    'Drivers License',
    'LAG-827364-AA',
    'https://storage.rentilly.ng/docs/drivers_license_falana.jpg',
    'EKEDC',
    '04198273615',
    'https://storage.rentilly.ng/docs/ekedc_ikoyi_bill.pdf',
    'pending',
    'pending'
);

-- Sample Inspections
INSERT INTO inspections (
    id, property_id, prospect_id, owner_id, scheduled_date, scheduled_time_slot,
    inspection_pass_code, status, prospect_notes
)
VALUES
(
    'c1111111-1111-1111-1111-111111111111',
    'a1111111-1111-1111-1111-111111111111',
    '44444444-4444-4444-4444-444444444444',
    '22222222-2222-2222-2222-222222222222',
    CURRENT_DATE + INTERVAL '2 days',
    '11:00 AM - 12:00 PM',
    '749201',
    'confirmed',
    'Looking forward to inspecting the apartment. Please have the facility manager on standby.'
);

-- Sample Transactions & Escrow
INSERT INTO transactions (
    id, property_id, payer_id, owner_id, transaction_type, payment_reference, payment_gateway,
    base_amount, rentilly_legal_fee, caution_fee, service_charge, total_amount, escrow_status
)
VALUES
(
    'd1111111-1111-1111-1111-111111111111',
    'a1111111-1111-1111-1111-111111111111',
    '44444444-4444-4444-4444-444444444444',
    '22222222-2222-2222-2222-222222222222',
    'rent',
    'RNT-2026-PAY-882910',
    'paystack',
    4500000.00,
    450000.00,
    400000.00,
    500000.00,
    5850000.00,
    'held_in_escrow'
);
