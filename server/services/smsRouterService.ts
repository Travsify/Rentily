import { TermiiService } from './termiiService';
import { TwilioService } from './twilioService';

export class SmsRouterService {
  /**
   * Phone SMS verification is completely TURNED OFF per executive directive to eliminate Twilio costs.
   * Phone verification is waived for all users (both already installed and new installs).
   */
  static async sendOtpSms(params: {
    to: string;
    code: string;
    purpose?: string;
  }): Promise<{ status: boolean; provider: 'termii' | 'twilio' | 'disabled'; message: string; data?: any }> {
    console.log(`[SmsRouter] 🚫 Phone SMS verification is turned OFF. Dispatch to ${params.to} safely waived ($0 carrier costs).`);
    return {
      status: true,
      provider: 'disabled',
      message: 'Phone number verification is turned off across the platform. Verification waived.',
      data: { waived: true }
    };
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
