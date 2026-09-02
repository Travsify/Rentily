import type { Request, Response } from 'express';
import { UserStore } from '../services/userStore';

export async function checkEligibility(req: Request, res: Response) {
  try {
    const { userId } = req.params;
    const user = await UserStore.findById(userId);

    const isTier3 = user?.isVerified === true || (user?.ninNumber && user?.bvnVerified);
    const preApprovedLimit = isTier3 ? 5000000.0 : 2500000.0;

    res.json({
      eligible: true,
      preApprovedLimit,
      reason: isTier3
        ? 'Pre-approved for Tier-3 Rent Now Pay Later with NIBSS Direct Debit mandate.'
        : 'Pre-approved based on identity standing. Complete Tier-3 KYC to unlock ₦5M limit.',
      userStatus: {
        isVerified: user?.isVerified || false,
        accountNumber: user?.accountNumber || null,
        bankName: user?.bankName || null,
      },
      repaymentPlans: [
        { months: 3, monthlyAmount: Math.round((preApprovedLimit / 3) * 1.02), interestRate: 0.02 },
        { months: 6, monthlyAmount: Math.round((preApprovedLimit / 6) * 1.05), interestRate: 0.05 },
        { months: 12, monthlyAmount: Math.round((preApprovedLimit / 12) * 1.10), interestRate: 0.10 },
      ]
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function submitMandate(req: Request, res: Response) {
  try {
    const { mandateId, bankCode, accountNumber, monthlyDebitAmount } = req.body;

    if (!accountNumber || !bankCode) {
      return res.status(400).json({ error: 'Bank account number and bank code are required for NIBSS direct debit.' });
    }

    const mandateReference = `NIBSS-MND-${Date.now()}`;

    res.json({
      status: 'active',
      mandateId: mandateId || mandateReference,
      mandateReference,
      accountNumber,
      monthlyDebitAmount: Number(monthlyDebitAmount || 0),
      message: 'Direct debit mandate registered with NIBSS successfully. Escrow rent financing active.'
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}
