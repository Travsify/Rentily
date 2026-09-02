import type { 
  Property, 
  KYPRecord, 
  Inspection, 
  Transaction, 
  LegalAgreement,
  UserProfile
} from '../types';

// Dynamic API Base URL — dynamically targets current host origin
const getApiBase = () => {
  if (typeof window !== 'undefined') {
    return `${window.location.origin}/api`;
  }
  return '/api';
};

const activeApiBase = getApiBase();

const STORAGE_KEYS = {
  AUTH_TOKEN: 'rentilly_auth_token',
  AUTH_USER: 'rentilly_auth_user'
};

// Check backend availability
export async function checkServerHealth() {
  try {
    const res = await fetch(`${activeApiBase}/health`, { signal: AbortSignal.timeout(3000) });
    if (res.ok) {
      return await res.json();
    }
  } catch {}

  return null;
}

export class RentillyApiService {
  // 1. Authentication
  static async login(email: string, password: string): Promise<{ user: UserProfile; token: string }> {
    const res = await fetch(`${activeApiBase}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password })
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({ error: 'Authentication failed' }));
      throw new Error(err.error || 'Authentication failed');
    }

    const data = await res.json();
    localStorage.setItem(STORAGE_KEYS.AUTH_TOKEN, data.token);
    localStorage.setItem(STORAGE_KEYS.AUTH_USER, JSON.stringify(data.user));
    return data;
  }

  static getCurrentUser(): UserProfile | null {
    try {
      const user = localStorage.getItem(STORAGE_KEYS.AUTH_USER);
      return user ? JSON.parse(user) : null;
    } catch {
      return null;
    }
  }

  static getAuthToken(): string | null {
    return localStorage.getItem(STORAGE_KEYS.AUTH_TOKEN);
  }

  static logout(): void {
    localStorage.removeItem(STORAGE_KEYS.AUTH_TOKEN);
    localStorage.removeItem(STORAGE_KEYS.AUTH_USER);
  }

  // 2. Properties
  static async getProperties(params?: { purpose?: string; status?: string; search?: string }): Promise<Property[]> {
    try {
      const query = new URLSearchParams(params as Record<string, string>).toString();
      const url = `${activeApiBase}/properties${query ? `?${query}` : ''}`;
      const res = await fetch(url);
      if (res.ok) return await res.json();
    } catch (e) {
      console.error('Error fetching properties:', e);
    }
    return [];
  }

  static async createProperty(propertyData: Partial<Property> & Record<string, any>): Promise<Property> {
    const res = await fetch(`${activeApiBase}/properties`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(propertyData)
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({ error: 'Failed to create property' }));
      throw new Error(err.error || 'Failed to create property');
    }

    return await res.json();
  }

  static async updatePropertyStatus(id: string, status: Property['status']): Promise<Property> {
    const res = await fetch(`${activeApiBase}/properties/${id}/status`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status })
    });

    if (!res.ok) throw new Error('Failed to update property status');
    return await res.json();
  }

  // 3. KYP Verifications
  static async getKYPRecords(status?: string): Promise<KYPRecord[]> {
    try {
      const url = `${activeApiBase}/kyp/records${status ? `?status=${status}` : ''}`;
      const res = await fetch(url);
      if (res.ok) return await res.json();
    } catch (e) {
      console.error('Error fetching KYP records:', e);
    }
    return [];
  }

  static async reviewKYP(
    kypId: string, 
    status: 'approved' | 'rejected' | 'more_info_required', 
    landRegistrySearchNotes?: string,
    rejectionReason?: string
  ): Promise<KYPRecord> {
    const res = await fetch(`${activeApiBase}/kyp/${kypId}/review`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status, landRegistrySearchNotes, rejectionReason })
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({ error: 'Failed to review KYP record' }));
      throw new Error(err.error || 'Failed to review KYP record');
    }

    return await res.json();
  }

  // 4. Inspections
  static async getInspections(): Promise<Inspection[]> {
    try {
      const res = await fetch(`${activeApiBase}/inspections`);
      if (res.ok) return await res.json();
    } catch (e) {
      console.error('Error fetching inspections:', e);
    }
    return [];
  }

  static async bookInspection(data: {
    propertyId: string;
    scheduledDate: string;
    scheduledTimeSlot: string;
    prospectName?: string;
    prospectPhone?: string;
    prospectNotes?: string;
  }): Promise<Inspection> {
    const res = await fetch(`${activeApiBase}/inspections/book`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });

    if (!res.ok) throw new Error('Failed to book inspection');
    return await res.json();
  }

  static async updateInspectionStatus(id: string, status: Inspection['status'], ownerNotes?: string): Promise<Inspection> {
    const res = await fetch(`${activeApiBase}/inspections/${id}/status`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status, ownerNotes })
    });

    if (!res.ok) throw new Error('Failed to update inspection status');
    return await res.json();
  }

  // 5. Escrow & Transactions
  static async getTransactions(): Promise<Transaction[]> {
    try {
      const res = await fetch(`${activeApiBase}/escrow/transactions`);
      if (res.ok) return await res.json();
    } catch (e) {
      console.error('Error fetching transactions:', e);
    }
    return [];
  }

  static async releaseEscrowPayout(transactionId: string): Promise<Transaction> {
    const res = await fetch(`${activeApiBase}/escrow/${transactionId}/release-payout`, {
      method: 'POST'
    });

    if (!res.ok) throw new Error('Failed to release escrow payout');
    return await res.json();
  }

  // 6. Legal Agreements
  static async getLegalAgreements(): Promise<LegalAgreement[]> {
    try {
      const res = await fetch(`${activeApiBase}/legal/agreements`);
      if (res.ok) return await res.json();
    } catch (e) {
      console.error('Error fetching legal agreements:', e);
    }
    return [];
  }

  static async generateAgreement(data: {
    propertyId: string;
    tenantId?: string;
    tenantName?: string;
    commencementDate?: string;
    durationMonths?: number;
  }): Promise<LegalAgreement> {
    const res = await fetch(`${activeApiBase}/legal/generate-agreement`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });

    if (!res.ok) throw new Error('Failed to generate legal agreement');
    return await res.json();
  }

  // 7. Users & Stakeholders Audit
  static async getUsers(): Promise<UserProfile[]> {
    try {
      const res = await fetch(`${activeApiBase}/users`);
      if (res.ok) return await res.json();
    } catch (e) {
      console.error('Error fetching users:', e);
    }
    return [];
  }

  // 8. Dynamic Supabase Configuration
  static async configureSupabase(data: { url: string; anonKey?: string; serviceRoleKey?: string }): Promise<{ success: boolean; connected: boolean; message: string }> {
    const res = await fetch(`${activeApiBase}/config/supabase`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });
    return await res.json();
  }
}
