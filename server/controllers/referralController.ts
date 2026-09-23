import { Request, Response } from 'express';
import { ReferralService } from '../services/referralService';

/**
 * 1. Get referral program configuration (Public / Mobile App)
 */
export async function getReferralConfig(_req: Request, res: Response) {
  try {
    const config = await ReferralService.getConfig();
    return res.status(200).json(config);
  } catch (err: any) {
    return res.status(500).json({ error: 'Failed to fetch referral config', details: err.message });
  }
}

/**
 * 2. Update referral program configuration (Admin with Toggles & Amounts)
 */
export async function updateReferralConfig(req: Request, res: Response) {
  try {
    const { enabled, instantEarning, signupBonusAmount, referrerBonusAmount, requireKycForPayout } = req.body;
    
    const updated = await ReferralService.updateConfig({
      enabled: enabled !== undefined ? Boolean(enabled) : undefined,
      instantEarning: instantEarning !== undefined ? Boolean(instantEarning) : undefined,
      signupBonusAmount: signupBonusAmount !== undefined ? Number(signupBonusAmount) : undefined,
      referrerBonusAmount: referrerBonusAmount !== undefined ? Number(referrerBonusAmount) : undefined,
      requireKycForPayout: requireKycForPayout !== undefined ? Boolean(requireKycForPayout) : undefined,
    });

    return res.status(200).json({
      success: true,
      message: 'Referral program configuration updated successfully',
      config: updated
    });
  } catch (err: any) {
    return res.status(500).json({ error: 'Failed to update referral config', details: err.message });
  }
}

/**
 * 3. Validate a referral code during signup
 */
export async function validateReferralCode(req: Request, res: Response) {
  try {
    const rawCode = req.body?.code || req.query?.code || req.params?.code;
    const code = rawCode ? String(rawCode).trim().toUpperCase() : '';

    if (!code) {
      return res.status(400).json({ valid: false, message: 'Referral code is required' });
    }

    const referrer = await ReferralService.findUserByReferralCode(code);
    if (!referrer) {
      return res.status(404).json({
        valid: false,
        message: 'Invalid or expired referral code. Check the code and try again.'
      });
    }

    const config = await ReferralService.getConfig();
    return res.status(200).json({
      valid: true,
      referrerName: referrer.fullName || referrer.businessName || 'Verified Rentilly User',
      referrerEmail: referrer.email,
      signupBonus: config.signupBonusAmount,
      referrerReward: config.referrerBonusAmount,
      message: `Valid code from ${referrer.fullName || 'a friend'}. You get ₦${config.signupBonusAmount.toLocaleString()} upon verification!`
    });
  } catch (err: any) {
    return res.status(500).json({ valid: false, error: err.message });
  }
}

/**
 * 4. Get User's Referral Stats (Mobile App Wallet / Referral Hub)
 */
export async function getUserReferralStats(req: Request, res: Response) {
  try {
    const identifier = (req.params.identifier || req.query.email || req.query.userId || '').toString().trim();
    if (!identifier) {
      return res.status(400).json({ error: 'User email or ID is required' });
    }

    const stats = await ReferralService.getUserReferralStats(identifier);
    return res.status(200).json(stats);
  } catch (err: any) {
    return res.status(500).json({ error: 'Failed to fetch user referral stats', details: err.message });
  }
}

/**
 * 5. Get all referrals & analytics (Admin Dashboard)
 */
export async function getAdminReferralsList(_req: Request, res: Response) {
  try {
    const data = await ReferralService.getAllReferralsForAdmin();
    return res.status(200).json(data);
  } catch (err: any) {
    return res.status(500).json({ error: 'Failed to fetch admin referral list', details: err.message });
  }
}
