import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';
import type { Property } from '../types';
import { AdminDataStore } from '../services/adminDataStore';

export async function getProperties(req: Request, res: Response) {
  try {
    const { purpose, status, state, search } = req.query;

    // Try Supabase first
    let supabaseProps: Property[] = [];
    if (supabase) {
      try {
        let query = supabase.from('properties').select('*');
        if (purpose) query = query.eq('purpose', purpose);
        if (status) query = query.eq('status', status);
        if (state) query = query.ilike('state', `%${state}%`);
        if (search) query = query.or(`title.ilike.%${search}%,neighborhood.ilike.%${search}%,address.ilike.%${search}%`);

        const { data, error } = await query.order('created_at', { ascending: false });
        if (!error && data && data.length > 0) {
          supabaseProps = data.map((row: any) => ({
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
            createdAt: row.created_at,
            updatedAt: row.updated_at
          }));
        }
      } catch (_) {}
    }

    // Fallback: AdminDataStore (file-backed with seed data)
    let storeProps = AdminDataStore.getProperties();

    // Apply filters to store results
    if (purpose) storeProps = storeProps.filter(p => p.purpose === purpose);
    if (status) storeProps = storeProps.filter(p => p.status === status);
    if (state) storeProps = storeProps.filter(p => p.state.toLowerCase().includes(String(state).toLowerCase()));
    if (search) {
      const s = String(search).toLowerCase();
      storeProps = storeProps.filter(p =>
        p.title.toLowerCase().includes(s) ||
        p.neighborhood.toLowerCase().includes(s) ||
        p.address.toLowerCase().includes(s)
      );
    }

    // Merge: Supabase takes priority; append store records that aren't in Supabase
    if (supabaseProps.length > 0) {
      const supabaseIds = new Set(supabaseProps.map(p => p.id));
      const extraStoreProps = storeProps.filter(p => !supabaseIds.has(p.id));
      return res.json([...supabaseProps, ...extraStoreProps]);
    }

    return res.json(storeProps);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function getPropertyById(req: Request, res: Response) {
  try {
    const { id } = req.params;

    // Try Supabase
    if (supabase) {
      try {
        const { data, error } = await supabase.from('properties').select('*').eq('id', id).single();
        if (!error && data) return res.json(data);
      } catch (_) {}
    }

    // Fallback: AdminDataStore
    const props = AdminDataStore.getProperties();
    const found = props.find(p => p.id === id);
    if (found) return res.json(found);

    res.status(404).json({ error: 'Property not found' });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function createProperty(req: Request, res: Response) {
  try {
    const body = req.body;
    const basePrice = Number(body.basePrice || 0);
    const isRent = body.purpose === 'rent';
    const rentillyFeeRate = isRent ? 0.10 : 0.05;
    const rentillyFee = Math.round(basePrice * rentillyFeeRate);
    const cautionFee = Number(body.cautionFee || 0);
    const serviceCharge = Number(body.serviceCharge || 0);
    const totalInitialPayment = basePrice + cautionFee + serviceCharge + rentillyFee;

    const now = new Date().toISOString();
    const newId = `prop_${Date.now()}`;

    const newProperty: Property = {
      id: newId,
      ownerId: body.ownerId || body.userId || 'unknown_owner',
      ownerName: body.ownerName || 'Property Owner',
      ownerPhone: body.ownerPhone || '',
      title: body.title || 'Untitled Property',
      description: body.description || '',
      purpose: body.purpose || 'rent',
      propertyType: body.propertyType || 'flat_apartment',
      basePrice,
      cautionFee,
      serviceCharge,
      rentillyFee,
      totalInitialPayment,
      paymentFrequency: body.paymentFrequency || 'annually',
      address: body.address || '',
      state: body.state || '',
      lga: body.lga || '',
      neighborhood: body.neighborhood || '',
      bedrooms: Number(body.bedrooms || 0),
      bathrooms: Number(body.bathrooms || 0),
      toilets: Number(body.toilets || 0),
      furnishing: body.furnishing || 'unfurnished',
      amenities: body.amenities || [],
      images: body.images || [],
      videoWalkthroughUrl: body.videoWalkthroughUrl,
      status: 'pending_kyp',
      createdAt: now,
      updatedAt: now,
    };

    // Try Supabase first
    if (supabase) {
      try {
        const { data, error } = await supabase
          .from('properties')
          .insert({
            owner_id: newProperty.ownerId,
            owner_name: newProperty.ownerName,
            owner_phone: newProperty.ownerPhone,
            title: newProperty.title,
            description: newProperty.description,
            purpose: newProperty.purpose,
            property_type: newProperty.propertyType,
            base_price: newProperty.basePrice,
            caution_fee: newProperty.cautionFee,
            service_charge: newProperty.serviceCharge,
            rentilly_legal_fee: newProperty.rentillyFee,
            total_initial_payment: newProperty.totalInitialPayment,
            payment_frequency: newProperty.paymentFrequency,
            address: newProperty.address,
            state: newProperty.state,
            lga: newProperty.lga,
            neighborhood: newProperty.neighborhood,
            bedrooms: newProperty.bedrooms,
            bathrooms: newProperty.bathrooms,
            toilets: newProperty.toilets,
            furnishing: newProperty.furnishing,
            amenities: newProperty.amenities,
            images: newProperty.images,
            status: newProperty.status,
          })
          .select()
          .single();

        if (!error && data) {
          AdminDataStore.addProperty({ ...newProperty, id: data.id });
          return res.status(201).json(data);
        }
      } catch (_) {}
    }

    // Fallback: Save to AdminDataStore only
    AdminDataStore.addProperty(newProperty);
    res.status(201).json(newProperty);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function updatePropertyStatus(req: Request, res: Response) {
  try {
    const { id } = req.params;
    const { status, verifiedBy } = req.body;
    const now = new Date().toISOString();

    // Try Supabase
    if (supabase) {
      try {
        const { data, error } = await supabase
          .from('properties')
          .update({ status, verified_at: now, verified_by: verifiedBy, updated_at: now })
          .eq('id', id)
          .select()
          .single();
        if (!error && data) {
          AdminDataStore.updatePropertyStatus(id, status);
          return res.json(data);
        }
      } catch (_) {}
    }

    // Fallback: AdminDataStore only
    const updated = AdminDataStore.updatePropertyStatus(id, status);
    if (!updated) return res.status(404).json({ error: 'Property not found' });
    res.json(updated);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}
