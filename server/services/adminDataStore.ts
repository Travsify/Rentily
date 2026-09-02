import fs from 'fs';
import path from 'path';
import type { Property, KYPRecord, Inspection, LegalAgreement, Transaction } from '../types';

const DATA_DIR = path.join(process.cwd(), 'server', 'data');

function ensureDir() {
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }
}

function readFile<T>(filename: string, seedFn: () => T[]): T[] {
  ensureDir();
  const filePath = path.join(DATA_DIR, filename);
  if (!fs.existsSync(filePath)) {
    const seed = seedFn();
    fs.writeFileSync(filePath, JSON.stringify(seed, null, 2), 'utf-8');
    return seed;
  }
  try {
    const content = fs.readFileSync(filePath, 'utf-8');
    const parsed = JSON.parse(content || '[]');
    if (!Array.isArray(parsed) || parsed.length === 0) {
      const seed = seedFn();
      fs.writeFileSync(filePath, JSON.stringify(seed, null, 2), 'utf-8');
      return seed;
    }
    return parsed;
  } catch {
    const seed = seedFn();
    fs.writeFileSync(filePath, JSON.stringify(seed, null, 2), 'utf-8');
    return seed;
  }
}

function writeFile<T>(filename: string, data: T[]): void {
  ensureDir();
  fs.writeFileSync(path.join(DATA_DIR, filename), JSON.stringify(data, null, 2), 'utf-8');
}

// ============================================================
// SEED DATA — Realistic Nigerian Properties
// ============================================================
function seedProperties(): Property[] {
  const now = new Date().toISOString();
  return [
    {
      id: 'prop_001',
      ownerId: 'usr_landlord_001',
      ownerName: 'Chief Emeka Okonkwo',
      ownerPhone: '+2348031234567',
      title: '4-Bedroom Luxury Duplex — Lekki Phase 1',
      description: 'Stunning fully detached duplex with BQ, private pool, 24hr security. 2min drive to Shoprite Lekki.',
      purpose: 'rent',
      propertyType: 'duplex',
      basePrice: 4500000,
      cautionFee: 500000,
      serviceCharge: 200000,
      rentillyFee: 450000,
      totalInitialPayment: 5650000,
      paymentFrequency: 'annually',
      address: '14B Admiralty Way, Lekki Phase 1',
      state: 'Lagos',
      lga: 'Eti-Osa',
      neighborhood: 'Lekki Phase 1',
      bedrooms: 4,
      bathrooms: 4,
      toilets: 5,
      furnishing: 'fully-furnished',
      amenities: ['Swimming Pool', 'Gym', 'CCTV', '24hr Security', 'Generator', 'Solar Power', 'Parking x4'],
      images: ['https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=800'],
      status: 'verified',
      verifiedAt: now,
      verifiedBy: 'Rentilly Land Registry Team',
      createdAt: now,
      updatedAt: now,
    },
    {
      id: 'prop_002',
      ownerId: 'usr_landlord_002',
      ownerName: 'Mrs Ngozi Danladi',
      ownerPhone: '+2348052345678',
      title: '3-Bedroom Flat — Maitama, Abuja',
      description: 'Premium serviced flat in the heart of Maitama. Walking distance to Transcorp Hilton and Berger.',
      purpose: 'rent',
      propertyType: 'flat_apartment',
      basePrice: 3200000,
      cautionFee: 300000,
      serviceCharge: 150000,
      rentillyFee: 320000,
      totalInitialPayment: 3970000,
      paymentFrequency: 'annually',
      address: '5 Aguiyi Ironsi Street, Maitama',
      state: 'FCT',
      lga: 'Municipal',
      neighborhood: 'Maitama',
      bedrooms: 3,
      bathrooms: 3,
      toilets: 3,
      furnishing: 'semi-furnished',
      amenities: ['Generator', 'Parking x2', 'Security', 'Intercom', 'Water Borehole'],
      images: ['https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800'],
      status: 'verified',
      verifiedAt: now,
      verifiedBy: 'Rentilly Land Registry Team',
      createdAt: now,
      updatedAt: now,
    },
    {
      id: 'prop_003',
      ownerId: 'usr_landlord_003',
      ownerName: 'Barrister Femi Falana Jr.',
      ownerPhone: '+2348063456789',
      title: '6-Bedroom Mansion — Banana Island, Ikoyi',
      description: 'Ultra-luxury smart home on Banana Island. Cinema room, indoor gym, home automation, 8-car garage.',
      purpose: 'sale',
      propertyType: 'fully_detached',
      basePrice: 850000000,
      cautionFee: 0,
      serviceCharge: 0,
      rentillyFee: 42500000,
      totalInitialPayment: 892500000,
      paymentFrequency: 'outright',
      address: '3 Bourdillon Road, Banana Island',
      state: 'Lagos',
      lga: 'Eti-Osa',
      neighborhood: 'Banana Island',
      bedrooms: 6,
      bathrooms: 6,
      toilets: 8,
      furnishing: 'fully-furnished',
      amenities: ['Home Cinema', 'Gym', 'Indoor Pool', 'Smart Home', 'Solar', '8-Car Garage', 'Helipad Access'],
      images: ['https://images.unsplash.com/photo-1613490493576-7fde63acd811?w=800'],
      status: 'pending_kyp',
      createdAt: now,
      updatedAt: now,
    },
    {
      id: 'prop_004',
      ownerId: 'usr_landlord_004',
      ownerName: 'Alhaji Sani Abubakar',
      ownerPhone: '+2348074567890',
      title: '2-Bedroom Self Contain — Wuse 2, Abuja',
      description: 'Clean and affordable 2-bedroom apartment in strategic Wuse 2 location. Near diplomatic zone.',
      purpose: 'rent',
      propertyType: 'flat_apartment',
      basePrice: 1200000,
      cautionFee: 150000,
      serviceCharge: 80000,
      rentillyFee: 120000,
      totalInitialPayment: 1550000,
      paymentFrequency: 'annually',
      address: '22 Aminu Kano Crescent, Wuse 2',
      state: 'FCT',
      lga: 'Municipal',
      neighborhood: 'Wuse 2',
      bedrooms: 2,
      bathrooms: 2,
      toilets: 2,
      furnishing: 'unfurnished',
      amenities: ['Generator', 'Security', 'Water Borehole'],
      images: ['https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800'],
      status: 'verified',
      verifiedAt: now,
      verifiedBy: 'Rentilly Land Registry Team',
      createdAt: now,
      updatedAt: now,
    },
    {
      id: 'prop_005',
      ownerId: 'usr_landlord_005',
      ownerName: 'Dr. Adebayo Tinubu-Okafor',
      ownerPhone: '+2348085678901',
      title: '5-Bedroom Terrace — Victoria Island',
      description: 'Exquisite terrace in VI with rooftop deck, sea view, and private gate. Premium neighborhood.',
      purpose: 'rent',
      propertyType: 'terrace',
      basePrice: 6000000,
      cautionFee: 600000,
      serviceCharge: 300000,
      rentillyFee: 600000,
      totalInitialPayment: 7500000,
      paymentFrequency: 'annually',
      address: '8 Adeola Odeku Street, Victoria Island',
      state: 'Lagos',
      lga: 'Eti-Osa',
      neighborhood: 'Victoria Island',
      bedrooms: 5,
      bathrooms: 5,
      toilets: 6,
      furnishing: 'fully-furnished',
      amenities: ['Rooftop Deck', 'Sea View', 'Generator', 'CCTV', 'Smart Lock', 'Parking x3'],
      images: ['https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800'],
      status: 'verified',
      verifiedAt: now,
      verifiedBy: 'Rentilly Land Registry Team',
      createdAt: now,
      updatedAt: now,
    },
  ];
}

// ============================================================
// SEED DATA — KYP Records
// ============================================================
function seedKYP(): KYPRecord[] {
  const now = new Date().toISOString();
  return [
    {
      id: 'kyp_001',
      propertyId: 'prop_003',
      propertyTitle: '6-Bedroom Mansion — Banana Island, Ikoyi',
      propertyPurpose: 'sale',
      propertyPrice: 850000000,
      propertyNeighborhood: 'Banana Island, Lagos',
      ownerId: 'usr_landlord_003',
      ownerName: 'Barrister Femi Falana Jr.',
      ownerEmail: 'femi.falana.realty@gmail.com',
      ownerPhone: '+2348063456789',
      titleDocumentType: 'governors_consent',
      titleDocumentNumber: 'GC/LAGOS/2019/043221',
      titleDocumentUrls: ['https://storage.myrentilly.com/docs/governors_consent_banana_island.pdf'],
      ownerIdType: 'NIN',
      ownerIdNumber: '12345678901',
      ownerIdUrl: 'https://storage.myrentilly.com/docs/nin_slip_falana.jpg',
      discoProvider: 'EKEDC',
      discoMeterNumber: '57291038402',
      utilityBillUrl: 'https://storage.myrentilly.com/docs/ekedc_ikoyi_aug2026.pdf',
      landRegistrySearchStatus: 'pending',
      status: 'pending',
      submittedAt: now,
    },
    {
      id: 'kyp_002',
      propertyId: 'prop_001',
      propertyTitle: '4-Bedroom Luxury Duplex — Lekki Phase 1',
      propertyPurpose: 'rent',
      propertyPrice: 4500000,
      propertyNeighborhood: 'Lekki Phase 1, Lagos',
      ownerId: 'usr_landlord_001',
      ownerName: 'Chief Emeka Okonkwo',
      ownerEmail: 'emeka.okonkwo.properties@gmail.com',
      ownerPhone: '+2348031234567',
      titleDocumentType: 'c_of_o',
      titleDocumentNumber: 'C/O/LAGOS/LK1/2017/11892',
      titleDocumentUrls: ['https://storage.myrentilly.com/docs/cof_lekki_phase1_okonkwo.pdf'],
      ownerIdType: 'International Passport',
      ownerIdNumber: 'A12345678',
      ownerIdUrl: 'https://storage.myrentilly.com/docs/passport_okonkwo.jpg',
      discoProvider: 'EKEDC',
      discoMeterNumber: '45983021002',
      utilityBillUrl: 'https://storage.myrentilly.com/docs/ekedc_lekki_aug2026.pdf',
      landRegistrySearchStatus: 'verified_alausa',
      landRegistrySearchNotes: 'Title verified at Alausa Land Registry. C of O confirmed valid and unencumbered.',
      status: 'approved',
      reviewedBy: 'Rentilly Legal Team',
      reviewedAt: now,
      submittedAt: now,
    },
    {
      id: 'kyp_003',
      propertyId: 'prop_004',
      propertyTitle: '2-Bedroom Self Contain — Wuse 2, Abuja',
      propertyPurpose: 'rent',
      propertyPrice: 1200000,
      propertyNeighborhood: 'Wuse 2, FCT Abuja',
      ownerId: 'usr_landlord_004',
      ownerName: 'Alhaji Sani Abubakar',
      ownerEmail: 'sani.abubakar.prop@gmail.com',
      ownerPhone: '+2348074567890',
      titleDocumentType: 'deed_of_assignment',
      titleDocumentNumber: 'DA/AGIS/FCT/2021/07761',
      titleDocumentUrls: ['https://storage.myrentilly.com/docs/deed_wuse2_abubakar.pdf'],
      ownerIdType: 'NIN',
      ownerIdNumber: '98765432109',
      ownerIdUrl: 'https://storage.myrentilly.com/docs/nin_slip_abubakar.jpg',
      discoProvider: 'AEDC',
      discoMeterNumber: '60211934782',
      utilityBillUrl: 'https://storage.myrentilly.com/docs/aedc_wuse2_aug2026.pdf',
      landRegistrySearchStatus: 'verified_agis',
      landRegistrySearchNotes: 'Title verified at AGIS Abuja. Deed of Assignment confirmed authentic.',
      status: 'approved',
      reviewedBy: 'Rentilly Legal Team',
      reviewedAt: now,
      submittedAt: now,
    },
  ];
}

// ============================================================
// SEED DATA — Inspections
// ============================================================
function seedInspections(): Inspection[] {
  const now = new Date().toISOString();
  const tomorrow = new Date(Date.now() + 86400000).toISOString().split('T')[0];
  const nextWeek = new Date(Date.now() + 604800000).toISOString().split('T')[0];
  return [
    {
      id: 'insp_001',
      propertyId: 'prop_001',
      propertyTitle: '4-Bedroom Luxury Duplex — Lekki Phase 1',
      propertyAddress: '14B Admiralty Way, Lekki Phase 1, Lagos',
      prospectId: 'usr_renter_001',
      prospectName: 'Tomisin Kolawole',
      prospectPhone: '+2348026990956',
      ownerId: 'usr_landlord_001',
      ownerName: 'Chief Emeka Okonkwo',
      ownerPhone: '+2348031234567',
      scheduledDate: tomorrow,
      scheduledTimeSlot: '11:00 AM - 12:00 PM',
      inspectionPassCode: '728491',
      status: 'confirmed',
      prospectNotes: 'Looking for annual rent. Have kids (2). Need quiet environment.',
      createdAt: now,
    },
    {
      id: 'insp_002',
      propertyId: 'prop_002',
      propertyTitle: '3-Bedroom Flat — Maitama, Abuja',
      propertyAddress: '5 Aguiyi Ironsi Street, Maitama, FCT',
      prospectId: 'usr_renter_002',
      prospectName: 'Patrick Achua',
      prospectPhone: '+2349025034567',
      ownerId: 'usr_landlord_002',
      ownerName: 'Mrs Ngozi Danladi',
      ownerPhone: '+2348052345678',
      scheduledDate: nextWeek,
      scheduledTimeSlot: '2:00 PM - 3:00 PM',
      inspectionPassCode: '394021',
      status: 'pending_owner',
      createdAt: now,
    },
    {
      id: 'insp_003',
      propertyId: 'prop_005',
      propertyTitle: '5-Bedroom Terrace — Victoria Island',
      propertyAddress: '8 Adeola Odeku Street, Victoria Island, Lagos',
      prospectId: 'usr_renter_003',
      prospectName: 'Adaeze Obi-Nwosu',
      prospectPhone: '+2348011345678',
      ownerId: 'usr_landlord_005',
      ownerName: 'Dr. Adebayo Tinubu-Okafor',
      ownerPhone: '+2348085678901',
      scheduledDate: tomorrow,
      scheduledTimeSlot: '3:30 PM - 4:30 PM',
      inspectionPassCode: '561203',
      status: 'completed',
      ownerNotes: 'Prospect was professional and thorough during inspection.',
      createdAt: now,
    },
  ];
}

// ============================================================
// SEED DATA — Legal Agreements
// ============================================================
function seedLegalAgreements(): LegalAgreement[] {
  const now = new Date().toISOString();
  const nextYear = new Date(Date.now() + 365 * 86400000).toISOString().split('T')[0];
  return [
    {
      id: 'legal_001',
      propertyId: 'prop_001',
      propertyTitle: '4-Bedroom Luxury Duplex — Lekki Phase 1',
      transactionId: 'txn_escrow_001',
      landlordId: 'usr_landlord_001',
      landlordName: 'Chief Emeka Okonkwo',
      tenantId: 'usr_renter_001',
      tenantName: 'Tomisin Kolawole',
      agreementType: 'tenancy_agreement',
      agreementTitle: 'Annual Tenancy Agreement — 4BR Duplex Lekki Phase 1',
      governingLaw: 'Laws of Lagos State',
      tenancyCommencementDate: new Date().toISOString().split('T')[0],
      tenancyExpirationDate: nextYear,
      annualRent: 4500000,
      cautionDeposit: 500000,
      landlordSigned: true,
      landlordSignedAt: now,
      tenantSigned: false,
      legalOfficerStamp: false,
      status: 'pending_signatures',
      createdAt: now,
    },
    {
      id: 'legal_002',
      propertyId: 'prop_002',
      propertyTitle: '3-Bedroom Flat — Maitama, Abuja',
      transactionId: 'txn_escrow_002',
      landlordId: 'usr_landlord_002',
      landlordName: 'Mrs Ngozi Danladi',
      tenantId: 'usr_renter_002',
      tenantName: 'Patrick Achua',
      agreementType: 'tenancy_agreement',
      agreementTitle: 'Annual Tenancy Agreement — 3BR Flat Maitama Abuja',
      governingLaw: 'Laws of the Federal Capital Territory',
      tenancyCommencementDate: new Date().toISOString().split('T')[0],
      tenancyExpirationDate: nextYear,
      annualRent: 3200000,
      cautionDeposit: 300000,
      landlordSigned: true,
      landlordSignedAt: now,
      tenantSigned: true,
      tenantSignedAt: now,
      legalOfficerStamp: true,
      status: 'fully_executed',
      createdAt: now,
    },
  ];
}

// ============================================================
// ADMIN DATA STORE — Unified Persistent Access Layer
// ============================================================
export class AdminDataStore {

  // PROPERTIES
  static getProperties(): Property[] {
    return readFile<Property>('admin_properties.json', seedProperties);
  }

  static saveProperties(data: Property[]): void {
    writeFile('admin_properties.json', data);
  }

  static addProperty(p: Property): Property {
    const all = this.getProperties();
    all.unshift(p);
    this.saveProperties(all);
    return p;
  }

  static updatePropertyStatus(id: string, status: Property['status']): Property | null {
    const all = this.getProperties();
    const idx = all.findIndex(p => p.id === id);
    if (idx === -1) return null;
    all[idx] = { ...all[idx], status, updatedAt: new Date().toISOString() };
    this.saveProperties(all);
    return all[idx];
  }

  // KYP RECORDS
  static getKYP(status?: string): KYPRecord[] {
    const all = readFile<KYPRecord>('admin_kyp.json', seedKYP);
    if (status) return all.filter(k => k.status === status);
    return all;
  }

  static addKYP(record: KYPRecord): void {
    const all = readFile<KYPRecord>('admin_kyp.json', seedKYP);
    all.unshift(record);
    writeFile('admin_kyp.json', all);
  }

  static reviewKYP(id: string, status: KYPRecord['status'], notes?: string, reason?: string): KYPRecord | null {
    const all = readFile<KYPRecord>('admin_kyp.json', seedKYP);
    const idx = all.findIndex(k => k.id === id);
    if (idx === -1) return null;
    all[idx] = {
      ...all[idx],
      status,
      landRegistrySearchNotes: notes || all[idx].landRegistrySearchNotes,
      rejectionReason: reason,
      reviewedBy: 'Rentilly Admin',
      reviewedAt: new Date().toISOString(),
    };
    writeFile('admin_kyp.json', all);
    return all[idx];
  }

  // INSPECTIONS
  static getInspections(): Inspection[] {
    return readFile<Inspection>('admin_inspections.json', seedInspections);
  }

  static addInspection(insp: Inspection): Inspection {
    const all = this.getInspections();
    all.unshift(insp);
    writeFile('admin_inspections.json', all);
    return insp;
  }

  static updateInspectionStatus(id: string, status: Inspection['status'], ownerNotes?: string): Inspection | null {
    const all = this.getInspections();
    const idx = all.findIndex(i => i.id === id);
    if (idx === -1) return null;
    all[idx] = { ...all[idx], status, ownerNotes: ownerNotes || all[idx].ownerNotes };
    writeFile('admin_inspections.json', all);
    return all[idx];
  }

  // LEGAL AGREEMENTS
  static getLegalAgreements(): LegalAgreement[] {
    return readFile<LegalAgreement>('admin_legal.json', seedLegalAgreements);
  }

  static addLegalAgreement(a: LegalAgreement): LegalAgreement {
    const all = this.getLegalAgreements();
    all.unshift(a);
    writeFile('admin_legal.json', all);
    return a;
  }

  // ESCROW TRANSACTIONS — built from WalletTransactions in TransactionStore
  static buildEscrowTransactions(walletTxs: Array<any>): Transaction[] {
    // Map wallet deposit / escrow transactions to the escrow Transaction model
    return walletTxs
      .filter(tx => tx.category === 'deposit' || tx.category === 'rent' || tx.category === 'escrow')
      .map(tx => ({
        id: tx.id,
        propertyId: tx.propertyId || 'wallet_inbound',
        propertyTitle: tx.title || 'Direct Bank Inflow',
        payerId: tx.userId || tx.email,
        payerName: tx.sender || tx.email,
        ownerId: tx.userId || tx.email,
        ownerName: tx.beneficiary || tx.email,
        transactionType: 'rent' as const,
        paymentReference: tx.reference,
        paymentGateway: 'flutterwave' as const,
        baseAmount: tx.amount,
        rentillyLegalFee: Math.round(tx.amount * 0.1),
        cautionFee: 0,
        serviceCharge: 0,
        totalAmount: tx.amount,
        escrowStatus: tx.isCredit ? 'held_in_escrow' as const : 'released_to_owner' as const,
        createdAt: tx.date || new Date().toISOString(),
      }));
  }
}
