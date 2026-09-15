import type { Request, Response } from 'express';
import { ResendService } from '../services/resendService';
import { TwilioService } from '../services/twilioService';
import { OtpStore } from '../services/otpStore';
import { UserStore } from '../services/userStore';
import { supabase } from '../supabaseClient';
import { tryFormatToE164 } from '../utils/phoneUtils';

export async function sendOtp(req: Request, res: Response) {
  try {
    const { email, phoneNumber, userName, channel = 'both', purpose = 'Account Verification' } = req.body;

    if (!email && !phoneNumber) {
      return res.status(400).json({
        status: false,
        message: 'Please provide at least an email address or mobile phone number.'
      });
    }

    // 1. Strict Phone Sanitization to E.164
    let cleanPhone: string | null = null;
    let phoneError: string | null = null;

    if (phoneNumber && typeof phoneNumber === 'string' && phoneNumber.trim().length > 0) {
      const phoneRes = tryFormatToE164(phoneNumber.trim());
      if (phoneRes.success && phoneRes.formatted) {
        cleanPhone = phoneRes.formatted;
      } else {
        phoneError = phoneRes.error || 'Invalid phone number format.';
        console.warn(`[OtpController] ⚠️ Phone number validation failed for "${phoneNumber}": ${phoneError}`);
      }
    }

    // If channel requires SMS and phone is invalid, reject early with 400
    if (channel === 'sms' && !cleanPhone) {
      return res.status(400).json({
        status: false,
        message: phoneError || 'A valid mobile phone number in international E.164 format (e.g., +2348012345678 or 08012345678) is required for SMS delivery.'
      });
    }

    const cleanEmail = email && typeof email === 'string' ? email.trim().toLowerCase() : null;
    const primaryIdentifier = cleanEmail || cleanPhone || '';

    if (!primaryIdentifier) {
      return res.status(400).json({
        status: false,
        message: 'Valid recipient contact required to dispatch OTP.'
      });
    }

    const { code, expiresAt } = OtpStore.createOtp(primaryIdentifier, purpose);
    console.log(`[OtpController] 🔑 Dispatched OTP for ${primaryIdentifier}: [${code}] (Purpose: ${purpose})`);

    const deliveryResults: { email?: any; sms?: any } = {};
    let atLeastOneSuccess = false;

    // 2. Dispatch Email via Resend
    if (cleanEmail && (channel === 'email' || channel === 'both')) {
      const emailRes = await ResendService.sendOtpEmail({
        to: cleanEmail,
        code,
        userName,
        purpose
      });
      deliveryResults.email = emailRes;
      if (emailRes.status) atLeastOneSuccess = true;
    }

    // 3. Dispatch SMS via Twilio using sanitized E.164 phone
    if (cleanPhone && (channel === 'sms' || channel === 'both')) {
      const smsRes = await TwilioService.sendOtpSms({
        to: cleanPhone,
        code,
        purpose
      });
      deliveryResults.sms = smsRes;
      if (smsRes.status) atLeastOneSuccess = true;
    } else if (channel === 'both' && phoneError) {
      deliveryResults.sms = {
        status: false,
        message: `SMS skipped: ${phoneError}`
      };
    }

    if (atLeastOneSuccess) {
      return res.json({
        status: true,
        message: `Security code sent successfully to ${cleanEmail ? cleanEmail : ''}${cleanEmail && cleanPhone ? ' and ' : ''}${cleanPhone ? cleanPhone : ''}.`,
        expiresAt,
        delivery: deliveryResults
      });
    }

    return res.status(500).json({
      status: false,
      message: deliveryResults.email?.message || deliveryResults.sms?.message || 'Failed to dispatch verification code.',
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
    let cleanPhone: string | null = null;
    if (phoneNumber && typeof phoneNumber === 'string' && phoneNumber.trim().length > 0) {
      const pRes = tryFormatToE164(phoneNumber.trim());
      if (pRes.success && pRes.formatted) {
        cleanPhone = pRes.formatted;
      }
    }

    const cleanEmail = email && typeof email === 'string' ? email.trim().toLowerCase() : null;
    const identifier = cleanEmail || cleanPhone || (phoneNumber || '').trim();

    if (!identifier || !code) {
      return res.status(400).json({
        status: false,
        message: 'Identifier (email or phone) and 6-digit code are required.'
      });
    }

    const verification = OtpStore.verifyOtp(identifier, code);

    if (!verification.valid) {
      return res.status(400).json({
        status: false,
        message: verification.message
      });
    }

    // Mark verified in Supabase & UserStore if user exists
    try {
      if (cleanEmail) {
        if (supabase) {
          await supabase.from('users').update({ email_verified: true }).eq('email', cleanEmail);
        }
        const existing = await UserStore.findByEmail(cleanEmail);
        if (existing) {
          UserStore.upsertUser({ ...existing, isVerified: true });
        }
      }
      if (cleanPhone && supabase) {
        await supabase.from('users').update({ phone_verified: true }).eq('phone_number', cleanPhone);
      }
    } catch (_) {}

    return res.json({
      status: true,
      message: 'Verification successful! Your account security is validated.'
    });
  } catch (err: any) {
    console.error('[OtpController] Verify OTP Error:', err);
    return res.status(500).json({
      status: false,
      message: err.message || 'Error processing OTP verification'
    });
  }
}
