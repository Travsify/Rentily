import { EmailTransportService } from './emailTransport';

const RESEND_API_KEY = process.env.RESEND_API_KEY || '';
const SENDER_EMAIL = process.env.RESEND_FROM_EMAIL || 'Rentilly Security <security@myrentilly.com>';

// Quarantined non-responsive / hard-bounced mailboxes to prevent reputation damage
const quarantinedEmails = new Set<string>([
  'saddiqmusa71@gmail.com'
]);

export class ResendService {
  /**
   * Sanitizes email address and fixes common domain typos
   */
  static sanitizeEmail(email: string): string {
    if (!email) return '';
    let clean = email.trim().toLowerCase();
    clean = clean.replace(/@gmial\.com$/, '@gmail.com');
    clean = clean.replace(/@gmai\.com$/, '@gmail.com');
    clean = clean.replace(/@gamil\.com$/, '@gmail.com');
    clean = clean.replace(/@yaho\.com$/, '@yahoo.com');
    clean = clean.replace(/@hotmial\.com$/, '@hotmail.com');
    return clean;
  }

  /**
   * Checks if an email is quarantined
   */
  static isQuarantined(email: string): boolean {
    return quarantinedEmails.has(email.trim().toLowerCase());
  }

  /**
   * Adds an email to quarantine
   */
  static quarantineEmail(email: string) {
    quarantinedEmails.add(email.trim().toLowerCase());
  }

  /**
   * Sends a 6-digit OTP verification email with branded HTML layout.
   * Utilizes intelligent dual-rail delivery: Hostinger SMTP for Gmail (bypasses SES deferrals) and Resend API with automated fallback.
   */
  static async sendOtpEmail(params: {
    to: string;
    code: string;
    userName?: string;
    purpose?: string;
  }): Promise<{ status: boolean; message: string; data?: any }> {
    try {
      const { to, code, userName, purpose = 'Account Verification' } = params;
      const cleanEmail = this.sanitizeEmail(to);

      if (!cleanEmail || !cleanEmail.includes('@')) {
        return { status: false, message: 'Invalid recipient email address format' };
      }

      if (this.isQuarantined(cleanEmail)) {
        console.warn(`[ResendService] 🛑 Suppressed delivery to quarantined address: ${cleanEmail}`);
        return { status: false, message: 'Recipient email is currently flagged as undeliverable' };
      }

      const displayName = userName && userName.trim().length > 0 ? userName.trim() : 'Valued User';

      const htmlContent = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Rentilly Verification Code</title>
</head>
<body style="margin: 0; padding: 24px; background-color: #F8FAFC; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #1E293B;">
  <div style="max-width: 480px; margin: 0 auto; background-color: #FFFFFF; border-radius: 14px; border: 1px solid #E2E8F0; padding: 32px 28px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05);">
    
    <div style="text-align: center; margin-bottom: 24px;">
      <h1 style="margin: 0; color: #047857; font-size: 26px; font-weight: 800; letter-spacing: -0.5px;">RENTILLY</h1>
      <p style="margin: 4px 0 0 0; color: #64748B; font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 1px;">Zero Agents • Legal Escrow • Direct Access</p>
    </div>

    <p style="margin: 0 0 16px 0; font-size: 15px; color: #334155; line-height: 1.5;">
      Hello ${displayName},
    </p>

    <p style="margin: 0 0 20px 0; font-size: 14px; color: #475569; line-height: 1.5;">
      Your single-use verification code for <strong>${purpose}</strong> on your Rentilly account is:
    </p>

    <div style="background-color: #F0FDF4; border: 1.5px dashed #059669; border-radius: 10px; padding: 20px; text-align: center; margin-bottom: 22px;">
      <span style="font-family: 'Courier New', Courier, monospace; font-size: 38px; font-weight: 800; letter-spacing: 8px; color: #047857;">${code}</span>
    </div>

    <div style="background-color: #FFFBEB; border: 1px solid #FDE68A; border-radius: 8px; padding: 12px 16px; margin-bottom: 22px;">
      <p style="margin: 0; font-size: 12.5px; color: #92400E; line-height: 1.4;">
        ⏱️ This code expires in <strong>10 minutes</strong>. Never share your verification code with anyone. Rentilly staff will never ask for your security code.
      </p>
    </div>

    <p style="margin: 0 0 24px 0; font-size: 12px; color: #64748B; line-height: 1.5;">
      If you did not initiate this request, you can safely disregard this email or contact support at <a href="mailto:info@myrentilly.com" style="color: #047857; text-decoration: none; font-weight: 600;">info@myrentilly.com</a>.
    </p>

    <div style="border-top: 1px solid #E2E8F0; padding-top: 18px; text-align: center;">
      <p style="margin: 0 0 4px 0; font-size: 12px; color: #475569; font-weight: 600;">
        Rentilly is a product of E-Homes Global Inclusive Limited
      </p>
      <p style="margin: 0 0 6px 0; font-size: 11px; color: #64748B;">
        ✉️ Support: <a href="mailto:info@myrentilly.com" style="color: #047857; text-decoration: none;">info@myrentilly.com</a> | 🌐 <a href="https://myrentilly.com" style="color: #047857; text-decoration: none;">www.myrentilly.com</a>
      </p>
      <p style="margin: 0; font-size: 10px; color: #94A3B8;">
        © ${new Date().getFullYear()} E-Homes Global Inclusive Limited. All rights reserved.
      </p>
    </div>

  </div>
</body>
</html>
      `;

      const result = await EmailTransportService.sendMail({
        to: cleanEmail,
        from: SENDER_EMAIL,
        replyTo: 'info@myrentilly.com',
        subject: `${code} is your Rentilly verification code`,
        headers: {
          'X-Entity-Ref-ID': `otp-${Date.now()}-${Math.floor(Math.random() * 100000)}`,
          'Auto-Submitted': 'auto-generated',
          'X-Auto-Response-Suppress': 'All, NDR, RN, NRN, OOF'
        },
        html: htmlContent,
        text: `Hello ${displayName},\n\nYour single-use verification code for ${purpose} on your Rentilly account is: ${code}\n\nThis code expires in 10 minutes. Never share this code with anyone.\n\nRentilly is a product of E-Homes Global Inclusive Limited\nSupport: info@myrentilly.com | https://myrentilly.com`
      });

      if (result.success) {
        console.log(`[ResendService] ✅ OTP email dispatched to ${cleanEmail} via [${result.provider}] from ${SENDER_EMAIL}, ID: ${result.messageId}`);
        return {
          status: true,
          message: 'OTP email delivered successfully',
          data: result.data
        };
      }

      console.warn(`[ResendService] Delivery notice:`, result.error);

      return {
        status: false,
        message: result.error || 'Failed to send OTP email'
      };
    } catch (err: any) {
      console.error('[ResendService] Exception sending email:', err);
      return {
        status: false,
        message: err.message || 'Email delivery service failure'
      };
    }
  }
}
