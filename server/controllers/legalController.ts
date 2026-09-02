import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';
import type { LegalAgreement } from '../types';
import { AdminDataStore } from '../services/adminDataStore';

export async function getLegalAgreements(_req: Request, res: Response) {
  try {
    // Try Supabase first
    let supabaseLegal: LegalAgreement[] = [];
    if (supabase) {
      try {
        const { data, error } = await supabase
          .from('legal_agreements')
          .select('*, properties(*)')
          .order('created_at', { ascending: false });

        if (!error && data && data.length > 0) {
          supabaseLegal = data.map((row: any) => ({
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
        }
      } catch (_) {}
    }

    // Fallback: AdminDataStore
    const storeLegal = AdminDataStore.getLegalAgreements();

    if (supabaseLegal.length > 0) {
      const supabaseIds = new Set(supabaseLegal.map(l => l.id));
      const extraStore = storeLegal.filter(l => !supabaseIds.has(l.id));
      return res.json([...supabaseLegal, ...extraStore]);
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

    if (!prop) {
      return res.status(404).json({ error: 'Property not found' });
    }

    const commencementDateObj = new Date(commencementDate || now);
    const expirationDate = new Date(commencementDateObj);
    expirationDate.setMonth(expirationDate.getMonth() + Number(durationMonths));

    const agreementId = `legal_${Date.now()}`;
    const agreementTitle = `${durationMonths}-Month ${prop.purpose === 'rent' ? 'Tenancy' : 'Sale'} Agreement — ${prop.title || prop.neighborhood}`;

    const newAgreement: LegalAgreement = {
      id: agreementId,
      propertyId,
      propertyTitle: prop.title || 'Property',
      transactionId: `txn_${Date.now()}`,
      landlordId: prop.owner_id || prop.ownerId || 'unknown_landlord',
      landlordName: prop.owner_name || prop.ownerName || 'Property Owner',
      tenantId: tenantId || `tenant_${Date.now()}`,
      tenantName: tenantName || 'Tenant',
      agreementType: prop.purpose === 'rent' ? 'tenancy_agreement' : 'contract_of_sale',
      agreementTitle,
      governingLaw: prop.state === 'FCT' ? 'Laws of the Federal Capital Territory' : `Laws of ${prop.state} State`,
      tenancyCommencementDate: commencementDateObj.toISOString().split('T')[0],
      tenancyExpirationDate: expirationDate.toISOString().split('T')[0],
      annualRent: Number(prop.base_price || prop.basePrice || 0),
      cautionDeposit: Number(prop.caution_fee || prop.cautionFee || 0),
      landlordSigned: false,
      tenantSigned: false,
      legalOfficerStamp: false,
      status: 'drafting',
      createdAt: now,
    };

    // Try Supabase
    if (supabase) {
      try {
        const { data, error } = await supabase
          .from('legal_agreements')
          .insert({
            property_id: propertyId,
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
            status: 'drafting',
          })
          .select()
          .single();

        if (!error && data) {
          AdminDataStore.addLegalAgreement({ ...newAgreement, id: data.id });
          return res.status(201).json({ agreement: { ...newAgreement, id: data.id }, agreementTitle });
        }
      } catch (_) {}
    }

    // Fallback: AdminDataStore only
    AdminDataStore.addLegalAgreement(newAgreement);
    res.status(201).json({ agreement: newAgreement, agreementTitle });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}
