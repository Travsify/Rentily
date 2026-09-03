import { supabase } from '../supabaseClient';
import type { Property, KYPRecord, Inspection, LegalAgreement } from '../types';

// In-memory runtime cache hydrated and synced with Supabase Cloud
let _propertiesCache: Property[] = [];
let _kypCache: KYPRecord[] = [];
let _inspectionsCache: Inspection[] = [];
let _agreementsCache: LegalAgreement[] = [];

export class AdminDataStore {
  /**
   * Hydrates all admin data from Supabase Cloud on server startup
   */
  static async initFromSupabase(): Promise<void> {
    if (!supabase) return;

    // 1. Hydrate Properties
    try {
      const { data, error } = await supabase
        .from('properties')
        .select('*')
        .order('created_at', { ascending: false });

      if (!error && data) {
        _propertiesCache = data.map((p: any) => ({
          id: p.id,
          title: p.title || 'Property',
          description: p.description || '',
          purpose: p.purpose || 'rent',
          propertyType: p.property_type || 'flat_apartment',
          basePrice: Number(p.base_price || 0),
          cautionFee: Number(p.caution_fee || 0),
          serviceCharge: Number(p.service_charge || 0),
          rentillyFee: Number(p.rentilly_fee || 0),
          totalInitialPayment: Number(p.total_initial_payment || 0),
          paymentFrequency: p.payment_frequency || 'annually',
          address: p.address || '',
          state: p.state || 'Lagos',
          lga: p.lga || 'Eti-Osa',
          neighborhood: p.neighborhood || 'Lekki',
          bedrooms: p.bedrooms || 1,
          bathrooms: p.bathrooms || 1,
          toilets: p.toilets || 1,
          furnishing: p.furnishing || 'unfurnished',
          amenities: p.amenities || [],
          images: p.images || [],
          videoWalkthroughUrl: p.video_walkthrough_url,
          status: p.status || 'pending_kyp',
          ownerId: p.owner_id || '',
          ownerName: 'Property Owner',
          ownerPhone: '+2348000000000',
          listedByRole: 'owner',
          createdAt: p.created_at || new Date().toISOString(),
          updatedAt: p.updated_at || new Date().toISOString(),
        }));
        console.log(`[AdminDataStore] Hydrated ${_propertiesCache.length} properties from Supabase.`);
      }
    } catch (e: any) {
      console.warn('[AdminDataStore] Properties hydration notice:', e.message);
    }

    // 2. Hydrate Inspections
    try {
      const { data, error } = await supabase
        .from('inspections')
        .select('*')
        .order('created_at', { ascending: false });

      if (!error && data) {
        _inspectionsCache = data.map((i: any) => ({
          id: i.id,
          propertyId: i.property_id,
          renterId: i.renter_id,
          date: i.date || '',
          timeSlot: i.time_slot || '',
          type: i.type || 'physical',
          status: i.status || 'pending',
          propertyTitle: i.property_title || '',
          propertyAddress: i.property_address || '',
          renterName: i.renter_name || '',
          renterPhone: i.renter_phone || '',
          renterEmail: i.renter_email || '',
          ownerNotes: i.owner_notes,
          feedback: i.feedback,
          rating: i.rating,
          createdAt: i.created_at || new Date().toISOString(),
          updatedAt: i.updated_at || new Date().toISOString(),
        }));
      }
    } catch (_) {}

    // 3. Hydrate Legal Agreements
    try {
      const { data, error } = await supabase
        .from('legal_agreements')
        .select('*')
        .order('created_at', { ascending: false });

      if (!error && data) {
        _agreementsCache = data.map((a: any) => ({
          id: a.id,
          propertyId: a.property_id,
          renterId: a.renter_id,
          ownerId: a.owner_id,
          agreementType: a.agreement_type || 'residential_lease',
          status: a.status || 'draft',
          agreementText: a.agreement_text || '',
          rentAmount: Number(a.rent_amount || 0),
          tenancyPeriodMonths: a.tenancy_period_months || 12,
          startDate: a.start_date || '',
          endDate: a.end_date || '',
          signedByRenterAt: a.signed_by_renter_at,
          signedByOwnerAt: a.signed_by_owner_at,
          createdAt: a.created_at || new Date().toISOString(),
          updatedAt: a.updated_at || new Date().toISOString(),
        }));
      }
    } catch (_) {}
  }

  // ============================================================
  // PROPERTIES
  // ============================================================
  static getProperties(): Property[] {
    return _propertiesCache;
  }

  static async addProperty(p: Property): Promise<Property> {
    const existingIdx = _propertiesCache.findIndex(item => item.id === p.id);
    if (existingIdx >= 0) {
      _propertiesCache[existingIdx] = { ..._propertiesCache[existingIdx], ...p, updatedAt: new Date().toISOString() };
    } else {
      _propertiesCache.unshift(p);
    }

    // Save to Supabase
    if (supabase) {
      try {
        await supabase.from('properties').upsert({
          id: p.id,
          owner_id: p.ownerId || 'b0000000-0000-0000-0000-000000000001',
          title: p.title,
          description: p.description,
          purpose: p.purpose,
          property_type: p.propertyType,
          base_price: p.basePrice,
          caution_fee: p.cautionFee || 0,
          service_charge: p.serviceCharge || 0,
          rentilly_fee: p.rentillyFee,
          total_initial_payment: p.totalInitialPayment,
          payment_frequency: p.paymentFrequency || 'annually',
          address: p.address,
          state: p.state || 'Lagos',
          lga: p.lga || 'Eti-Osa',
          neighborhood: p.neighborhood || 'Lekki',
          bedrooms: p.bedrooms || 1,
          bathrooms: p.bathrooms || 1,
          toilets: p.toilets || 1,
          furnishing: p.furnishing || 'unfurnished',
          amenities: p.amenities || [],
          images: p.images || [],
          video_walkthrough_url: p.videoWalkthroughUrl,
          status: p.status || 'pending_kyp',
          created_at: p.createdAt || new Date().toISOString(),
          updated_at: new Date().toISOString()
        }, { onConflict: 'id' });
      } catch (err) {
        console.error('[AdminDataStore] Error saving property to Supabase:', err);
      }
    }

    return p;
  }

  static async updatePropertyStatus(id: string, status: Property['status']): Promise<Property | null> {
    const idx = _propertiesCache.findIndex(p => p.id === id);
    if (idx === -1) return null;

    _propertiesCache[idx] = { ..._propertiesCache[idx], status, updatedAt: new Date().toISOString() };

    if (supabase) {
      try {
        await supabase
          .from('properties')
          .update({ status, updated_at: new Date().toISOString() })
          .eq('id', id);
      } catch (err) {
        console.error('[AdminDataStore] Error updating property status in Supabase:', err);
      }
    }

    return _propertiesCache[idx];
  }

  // ============================================================
  // KYP RECORDS
  // ============================================================
  static getKYP(status?: string): KYPRecord[] {
    if (status) return _kypCache.filter(k => k.status === status);
    return _kypCache;
  }

  static async addKYP(record: KYPRecord): Promise<KYPRecord> {
    const existingIdx = _kypCache.findIndex(item => item.id === record.id || item.propertyId === record.propertyId);
    if (existingIdx >= 0) {
      _kypCache[existingIdx] = { ..._kypCache[existingIdx], ...record };
    } else {
      _kypCache.unshift(record);
    }
    return record;
  }

  static async reviewKYP(id: string, status: KYPRecord['status'], notes?: string, reason?: string): Promise<KYPRecord | null> {
    const idx = _kypCache.findIndex(k => k.id === id);
    if (idx === -1) return null;

    _kypCache[idx] = {
      ..._kypCache[idx],
      status,
      landRegistrySearchNotes: notes || _kypCache[idx].landRegistrySearchNotes,
      rejectionReason: reason,
      reviewedBy: 'Rentilly Admin',
      reviewedAt: new Date().toISOString(),
    };

    return _kypCache[idx];
  }

  // ============================================================
  // INSPECTIONS
  // ============================================================
  static getInspections(): Inspection[] {
    return _inspectionsCache;
  }

  static async addInspection(insp: Inspection): Promise<Inspection> {
    const existingIdx = _inspectionsCache.findIndex(item => item.id === insp.id);
    if (existingIdx >= 0) {
      _inspectionsCache[existingIdx] = { ..._inspectionsCache[existingIdx], ...insp };
    } else {
      _inspectionsCache.unshift(insp);
    }

    if (supabase) {
      try {
        await supabase.from('inspections').upsert({
          id: insp.id,
          property_id: insp.propertyId,
          renter_id: insp.renterId || 'b0000000-0000-0000-0000-000000000001',
          date: insp.date,
          time_slot: insp.timeSlot,
          type: insp.type,
          status: insp.status,
          property_title: insp.propertyTitle,
          property_address: insp.propertyAddress,
          renter_name: insp.renterName,
          renter_phone: insp.renterPhone,
          renter_email: insp.renterEmail,
          created_at: insp.createdAt || new Date().toISOString(),
        }, { onConflict: 'id' });
      } catch (_) {}
    }

    return insp;
  }

  static async updateInspectionStatus(id: string, status: Inspection['status'], ownerNotes?: string): Promise<Inspection | null> {
    const idx = _inspectionsCache.findIndex(i => i.id === id);
    if (idx === -1) return null;

    _inspectionsCache[idx] = { ..._inspectionsCache[idx], status, ownerNotes: ownerNotes || _inspectionsCache[idx].ownerNotes };

    if (supabase) {
      try {
        await supabase
          .from('inspections')
          .update({ status, owner_notes: ownerNotes, updated_at: new Date().toISOString() })
          .eq('id', id);
      } catch (_) {}
    }

    return _inspectionsCache[idx];
  }

  // ============================================================
  // LEGAL AGREEMENTS
  // ============================================================
  static getLegalAgreements(): LegalAgreement[] {
    return _agreementsCache;
  }

  static async addLegalAgreement(la: LegalAgreement): Promise<LegalAgreement> {
    const existingIdx = _agreementsCache.findIndex(item => item.id === la.id);
    if (existingIdx >= 0) {
      _agreementsCache[existingIdx] = { ..._agreementsCache[existingIdx], ...la };
    } else {
      _agreementsCache.unshift(la);
    }

    if (supabase) {
      try {
        await supabase.from('legal_agreements').upsert({
          id: la.id,
          property_id: la.propertyId,
          renter_id: la.renterId || 'b0000000-0000-0000-0000-000000000001',
          owner_id: la.ownerId || 'b0000000-0000-0000-0000-000000000001',
          agreement_type: la.agreementType,
          status: la.status,
          agreement_text: la.agreementText,
          rent_amount: la.rentAmount,
          tenancy_period_months: la.tenancyPeriodMonths,
          start_date: la.startDate,
          end_date: la.endDate,
          created_at: la.createdAt || new Date().toISOString(),
        }, { onConflict: 'id' });
      } catch (_) {}
    }

    return la;
  }

  static async signLegalAgreement(id: string, role: 'renter' | 'owner'): Promise<LegalAgreement | null> {
    const idx = _agreementsCache.findIndex(la => la.id === id);
    if (idx === -1) return null;

    const la = _agreementsCache[idx];
    const now = new Date().toISOString();

    if (role === 'renter') la.signedByRenterAt = now;
    if (role === 'owner') la.signedByOwnerAt = now;

    if (la.signedByRenterAt && la.signedByOwnerAt) {
      la.status = 'active';
    } else {
      la.status = 'pending_signatures';
    }

    if (supabase) {
      try {
        await supabase
          .from('legal_agreements')
          .update({
            signed_by_renter_at: la.signedByRenterAt,
            signed_by_owner_at: la.signedByOwnerAt,
            status: la.status,
            updated_at: now
          })
          .eq('id', id);
      } catch (_) {}
    }

    return la;
  }

  static buildEscrowTransactions(walletTxs: any[]): Transaction[] {
    if (!Array.isArray(walletTxs)) return [];
    return walletTxs.map((tx: any) => ({
      id: tx.id || `escrow_${Date.now()}`,
      propertyId: tx.propertyId || 'wallet_movement',
      propertyTitle: tx.description || tx.title || 'Escrow Settlement',
      payerId: tx.userId || tx.senderId || 'user',
      payerName: tx.userName || tx.senderName || 'Rentilly User',
      ownerId: tx.ownerId || tx.recipientId || 'system',
      ownerName: tx.recipientName || 'Rentilly Settlement Vault',
      transactionType: (tx.type || 'rent').toLowerCase(),
      paymentReference: tx.reference || tx.flwRef || tx.txRef || tx.id,
      paymentGateway: tx.provider || tx.gateway || 'flutterwave',
      baseAmount: Number(tx.amount || 0),
      rentillyLegalFee: Number(tx.fee || 0),
      cautionFee: 0,
      serviceCharge: 0,
      totalAmount: Number(tx.amount || 0),
      escrowStatus: (tx.status === 'completed' || tx.status === 'success') ? 'held_in_escrow' : 'pending',
      ownerPayoutReference: tx.payoutReference,
      payoutReleasedAt: tx.payoutReleasedAt,
      createdAt: tx.createdAt || tx.timestamp || new Date().toISOString()
    })) as Transaction[];
  }
}
