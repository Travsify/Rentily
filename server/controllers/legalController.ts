import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';
import type { LegalAgreement } from '../types';

export async function getLegalAgreements(_req: Request, res: Response) {
  try {
    if (!supabase) return res.json([]);

    const { data, error } = await supabase
      .from('legal_agreements')
      .select('*, properties(*)')
      .order('created_at', { ascending: false });

    if (error) return res.json([]);

    const agreements: LegalAgreement[] = (data || []).map((row: any) => ({
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
      tenantSigned: row.tenant_signed,
      legalOfficerStamp: row.legal_officer_stamp,
      pdfDocumentUrl: row.pdf_document_url,
      status: row.status,
      createdAt: row.created_at
    }));

    res.json(agreements);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function generateAgreement(req: Request, res: Response) {
  try {
    const { propertyId, tenantId, tenantName, commencementDate, durationMonths = 12 } = req.body;
    if (!supabase) return res.status(500).json({ error: 'Database unavailable' });

    // Fetch property details
    const { data: prop, error: propError } = await supabase
      .from('properties')
      .select('*')
      .eq('id', propertyId)
      .single();

    if (propError || !prop) {
      return res.status(404).json({ error: 'Property not found' });
    }

    const startDate = new Date(commencementDate || Date.now());
    const expDate = new Date(startDate);
    expDate.setMonth(expDate.getMonth() + durationMonths);

    const isRent = prop.purpose === 'rent';
    const agreementType = isRent ? 'tenancy_agreement' : 'contract_of_sale';
    const governingLaw = prop.state === 'Lagos' 
      ? 'Lagos State Tenancy Law 2011' 
      : 'Recovery of Premises Act & Laws of the Federal Capital Territory';

    const { data: newAgreement, error: createError } = await supabase
      .from('legal_agreements')
      .insert({
        property_id: prop.id,
        landlord_id: prop.owner_id,
        tenant_id: tenantId || '00000000-0000-0000-0000-000000000002',
        agreement_type: agreementType,
        agreement_title: isRent 
          ? 'Standard Residential Tenancy Agreement (Lagos Tenancy Law 2011 / FCT Laws)'
          : 'Standard Contract of Sale of Real Property & Deed Transfer Covenants',
        governing_law: governingLaw,
        tenancy_commencement_date: startDate.toISOString().split('T')[0],
        tenancy_expiration_date: expDate.toISOString().split('T')[0],
        annual_rent: prop.base_price,
        caution_deposit: prop.caution_fee,
        landlord_signed: false,
        tenant_signed: false,
        legal_officer_stamp: true,
        status: 'drafting'
      })
      .select()
      .single();

    if (createError) throw new Error(createError.message);
    res.status(201).json(newAgreement);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}
