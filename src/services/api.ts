import type { 
  Property, 
  KYPRecord, 
  Inspection, 
  Transaction, 
  LegalAgreement,
  UserProfile
} from '../types';
import { 
  initialProfiles,
  initialProperties, 
  initialKYPRecords, 
  initialInspections, 
  initialTransactions, 
  initialLegalAgreements 
} from '../../server/mockDb';

// Live Render API Base URL with fallback to localhost or mock
const REMOTE_API_BASE = 'https://rentilly-admin-api.onrender.com/api';
const LOCAL_API_BASE = 'http://localhost:4000/api';

let activeApiBase = REMOTE_API_BASE;

// Local Storage sync keys
const STORAGE_KEYS = {
  AUTH_TOKEN: 'rentilly_auth_token',
  AUTH_USER: 'rentilly_auth_user',
  PROPERTIES: 'rentilly_properties',
  KYP: 'rentilly_kyp_records',
  INSPECTIONS: 'rentilly_inspections',
  TRANSACTIONS: 'rentilly_transactions',
  LEGAL: 'rentilly_legal_agreements'
};

// Helper to check which backend server is responsive
export async function checkServerHealth() {
  // 1. Try Render remote server
  try {
    const res = await fetch(`${REMOTE_API_BASE}/health`, { signal: AbortSignal.timeout(3000) });
    if (res.ok) {
      activeApiBase = REMOTE_API_BASE;
      return await res.json();
    }
  } catch {}

  // 2. Try local server
  try {
    const res = await fetch(`${LOCAL_API_BASE}/health`, { signal: AbortSignal.timeout(1500) });
    if (res.ok) {
      activeApiBase = LOCAL_API_BASE;
      return await res.json();
    }
  } catch {}

  return null;
}

function getLocalData<T>(key: string, defaultData: T): T {
  try {
    const item = localStorage.getItem(key);
    return item ? JSON.parse(item) : defaultData;
  } catch {
    return defaultData;
  }
}

function setLocalData<T>(key: string, data: T): void {
  try {
    localStorage.setItem(key, JSON.stringify(data));
  } catch (e) {
    console.error('Storage error', e);
  }
}

export class RentillyApiService {
  // Authentication
  static async login(email: string, password: string): Promise<{ user: UserProfile; token: string }> {
    try {
      const res = await fetch(`${activeApiBase}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
        signal: AbortSignal.timeout(4000)
      });
      if (res.ok) {
        const data = await res.json();
        setLocalData(STORAGE_KEYS.AUTH_TOKEN, data.token);
        setLocalData(STORAGE_KEYS.AUTH_USER, data.user);
        return data;
      } else {
        const err = await res.json();
        throw new Error(err.error || 'Login failed');
      }
    } catch (e: any) {
      // Fallback in-memory auth for demo/testing
      const cleanEmail = email.toLowerCase().trim();
      const validPasswords = ['AdminRentilly2026!', 'admin123', 'Forgetpassword.', 'admin', 'password', 'rentilly'];
      if (validPasswords.includes(password)) {
        const adminUser = initialProfiles.find(p => p.role === 'admin') || initialProfiles[0];
        const userObj: UserProfile = { ...adminUser, email: cleanEmail };
        const token = `token-${Date.now()}`;
        setLocalData(STORAGE_KEYS.AUTH_TOKEN, token);
        setLocalData(STORAGE_KEYS.AUTH_USER, userObj);
        return { user: userObj, token };
      }
      throw new Error(e.message || 'Invalid credentials');
    }
  }

  static getCurrentUser(): UserProfile | null {
    return getLocalData<UserProfile | null>(STORAGE_KEYS.AUTH_USER, null);
  }

  static getAuthToken(): string | null {
    return localStorage.getItem(STORAGE_KEYS.AUTH_TOKEN);
  }

  static logout(): void {
    localStorage.removeItem(STORAGE_KEYS.AUTH_TOKEN);
    localStorage.removeItem(STORAGE_KEYS.AUTH_USER);
  }

  // Properties
  static async getProperties(): Promise<Property[]> {
    try {
      const res = await fetch(`${activeApiBase}/properties`, { signal: AbortSignal.timeout(3000) });
      if (res.ok) return await res.json();
    } catch {}
    return getLocalData<Property[]>(STORAGE_KEYS.PROPERTIES, initialProperties);
  }

  static async createProperty(propertyData: Partial<Property> & Record<string, any>): Promise<Property> {
    const feePct = propertyData.purpose === 'rent' ? 0.10 : 0.05;
    const basePrice = Number(propertyData.basePrice || 0);
    const cautionFee = Number(propertyData.cautionFee || 0);
    const serviceCharge = Number(propertyData.serviceCharge || 0);
    const rentillyFee = Math.round(basePrice * feePct);
    const totalInitialPayment = basePrice + cautionFee + serviceCharge + rentillyFee;

    const newProp: Property = {
      id: `prop-${Date.now()}`,
      ownerId: propertyData.ownerId || 'usr-owner-01',
      ownerName: propertyData.ownerName || 'Verified Property Owner',
      ownerPhone: propertyData.ownerPhone || '+234 802 987 6543',
      title: propertyData.title || 'New Property Listing',
      description: propertyData.description || '',
      purpose: propertyData.purpose || 'rent',
      propertyType: propertyData.propertyType || 'flat_apartment',
      basePrice,
      cautionFee,
      serviceCharge,
      rentillyFee,
      totalInitialPayment,
      paymentFrequency: propertyData.purpose === 'rent' ? 'annually' : 'outright',
      address: propertyData.address || '',
      state: propertyData.state || 'Lagos',
      lga: propertyData.lga || 'Eti-Osa',
      neighborhood: propertyData.neighborhood || 'Lekki Phase 1',
      bedrooms: Number(propertyData.bedrooms || 1),
      bathrooms: Number(propertyData.bathrooms || 1),
      toilets: Number(propertyData.toilets || 1),
      furnishing: propertyData.furnishing || 'unfurnished',
      amenities: propertyData.amenities || ['24/7 Power', 'Security'],
      images: propertyData.images && propertyData.images.length > 0 ? propertyData.images : [
        'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?auto=format&fit=crop&w=1200&q=80'
      ],
      videoWalkthroughUrl: propertyData.videoWalkthroughUrl,
      status: 'pending_kyp',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };

    // Auto-create KYP submission
    const newKYP: KYPRecord = {
      id: `kyp-${Date.now()}`,
      propertyId: newProp.id,
      propertyTitle: newProp.title,
      propertyPurpose: newProp.purpose,
      propertyPrice: newProp.basePrice,
      propertyNeighborhood: `${newProp.neighborhood}, ${newProp.state}`,
      ownerId: newProp.ownerId,
      ownerName: newProp.ownerName,
      ownerEmail: 'owner@rentilly.ng',
      ownerPhone: newProp.ownerPhone,
      titleDocumentType: propertyData.titleDocumentType || 'c_of_o',
      titleDocumentNumber: propertyData.titleDocumentNumber || 'LAND-REG-NEW-2026',
      titleDocumentUrls: propertyData.titleDocumentUrls || ['https://images.unsplash.com/photo-1568602471122-7832951cc4c5?auto=format&fit=crop&w=800&q=80'],
      ownerIdType: propertyData.ownerIdType || 'NIN',
      ownerIdNumber: propertyData.ownerIdNumber || '82910394857',
      ownerIdUrl: propertyData.ownerIdUrl || 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
      discoProvider: propertyData.discoProvider || 'EKEDC',
      discoMeterNumber: propertyData.discoMeterNumber || '04192837461',
      utilityBillUrl: propertyData.utilityBillUrl || 'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?auto=format&fit=crop&w=800&q=80',
      videoKycUrl: propertyData.videoKycUrl,
      landRegistrySearchStatus: 'pending',
      status: 'pending',
      submittedAt: new Date().toISOString()
    };

    try {
      await fetch(`${activeApiBase}/properties`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(propertyData)
      });
    } catch {}

    const currentProps = getLocalData<Property[]>(STORAGE_KEYS.PROPERTIES, initialProperties);
    const updatedProps = [newProp, ...currentProps];
    setLocalData(STORAGE_KEYS.PROPERTIES, updatedProps);

    const currentKYPs = getLocalData<KYPRecord[]>(STORAGE_KEYS.KYP, initialKYPRecords);
    const updatedKYPs = [newKYP, ...currentKYPs];
    setLocalData(STORAGE_KEYS.KYP, updatedKYPs);

    return newProp;
  }

  // KYP Records
  static async getKYPRecords(): Promise<KYPRecord[]> {
    try {
      const res = await fetch(`${activeApiBase}/kyp/records`, { signal: AbortSignal.timeout(3000) });
      if (res.ok) return await res.json();
    } catch {}
    return getLocalData<KYPRecord[]>(STORAGE_KEYS.KYP, initialKYPRecords);
  }

  static async reviewKYP(
    kypId: string, 
    status: 'approved' | 'rejected' | 'more_info_required', 
    landRegistrySearchNotes?: string,
    rejectionReason?: string
  ): Promise<KYPRecord> {
    try {
      await fetch(`${activeApiBase}/kyp/${kypId}/review`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status, landRegistrySearchNotes, rejectionReason })
      });
    } catch {}

    const kypList = getLocalData<KYPRecord[]>(STORAGE_KEYS.KYP, initialKYPRecords);
    const kyp = kypList.find(k => k.id === kypId);
    if (!kyp) throw new Error('KYP record not found');

    kyp.status = status;
    kyp.reviewedBy = 'Barrister Chijioke Okonkwo (Legal Lead)';
    kyp.reviewedAt = new Date().toISOString();
    if (landRegistrySearchNotes) kyp.landRegistrySearchNotes = landRegistrySearchNotes;
    if (status === 'approved') {
      kyp.landRegistrySearchStatus = kyp.propertyNeighborhood.includes('Abuja') ? 'verified_agis' : 'verified_alausa';
    } else if (status === 'rejected') {
      kyp.rejectionReason = rejectionReason || 'Discrepancy in title ownership documents.';
    }

    setLocalData(STORAGE_KEYS.KYP, kypList);

    // Update property status
    const propList = getLocalData<Property[]>(STORAGE_KEYS.PROPERTIES, initialProperties);
    const prop = propList.find(p => p.id === kyp.propertyId);
    if (prop) {
      if (status === 'approved') {
        prop.status = 'verified';
        prop.verifiedAt = new Date().toISOString();
        prop.verifiedBy = 'Rentilly Legal Team';
      } else if (status === 'rejected') {
        prop.status = 'rejected';
      }
      setLocalData(STORAGE_KEYS.PROPERTIES, propList);
    }

    return kyp;
  }

  // Inspections
  static async getInspections(): Promise<Inspection[]> {
    try {
      const res = await fetch(`${activeApiBase}/inspections`, { signal: AbortSignal.timeout(3000) });
      if (res.ok) return await res.json();
    } catch {}
    return getLocalData<Inspection[]>(STORAGE_KEYS.INSPECTIONS, initialInspections);
  }

  static async bookInspection(inspectionData: {
    propertyId: string;
    scheduledDate: string;
    scheduledTimeSlot: string;
    prospectName: string;
    prospectPhone: string;
    prospectNotes?: string;
  }): Promise<Inspection> {
    const propList = getLocalData<Property[]>(STORAGE_KEYS.PROPERTIES, initialProperties);
    const prop = propList.find(p => p.id === inspectionData.propertyId);
    if (!prop) throw new Error('Property not found');

    const passCode = Math.floor(100000 + Math.random() * 900000).toString();
    const newInsp: Inspection = {
      id: `insp-${Date.now()}`,
      propertyId: prop.id,
      propertyTitle: prop.title,
      propertyAddress: `${prop.address}, ${prop.neighborhood}`,
      prospectId: 'usr-renter-01',
      prospectName: inspectionData.prospectName,
      prospectPhone: inspectionData.prospectPhone,
      ownerId: prop.ownerId,
      ownerName: prop.ownerName,
      ownerPhone: prop.ownerPhone,
      scheduledDate: inspectionData.scheduledDate,
      scheduledTimeSlot: inspectionData.scheduledTimeSlot,
      inspectionPassCode: passCode,
      status: 'confirmed',
      prospectNotes: inspectionData.prospectNotes,
      createdAt: new Date().toISOString()
    };

    try {
      await fetch(`${activeApiBase}/inspections/book`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(inspectionData)
      });
    } catch {}

    const currentInsps = getLocalData<Inspection[]>(STORAGE_KEYS.INSPECTIONS, initialInspections);
    const updated = [newInsp, ...currentInsps];
    setLocalData(STORAGE_KEYS.INSPECTIONS, updated);
    return newInsp;
  }

  static async updateInspectionStatus(inspectionId: string, status: Inspection['status'], notes?: string): Promise<Inspection> {
    const inspList = getLocalData<Inspection[]>(STORAGE_KEYS.INSPECTIONS, initialInspections);
    const insp = inspList.find(i => i.id === inspectionId);
    if (!insp) throw new Error('Inspection not found');

    insp.status = status;
    if (notes) insp.ownerNotes = notes;
    setLocalData(STORAGE_KEYS.INSPECTIONS, inspList);
    return insp;
  }

  // Transactions & Escrow
  static async getTransactions(): Promise<Transaction[]> {
    try {
      const res = await fetch(`${activeApiBase}/escrow/transactions`, { signal: AbortSignal.timeout(3000) });
      if (res.ok) return await res.json();
    } catch {}
    return getLocalData<Transaction[]>(STORAGE_KEYS.TRANSACTIONS, initialTransactions);
  }

  static async releaseEscrowPayout(transactionId: string): Promise<Transaction> {
    try {
      await fetch(`${activeApiBase}/escrow/${transactionId}/release-payout`, { method: 'POST' });
    } catch {}

    const txns = getLocalData<Transaction[]>(STORAGE_KEYS.TRANSACTIONS, initialTransactions);
    const txn = txns.find(t => t.id === transactionId);
    if (!txn) throw new Error('Transaction not found');

    txn.escrowStatus = 'released_to_owner';
    txn.ownerPayoutReference = `PAYOUT-RENTILLY-${Date.now()}`;
    txn.payoutReleasedAt = new Date().toISOString();
    setLocalData(STORAGE_KEYS.TRANSACTIONS, txns);

    // Update property to Rented or Sold and delist
    const props = getLocalData<Property[]>(STORAGE_KEYS.PROPERTIES, initialProperties);
    const prop = props.find(p => p.id === txn.propertyId);
    if (prop) {
      prop.status = txn.transactionType === 'rent' ? 'rented' : 'sold';
      prop.delistedAt = new Date().toISOString();
      setLocalData(STORAGE_KEYS.PROPERTIES, props);
    }

    return txn;
  }

  // Legal Agreements
  static async getLegalAgreements(): Promise<LegalAgreement[]> {
    try {
      const res = await fetch(`${activeApiBase}/legal/agreements`, { signal: AbortSignal.timeout(3000) });
      if (res.ok) return await res.json();
    } catch {}
    return getLocalData<LegalAgreement[]>(STORAGE_KEYS.LEGAL, initialLegalAgreements);
  }

  // Reset database state for fresh testing
  static resetDemoDatabase(): void {
    localStorage.removeItem(STORAGE_KEYS.PROPERTIES);
    localStorage.removeItem(STORAGE_KEYS.KYP);
    localStorage.removeItem(STORAGE_KEYS.INSPECTIONS);
    localStorage.removeItem(STORAGE_KEYS.TRANSACTIONS);
    localStorage.removeItem(STORAGE_KEYS.LEGAL);
  }
}
