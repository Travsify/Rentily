import { ResendService } from './resendService';
import { supabase } from '../supabaseClient';
import { UserStore } from './userStore';

const RESEND_API_KEY = process.env.RESEND_API_KEY || '';
const SENDER_EMAIL = process.env.RESEND_FROM_EMAIL || 'Rentilly Security <info@myrentilly.com>';

export type NotificationCategory = 'security' | 'wallet' | 'escrow' | 'inspection' | 'property' | 'utilities';

export interface NotificationEvent {
  userId?: string;
  email: string;
  userName?: string;
  title: string;
  category: NotificationCategory;
  message: string;
  metadata?: {
    amount?: number;
    reference?: string;
    propertyTitle?: string;
    gateCode?: string;
    token?: string;
    meterNumber?: string;
    bankName?: string;
    accountNumber?: string;
    date?: string;
    [key: string]: any;
  };
}

export class NotificationDispatcher {
  /**
   * Generates responsive, executive HTML email templates branded for Rentilly by E-Homes Global Inclusive Limited.
   */
  private static buildHtmlEmail(event: NotificationEvent): string {
    const { userName, title, category, message, metadata } = event;
    const displayName = userName && userName.trim().length > 0 ? userName.trim() : 'Valued User';
    const dateStr = metadata?.date || new Date().toLocaleString('en-NG', { timeZone: 'Africa/Lagos', dateStyle: 'medium', timeStyle: 'short' });

    let categoryPillColor = '#10B981';
    let categoryPillBg = 'rgba(16, 185, 129, 0.15)';
    let categoryLabel = 'NOTIFICATION';

    if (category === 'wallet') {
      categoryPillColor = '#0284C7';
      categoryPillBg = 'rgba(2, 132, 199, 0.15)';
      categoryLabel = 'WALLET TRANSACTION';
    } else if (category === 'escrow') {
      categoryPillColor = '#F59E0B';
      categoryPillBg = 'rgba(245, 158, 11, 0.15)';
      categoryLabel = 'ESCROW & COMMISSIONS';
    } else if (category === 'inspection') {
      categoryPillColor = '#8B5CF6';
      categoryPillBg = 'rgba(139, 92, 246, 0.15)';
      categoryLabel = 'INSPECTION PASS';
    } else if (category === 'utilities') {
      categoryPillColor = '#EC4899';
      categoryPillBg = 'rgba(236, 72, 153, 0.15)';
      categoryLabel = 'UTILITIES RECEIPT';
    } else if (category === 'security') {
      categoryPillColor = '#10B981';
      categoryPillBg = 'rgba(16, 185, 129, 0.15)';
      categoryLabel = 'SECURITY ALERT';
    }

    // Dynamic metadata table rows
    let metaRows = '';
    if (metadata) {
      if (metadata.amount !== undefined) {
        metaRows += `
          <tr>
            <td style="padding: 10px 0; color: #94A3B8; font-size: 13px; border-bottom: 1px solid #1E293B;">Amount:</td>
            <td style="padding: 10px 0; color: #FFFFFF; font-size: 15px; font-weight: 800; text-align: right; border-bottom: 1px solid #1E293B;">₦${Number(metadata.amount).toLocaleString('en-NG', { minimumFractionDigits: 2 })}</td>
          </tr>
        `;
      }
      if (metadata.reference) {
        metaRows += `
          <tr>
            <td style="padding: 10px 0; color: #94A3B8; font-size: 13px; border-bottom: 1px solid #1E293B;">Reference:</td>
            <td style="padding: 10px 0; color: #CBD5E1; font-size: 12px; font-family: monospace; text-align: right; border-bottom: 1px solid #1E293B;">${metadata.reference}</td>
          </tr>
        `;
      }
      if (metadata.propertyTitle) {
        metaRows += `
          <tr>
            <td style="padding: 10px 0; color: #94A3B8; font-size: 13px; border-bottom: 1px solid #1E293B;">Property:</td>
            <td style="padding: 10px 0; color: #FFFFFF; font-size: 13px; font-weight: 600; text-align: right; border-bottom: 1px solid #1E293B;">${metadata.propertyTitle}</td>
          </tr>
        `;
      }
      if (metadata.gateCode) {
        metaRows += `
          <tr>
            <td style="padding: 10px 0; color: #94A3B8; font-size: 13px; border-bottom: 1px solid #1E293B;">6-Digit Gate Pass:</td>
            <td style="padding: 10px 0; color: #10B981; font-size: 18px; font-weight: 900; letter-spacing: 3px; font-family: monospace; text-align: right; border-bottom: 1px solid #1E293B;">${metadata.gateCode}</td>
          </tr>
        `;
      }
      if (metadata.token) {
        metaRows += `
          <tr>
            <td style="padding: 10px 0; color: #94A3B8; font-size: 13px; border-bottom: 1px solid #1E293B;">Prepaid Token:</td>
            <td style="padding: 10px 0; color: #F59E0B; font-size: 16px; font-weight: 900; letter-spacing: 2px; font-family: monospace; text-align: right; border-bottom: 1px solid #1E293B;">${metadata.token}</td>
          </tr>
        `;
      }
      if (metadata.bankName) {
        metaRows += `
          <tr>
            <td style="padding: 10px 0; color: #94A3B8; font-size: 13px; border-bottom: 1px solid #1E293B;">Bank / Channel:</td>
            <td style="padding: 10px 0; color: #CBD5E1; font-size: 13px; text-align: right; border-bottom: 1px solid #1E293B;">${metadata.bankName}</td>
          </tr>
        `;
      }
      metaRows += `
        <tr>
          <td style="padding: 10px 0; color: #94A3B8; font-size: 13px;">Date & Time:</td>
          <td style="padding: 10px 0; color: #CBD5E1; font-size: 12px; text-align: right;">${dateStr}</td>
        </tr>
      `;
    }

    return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title}</title>
</head>
<body style="margin: 0; padding: 0; background-color: #070B14; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #FFFFFF;">
  <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #070B14; padding: 30px 15px;">
    <tr>
      <td align="center">
        <table width="100%" max-width="540" border="0" cellspacing="0" cellpadding="0" style="max-width: 540px; background-color: #0F172A; border-radius: 20px; border: 1px solid #1E293B; overflow: hidden; box-shadow: 0 12px 36px rgba(0,0,0,0.6);">
          
          <!-- Header Bar -->
          <tr>
            <td style="padding: 26px 32px; background: linear-gradient(135deg, #064E3B 0%, #065F46 100%); text-align: center;">
              <table width="100%" border="0" cellspacing="0" cellpadding="0">
                <tr>
                  <td align="center">
                    <div style="display: inline-block; background-color: #10B981; color: #FFFFFF; font-weight: 900; font-size: 20px; width: 42px; height: 42px; line-height: 42px; border-radius: 12px; margin-bottom: 8px;">R</div>
                    <h1 style="margin: 0; color: #FFFFFF; font-size: 22px; font-weight: 800; letter-spacing: -0.5px;">RENTILLY</h1>
                    <p style="margin: 4px 0 0 0; color: #A7F3D0; font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px;">Rentily, built by a landlord for every tenant/landlord</p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Main Content -->
          <tr>
            <td style="padding: 32px 32px 24px 32px;">
              <!-- Category Pill -->
              <div style="display: inline-block; background-color: ${categoryPillBg}; border: 1px solid ${categoryPillColor}; border-radius: 20px; padding: 4px 12px; margin-bottom: 16px;">
                <span style="color: ${categoryPillColor}; font-size: 10.5px; font-weight: 800; letter-spacing: 1px; text-transform: uppercase;">${categoryLabel}</span>
              </div>

              <h2 style="margin: 0 0 12px 0; color: #FFFFFF; font-size: 20px; font-weight: 800; letter-spacing: -0.3px;">${title}</h2>
              <p style="margin: 0 0 20px 0; color: #94A3B8; font-size: 14px; line-height: 1.6;">
                Hello <strong>${displayName}</strong>,<br>
                ${message}
              </p>

              ${metaRows ? `
              <!-- Activity Summary Box -->
              <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #131D31; border: 1px solid #1E293B; border-radius: 14px; padding: 16px 20px; margin-bottom: 24px;">
                <tr>
                  <td>
                    <table width="100%" border="0" cellspacing="0" cellpadding="0">
                      ${metaRows}
                    </table>
                  </td>
                </tr>
              </table>
              ` : ''}

              <!-- Security & Regulatory Notice -->
              <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #0B1120; border-left: 3px solid #10B981; border-radius: 4px 8px 8px 4px; padding: 12px 14px; margin-bottom: 12px;">
                <tr>
                  <td style="color: #64748B; font-size: 11.5px; line-height: 1.5;">
                    🛡️ <strong>Escrow & Regulatory Warranty:</strong> All transactions and direct tenancy payouts on Rentilly are backed by Lagos Tenancy Law compliant escrow protocols and verified banking rails.
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Corporate Footer -->
          <tr>
            <td style="padding: 24px 32px; background-color: #070B14; border-top: 1px solid #1E293B; text-align: center;">
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
  }

  /**
   * Dispatches both an In-App Notification (Database) and an Instant Transactional Email (Resend).
   */
  static async dispatch(event: NotificationEvent): Promise<{ success: boolean; inApp: boolean; email: boolean }> {
    let inAppSuccess = false;
    let emailSuccess = false;

    // 1. Dispatch In-App Notification (Supabase / Database)
    try {
      if (supabase && event.userId) {
        await supabase.from('notifications').insert({
          user_id: event.userId,
          title: event.title,
          category: event.category,
          message: event.message,
          metadata: event.metadata || {},
          read: false,
          created_at: new Date().toISOString()
        });
        inAppSuccess = true;
      }
    } catch (e) {
      console.warn('[NotificationDispatcher] In-App database save error:', e);
    }

    // 2. Dispatch Branded HTML Email via Resend
    try {
      const cleanEmail = event.email.trim().toLowerCase();
      const htmlBody = this.buildHtmlEmail(event);

      const response = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${RESEND_API_KEY}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          from: SENDER_EMAIL,
          to: [cleanEmail],
          subject: event.title,
          html: htmlBody
        })
      });

      const resData: any = await response.json();
      if (response.ok && (resData.id || resData.data?.id)) {
        console.log(`[NotificationDispatcher] Email successfully sent to ${cleanEmail}: "${event.title}"`);
        emailSuccess = true;
      } else {
        console.warn('[NotificationDispatcher] Resend API error:', JSON.stringify(resData));
      }
    } catch (e) {
      console.error('[NotificationDispatcher] Email dispatch exception:', e);
    }

    return {
      success: inAppSuccess || emailSuccess,
      inApp: inAppSuccess,
      email: emailSuccess
    };
  }
}
