import type { Request, Response } from 'express';
import { ResendService } from '../services/resendService';
import { TwilioService } from '../services/twilioService';
import { OtpStore } from '../services/otpStore';
import { UserStore } from '../services/userStore';
import { supabase } from '../supabaseClient';

export async function sendOtp(req: Request, res: Response) {
  try {
    const { email, phoneNumber, userName, channel = 'both', purpose = 'Account Verification' } = req.body;

    if (!email && !phoneNumber) {
      return res.status(400).json({
        status: false,
        message: 'Please provide at least an email address or mobile phone number.'
      });
    }

    const primaryIdentifier = (email || phoneNumber).trim().toLowerCase();
    const { code, expiresAt } = OtpStore.createOtp(primaryIdentifier, purpose);

    const deliveryResults: { email?: any; sms?: any } = {};
    let atLeastOneSuccess = false;

    // 1. Dispatch Email via Resend
    if (email && (channel === 'email' || channel === 'both')) {
      const emailRes = await ResendService.sendOtpEmail({
        to: email,
        code,
        userName,
        purpose
      });
      deliveryResults.email = emailRes;
      if (emailRes.status) atLeastOneSuccess = true;
    }

    // 2. Dispatch SMS via Twilio
    if (phoneNumber && (channel === 'sms' || channel === 'both')) {
      const smsRes = await TwilioService.sendOtpSms({
        to: phoneNumber,
        code,
        purpose
      });
      deliveryResults.sms = smsRes;
      if (smsRes.status) atLeastOneSuccess = true;
    }

    if (atLeastOneSuccess) {
      return res.json({
        status: true,
        message: `Security code sent successfully to ${email ? email : ''}${email && phoneNumber ? ' and ' : ''}${phoneNumber ? phoneNumber : ''}.`,
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
    const identifier = (email || phoneNumber || '').trim().toLowerCase();

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
      if (email) {
        if (supabase) {
          await supabase.from('users').update({ email_verified: true }).eq('email', email.trim().toLowerCase());
        }
        const existing = await UserStore.findByEmail(email.trim().toLowerCase());
        if (existing) {
          UserStore.upsertUser({ ...existing, isVerified: true });
        }
      }
      if (phoneNumber && supabase) {
        await supabase.from('users').update({ phone_verified: true }).eq('phone_number', phoneNumber.trim());
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
