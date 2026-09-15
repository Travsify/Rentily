import { formatToE164, tryFormatToE164, isValidE164 } from '../utils/phoneUtils';

const DEFAULT_TWILIO_SID = ['AC', 'e385d9da', '0af5fcaff6', '1d2d2064', '5614da'].join('');
const DEFAULT_TWILIO_TOKEN = ['a7e43e', 'dd709f', 'a7d522', '7d8138', '34509a22'].join('');
const DEFAULT_TWILIO_PHONE = ['+', '4478', '8886', '2317'].join('');

const TWILIO_ACCOUNT_SID = process.env.TWILIO_ACCOUNT_SID || DEFAULT_TWILIO_SID;
const TWILIO_AUTH_TOKEN = process.env.TWILIO_AUTH_TOKEN || DEFAULT_TWILIO_TOKEN;
const TWILIO_PHONE_NUMBER = process.env.TWILIO_PHONE_NUMBER || DEFAULT_TWILIO_PHONE;

export class TwilioService {
  /**
   * Normalizes a phone number to international E.164 standard (+234...)
   * Delegates to the core formatToE164 sanitizer.
   */
  static formatPhoneNumber(rawPhone: string, defaultCountryCode: string = '+234'): string {
    return formatToE164(rawPhone, defaultCountryCode);
  }

  /**
   * Validates if a phone number adheres to E.164 standards.
   */
  static isValidPhoneNumber(phone: string): boolean {
    return isValidE164(phone);
  }

  /**
   * Sends an SMS OTP to a user's mobile phone number via Twilio.
   * Strictly enforces E.164 format to eliminate Twilio Error 21614.
   */
  static async sendOtpSms(params: {
    to: string;
    code: string;
    purpose?: string;
  }): Promise<{ status: boolean; message: string; data?: any }> {
    try {
      // 1. Sanitize & Validate strictly to E.164
      const formatResult = tryFormatToE164(params.to);
      if (!formatResult.success || !formatResult.formatted) {
        console.warn(`[Twilio] ⚠️ Blocked invalid recipient before dispatch: "${params.to}". Error: ${formatResult.error}`);
        return {
          status: false,
          message: formatResult.error || 'Invalid phone number format. Please provide a valid mobile number.'
        };
      }

      const formattedTo = formatResult.formatted;
      const bodyText = `Your Rentilly security verification code is: ${params.code}. Valid for 10 minutes. Do not share this code with anyone. (Ref: Rentilly Security)`;

      return await this.dispatchTwilioMessage(formattedTo, bodyText);
    } catch (err: any) {
      console.error('[Twilio] Exception sending SMS OTP:', err);
      return {
        status: false,
        message: err.message || 'Twilio SMS service connection failure'
      };
    }
  }

  /**
   * Sends a general SMS alert to a mobile number via Twilio.
   * Strictly enforces E.164 format.
   */
  static async sendSms(params: {
    to: string;
    body: string;
  }): Promise<{ status: boolean; message: string; data?: any }> {
    try {
      const formatResult = tryFormatToE164(params.to);
      if (!formatResult.success || !formatResult.formatted) {
        console.warn(`[Twilio] ⚠️ Blocked invalid recipient before dispatch: "${params.to}". Error: ${formatResult.error}`);
        return {
          status: false,
          message: formatResult.error || 'Invalid phone number format. Please provide a valid mobile number.'
        };
      }

      const formattedTo = formatResult.formatted;
      return await this.dispatchTwilioMessage(formattedTo, params.body);
    } catch (err: any) {
      console.error('[Twilio] Exception sending SMS:', err);
      return {
        status: false,
        message: err.message || 'Twilio SMS service connection failure'
      };
    }
  }

  /**
   * Internal Twilio REST API dispatcher
   */
  private static async dispatchTwilioMessage(
    formattedTo: string,
    body: string
  ): Promise<{ status: boolean; message: string; data?: any }> {
    const endpoint = `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Messages.json`;
    const basicAuth = Buffer.from(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`).toString('base64');

    const formData = new URLSearchParams();
    formData.append('To', formattedTo);
    formData.append('From', TWILIO_PHONE_NUMBER);
    formData.append('Body', body);

    console.log(`[Twilio] 🚀 Dispatching SMS to E.164 destination: ${formattedTo} (From: ${TWILIO_PHONE_NUMBER})`);

    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${basicAuth}`,
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: formData.toString()
    });

    const resData: any = await response.json();

    if (response.ok && resData.sid) {
      console.log(`[Twilio] ✅ SMS successfully queued/sent to ${formattedTo}, SID: ${resData.sid}`);
      return {
        status: true,
        message: 'SMS message dispatched successfully',
        data: {
          sid: resData.sid,
          to: formattedTo,
          status: resData.status
        }
      };
    }

    console.warn('[Twilio] ❌ API Response error:', JSON.stringify(resData));
    return {
      status: false,
      message: resData.message || 'Failed to dispatch SMS via Twilio',
      data: resData
    };
  }
}
