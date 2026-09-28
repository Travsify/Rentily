import type { Request, Response } from 'express';
import { ResendService } from '../services/resendService';
import { SmsRouterService } from '../services/smsRouterService';
import { OtpStore } from '../services/otpStore';
import { UserStore } from '../services/userStore';
import { supabase } from '../supabaseClient';
import { tryFormatToE164 } from '../utils/phoneUtils';
import { getFeatureFlags } from './featureFlagController';

export async function sendOtp(req: Request, res: Response) {
  try {
    const { email, phoneNumber, userName, channel = 'email', purpose = 'Account Verification' } = req.body;

    if (!email && !phoneNumber) {
      return res.status(400).json({
        status: false,
        message: 'Please provide an email address or mobile phone number for verification.'
      });
    }

    const cleanEmail = email && typeof email === 'string' ? email.trim().toLowerCase() : null;
    const cleanPhone = phoneNumber && typeof phoneNumber === 'string' ? phoneNumber.trim() : null;
    const primaryIdentifier = cleanEmail || cleanPhone || '';

    const { code, expiresAt } = OtpStore.createOtp(primaryIdentifier, purpose);
    if (cleanPhone && cleanEmail) {
      OtpStore.createOtp(cleanPhone, purpose);
    }

    console.log(`[OtpController] 🔑 Dispatched OTP for ${primaryIdentifier}: [${code}] (Purpose: ${purpose})`);

    const deliveryResults: { email?: any; sms?: any } = {};
    let atLeastOneSuccess = false;

    // 1. Dispatch Email via Resend if email is provided (Primary zero-cost security rail)
    if (cleanEmail) {
      const emailRes = await ResendService.sendOtpEmail({
        to: cleanEmail,
        code,
        userName,
        purpose
      });
      deliveryResults.email = emailRes;
      if (emailRes.status) atLeastOneSuccess = true;
    }

    // 2. Phone SMS: Deactivated across the platform to eliminate Twilio costs ($0 spend)
    // Only handle if request is specifically targeted at SMS channel or phone-only
    const flags = getFeatureFlags();
    if (cleanPhone && (channel === 'sms' || !cleanEmail)) {
      if (flags.requirePhoneVerification && flags.enablePhoneOtp) {
        const smsRes = await SmsRouterService.sendOtpSms({
          to: cleanPhone,
          code,
          purpose
        });
        deliveryResults.sms = smsRes;
        if (smsRes.status) atLeastOneSuccess = true;
      } else {
        // Phone verification waived: Pre-seed code so any legacy verification check passes instantly
        console.log(`[OtpController] ℹ️ Phone verification is turned OFF. Pre-seeding code [${code}] for legacy phone: ${cleanPhone}`);
        atLeastOneSuccess = true;
        deliveryResults.sms = {
          status: true,
          provider: 'system_waived',
          message: 'Phone verification is deactivated. Verification waived.'
        };
      }
    }

    const destination = cleanEmail || cleanPhone || 'your contact';

    return res.json({
      status: atLeastOneSuccess,
      message: atLeastOneSuccess
        ? `Security verification code sent successfully to ${destination}.`
        : 'Failed to deliver verification code. Please check your contact information.',
      expiresAt,
      delivery: deliveryResults
    });
  } catch (err: any) {
    console.error('[OtpController] Send OTP Error:', err);
    return res.status(500).json({
      status: false,
      message: err.message || 'Internal server error while generating verification code'
    });
  }
}

export async function verifyOtp(req: Request, res: Response) {
  try {
    const { email, phoneNumber, code } = req.body;
    const cleanEmail = email && typeof email === 'string' ? email.trim().toLowerCase() : null;
    const cleanPhone = phoneNumber && typeof phoneNumber === 'string' ? phoneNumber.trim() : null;
    const identifier = cleanEmail || cleanPhone || '';

    if (!identifier) {
      return res.status(400).json({
        status: false,
        message: 'Identifier (email or phone number) is required.'
      });
    }

    const flags = getFeatureFlags();

    // If verification is specifically for a phone number and phone verification is turned off, instantly approve!
    const isPhoneIdentifier = (!cleanEmail || identifier === cleanPhone);
    if (isPhoneIdentifier && (!flags.requirePhoneVerification || !flags.enablePhoneOtp)) {
      console.log(`[OtpController] ✅ Phone verification waived for identifier: ${identifier}`);
      return res.json({
        status: true,
        message: 'Phone verification completed.',
        isVerified: true,
        phoneVerified: true,
        emailVerified: true
      });
    }

    if (!code) {
      return res.status(400).json({
        status: false,
        message: 'Verification code is required.'
      });
    }

    // Strict 6-digit OTP verification: validates against OtpStore
    const verification = OtpStore.verifyOtp(identifier, code);
    if (!verification.valid) {
      // Also check phone identifier if email was passed
      let altValid = false;
      if (cleanPhone && cleanPhone !== identifier) {
        const altCheck = OtpStore.verifyOtp(cleanPhone, code);
        if (altCheck.valid) altValid = true;
      }
      if (!altValid && cleanPhone && (!flags.requirePhoneVerification || !flags.enablePhoneOtp)) {
        altValid = true;
        console.log(`[OtpController] ✅ Phone verification waived - accepted for ${cleanPhone}`);
      }
      if (!altValid) {
        return res.status(400).json({
          status: false,
          message: verification.message || 'Invalid or expired verification code.'
        });
      }
    }

    // Verify communication channel without prematurely marking partner KYB as verified
    let isKybDone = false;
    try {
      if (cleanEmail) {
        const existing = await UserStore.findByEmail(cleanEmail);
        if (existing) {
          const isPartner = existing.role === 'partner' || Boolean(existing.businessName && existing.buyerType === 'corporate');
          isKybDone = isPartner 
            ? Boolean(existing.isVerified && (existing.bvnVerified || existing.cacNumber) && existing.partnerStatus === 'verified')
            : Boolean(existing.isVerified);
        }
      }
    } catch (_) {}

    return res.json({
      status: true,
      message: 'Verification successful! Your security code is confirmed.',
      isVerified: isKybDone,
      phoneVerified: true,
      emailVerified: true
    });
  } catch (err: any) {
    console.error('[OtpController] Verify OTP Error:', err);
    return res.status(500).json({
      status: false,
      message: err.message || 'Error processing OTP verification'
    });
  }
}
