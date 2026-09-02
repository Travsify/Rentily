import type { Request, Response } from 'express';
import fs from 'fs';
import path from 'path';

export interface StatutoryNotice {
  id: string;
  noticeType: 'notice_to_quit_yearly' | 'notice_to_quit_monthly' | 'seven_days_owners_intention' | 'rent_arrears_demand';
  jurisdiction: 'lagos' | 'abuja_fct' | 'general_nigeria';
  landlordName: string;
  tenantName: string;
  propertyAddress: string;
  annualRent: number;
  serviceDate: string;
  expiryDate: string;
  legalGrounds?: string;
  legalCitation: string;
  documentBody: string;
  servedBy: string;
  createdAt: string;
}

const _noticesHistory: StatutoryNotice[] = [];

export function generateStatutoryNotice(req: Request, res: Response) {
  try {
    const {
      noticeType,
      jurisdiction = 'lagos',
      landlordName,
      tenantName,
      propertyAddress,
      annualRent,
      serviceDate,
      legalGrounds
    } = req.body;

    if (!landlordName || !tenantName || !propertyAddress) {
      return res.status(400).json({ error: 'Landlord name, tenant name, and property address are required.' });
    }

    const sDate = serviceDate ? new Date(serviceDate) : new Date();
    let expiryDate = new Date(sDate);
    let legalCitation = '';
    let noticeTitle = '';

    if (noticeType === 'notice_to_quit_yearly') {
      expiryDate.setMonth(expiryDate.getMonth() + 6);
      legalCitation = jurisdiction === 'lagos'
        ? 'Section 13(1) of the Lagos State Tenancy Law 2011'
        : 'Section 8 of the Recovery of Premises Act, Laws of the Federation of Nigeria (Abuja FCT)';
      noticeTitle = 'STATUTORY NOTICE TO QUIT (YEARLY TENANCY)';
    } else if (noticeType === 'notice_to_quit_monthly') {
      expiryDate.setMonth(expiryDate.getMonth() + 1);
      legalCitation = jurisdiction === 'lagos'
        ? 'Section 13(1)(b) of the Lagos State Tenancy Law 2011'
        : 'Section 8 of the Recovery of Premises Act (FCT)';
      noticeTitle = 'STATUTORY NOTICE TO QUIT (MONTHLY TENANCY)';
    } else if (noticeType === 'seven_days_owners_intention') {
      expiryDate.setDate(expiryDate.getDate() + 7);
      legalCitation = jurisdiction === 'lagos'
        ? 'Section 16 of the Lagos State Tenancy Law 2011 (Form E)'
        : 'Section 7 of the Recovery of Premises Act (Form E)';
      noticeTitle = "NOTICE OF OWNER'S INTENTION TO APPLY TO RECOVER POSSESSION (7-DAY NOTICE)";
    } else {
      expiryDate.setDate(expiryDate.getDate() + 14);
      legalCitation = 'Common Law Demand & Tenancy Contract Enforcement';
      noticeTitle = 'FORMAL DEMAND FOR ACCRUED RENT ARREARS';
    }

    const documentBody = `
================================================================================
${noticeTitle}
PURSUANT TO: ${legalCitation}
================================================================================

TO: ${tenantName} (Tenant in Lawful Possession)
ADDRESS: ${propertyAddress}

TAKE NOTICE that you are hereby required to quit and deliver up possession of the residential/commercial premises situate, lying and being at:

    "${propertyAddress}"

which you hold of ${landlordName} as tenant thereof at the annual reserved rent of ₦${Number(annualRent || 0).toLocaleString()}, on or before the ${expiryDate.toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric' })}.

${noticeType === 'seven_days_owners_intention' ? `
FURTHER TAKE NOTICE that if you fail to quit and deliver up peaceable possession of the said premises on or before the expiration of seven (7) clear days from the service of this notice, the Landlord shall immediately proceed to the High Court / Magistrate Court having jurisdiction to apply for an Order for possession of the premises and to recover mesne profits and damages for unlawful detention.
` : `
GROUNDS: ${legalGrounds || 'Determination of tenancy by statutory effluxion of notice pursuant to state tenancy enactments.'}
`}

DATED THIS ${sDate.toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric' })}.

_______________________________________
${landlordName} (Landlord / Property Owner)
c/o Legal Operations Department, Rentilly Protocol
Lagos & Abuja, Nigeria
================================================================================
    `.trim();

    const record: StatutoryNotice = {
      id: `STAT-${Date.now()}`,
      noticeType,
      jurisdiction,
      landlordName,
      tenantName,
      propertyAddress,
      annualRent: Number(annualRent || 0),
      serviceDate: sDate.toISOString(),
      expiryDate: expiryDate.toISOString(),
      legalGrounds,
      legalCitation,
      documentBody,
      servedBy: 'Rentilly Legal Desk',
      createdAt: new Date().toISOString()
    };

    _noticesHistory.unshift(record);

    res.json({
      success: true,
      message: 'Statutory legal notice generated successfully.',
      notice: record
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export function listStatutoryNotices(_req: Request, res: Response) {
  res.json({
    success: true,
    count: _noticesHistory.length,
    notices: _noticesHistory
  });
}
