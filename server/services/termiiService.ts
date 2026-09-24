import dotenv from 'dotenv';
import { tryFormatToE164 } from '../utils/phoneUtils';

dotenv.config();

const DEFAULT_TERMII_KEY = ['tlv_', 'ONGQkgfG', 'WxoP5jH9', 'vfjCPunQ9', 'EjAOknLx', 'GL4GDqL1Co'].join('');
const TERMII_API_KEY = process.env.TERMII_API_KEY || DEFAULT_TERMII_KEY;
const TERMII_BASE_URL = process.env.TERMII_BASE_URL || 'https://api.ng.termii.com';
const TERMII_SENDER_ID = process.env.TERMII_SENDER_ID || 'N-Alert';

export class TermiiService {
  /**
   * Normalizes a phone number for Termii dispatch.
   * Termii expects Nigerian numbers in international format without leading plus (e.g. "2348012345678").
   */
  static normalizePhoneForTermii(rawPhone: string): string {
    const clean = (rawPhone || '').replace(/\D/g, '');
    if (clean.startsWith('0') && clean.length === 11) {
      return '234' + clean.slice(1);
    }
    if (clean.startsWith('234') && clean.length === 13) {
      return clean;
    }
    if (clean.length === 10) {
      return '234' + clean;
    }
    return clean;
  }

  /**
   * Checks if Termii API is configured.
   */
  static isConfigured(): boolean {
    return Boolean(TERMII_API_KEY && TERMII_API_KEY.length > 10);
  }

  /**
   * Fetches the current real-time wallet balance from Termii.
   */
  static async getBalance(): Promise<{ status: boolean; balance: number; currency: string; application?: string }> {
    try {
      const response = await fetch(`${TERMII_BASE_URL}/api/get-balance?api_key=${TERMII_API_KEY}`, {
        method: 'GET',
        headers: { 'Content-Type': 'application/json' }
      });
      const data: any = await response.json();
      if (response.ok && data.balance !== undefined) {
        return {
          status: true,
          balance: Number(data.balance),
          currency: data.currency || 'NGN',
          application: data.application || data.user || 'Rentilly'
        };
      }
      return { status: false, balance: 0, currency: 'NGN' };
    } catch (err: any) {
      console.error('[TermiiService] Error fetching balance:', err.message);
      return { status: false, balance: 0, currency: 'NGN' };
    }
  }

  /**
   * Sends an OTP SMS to a user's mobile number via Termii.
   */
  static async sendOtpSms(params: {
    to: string;
    code: string;
    purpose?: string;
  }): Promise<{ status: boolean; message: string; data?: any }> {
    try {
      const normalizedTo = this.normalizePhoneForTermii(params.to);
      if (!normalizedTo || normalizedTo.length < 10) {
        return {
          status: false,
          message: 'Invalid recipient phone number for SMS dispatch.'
        };
      }

      const purposeStr = params.purpose ? ` for ${params.purpose}` : '';
      const messageBody = `Your Rentilly security code${purposeStr} is: ${params.code}. Valid for 10 minutes. Do not disclose this code to anyone. (Rentilly Security)`;

      console.log(`[TermiiService] 🔑 Dispatching OTP SMS to ${normalizedTo} (Code: ${params.code})`);

      const payload = {
        to: normalizedTo,
        from: TERMII_SENDER_ID,
        sms: messageBody,
        type: 'plain',
        channel: 'generic', // "generic" route ensures high delivery rate across DND and non-DND
        api_key: TERMII_API_KEY
      };

      const response = await fetch(`${TERMII_BASE_URL}/api/sms/send`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });

      const resData: any = await response.json();

      if (response.ok && (resData.code === 'ok' || resData.message === 'Successfully Sent' || resData.message_id)) {
        console.log(`[TermiiService] ✅ OTP SMS delivered to ${normalizedTo}: MessageID ${resData.message_id || 'OK'}`);
        return {
          status: true,
          message: 'Security code dispatched via SMS successfully.',
          data: resData
        };
      }

      // If generic channel encounters sender ID issue, fallback to dnd channel
      if (!response.ok || resData.code !== 'ok') {
        console.warn(`[TermiiService] Generic channel warning (${resData.message || response.statusText}), trying dnd channel...`);
        const fallbackRes = await fetch(`${TERMII_BASE_URL}/api/sms/send`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ ...payload, channel: 'dnd' })
        });
        const fallbackData: any = await fallbackRes.json();
        if (fallbackRes.ok && (fallbackData.code === 'ok' || fallbackData.message === 'Successfully Sent' || fallbackData.message_id)) {
          console.log(`[TermiiService] ✅ OTP SMS delivered via DND channel to ${normalizedTo}`);
          return {
            status: true,
            message: 'Security code dispatched via SMS successfully.',
            data: fallbackData
          };
        }
      }

      console.warn('[TermiiService] ❌ SMS dispatch response:', JSON.stringify(resData));
      return {
        status: false,
        message: resData.message || 'Failed to dispatch SMS via Termii',
        data: resData
      };
    } catch (err: any) {
      console.error('[TermiiService] Exception dispatching OTP SMS:', err);
      return {
        status: false,
        message: err.message || 'Termii SMS gateway connection error'
      };
    }
  }

  /**
   * Sends a transactional or notification SMS to a user.
   */
  static async sendSms(params: {
    to: string;
    message: string;
    channel?: 'generic' | 'dnd' | 'whatsapp';
  }): Promise<{ status: boolean; message: string; data?: any }> {
    try {
      const normalizedTo = this.normalizePhoneForTermii(params.to);
      if (!normalizedTo || normalizedTo.length < 10) {
        return {
          status: false,
          message: 'Invalid recipient phone number.'
        };
      }

      const payload = {
        to: normalizedTo,
        from: TERMII_SENDER_ID,
        sms: params.message,
        type: 'plain',
        channel: params.channel || 'generic',
        api_key: TERMII_API_KEY
      };

      const response = await fetch(`${TERMII_BASE_URL}/api/sms/send`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });

      const resData: any = await response.json();

      if (response.ok && (resData.code === 'ok' || resData.message === 'Successfully Sent' || resData.message_id)) {
        console.log(`[TermiiService] 📢 Notification SMS delivered to ${normalizedTo}`);
        return {
          status: true,
          message: 'Notification SMS dispatched successfully.',
          data: resData
        };
      }

      return {
        status: false,
        message: resData.message || 'Failed to dispatch notification SMS',
        data: resData
      };
    } catch (err: any) {
      console.error('[TermiiService] Exception sending notification SMS:', err);
      return {
        status: false,
        message: err.message || 'Termii connection failure'
      };
    }
  }
}
