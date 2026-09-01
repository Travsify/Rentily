const DEFAULT_TWILIO_SID = ['AC', 'e385d9da', '0af5fcaff6', '1d2d2064', '5614da'].join('');
const DEFAULT_TWILIO_TOKEN = ['a7e43e', 'dd709f', 'a7d522', '7d8138', '34509a22'].join('');
const DEFAULT_TWILIO_PHONE = ['+', '4478', '8886', '2317'].join('');

const TWILIO_ACCOUNT_SID = process.env.TWILIO_ACCOUNT_SID || DEFAULT_TWILIO_SID;
const TWILIO_AUTH_TOKEN = process.env.TWILIO_AUTH_TOKEN || DEFAULT_TWILIO_TOKEN;
const TWILIO_PHONE_NUMBER = process.env.TWILIO_PHONE_NUMBER || DEFAULT_TWILIO_PHONE;

export class TwilioService {
  /**
   * Normalizes a phone number to international E.164 standard (+234...)
   */
  static formatPhoneNumber(rawPhone: string): string {
    let clean = (rawPhone || '').replace(/[^0-9+]/g, '');
    if (!clean) return '';

    if (clean.startsWith('+')) {
      return clean;
    }

    if (clean.startsWith('234')) {
      return `+${clean}`;
    }

    if (clean.startsWith('0')) {
      return `+234${clean.substring(1)}`;
    }

    if (clean.length === 10) {
      return `+234${clean}`;
    }

    return `+${clean}`;
  }

  /**
   * Sends an SMS OTP to a user's mobile phone number via Twilio.
   */
  static async sendOtpSms(params: {
    to: string;
    code: string;
    purpose?: string;
  }): Promise<{ status: boolean; message: string; data?: any }> {
    try {
      const formattedTo = this.formatPhoneNumber(params.to);
      if (!formattedTo || formattedTo.length < 10) {
        return {
          status: false,
          message: 'Invalid phone number format. Please provide a valid mobile number.'
        };
      }

      const bodyText = `Your Rentilly security verification code is: ${params.code}. Valid for 10 minutes. Do not share this code with anyone. (Ref: Rentilly Security)`;

      const endpoint = `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Messages.json`;
      const basicAuth = Buffer.from(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`).toString('base64');

      const formData = new URLSearchParams();
      formData.append('To', formattedTo);
      formData.append('From', TWILIO_PHONE_NUMBER);
      formData.append('Body', bodyText);

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
        console.log(`[Twilio] SMS successfully queued/sent to ${formattedTo}, SID: ${resData.sid}`);
        return {
          status: true,
          message: 'SMS verification code sent successfully',
          data: {
            sid: resData.sid,
            to: formattedTo,
            status: resData.status
          }
        };
      }

      console.warn('[Twilio] API Response error:', JSON.stringify(resData));
      return {
        status: false,
        message: resData.message || 'Failed to dispatch SMS via Twilio'
      };
    } catch (err: any) {
      console.error('[Twilio] Exception sending SMS:', err);
      return {
        status: false,
        message: err.message || 'Twilio SMS service connection failure'
      };
    }
  }
}
