import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';
import type { Property } from '../types';

export async function getProperties(req: Request, res: Response) {
  try {
    const { purpose, status, state, search } = req.query;

    if (!supabase) {
      return res.json([]);
    }

    let query = supabase.from('properties').select('*');

    if (purpose) {
      query = query.eq('purpose', purpose);
    }
    if (status) {
      query = query.eq('status', status);
    }
    if (state) {
      query = query.ilike('state', `%${state}%`);
    }
    if (search) {
      query = query.or(`title.ilike.%${search}%,neighborhood.ilike.%${search}%,address.ilike.%${search}%`);
    }

    const { data, error } = await query.order('created_at', { ascending: false });

    if (error) {
      // Table may be newly initialized
      return res.json([]);
    }

    // Map database snake_case columns to camelCase domain model
    const properties: Property[] = (data || []).map((row: any) => ({
      id: row.id,
      ownerId: row.owner_id,
      ownerName: row.owner_name || 'Property Owner',
      ownerPhone: row.owner_phone || '',
      title: row.title,
      description: row.description || '',
      purpose: row.purpose,
      propertyType: row.property_type,
      basePrice: Number(row.base_price || 0),
      cautionFee: Number(row.caution_fee || 0),
      serviceCharge: Number(row.service_charge || 0),
      rentillyFee: Number(row.rentilly_legal_fee || 0),
      totalInitialPayment: Number(row.total_initial_payment || 0),
      paymentFrequency: row.payment_frequency,
      address: row.address,
      state: row.state,
      lga: row.lga,
      neighborhood: row.neighborhood,
      bedrooms: row.bedrooms,
      bathrooms: row.bathrooms,
      toilets: row.toilets,
      furnishing: row.furnishing,
      amenities: row.amenities || [],
      images: row.images || [],
      videoWalkthroughUrl: row.video_walkthrough_url,
      status: row.status,
      verifiedAt: row.verified_at,
      verifiedBy: row.verified_by,
      delistedAt: row.delisted_at,
      createdAt: row.created_at,
      updatedAt: row.updated_at
    }));

    res.json(properties);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function getPropertyById(req: Request, res: Response) {
  try {
    const { id } = req.params;
    if (!supabase) return res.status(404).json({ error: 'Property not found' });

    const { data, error } = await supabase
      .from('properties')
      .select('*')
      .eq('id', id)
      .single();

    if (error || !data) {
      return res.status(404).json({ error: 'Property not found' });
    }

    res.json(data);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function createProperty(req: Request, res: Response) {
  try {
    const body = req.body;
    const basePrice = Number(body.basePrice || 0);
    const cautionFee = Number(body.cautionFee || 0);
    const serviceCharge = Number(body.serviceCharge || 0);
    const feePercentage = body.purpose === 'rent' ? 0.10 : 0.05;
    const rentillyFee = Math.round(basePrice * feePercentage);
    const totalInitialPayment = basePrice + cautionFee + serviceCharge + rentillyFee;

    if (!supabase) {
      return res.status(500).json({ error: 'Database service unavailable' });
    }

    // 1. Insert property into Supabase
    const { data: propData, error: propError } = await supabase
      .from('properties')
      .insert({
        owner_id: body.ownerId || '00000000-0000-0000-0000-000000000001',
        title: body.title,
        description: body.description,
        purpose: body.purpose || 'rent',
        property_type: body.propertyType || 'flat_apartment',
        base_price: basePrice,
        caution_fee: cautionFee,
        service_charge: serviceCharge,
        rentilly_legal_fee: rentillyFee,
        total_initial_payment: totalInitialPayment,
        payment_frequency: body.purpose === 'rent' ? 'annually' : 'outright',
        address: body.address,
        state: body.state || 'Lagos',
        lga: body.lga || 'Eti-Osa',
        neighborhood: body.neighborhood || 'Lekki Phase 1',
        bedrooms: Number(body.bedrooms || 1),
        bathrooms: Number(body.bathrooms || 1),
        toilets: Number(body.toilets || 1),
        furnishing: body.furnishing || 'unfurnished',
        amenities: body.amenities || ['24/7 Power', 'Security'],
        images: body.images || [],
        video_walkthrough_url: body.videoWalkthroughUrl,
        status: 'pending_kyp'
      })
      .select()
      .single();

    if (propError) {
      throw new Error(propError.message);
    }

    // 2. Automatically create KYP Verification record in Supabase
    await supabase.from('kyp_verifications').insert({
      property_id: propData.id,
      owner_id: propData.owner_id,
      title_document_type: body.titleDocumentType || 'c_of_o',
      title_document_number: body.titleDocumentNumber || 'LAND-REG-SUBMITTED',
      title_document_urls: body.titleDocumentUrls || [],
      owner_id_type: body.ownerIdType || 'NIN',
      owner_id_number: body.ownerIdNumber || '00000000000',
      owner_id_url: body.ownerIdUrl,
      disco_provider: body.discoProvider || 'EKEDC',
      disco_meter_number: body.discoMeterNumber,
      utility_bill_url: body.utilityBillUrl,
      status: 'pending',
      land_registry_search_status: 'pending'
    });

    res.status(201).json(propData);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function updatePropertyStatus(req: Request, res: Response) {
  try {
    const { id } = req.params;
    const { status } = req.body;

    if (!supabase) return res.status(500).json({ error: 'Database service unavailable' });

    const updatePayload: any = {
      status,
      updated_at: new Date().toISOString()
    };

    if (status === 'verified') {
      updatePayload.verified_at = new Date().toISOString();
      updatePayload.verified_by = 'Rentilly Legal Admin';
    }

    const { data, error } = await supabase
      .from('properties')
      .update(updatePayload)
      .eq('id', id)
      .select()
      .single();

    if (error) throw new Error(error.message);
    res.json(data);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}
