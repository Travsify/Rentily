const RESEND_API_KEY = process.env.RESEND_API_KEY || '';
const SENDER_EMAIL = process.env.RESEND_FROM_EMAIL || 'Rentilly Security <info@myrentilly.com>';

export class ResendService {
  /**
   * Sends a 6-digit OTP verification email with branded HTML layout.
   */
  static async sendOtpEmail(params: {
    to: string;
    code: string;
    userName?: string;
    purpose?: string;
  }): Promise<{ status: boolean; message: string; data?: any }> {
    try {
      const { to, code, userName, purpose = 'Account Verification' } = params;
      const cleanEmail = to.trim().toLowerCase();
      const displayName = userName && userName.trim().length > 0 ? userName.trim() : 'Valued User';

      const htmlContent = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Rentilly Security Code</title>
</head>
<body style="margin: 0; padding: 0; background-color: #0B1120; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #FFFFFF;">
  <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #0B1120; padding: 30px 15px;">
    <tr>
      <td align="center">
        <table width="100%" max-width="520" border="0" cellspacing="0" cellpadding="0" style="max-width: 520px; background-color: #0F172A; border-radius: 20px; border: 1px solid #1E293B; overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.5);">
          
          <!-- Header Bar -->
          <tr>
            <td style="padding: 28px 32px; background: linear-gradient(135deg, #064E3B 0%, #065F46 100%); text-align: center;">
              <table width="100%" border="0" cellspacing="0" cellpadding="0">
                <tr>
                  <td align="center">
                    <div style="display: inline-block; background-color: #10B981; color: #FFFFFF; font-weight: 900; font-size: 20px; width: 44px; height: 44px; line-height: 44px; border-radius: 12px; margin-bottom: 8px;">R</div>
                    <h1 style="margin: 0; color: #FFFFFF; font-size: 22px; font-weight: 800; letter-spacing: -0.5px;">RENTILLY</h1>
                    <p style="margin: 4px 0 0 0; color: #A7F3D0; font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px;">Rentily, built by a landlord for every tenant/landlord</p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Main Body -->
          <tr>
            <td style="padding: 36px 32px 28px 32px;">
              <h2 style="margin: 0 0 12px 0; color: #FFFFFF; font-size: 18px; font-weight: 700;">Hello ${displayName},</h2>
              <p style="margin: 0 0 24px 0; color: #94A3B8; font-size: 14px; line-height: 1.6;">
                You requested a single-use verification code for <strong>${purpose}</strong> on your Rentilly account. Enter the 6-digit code below to continue:
              </p>

              <!-- OTP Code Display Card -->
              <table width="100%" border="0" cellspacing="0" cellpadding="0" style="margin-bottom: 24px;">
                <tr>
                  <td align="center" style="background-color: #1E293B; border: 2px dashed #10B981; border-radius: 14px; padding: 20px;">
                    <span style="font-family: 'Courier New', Courier, monospace; font-size: 36px; font-weight: 800; letter-spacing: 8px; color: #10B981;">${code}</span>
                  </td>
                </tr>
              </table>

              <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #131D31; border-radius: 10px; padding: 14px 16px; margin-bottom: 24px;">
                <tr>
                  <td width="24" valign="top" style="padding-right: 10px; color: #F59E0B; font-size: 16px;">⏱️</td>
                  <td style="color: #CBD5E1; font-size: 12px; line-height: 1.5;">
                    This code expires in <strong>10 minutes</strong>. Never share your verification code with anyone. Rentilly staff will never ask for your security code.
                  </td>
                </tr>
              </table>

              <p style="margin: 0; color: #64748B; font-size: 12px; line-height: 1.5;">
                If you did not initiate this request, you can safely disregard this email or contact support at <a href="mailto:info@myrentilly.com" style="color: #10B981; text-decoration: none;">info@myrentilly.com</a>.
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding: 24px 32px; background-color: #090E17; border-top: 1px solid #1E293B; text-align: center;">
              <p style="margin: 0 0 6px 0; color: #CBD5E1; font-size: 11.5px; font-weight: 700;">
                Rentily is a product of E-Homes Global Inclusive Limited
              </p>
              <p style="margin: 0 0 8px 0; color: #64748B; font-size: 11px; line-height: 1.4;">
                ✉️ Support: <a href="mailto:info@myrentilly.com" style="color: #10B981; text-decoration: none;">info@myrentilly.com</a> | 🌐 <a href="https://myrentilly.com" style="color: #10B981; text-decoration: none;">www.myrentilly.com</a>
              </p>
              <p style="margin: 0; color: #475569; font-size: 10px;">
                © ${new Date().getFullYear()} E-Homes Global Inclusive Limited. All rights reserved.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
      `;

      const response = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${RESEND_API_KEY}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          from: SENDER_EMAIL,
          to: [cleanEmail],
          subject: `${code} is your Rentilly security code`,
          html: htmlContent
        })
      });

      const resData: any = await response.json();

      if (response.ok && (resData.id || resData.data?.id)) {
        console.log(`[Resend] OTP email successfully sent to ${cleanEmail}, ID: ${resData.id || resData.data?.id}`);
        return {
          status: true,
          message: 'OTP email delivered successfully',
          data: resData
        };
      }

      console.warn('[Resend] API Response error:', JSON.stringify(resData));
      return {
        status: false,
        message: resData.message || resData.error?.message || 'Failed to send OTP email via Resend'
      };
    } catch (err: any) {
      console.error('[Resend] Exception sending email:', err);
      return {
        status: false,
        message: err.message || 'Resend service connection failure'
      };
    }
  }
}
