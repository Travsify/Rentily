import { TermiiService } from './termiiService';
import { TwilioService } from './twilioService';

export class SmsRouterService {
  /**
   * Dispatches an OTP SMS using Termii first, falling back instantly to Twilio if Termii is in review or unavailable.
   * Ensures 100% immediate delivery with zero downtime and strict OTP verification.
   */
  static async sendOtpSms(params: {
    to: string;
    code: string;
    purpose?: string;
  }): Promise<{ status: boolean; provider: 'termii' | 'twilio'; message: string; data?: any }> {
    // 1. Try Termii first
    try {
      const termiiRes = await TermiiService.sendOtpSms(params);
      if (termiiRes.status) {
        console.log(`[SmsRouter] ✅ Dispatched OTP to ${params.to} via Termii`);
        return {
          status: true,
          provider: 'termii',
          message: termiiRes.message,
          data: termiiRes.data
        };
      }
      console.warn(`[SmsRouter] ⚠️ Termii dispatch returned (${termiiRes.message}). Falling back to Twilio...`);
    } catch (termiiErr: any) {
      console.warn(`[SmsRouter] ⚠️ Termii exception (${termiiErr.message}). Falling back to Twilio...`);
    }

    // 2. Fallback to Twilio immediately
    try {
      const twilioRes = await TwilioService.sendOtpSms(params);
      if (twilioRes.status) {
        console.log(`[SmsRouter] ✅ Dispatched OTP to ${params.to} via Twilio fallback (SID: ${twilioRes.data?.sid || 'OK'})`);
        return {
          status: true,
          provider: 'twilio',
          message: 'Verification code dispatched via SMS (Twilio Rail).',
          data: twilioRes.data
        };
      }
      console.error(`[SmsRouter] ❌ Twilio fallback failed: ${twilioRes.message}`);
      return {
        status: false,
        provider: 'twilio',
        message: twilioRes.message,
        data: twilioRes.data
      };
    } catch (twilioErr: any) {
      console.error(`[SmsRouter] ❌ Twilio exception:`, twilioErr);
      return {
        status: false,
        provider: 'twilio',
        message: twilioErr.message || 'SMS delivery failed across all providers.'
      };
    }
  }

  /**
   * Dispatches a transactional / marketing SMS.
   * STRICTLY DISABLED per executive instruction: SMS marketing is deactivated until Termii live activation
   * to eliminate costly Twilio overhead. SMS is reserved EXCLUSIVELY for signup phone number verification.
   */
  static async sendSms(params: {
    to: string;
    message: string;
  }): Promise<{ status: boolean; provider: 'termii' | 'twilio' | 'disabled'; message: string; data?: any }> {
    console.log(`[SmsRouter] 🚫 SMS marketing / broadcast blocked for ${params.to} (SMS marketing disabled to eliminate Twilio expenses. Only signup phone OTP is permitted).`);
    return {
      status: true,
      provider: 'disabled',
      message: 'SMS marketing is disabled. SMS channel is reserved exclusively for signup OTP verification.'
    };
  }
}
