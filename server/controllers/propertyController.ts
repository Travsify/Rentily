import crypto from 'crypto';
import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';
import type { Property, KYPRecord } from '../types';
import { AdminDataStore } from '../services/adminDataStore';

export async function getProperties(req: Request, res: Response) {
  try {
    const { 
      purpose, 
      status, 
      state, 
      lga,
      search, 
      ownerId,
      propertyType,
      bedrooms,
      minPrice,
      maxPrice,
      furnishing,
      listedByRole,
      sortBy
    } = req.query;

    // Helper to check property type match
    const matchesPropertyType = (propType: string, filterType: string): boolean => {
      const p = (propType || '').toLowerCase();
      const f = filterType.toLowerCase();
      if (f === 'all' || f === 'all types') return true;
      if (f.includes('flat') || f.includes('apartment')) {
        return p.includes('flat') || p.includes('apartment') || p.includes('self_contain') || p.includes('studio') || p.includes('penthouse') || p.includes('maisonette');
      }
      if (f.includes('duplex') || f.includes('terrace')) {
        return p.includes('duplex') || p.includes('terrace') || p.includes('terraced') || p.includes('semi_detached');
      }
      if (f.includes('mansion') || f.includes('detached')) {
        return p.includes('mansion') || p.includes('fully_detached') || p.includes('detached');
      }
      if (f.includes('commercial') || f.includes('office')) {
        return p.includes('commercial') || p.includes('office') || p.includes('warehouse') || p.includes('shop');
      }
      if (f.includes('land') || f.includes('plot')) {
        return p.includes('land') || p.includes('plot');
      }
      return p === f;
    };

    // Try Supabase first
    let supabaseProps: Property[] = [];
    if (supabase) {
      try {
        let query = supabase.from('properties').select('*');
        if (ownerId) query = query.eq('owner_id', String(ownerId).trim());
        if (purpose && purpose !== 'all') query = query.eq('purpose', purpose);
        if (status && status !== 'all') query = query.eq('status', status);
        if (state && state !== 'All Nigeria') {
          const cleanState = String(state).split(' ')[0].replace(/[^a-zA-Z]/g, '');
          query = query.ilike('state', `%${cleanState}%`);
        }
        if (lga && lga !== 'All LGAs') query = query.ilike('lga', `%${lga}%`);
        if (bedrooms) {
          const b = Number(bedrooms);
          if (b >= 4) {
            query = query.gte('bedrooms', 4);
          } else if (b > 0) {
            query = query.eq('bedrooms', b);
          }
        }
        if (minPrice) query = query.gte('base_price', Number(minPrice));
        if (maxPrice) query = query.lte('base_price', Number(maxPrice));
        if (furnishing && furnishing !== 'all') query = query.ilike('furnishing', `%${furnishing}%`);
        if (listedByRole && listedByRole !== 'all') query = query.eq('listed_by_role', listedByRole);
        if (search) {
          query = query.or(`title.ilike.%${search}%,neighborhood.ilike.%${search}%,address.ilike.%${search}%,lga.ilike.%${search}%,state.ilike.%${search}%`);
        }

        // Sorting
        if (sortBy === 'price_asc') {
          query = query.order('base_price', { ascending: true });
        } else if (sortBy === 'price_desc') {
          query = query.order('base_price', { ascending: false });
        } else if (sortBy === 'bedrooms') {
          query = query.order('bedrooms', { ascending: false });
        } else {
          query = query.order('created_at', { ascending: false });
        }

        const { data, error } = await query;
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
            listedByRole: row.listed_by_role || 'direct_landlord',
            partnerId: row.partner_id,
            partnerName: row.partner_name,
            partnerBusinessName: row.partner_business_name,
            partnerCacNumber: row.partner_cac_number,
            createdAt: row.created_at,
            updatedAt: row.updated_at
          }));

          // If propertyType filter was requested, filter memory results since DB uses various slugs
          if (propertyType && propertyType !== 'all') {
            supabaseProps = supabaseProps.filter(p => matchesPropertyType(p.propertyType, String(propertyType)));
          }
        }
      } catch (_) {}
    }

    // Local / In-memory store (AdminDataStore)
    let storeProps = AdminDataStore.getProperties();

    // Apply filters
    if (ownerId) storeProps = storeProps.filter(p => p.ownerId === ownerId);
    if (purpose && purpose !== 'all') storeProps = storeProps.filter(p => p.purpose === purpose);
    if (status && status !== 'all') storeProps = storeProps.filter(p => p.status === status);
    if (state && state !== 'All Nigeria') {
      const cleanState = String(state).split(' ')[0].toLowerCase().replace(/[^a-z]/g, '');
      storeProps = storeProps.filter(p => p.state.toLowerCase().includes(cleanState));
    }
    if (lga && lga !== 'All LGAs') {
      const cleanLga = String(lga).toLowerCase();
      storeProps = storeProps.filter(p => (p.lga || '').toLowerCase().includes(cleanLga) || (p.neighborhood || '').toLowerCase().includes(cleanLga));
    }
    if (propertyType && propertyType !== 'all') {
      storeProps = storeProps.filter(p => matchesPropertyType(p.propertyType, String(propertyType)));
    }
    if (bedrooms) {
      const b = Number(bedrooms);
      if (b >= 4) {
        storeProps = storeProps.filter(p => p.bedrooms >= 4);
      } else if (b > 0) {
        storeProps = storeProps.filter(p => p.bedrooms === b);
      }
    }
    if (minPrice) storeProps = storeProps.filter(p => p.basePrice >= Number(minPrice));
    if (maxPrice) storeProps = storeProps.filter(p => p.basePrice <= Number(maxPrice));
    if (furnishing && furnishing !== 'all') {
      storeProps = storeProps.filter(p => (p.furnishing || '').toLowerCase().includes(String(furnishing).toLowerCase()));
    }
    if (listedByRole && listedByRole !== 'all') {
      storeProps = storeProps.filter(p => p.listedByRole === listedByRole);
    }
    if (search) {
      const s = String(search).toLowerCase();
      storeProps = storeProps.filter(p =>
        p.title.toLowerCase().includes(s) ||
        p.neighborhood.toLowerCase().includes(s) ||
        p.address.toLowerCase().includes(s) ||
        (p.lga || '').toLowerCase().includes(s) ||
        p.state.toLowerCase().includes(s)
      );
    }

    // Sort storeProps
    if (sortBy === 'price_asc') {
      storeProps.sort((a, b) => a.basePrice - b.basePrice);
    } else if (sortBy === 'price_desc') {
      storeProps.sort((a, b) => b.basePrice - a.basePrice);
    } else if (sortBy === 'bedrooms') {
      storeProps.sort((a, b) => b.bedrooms - a.bedrooms);
    }

    // Merge: prefer Supabase if it returned data, append non-duplicate store items
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
    
    // Rentilly Escrow Policy: Caution deposit is strictly capped at max 10% of annual rent
    const requestedCaution = Number(body.cautionFee || 0);
    const maxAllowedCaution = isRent ? Math.round(basePrice * 0.10) : 0;
    const cautionFee = isRent ? Math.min(requestedCaution, maxAllowedCaution) : 0;
    
    const serviceCharge = Number(body.serviceCharge || 0);
    const totalInitialPayment = basePrice + cautionFee + serviceCharge + rentillyFee;

    const isUuid = (str?: string) => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(str || '');
    const now = new Date().toISOString();
    const newId = isUuid(body.id) ? body.id : crypto.randomUUID();
    const validOwnerId = isUuid(body.ownerId) ? body.ownerId : (isUuid(body.userId) ? body.userId : 'a197e323-d8b1-4d54-800a-65c4f16299c0');
    const allowedStatuses = ['verified', 'draft', 'pending_kyp', 'rejected', 'rented', 'sold', 'unlisted'];
    const validStatus = allowedStatuses.includes(body.status) ? body.status : 'pending_kyp';

    const newProperty: Property = {
      id: newId,
      ownerId: validOwnerId,
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
      state: body.state || 'Lagos',
      lga: body.lga || '',
      neighborhood: body.neighborhood || body.address || '',
      bedrooms: Number(body.bedrooms || 0),
      bathrooms: Number(body.bathrooms || 0),
      toilets: Number(body.toilets || 0),
      furnishing: body.furnishing || 'unfurnished',
      amenities: body.amenities || [],
      images: body.images || [],
      videoWalkthroughUrl: body.videoWalkthroughUrl,
      status: body.status || 'pending_kyp',
      listedByRole: body.listedByRole || 'direct_landlord',
      partnerId: body.partnerId,
      partnerName: body.partnerName,
      partnerBusinessName: body.partnerBusinessName,
      partnerCacNumber: body.partnerCacNumber,
      partnerPresencePhotoUrl: body.partnerPresencePhotoUrl,
      powerOfAttorneyUrl: body.powerOfAttorneyUrl,
      createdAt: now,
      updatedAt: now,
    };

    // Auto-create a corresponding KYP record so Admin KYP verification can audit the title deed
    const kypRecord: KYPRecord = {
      id: `kyp_${newProperty.id}`,
      propertyId: newProperty.id,
      propertyTitle: newProperty.title,
      propertyPurpose: newProperty.purpose,
      propertyPrice: newProperty.basePrice,
      propertyNeighborhood: `${newProperty.neighborhood}, ${newProperty.state}`,
      ownerId: newProperty.ownerId,
      ownerName: newProperty.ownerName,
      ownerEmail: body.ownerEmail || `${newProperty.ownerId}@myrentilly.com`,
      ownerPhone: newProperty.ownerPhone,
      titleDocumentType: body.titleDocumentType || 'deed_of_assignment',
      titleDocumentNumber: body.titleDocumentNumber || `TITLE-${Date.now()}`,
      titleDocumentUrls: body.titleDocumentUrls || (body.titleDocumentUrl ? [body.titleDocumentUrl] : []),
      ownerIdType: body.ownerIdType || 'NIN',
      ownerIdNumber: body.ownerIdNumber || '',
      ownerIdUrl: body.ownerIdUrl || '',
      discoProvider: body.discoProvider || 'EKEDC',
      discoMeterNumber: body.discoMeterNumber || '',
      utilityBillUrl: body.utilityBillUrl || '',
      landRegistrySearchStatus: 'pending',
      status: 'pending',
      listedByRole: body.listedByRole || 'direct_landlord',
      partnerId: body.partnerId,
      partnerName: body.partnerName,
      partnerBusinessName: body.partnerBusinessName,
      partnerCacNumber: body.partnerCacNumber,
      partnerPresencePhotoUrl: body.partnerPresencePhotoUrl,
      powerOfAttorneyUrl: body.powerOfAttorneyUrl,
      submittedAt: now,
    };

    // Always save to AdminDataStore
    AdminDataStore.addProperty(newProperty);
    AdminDataStore.addKYP(kypRecord);

    // Also persist to Supabase if available
    if (supabase) {
      try {
        await supabase
          .from('properties')
          .insert({
            id: newProperty.id,
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
          });

        await supabase
          .from('kyp_verifications')
          .insert({
            id: kypRecord.id,
            property_id: kypRecord.propertyId,
            owner_id: kypRecord.ownerId,
            title_document_type: kypRecord.titleDocumentType,
            title_document_number: kypRecord.titleDocumentNumber,
            status: 'pending',
            submitted_at: now
          });
      } catch (_) {}
    }

    res.status(201).json(newProperty);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function updatePropertyStatus(req: Request, res: Response) {
  try {
    const id = req.params.id as string;
    const { status, verifiedBy } = req.body;
    const now = new Date().toISOString();

    // Update in AdminDataStore
    const updated = await AdminDataStore.updatePropertyStatus(id, status);

    // Also try Supabase
    if (supabase) {
      try {
        await supabase
          .from('properties')
          .update({ status, verified_at: now, verified_by: verifiedBy, updated_at: now })
          .eq('id', id);
      } catch (_) {}
    }

    if (!updated) return res.status(404).json({ error: 'Property not found' });
    res.json(updated);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}
