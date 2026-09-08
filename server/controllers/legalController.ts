import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';
import type { LegalAgreement, LegalDispatch } from '../types';
import { AdminDataStore } from '../services/adminDataStore';

export async function getLegalAgreements(req: Request, res: Response) {
  try {
    const { email, tenantId, landlordId } = req.query;
    const cleanEmail = email ? String(email).toLowerCase().trim() : '';

    // Primary: AdminDataStore
    let storeLegal = AdminDataStore.getLegalAgreements();

    // Secondary: Supabase (if available)
    if (supabase) {
      try {
        const { data, error } = await supabase
          .from('legal_agreements')
          .select('*, properties(*)')
          .order('created_at', { ascending: false });

        if (!error && data && data.length > 0) {
          const supabaseLegal: LegalAgreement[] = data.map((row: any) => ({
            id: row.id,
            propertyId: row.property_id,
            propertyTitle: row.properties?.title || 'Property Agreement',
            // ✅ Real address & state from joined properties table
            propertyAddress: row.properties?.address || row.properties?.location || '',
            propertyState: row.properties?.state || '',
            transactionId: row.transaction_id,
            landlordId: row.landlord_id,
            landlordName: row.landlord_name || 'Landlord',
            tenantId: row.tenant_id,
            tenantName: row.tenant_name || 'Tenant',
            agreementType: row.agreement_type,
            agreementTitle: row.agreement_title,
            // ✅ Governing law from DB, or derived from property state — never Lagos hardcode
            governingLaw: row.governing_law || (
              row.properties?.state === 'FCT'
                ? 'Laws of the Federal Capital Territory'
                : row.properties?.state
                  ? `Laws of ${row.properties.state} State`
                  : 'Laws of the Federal Republic of Nigeria'
            ),
            tenancyCommencementDate: row.tenancy_commencement_date,
            tenancyExpirationDate: row.tenancy_expiration_date,
            annualRent: Number(row.annual_rent || 0),
            cautionDeposit: Number(row.caution_deposit || 0),
            landlordSigned: row.landlord_signed,
            landlordSignedAt: row.landlord_signed_at,
            tenantSigned: row.tenant_signed,
            tenantSignedAt: row.tenant_signed_at,
            legalOfficerStamp: row.legal_officer_stamp,
            pdfContractUrl: row.pdf_document_url,
            status: row.status,
            createdAt: row.created_at
          }));

          const storeIds = new Set(storeLegal.map(l => l.id));
          const missing = supabaseLegal.filter(l => !storeIds.has(l.id));
          storeLegal = [...storeLegal, ...missing];
        }
      } catch (_) {}
    }

    // Filter if requested by Flutter app
    if (landlordId) {
      storeLegal = storeLegal.filter(a => a.landlordId === landlordId);
    } else if (tenantId) {
      storeLegal = storeLegal.filter(a => a.tenantId === tenantId);
    } else if (cleanEmail) {
      storeLegal = storeLegal.filter(a =>
        (a.tenantName || '').toLowerCase().includes(cleanEmail) ||
        (a.landlordName || '').toLowerCase().includes(cleanEmail) ||
        (a.tenantId || '').toLowerCase() === cleanEmail ||
        (a.landlordId || '').toLowerCase() === cleanEmail
      );
    }

    return res.json(storeLegal);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function generateAgreement(req: Request, res: Response) {
  try {
    const { propertyId, tenantId, tenantName, commencementDate, durationMonths = 12 } = req.body;
    const now = new Date().toISOString();

    // Fetch property from AdminDataStore (with Supabase fallback)
    let prop: any = null;

    if (supabase) {
      try {
        const { data, error } = await supabase.from('properties').select('*').eq('id', propertyId).single();
        if (!error && data) prop = data;
      } catch (_) {}
    }

    if (!prop) {
      const storeProps = AdminDataStore.getProperties();
      prop = storeProps.find(p => p.id === propertyId);
    }

    const commencementDateObj = new Date(commencementDate || now);
    const expirationDate = new Date(commencementDateObj);
    expirationDate.setMonth(expirationDate.getMonth() + Number(durationMonths));

    const agreementId = `legal_${Date.now()}`;
    const agreementTitle = `${durationMonths}-Month ${prop?.purpose === 'sale' ? 'Contract of Sale' : 'Tenancy Agreement'} — ${prop?.title || 'Rentilly Living'}`;

    const newAgreement: LegalAgreement = {
      id: agreementId,
      propertyId: propertyId || 'general_property',
      propertyTitle: prop?.title || 'Rentilly Property',
      // ✅ Include real address and state — mobile uses these to avoid any Lagos hardcode
      propertyAddress: prop?.address || prop?.location || '',
      propertyState: prop?.state || '',
      transactionId: `txn_${Date.now()}`,
      landlordId: prop?.owner_id || prop?.ownerId || 'usr_landlord',
      landlordName: prop?.owner_name || prop?.ownerName || 'Property Landlord',
      tenantId: tenantId || `usr_tenant_${Date.now()}`,
      tenantName: tenantName || 'Direct Tenant',
      agreementType: prop?.purpose === 'sale' ? 'contract_of_sale' : 'tenancy_agreement',
      agreementTitle,
      // ✅ Governing law derived from actual property state — no Lagos hardcode
      governingLaw: prop?.state === 'FCT'
        ? 'Laws of the Federal Capital Territory'
        : prop?.state
          ? `Laws of ${prop.state} State`
          : 'Laws of the Federal Republic of Nigeria',
      tenancyCommencementDate: commencementDateObj.toISOString().split('T')[0],
      tenancyExpirationDate: expirationDate.toISOString().split('T')[0],
      annualRent: Number(prop?.base_price || prop?.basePrice || 0),
      cautionDeposit: Number(prop?.caution_fee || prop?.cautionFee || 0),
      landlordSigned: true,
      landlordSignedAt: now,
      tenantSigned: false,
      legalOfficerStamp: true,
      status: 'pending_signatures',
      createdAt: now,
    };

    // Save to AdminDataStore
    AdminDataStore.addLegalAgreement(newAgreement);

    // Also persist to Supabase if available
    if (supabase) {
      try {
        await supabase
          .from('legal_agreements')
          .insert({
            id: newAgreement.id,
            property_id: newAgreement.propertyId,
            tenant_id: newAgreement.tenantId,
            tenant_name: newAgreement.tenantName,
            landlord_id: newAgreement.landlordId,
            landlord_name: newAgreement.landlordName,
            agreement_type: newAgreement.agreementType,
            agreement_title: newAgreement.agreementTitle,
            governing_law: newAgreement.governingLaw,
            tenancy_commencement_date: newAgreement.tenancyCommencementDate,
            tenancy_expiration_date: newAgreement.tenancyExpirationDate,
            annual_rent: newAgreement.annualRent,
            caution_deposit: newAgreement.cautionDeposit,
            landlord_signed: true,
            status: 'pending_signatures',
          });
      } catch (_) {}
    }

    res.status(201).json({ agreement: newAgreement, agreementTitle });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

// --- Legal Conveyance & Courier Dispatch Desk ---

let _inMemoryDispatches: LegalDispatch[] = [
  {
    id: 'dsp_default_01',
    agreementId: 'legal_default_01',
    propertyTitle: '3-Bedroom Luxury Terrace — Lekki Phase 1, Lagos',
    propertyAddress: '14 Admiralty Way, Lekki Phase 1, Lagos State',
    recipientName: 'Patrick Achua',
    recipientEmail: 'patrickachua3@gmail.com',
    recipientPhone: '+2348031234567',
    deliveryAddress: 'Plot 12, Block 4B, Admiralty Way, Lekki Phase 1',
    deliveryCity: 'Lekki',
    deliveryState: 'Lagos',
    deliveryCountry: 'Nigeria',
    isDiaspora: false,
    docusignStatus: 'not_applicable',
    courierPartner: 'GIG Logistics',
    waybillNumber: 'GIG-983210452',
    trackingUrl: 'https://giglogistics.com/tracking/?track_id=GIG-983210452',
    status: 'in_transit',
    estimatedDeliveryDate: '2-3 Business Days',
    dispatchedAt: new Date(Date.now() - 86400000).toISOString(),
    recipientConfirmed: false,
    notes: 'Hard copy Tenancy Agreement with Corporate Seal & Caution Deposit Escrow Rider.',
    createdAt: new Date(Date.now() - 86400000).toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: 'dsp_default_02',
    agreementId: 'legal_default_02',
    propertyTitle: '4-Bedroom Detached Duplex with BQ — Guzape, Abuja',
    propertyAddress: 'Guzape Hills District, Abuja FCT',
    recipientName: 'Chidi Okafor',
    recipientEmail: 'chidi.okafor@ukinvest.co.uk',
    recipientPhone: '+447911123456',
    deliveryAddress: '22 Canary Wharf Way, London E14 5AB',
    deliveryCity: 'London',
    deliveryState: 'Greater London',
    deliveryCountry: 'United Kingdom',
    isDiaspora: true,
    docusignStatus: 'signed',
    docusignEnvelopeUrl: 'https://app.docusign.com/documents/details/94a82-live',
    courierPartner: 'DHL Express',
    waybillNumber: 'DHL-4920194829',
    trackingUrl: 'https://www.dhl.com/en/express/tracking.html?AWB=DHL-4920194829&brand=DHL',
    status: 'dispatched',
    estimatedDeliveryDate: '3-5 Business Days',
    dispatchedAt: new Date().toISOString(),
    recipientConfirmed: false,
    notes: 'Contract of Sale executed via DocuSign; original wet-ink counterpart dispatched to London via DHL Express.',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  }
];

export function generateCourierTrackingUrl(courier: string, waybill: string): string {
  if (!waybill) return '';
  const clean = waybill.trim();
  switch (courier) {
    case 'DHL Express':
      return `https://www.dhl.com/en/express/tracking.html?AWB=${encodeURIComponent(clean)}&brand=DHL`;
    case 'FedEx':
      return `https://www.fedex.com/fedextrack/?trknbr=${encodeURIComponent(clean)}`;
    case 'GIG Logistics':
      return `https://giglogistics.com/tracking/?track_id=${encodeURIComponent(clean)}`;
    case 'UPS':
      return `https://www.ups.com/track?tracknum=${encodeURIComponent(clean)}`;
    case 'Red Star Express':
      return `https://redstarplc.com/track/?waybill=${encodeURIComponent(clean)}`;
    default:
      return `https://www.google.com/search?q=${encodeURIComponent(`${courier} tracking ${clean}`)}`;
  }
}

export async function getDispatches(req: Request, res: Response) {
  try {
    const { email, agreementId } = req.query;
    const cleanEmail = email ? String(email).toLowerCase().trim() : '';
    let list: LegalDispatch[] = [..._inMemoryDispatches];

    // Try sync with Supabase
    if (supabase) {
      try {
        const { data, error } = await supabase
          .from('system_configs')
          .select('data')
          .eq('id', 'global_courier_dispatches')
          .single();
        if (!error && data?.data && Array.isArray(data.data)) {
          const cloudList: LegalDispatch[] = data.data;
          const map = new Map<string, LegalDispatch>();
          list.forEach(item => map.set(item.id, item));
          cloudList.forEach(item => map.set(item.id, item));
          list = Array.from(map.values());
          _inMemoryDispatches = list;
        }
      } catch (_) {}
    }

    if (agreementId) {
      list = list.filter(d => d.agreementId === agreementId);
    } else if (cleanEmail) {
      list = list.filter(d => 
        (d.recipientEmail || '').toLowerCase() === cleanEmail ||
        (d.recipientName || '').toLowerCase().includes(cleanEmail)
      );
    }

    // Sort newest first
    list.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

    return res.json(list);
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
}

export async function createOrUpdateDispatch(req: Request, res: Response) {
  try {
    const {
      id,
      agreementId,
      propertyTitle,
      propertyAddress,
      recipientName,
      recipientEmail,
      recipientPhone,
      deliveryAddress,
      deliveryCity,
      deliveryState,
      deliveryCountry = 'Nigeria',
      isDiaspora,
      docusignStatus = 'not_applicable',
      docusignEnvelopeUrl,
      courierPartner = 'GIG Logistics',
      waybillNumber,
      status = 'drafting',
      estimatedDeliveryDate = '3-5 Business Days',
      notes,
    } = req.body;

    const dispatchId = id || `dsp_${Date.now()}`;
    const trackingUrl = generateCourierTrackingUrl(courierPartner, waybillNumber || '');
    const now = new Date().toISOString();

    const existingIndex = _inMemoryDispatches.findIndex(d => d.id === dispatchId);
    const existing = existingIndex >= 0 ? _inMemoryDispatches[existingIndex] : null;

    const dispatchRecord: LegalDispatch = {
      id: dispatchId,
      agreementId: agreementId || existing?.agreementId || 'legal_general',
      propertyTitle: propertyTitle || existing?.propertyTitle || 'Rentilly Property',
      propertyAddress: propertyAddress || existing?.propertyAddress || '',
      recipientName: recipientName || existing?.recipientName || 'Buyer/Tenant',
      recipientEmail: (recipientEmail || existing?.recipientEmail || '').toLowerCase().trim(),
      recipientPhone: recipientPhone || existing?.recipientPhone || '',
      deliveryAddress: deliveryAddress || existing?.deliveryAddress || '',
      deliveryCity: deliveryCity || existing?.deliveryCity || '',
      deliveryState: deliveryState || existing?.deliveryState || 'Lagos',
      deliveryCountry: deliveryCountry || existing?.deliveryCountry || 'Nigeria',
      isDiaspora: isDiaspora !== undefined ? Boolean(isDiaspora) : (deliveryCountry.toLowerCase() !== 'nigeria'),
      docusignStatus: docusignStatus || existing?.docusignStatus || 'not_applicable',
      docusignEnvelopeUrl: docusignEnvelopeUrl || existing?.docusignEnvelopeUrl,
      courierPartner: courierPartner || existing?.courierPartner || 'GIG Logistics',
      waybillNumber: waybillNumber || existing?.waybillNumber || '',
      trackingUrl: trackingUrl || existing?.trackingUrl || '',
      status: status || existing?.status || 'drafting',
      estimatedDeliveryDate: estimatedDeliveryDate || existing?.estimatedDeliveryDate || '3-5 Business Days',
      dispatchedAt: (status === 'dispatched' || status === 'in_transit') && !existing?.dispatchedAt ? now : existing?.dispatchedAt,
      deliveredAt: status === 'delivered' && !existing?.deliveredAt ? now : existing?.deliveredAt,
      recipientConfirmed: existing?.recipientConfirmed || false,
      recipientConfirmedAt: existing?.recipientConfirmedAt,
      notes: notes !== undefined ? notes : existing?.notes,
      createdAt: existing?.createdAt || now,
      updatedAt: now,
    };

    if (existingIndex >= 0) {
      _inMemoryDispatches[existingIndex] = dispatchRecord;
    } else {
      _inMemoryDispatches.unshift(dispatchRecord);
    }

    // Persist to Supabase system_configs
    if (supabase) {
      try {
        await supabase
          .from('system_configs')
          .upsert({
            id: 'global_courier_dispatches',
            data: _inMemoryDispatches,
            updated_at: now,
          }, { onConflict: 'id' });
      } catch (_) {}
    }

    return res.status(201).json({ success: true, dispatch: dispatchRecord });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
}

export async function confirmDispatchReceipt(req: Request, res: Response) {
  try {
    const { id } = req.params;
    const now = new Date().toISOString();
    const item = _inMemoryDispatches.find(d => d.id === id);

    if (!item) {
      return res.status(404).json({ error: 'Dispatch record not found' });
    }

    item.recipientConfirmed = true;
    item.recipientConfirmedAt = now;
    item.status = 'delivered';
    item.deliveredAt = item.deliveredAt || now;
    item.updatedAt = now;

    if (supabase) {
      try {
        await supabase
          .from('system_configs')
          .upsert({
            id: 'global_courier_dispatches',
            data: _inMemoryDispatches,
            updated_at: now,
          }, { onConflict: 'id' });
      } catch (_) {}
    }

    return res.json({ success: true, message: 'Receipt of physical legal documents confirmed', dispatch: item });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
}
