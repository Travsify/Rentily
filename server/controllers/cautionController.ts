import type { Request, Response } from 'express';
import { TransactionStore } from '../services/transactionStore';
import { UserStore } from '../services/userStore';
import { NotificationDispatcher } from '../services/notificationDispatcher';
import fs from 'fs';
import path from 'path';

export interface CautionDeposit {
  id: string;
  transactionId: string;
  propertyId: string;
  propertyTitle: string;
  tenantId: string;
  tenantName: string;
  tenantEmail: string;
  landlordId: string;
  landlordName: string;
  landlordEmail: string;
  cautionAmount: number;
  leaseStartDate: string;
  leaseEndDate: string;
  status: 'held_in_escrow' | 'claim_filed' | 'refunded_to_tenant' | 'partially_deducted' | 'forfeited_to_landlord';
  damageClaim?: {
    id: string;
    claimedAmount: number;
    description: string;
    evidencePhotos?: string[];
    filedAt: string;
    resolution?: string;
  };
  refundedAmount?: number;
  deductedAmount?: number;
  resolvedAt?: string;
}

function getCautionFilePath(): string {
  const candidates = [
    path.join(process.cwd(), 'server', 'data'),
    path.join('/opt/render/project/src', 'server', 'data'),
    path.join('/tmp', 'rentilly-data'),
  ];
  for (const dir of candidates) {
    try {
      if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
      return path.join(dir, 'caution_deposits.json');
    } catch { continue; }
  }
  return path.join('/tmp', 'caution_deposits.json');
}

let _cautionCache: CautionDeposit[] | null = null;

function loadCautionDeposits(): CautionDeposit[] {
  if (_cautionCache !== null) return _cautionCache;
  try {
    const file = getCautionFilePath();
    if (fs.existsSync(file)) {
      const data = JSON.parse(fs.readFileSync(file, 'utf-8'));
      if (Array.isArray(data)) {
        _cautionCache = data;
        return _cautionCache;
      }
    }
  } catch (_) {}
  _cautionCache = [];
  return _cautionCache;
}

function saveCautionDeposits(deposits: CautionDeposit[]): void {
  _cautionCache = deposits;
  try {
    const file = getCautionFilePath();
    fs.writeFileSync(file, JSON.stringify(deposits, null, 2), 'utf-8');
  } catch (err) {
    console.error('Failed to save caution deposits:', err);
  }
}

export function getCautionDeposits(_req: Request, res: Response) {
  const deposits = loadCautionDeposits();
  res.json({ success: true, count: deposits.length, deposits });
}

export async function submitDamageClaim(req: Request, res: Response) {
  try {
    const { depositId, claimedAmount, description, evidencePhotos } = req.body;
    const deposits = loadCautionDeposits();
    const item = deposits.find(d => d.id === depositId);
    if (!item) {
      return res.status(404).json({ error: 'Caution deposit record not found' });
    }

    const numClaim = Number(claimedAmount);
    if (numClaim <= 0 || numClaim > item.cautionAmount) {
      return res.status(400).json({ error: `Claimed amount must be between ₦1 and maximum caution fee ₦${item.cautionAmount.toLocaleString()}` });
    }

    item.status = 'claim_filed';
    item.damageClaim = {
      id: `CLM-${Date.now()}`,
      claimedAmount: numClaim,
      description,
      evidencePhotos: evidencePhotos || [],
      filedAt: new Date().toISOString()
    };
    saveCautionDeposits(deposits);

    // Notify Tenant of filed claim
    NotificationDispatcher.dispatch({
      userId: item.tenantId,
      email: item.tenantEmail,
      userName: item.tenantName,
      title: 'Move-Out Damage Claim Filed',
      category: 'escrow',
      message: `Landlord ${item.landlordName} has submitted a ₦${numClaim.toLocaleString()} damage deduction claim for "${item.propertyTitle}". Reason: ${description}. Rentilly arbitration is reviewing.`,
      metadata: { depositId, claimId: item.damageClaim.id }
    });

    res.json({ success: true, message: 'Damage claim submitted for legal arbitration', deposit: item });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function resolveCautionDeposit(req: Request, res: Response) {
  try {
    const { depositId, action, landlordShare, tenantShare, arbitrationNotes } = req.body;
    const deposits = loadCautionDeposits();
    const item = deposits.find(d => d.id === depositId);
    if (!item) {
      return res.status(404).json({ error: 'Caution deposit record not found' });
    }

    const resolvedAt = new Date().toISOString();
    let deducted = 0;
    let refunded = 0;

    if (action === 'full_refund') {
      // 100% refund to tenant
      refunded = item.cautionAmount;
      deducted = 0;
      item.status = 'refunded_to_tenant';
    } else if (action === 'full_forfeiture') {
      // 100% payout to landlord
      deducted = item.cautionAmount;
      refunded = 0;
      item.status = 'forfeited_to_landlord';
    } else {
      // Arbitrated split
      deducted = Number(landlordShare || 0);
      refunded = Number(tenantShare || 0);
      item.status = 'partially_deducted';
    }

    item.deductedAmount = deducted;
    item.refundedAmount = refunded;
    item.resolvedAt = resolvedAt;
    if (item.damageClaim) {
      item.damageClaim.resolution = arbitrationNotes || `Arbitrated: ₦${refunded} to tenant, ₦${deducted} to landlord.`;
    }
    saveCautionDeposits(deposits);

    // 1. Credit Tenant Wallet if refunded > 0
    if (refunded > 0) {
      const tenant = await UserStore.findByEmail(item.tenantEmail);
      if (tenant) {
        const newBal = (tenant.walletBalance || 0) + refunded;
        await UserStore.upsertUser({ ...tenant, walletBalance: newBal, updatedAt: resolvedAt });
        TransactionStore.recordTransaction({
          id: `TX_REF_${Date.now()}`,
          userId: tenant.id,
          email: tenant.email,
          title: `Caution Deposit Refund — ${item.propertyTitle}`,
          type: 'Caution Fee Settlement',
          category: 'deposit',
          amount: refunded,
          isCredit: true,
          reference: `REF-${item.id}`,
          status: 'SUCCESSFUL',
          date: resolvedAt
        });
      }
      NotificationDispatcher.dispatch({
        userId: item.tenantId,
        email: item.tenantEmail,
        userName: item.tenantName,
        title: `Caution Deposit Refunded: ₦${refunded.toLocaleString()}`,
        category: 'escrow',
        message: `Your caution fee of ₦${refunded.toLocaleString()} for "${item.propertyTitle}" has been released and credited to your wallet vault.`,
        metadata: { depositId, refunded }
      });
    }

    // 2. Credit Landlord Wallet if deducted > 0
    if (deducted > 0) {
      const landlord = await UserStore.findByEmail(item.landlordEmail);
      if (landlord) {
        const newBal = (landlord.walletBalance || 0) + deducted;
        await UserStore.upsertUser({ ...landlord, walletBalance: newBal, updatedAt: resolvedAt });
        TransactionStore.recordTransaction({
          id: `TX_DMG_${Date.now()}`,
          userId: landlord.id,
          email: landlord.email,
          title: `Damage Claim Payout — ${item.propertyTitle}`,
          type: 'Damage Deduction Settlement',
          category: 'deposit',
          amount: deducted,
          isCredit: true,
          reference: `DMG-${item.id}`,
          status: 'SUCCESSFUL',
          date: resolvedAt
        });
      }
      NotificationDispatcher.dispatch({
        userId: item.landlordId,
        email: item.landlordEmail,
        userName: item.landlordName,
        title: `Damage Deduction Payout: ₦${deducted.toLocaleString()}`,
        category: 'escrow',
        message: `Your damage claim of ₦${deducted.toLocaleString()} for "${item.propertyTitle}" has been approved and credited to your settlement account.`,
        metadata: { depositId, deducted }
      });
    }

    res.json({
      success: true,
      message: 'Caution deposit resolved and wallet payouts executed successfully.',
      deposit: item
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}
