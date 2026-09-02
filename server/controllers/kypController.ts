import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';
import type { KYPRecord } from '../types';
import { AdminDataStore } from '../services/adminDataStore';

export async function getKYPRecords(req: Request, res: Response) {
  try {
    const { status } = req.query;

    // Try Supabase first
    let supabaseKyp: KYPRecord[] = [];
    if (supabase) {
      try {
        let query = supabase.from('kyp_verifications').select('*, properties(*)');
        if (status) query = query.eq('status', status);
        const { data, error } = await query.order('submitted_at', { ascending: false });
        if (!error && data && data.length > 0) {
          supabaseKyp = data.map((row: any) => ({
            id: row.id,
            propertyId: row.property_id,
            propertyTitle: row.properties?.title || 'Property',
            propertyPurpose: row.properties?.purpose || 'rent',
            propertyPrice: Number(row.properties?.base_price || 0),
            propertyNeighborhood: row.properties ? `${row.properties.neighborhood}, ${row.properties.state}` : 'Lagos',
            ownerId: row.owner_id,
            ownerName: row.owner_name || 'Property Owner',
            ownerEmail: row.owner_email || 'owner@myrentilly.com',
            ownerPhone: row.owner_phone || '+2348000000000',
            titleDocumentType: row.title_document_type,
            titleDocumentNumber: row.title_document_number,
            titleDocumentUrls: row.title_document_urls || [],
            ownerIdType: row.owner_id_type,
            ownerIdNumber: row.owner_id_number,
            ownerIdUrl: row.owner_id_url,
            discoProvider: row.disco_provider,
            discoMeterNumber: row.disco_meter_number,
            utilityBillUrl: row.utility_bill_url,
            videoKycUrl: row.video_kyc_url,
            landRegistrySearchStatus: row.land_registry_search_status,
            landRegistrySearchNotes: row.land_registry_search_notes,
            rejectionReason: row.rejection_reason,
            status: row.status,
            reviewedBy: row.reviewed_by,
            reviewedAt: row.reviewed_at,
            submittedAt: row.submitted_at
          }));
        }
      } catch (_) {}
    }

    // Fallback: AdminDataStore
    const storeKyp = AdminDataStore.getKYP(status ? String(status) : undefined);

    if (supabaseKyp.length > 0) {
      const supabaseIds = new Set(supabaseKyp.map(k => k.id));
      const extraStore = storeKyp.filter(k => !supabaseIds.has(k.id));
      return res.json([...supabaseKyp, ...extraStore]);
    }

    return res.json(storeKyp);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function reviewKYP(req: Request, res: Response) {
  try {
    const { id } = req.params;
    const { status, landRegistrySearchStatus, landRegistrySearchNotes, rejectionReason, reviewerName } = req.body;

    const reviewedBy = reviewerName || 'Barrister Chijioke Okonkwo (Legal Lead)';
    const reviewedAt = new Date().toISOString();

    // Try Supabase
    if (supabase) {
      try {
        const { data: kyp, error: kypError } = await supabase
          .from('kyp_verifications')
          .update({
            status,
            land_registry_search_status: landRegistrySearchStatus || (status === 'approved' ? 'verified_alausa' : 'pending'),
            land_registry_search_notes: landRegistrySearchNotes,
            rejection_reason: rejectionReason,
            reviewed_by: reviewedBy,
            reviewed_at: reviewedAt
          })
          .eq('id', id)
          .select()
          .single();

        if (!kypError && kyp) {
          // Also update property status in Supabase
          if (kyp.property_id) {
            if (status === 'approved') {
              await supabase.from('properties').update({
                status: 'verified', verified_at: reviewedAt, verified_by: reviewedBy, updated_at: reviewedAt
              }).eq('id', kyp.property_id);
              AdminDataStore.updatePropertyStatus(kyp.property_id, 'verified');
            } else if (status === 'rejected') {
              await supabase.from('properties').update({ status: 'rejected', updated_at: reviewedAt }).eq('id', kyp.property_id);
              AdminDataStore.updatePropertyStatus(kyp.property_id, 'rejected');
            }
          }
          // Update AdminDataStore too
          AdminDataStore.reviewKYP(id, status, landRegistrySearchNotes, rejectionReason);
          return res.json(kyp);
        }
      } catch (_) {}
    }

    // Fallback: AdminDataStore only
    const updated = AdminDataStore.reviewKYP(id, status, landRegistrySearchNotes, rejectionReason);
    if (!updated) return res.status(404).json({ error: 'KYP record not found' });

    // Update linked property status in store
    if (updated.propertyId) {
      if (status === 'approved') AdminDataStore.updatePropertyStatus(updated.propertyId, 'verified');
      if (status === 'rejected') AdminDataStore.updatePropertyStatus(updated.propertyId, 'rejected');
    }

    res.json(updated);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}
