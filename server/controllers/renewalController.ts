import type { Request, Response } from 'express';
import { AdminDataStore } from '../services/adminDataStore';
import { NotificationDispatcher } from '../services/notificationDispatcher';

export interface LeaseRenewalItem {
  id: string;
  propertyId: string;
  propertyTitle: string;
  tenantId: string;
  tenantName: string;
  tenantEmail: string;
  landlordId: string;
  landlordName: string;
  landlordEmail: string;
  currentAnnualRent: number;
  leaseStartDate: string;
  leaseEndDate: string;
  daysRemaining: number;
  renewalStatus: 'active' | 'expiring_soon' | 'renewal_sent' | 'renewed' | 'vacating';
  proposedNewRent?: number;
}

export function getUpcomingRenewals(_req: Request, res: Response) {
  try {
    const agreements = AdminDataStore.getLegalAgreements();
    const now = new Date();
    const renewalItems: LeaseRenewalItem[] = [];

    for (const ag of agreements) {
      if (ag.agreementType === 'rent') {
        const start = new Date(ag.createdAt);
        const end = new Date(start);
        end.setFullYear(end.getFullYear() + 1); // 1-year lease in Nigeria

        const diffTime = end.getTime() - now.getTime();
        const daysRemaining = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

        let status: LeaseRenewalItem['renewalStatus'] = 'active';
        if (daysRemaining <= 0) {
          status = 'expiring_soon';
        } else if (daysRemaining <= 60) {
          status = 'expiring_soon';
        }

        renewalItems.push({
          id: `RNW-${ag.id}`,
          propertyId: ag.propertyId,
          propertyTitle: ag.propertyTitle,
          tenantId: ag.tenantId,
          tenantName: ag.tenantName,
          tenantEmail: `${ag.tenantId}@myrentilly.com`,
          landlordId: ag.ownerId,
          landlordName: ag.ownerName,
          landlordEmail: `${ag.ownerId}@myrentilly.com`,
          currentAnnualRent: ag.annualRent,
          leaseStartDate: start.toISOString(),
          leaseEndDate: end.toISOString(),
          daysRemaining,
          renewalStatus: status,
          proposedNewRent: ag.annualRent
        });
      }
    }

    res.json({
      success: true,
      count: renewalItems.length,
      renewals: renewalItems
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export function dispatchRenewalReminder(req: Request, res: Response) {
  try {
    const { renewalId, tenantEmail, tenantName, propertyTitle, annualRent, daysRemaining } = req.body;

    NotificationDispatcher.dispatch({
      userId: tenantEmail || renewalId,
      email: tenantEmail || 'tenant@myrentilly.com',
      userName: tenantName || 'Tenant',
      title: 'Annual Tenancy Renewal Notice 📜',
      category: 'legal',
      message: `Your annual lease for "${propertyTitle}" expires in ${daysRemaining} days. You can secure and renew your tenancy directly through Rentilly Escrow with zero agent fees.`,
      metadata: { renewalId, annualRent }
    });

    res.json({
      success: true,
      message: `Renewal reminder dispatched to ${tenantName} for "${propertyTitle}".`
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}
