import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';
import type { KYPRecord } from '../types';

export async function getKYPRecords(req: Request, res: Response) {
  try {
    const { status } = req.query;
    if (!supabase) return res.json([]);

    let query = supabase.from('kyp_verifications').select('*, properties(*)');

    if (status) {
      query = query.eq('status', status);
    }

    const { data, error } = await query.order('submitted_at', { ascending: false });

    if (error) {
      return res.json([]);
    }

    const records: KYPRecord[] = (data || []).map((row: any) => ({
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

    res.json(records);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function reviewKYP(req: Request, res: Response) {
  try {
    const { id } = req.params;
    const { status, landRegistrySearchStatus, landRegistrySearchNotes, rejectionReason, reviewerName } = req.body;

    if (!supabase) return res.status(500).json({ error: 'Database unavailable' });

    const reviewedBy = reviewerName || 'Barrister Chijioke Okonkwo (Legal Lead)';
    const reviewedAt = new Date().toISOString();

    // 1. Update KYP verification in Supabase
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

    if (kypError) throw new Error(kypError.message);

    // 2. Update associated Property status
    if (kyp && kyp.property_id) {
      if (status === 'approved') {
        await supabase
          .from('properties')
          .update({
            status: 'verified',
            verified_at: reviewedAt,
            verified_by: reviewedBy,
            updated_at: reviewedAt
          })
          .eq('id', kyp.property_id);
      } else if (status === 'rejected') {
        await supabase
          .from('properties')
          .update({
            status: 'rejected',
            updated_at: reviewedAt
          })
          .eq('id', kyp.property_id);
      }
    }

    res.json(kyp);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}
