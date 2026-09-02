import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';
import type { LegalAgreement } from '../types';
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
            transactionId: row.transaction_id,
            landlordId: row.landlord_id,
            landlordName: row.landlord_name || 'Landlord',
            tenantId: row.tenant_id,
            tenantName: row.tenant_name || 'Tenant',
            agreementType: row.agreement_type,
            agreementTitle: row.agreement_title,
            governingLaw: row.governing_law,
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
    if (cleanEmail) {
      storeLegal = storeLegal.filter(a =>
        a.tenantName.toLowerCase().includes(cleanEmail) ||
        a.landlordName.toLowerCase().includes(cleanEmail) ||
        a.tenantId.toLowerCase() === cleanEmail ||
        a.landlordId.toLowerCase() === cleanEmail
      );
    }
    if (tenantId) {
      storeLegal = storeLegal.filter(a => a.tenantId === tenantId);
    }
    if (landlordId) {
      storeLegal = storeLegal.filter(a => a.landlordId === landlordId);
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
      transactionId: `txn_${Date.now()}`,
      landlordId: prop?.owner_id || prop?.ownerId || 'usr_landlord',
      landlordName: prop?.owner_name || prop?.ownerName || 'Property Landlord',
      tenantId: tenantId || `usr_tenant_${Date.now()}`,
      tenantName: tenantName || 'Direct Tenant',
      agreementType: prop?.purpose === 'sale' ? 'contract_of_sale' : 'tenancy_agreement',
      agreementTitle,
      governingLaw: prop?.state === 'FCT' ? 'Laws of the Federal Capital Territory' : `Laws of ${prop?.state || 'Lagos'} State`,
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
