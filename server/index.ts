import express from 'express';
import type { Request, Response } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { 
  initialProfiles, 
  initialProperties, 
  initialKYPRecords, 
  initialInspections, 
  initialTransactions, 
  initialLegalAgreements 
} from './mockDb';
import type { 
  Property, 
  KYPRecord, 
  Inspection, 
  Transaction, 
  LegalAgreement, 
  UserProfile 
} from './types';
import { isSupabaseConfigured } from './supabaseClient';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 4000;

app.use(cors({ origin: '*' }));
app.use(express.json());

// In-Memory Database Store (with Supabase sync fallback)
let dbProfiles: UserProfile[] = [...initialProfiles];
let dbProperties: Property[] = [...initialProperties];
let dbKYPRecords: KYPRecord[] = [...initialKYPRecords];
let dbInspections: Inspection[] = [...initialInspections];
let dbTransactions: Transaction[] = [...initialTransactions];
let dbLegalAgreements: LegalAgreement[] = [...initialLegalAgreements];

// ==========================================
// 1. SYSTEM HEALTH & SUPABASE STATUS
// ==========================================
app.get('/api/health', (_req: Request, res: Response) => {
  res.json({
    status: 'healthy',
    platform: 'Rentilly Admin & Core API',
    version: '1.0.0',
    supabaseConnected: isSupabaseConfigured(),
    timestamp: new Date().toISOString(),
    stats: {
      propertiesCount: dbProperties.length,
      kypPendingCount: dbKYPRecords.filter(k => k.status === 'pending').length,
      inspectionsCount: dbInspections.length,
      escrowBalance: dbTransactions
        .filter(t => t.escrowStatus === 'held_in_escrow')
        .reduce((sum, t) => sum + t.totalAmount, 0)
    }
  });
});

// ==========================================
// 2. ANALYTICS & EXECUTIVE METRICS
// ==========================================
app.get('/api/analytics/metrics', (_req: Request, res: Response) => {
  const totalGMV = dbTransactions.reduce((acc, t) => acc + t.totalAmount, 0);
  const totalRentillyCommission = dbTransactions.reduce((acc, t) => acc + t.rentillyLegalFee, 0);
  const activeEscrowHeld = dbTransactions
    .filter(t => t.escrowStatus === 'held_in_escrow')
    .reduce((acc, t) => acc + t.totalAmount, 0);
  const verifiedProperties = dbProperties.filter(p => p.status === 'verified').length;
  const pendingKYP = dbKYPRecords.filter(k => k.status === 'pending').length;
  const activeInspections = dbInspections.filter(i => i.status === 'confirmed').length;

  res.json({
    totalGMV,
    totalRentillyCommission,
    activeEscrowHeld,
    verifiedProperties,
    pendingKYP,
    activeInspections,
    totalProperties: dbProperties.length,
    totalUsers: dbProfiles.length
  });
});

// ==========================================
// 3. PROPERTIES ENDPOINTS
// ==========================================
app.get('/api/properties', (req: Request, res: Response) => {
  const { purpose, status, state, search } = req.query;
  let result = [...dbProperties];

  if (purpose) {
    result = result.filter(p => p.purpose === purpose);
  }
  if (status) {
    result = result.filter(p => p.status === status);
  }
  if (state) {
    result = result.filter(p => p.state.toLowerCase().includes((state as string).toLowerCase()));
  }
  if (search) {
    const q = (search as string).toLowerCase();
    result = result.filter(p => 
      p.title.toLowerCase().includes(q) || 
      p.neighborhood.toLowerCase().includes(q) ||
      p.address.toLowerCase().includes(q)
    );
  }

  res.json(result);
});

app.get('/api/properties/:id', (req: Request, res: Response) => {
  const property = dbProperties.find(p => p.id === req.params.id);
  if (!property) {
    return res.status(404).json({ error: 'Property not found' });
  }
  res.json(property);
});

app.post('/api/properties', (req: Request, res: Response) => {
  const body = req.body;
  const feePercentage = body.purpose === 'rent' ? 0.10 : 0.05;
  const rentillyFee = Math.round(Number(body.basePrice) * feePercentage);
  const cautionFee = Number(body.cautionFee || 0);
  const serviceCharge = Number(body.serviceCharge || 0);
  const totalInitialPayment = Number(body.basePrice) + cautionFee + serviceCharge + rentillyFee;

  const newProperty: Property = {
    id: `prop-${Date.now()}`,
    ownerId: body.ownerId || 'usr-owner-01',
    ownerName: body.ownerName || 'Verified Property Owner',
    ownerPhone: body.ownerPhone || '+2348000000000',
    title: body.title,
    description: body.description,
    purpose: body.purpose || 'rent',
    propertyType: body.propertyType || 'flat_apartment',
    basePrice: Number(body.basePrice),
    cautionFee,
    serviceCharge,
    rentillyFee,
    totalInitialPayment,
    paymentFrequency: body.purpose === 'rent' ? 'annually' : 'outright',
    address: body.address,
    state: body.state || 'Lagos',
    lga: body.lga || 'Eti-Osa',
    neighborhood: body.neighborhood || 'Lekki Phase 1',
    bedrooms: Number(body.bedrooms || 1),
    bathrooms: Number(body.bathrooms || 1),
    toilets: Number(body.toilets || 1),
    furnishing: body.furnishing || 'unfurnished',
    amenities: body.amenities || ['24/7 Power', 'Security'],
    images: body.images && body.images.length > 0 ? body.images : [
      'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?auto=format&fit=crop&w=1200&q=80'
    ],
    videoWalkthroughUrl: body.videoWalkthroughUrl,
    status: 'pending_kyp',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  };

  dbProperties.unshift(newProperty);

  // Auto-generate a pending KYP record
  const newKYP: KYPRecord = {
    id: `kyp-${Date.now()}`,
    propertyId: newProperty.id,
    propertyTitle: newProperty.title,
    propertyPurpose: newProperty.purpose,
    propertyPrice: newProperty.basePrice,
    propertyNeighborhood: `${newProperty.neighborhood}, ${newProperty.state}`,
    ownerId: newProperty.ownerId,
    ownerName: newProperty.ownerName,
    ownerEmail: 'owner@rentilly.ng',
    ownerPhone: newProperty.ownerPhone,
    titleDocumentType: body.titleDocumentType || 'c_of_o',
    titleDocumentNumber: body.titleDocumentNumber || 'LAND-REG-PENDING',
    titleDocumentUrls: body.titleDocumentUrls || ['https://images.unsplash.com/photo-1568602471122-7832951cc4c5?auto=format&fit=crop&w=800&q=80'],
    ownerIdType: body.ownerIdType || 'NIN',
    ownerIdNumber: body.ownerIdNumber || '12345678901',
    ownerIdUrl: body.ownerIdUrl || 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
    discoProvider: body.discoProvider || 'EKEDC',
    discoMeterNumber: body.discoMeterNumber || '04000000000',
    utilityBillUrl: body.utilityBillUrl || 'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?auto=format&fit=crop&w=800&q=80',
    landRegistrySearchStatus: 'pending',
    status: 'pending',
    submittedAt: new Date().toISOString()
  };

  dbKYPRecords.unshift(newKYP);

  res.status(201).json({ property: newProperty, kypRecord: newKYP });
});

app.patch('/api/properties/:id/status', (req: Request, res: Response) => {
  const { status } = req.body;
  const property = dbProperties.find(p => p.id === req.params.id);
  if (!property) {
    return res.status(404).json({ error: 'Property not found' });
  }

  property.status = status;
  property.updatedAt = new Date().toISOString();
  if (status === 'verified') {
    property.verifiedAt = new Date().toISOString();
    property.verifiedBy = 'Rentilly Legal Admin';
  }

  res.json(property);
});

// ==========================================
// 4. KYP (KNOW YOUR PROPERTY) DESK ENDPOINTS
// ==========================================
app.get('/api/kyp/records', (req: Request, res: Response) => {
  const { status } = req.query;
  let result = [...dbKYPRecords];
  if (status) {
    result = result.filter(k => k.status === status);
  }
  res.json(result);
});

app.get('/api/kyp/:id', (req: Request, res: Response) => {
  const kyp = dbKYPRecords.find(k => k.id === req.params.id);
  if (!kyp) {
    return res.status(404).json({ error: 'KYP Record not found' });
  }
  res.json(kyp);
});

app.post('/api/kyp/:id/review', (req: Request, res: Response) => {
  const { status, landRegistrySearchStatus, landRegistrySearchNotes, rejectionReason, reviewerName } = req.body;
  const kyp = dbKYPRecords.find(k => k.id === req.params.id);
  if (!kyp) {
    return res.status(404).json({ error: 'KYP Record not found' });
  }

  kyp.status = status;
  kyp.landRegistrySearchStatus = landRegistrySearchStatus || kyp.landRegistrySearchStatus;
  kyp.landRegistrySearchNotes = landRegistrySearchNotes || kyp.landRegistrySearchNotes;
  kyp.rejectionReason = rejectionReason;
  kyp.reviewedBy = reviewerName || 'Barrister Chijioke Okonkwo';
  kyp.reviewedAt = new Date().toISOString();

  // Update associated property status
  const property = dbProperties.find(p => p.id === kyp.propertyId);
  if (property) {
    if (status === 'approved') {
      property.status = 'verified';
      property.verifiedAt = new Date().toISOString();
      property.verifiedBy = reviewerName || 'Barrister Chijioke Okonkwo';
    } else if (status === 'rejected') {
      property.status = 'rejected';
    }
  }

  res.json({ kyp, property });
});

// ==========================================
// 5. INSPECTION SCHEDULER ENDPOINTS
// ==========================================
app.get('/api/inspections', (_req: Request, res: Response) => {
  res.json(dbInspections);
});

app.post('/api/inspections/book', (req: Request, res: Response) => {
  const body = req.body;
  const property = dbProperties.find(p => p.id === body.propertyId);
  if (!property) {
    return res.status(404).json({ error: 'Property not found' });
  }

  const passCode = Math.floor(100000 + Math.random() * 900000).toString();
  const newInspection: Inspection = {
    id: `insp-${Date.now()}`,
    propertyId: property.id,
    propertyTitle: property.title,
    propertyAddress: `${property.address}, ${property.neighborhood}`,
    prospectId: body.prospectId || 'usr-renter-01',
    prospectName: body.prospectName || 'Femi Adesanya',
    prospectPhone: body.prospectPhone || '+234 812 345 6789',
    ownerId: property.ownerId,
    ownerName: property.ownerName,
    ownerPhone: property.ownerPhone,
    scheduledDate: body.scheduledDate,
    scheduledTimeSlot: body.scheduledTimeSlot || '11:00 AM - 12:00 PM',
    inspectionPassCode: passCode,
    status: 'pending_owner',
    prospectNotes: body.prospectNotes,
    createdAt: new Date().toISOString()
  };

  dbInspections.unshift(newInspection);
  res.status(201).json(newInspection);
});

app.patch('/api/inspections/:id/status', (req: Request, res: Response) => {
  const { status, ownerNotes } = req.body;
  const inspection = dbInspections.find(i => i.id === req.params.id);
  if (!inspection) {
    return res.status(404).json({ error: 'Inspection not found' });
  }

  inspection.status = status;
  if (ownerNotes) inspection.ownerNotes = ownerNotes;
  res.json(inspection);
});

// ==========================================
// 6. ESCROW & TRANSACTION ENDPOINTS
// ==========================================
app.get('/api/escrow/transactions', (_req: Request, res: Response) => {
  res.json(dbTransactions);
});

app.post('/api/escrow/:id/release-payout', (req: Request, res: Response) => {
  const transaction = dbTransactions.find(t => t.id === req.params.id);
  if (!transaction) {
    return res.status(404).json({ error: 'Transaction not found' });
  }

  transaction.escrowStatus = 'released_to_owner';
  transaction.ownerPayoutReference = `PAYOUT-RENTILLY-${Date.now()}`;
  transaction.payoutReleasedAt = new Date().toISOString();

  // Mark property as rented / sold and delist
  const property = dbProperties.find(p => p.id === transaction.propertyId);
  if (property) {
    property.status = property.purpose === 'rent' ? 'rented' : 'sold';
    property.delistedAt = new Date().toISOString();
  }

  res.json({ transaction, property });
});

// ==========================================
// 7. LEGAL AGREEMENTS & CONTRACTS
// ==========================================
app.get('/api/legal/agreements', (_req: Request, res: Response) => {
  res.json(dbLegalAgreements);
});

app.post('/api/legal/generate-agreement', (req: Request, res: Response) => {
  const { propertyId, tenantId, tenantName, commencementDate, durationMonths = 12 } = req.body;
  const property = dbProperties.find(p => p.id === propertyId);
  if (!property) {
    return res.status(404).json({ error: 'Property not found' });
  }

  const startDate = new Date(commencementDate || Date.now());
  const expDate = new Date(startDate);
  expDate.setMonth(expDate.getMonth() + durationMonths);

  const agreementType = property.purpose === 'rent' ? 'tenancy_agreement' : 'contract_of_sale';
  const newAgreement: LegalAgreement = {
    id: `leg-${Date.now()}`,
    propertyId: property.id,
    propertyTitle: property.title,
    transactionId: `txn-${Date.now()}`,
    landlordId: property.ownerId,
    landlordName: property.ownerName,
    tenantId: tenantId || 'usr-renter-01',
    tenantName: tenantName || 'Femi Adesanya',
    agreementType,
    agreementTitle: property.purpose === 'rent' 
      ? 'Standard Residential Tenancy Agreement (Lagos Tenancy Law 2011 / FCT Laws)'
      : 'Standard Contract of Sale of Real Property & Deed Transfer Covenants',
    governingLaw: property.state === 'Lagos' ? 'Lagos State Tenancy Law 2011' : 'Recovery of Premises Act & Laws of the FCT',
    tenancyCommencementDate: startDate.toISOString().split('T')[0],
    tenancyExpirationDate: expDate.toISOString().split('T')[0],
    annualRent: property.basePrice,
    cautionDeposit: property.cautionFee,
    landlordSigned: false,
    tenantSigned: false,
    legalOfficerStamp: true,
    status: 'drafting',
    createdAt: new Date().toISOString()
  };

  dbLegalAgreements.unshift(newAgreement);
  res.status(201).json(newAgreement);
});

// Start Express Server
if (process.env.NODE_ENV !== 'test') {
  app.listen(PORT, () => {
    console.log(`=================================================`);
    console.log(`🚀 Rentilly Admin Backend & API running on port ${PORT}`);
    console.log(`🛡️ KYP Verification & Escrow Engine Active`);
    console.log(`📦 Supabase Status: ${isSupabaseConfigured() ? 'Connected ✅' : 'Mock Memory Fallback Mode ⚡'}`);
    console.log(`=================================================`);
  });
}

export default app;
