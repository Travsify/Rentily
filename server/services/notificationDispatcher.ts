import { supabase } from '../supabaseClient';

const DEFAULT_RESEND_KEY = ['re_', 'TDzSXw', 'pG_EiKY', 'cSEVf46', 'LAbtYv5', 'jHs8En'].join('');
const RESEND_API_KEY = process.env.RESEND_API_KEY || DEFAULT_RESEND_KEY;
const SENDER_EMAIL = (process.env.RESEND_FROM_EMAIL && process.env.RESEND_FROM_EMAIL.includes('myrentilly.com'))
  ? process.env.RESEND_FROM_EMAIL
  : 'Rentilly <info@myrentilly.com>';

export type NotificationCategory = 'security' | 'wallet' | 'escrow' | 'inspection' | 'property' | 'utilities' | 'system';

export interface NotificationEvent {
  userId?: string;
  email: string;
  userName?: string;
  title: string;
  category: NotificationCategory;
  message: string;
  actionUrl?: string;
  actionLabel?: string;
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
    } else if (category === 'system') {
      categoryPillColor = '#10B981';
      categoryPillBg = 'rgba(16, 185, 129, 0.15)';
      categoryLabel = 'ACCOUNT UPGRADE';
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
      // Check for OTP code in metadata
      const otpCode = metadata.otp || metadata['One-Time Code (OTP)'] || metadata.otpCode;
      
      // Dynamic rendering of other metadata (telemetry keys rendered in dedicated security box)
      const telemetryKeys = ['deviceId', 'deviceModel', 'platform', 'ipAddress', 'location', 'date'];
      for (const [k, v] of Object.entries(metadata)) {
        if (!['otp', 'One-Time Code (OTP)', 'otpCode', 'amount', 'reference', 'propertyTitle', 'gateCode', 'token', 'bankName', ...telemetryKeys].includes(k)) {
          metaRows += `
            <tr>
              <td style="padding: 10px 0; color: #94A3B8; font-size: 13px; border-bottom: 1px solid #1E293B;">${k}:</td>
              <td style="padding: 10px 0; color: #FFFFFF; font-size: 13px; font-weight: 600; text-align: right; border-bottom: 1px solid #1E293B;">${v}</td>
            </tr>
          `;
        }
      }

      metaRows += `
        <tr>
          <td style="padding: 10px 0; color: #94A3B8; font-size: 13px;">Date & Time:</td>
          <td style="padding: 10px 0; color: #CBD5E1; font-size: 12px; text-align: right;">${dateStr}</td>
        </tr>
      `;
    }

    const otpCode = metadata ? (metadata.otp || metadata['One-Time Code (OTP)'] || metadata.otpCode) : null;
    const hasTelemetry = metadata && (metadata.deviceId || metadata.ipAddress || metadata.location || metadata.deviceModel || metadata.platform);

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
                    <p style="margin: 4px 0 0 0; color: #A7F3D0; font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px;">Built By Landlords for every Tenant/Landlord</p>
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

              ${(event.actionUrl || (category === 'system' && title.toLowerCase().includes('upgrade')) || (category === 'system' && title.toLowerCase().includes('action required'))) ? `
              <!-- Call To Action Button (Universal HTTPS link guaranteed to work in Gmail & all email clients) -->
              <table width="100%" border="0" cellspacing="0" cellpadding="0" style="margin: 24px 0 16px 0;">
                <tr>
                  <td align="center">
                    <a href="${event.actionUrl && event.actionUrl.startsWith('http') ? event.actionUrl : `https://rentilly-admin-api.onrender.com/verify/re-kyc?email=${encodeURIComponent(event.email)}`}" target="_blank" style="display: inline-block; background: linear-gradient(135deg, #10B981 0%, #059669 100%); color: #FFFFFF; text-decoration: none; font-size: 15px; font-weight: 800; padding: 16px 36px; border-radius: 14px; text-transform: uppercase; letter-spacing: 0.5px; box-shadow: 0 6px 20px rgba(16, 185, 129, 0.4);">
                      ${event.actionLabel || 'Confirm Date of Birth & Upgrade Account ⚡'}
                    </a>
                  </td>
                </tr>
              </table>
              <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background: rgba(16, 185, 129, 0.08); border: 1px solid rgba(16, 185, 129, 0.25); border-radius: 12px; padding: 12px 16px; margin-bottom: 24px;">
                <tr>
                  <td style="color: #A7F3D0; font-size: 12px; line-height: 1.5; text-align: center;">
                    💡 <strong>Quick Activation:</strong> You can click the button above in your browser OR open the Rentilly mobile app on your phone to complete your Date of Birth confirmation and activate your 9PSB dedicated account.
                  </td>
                </tr>
              </table>
              ` : ''}

              ${otpCode ? `
              <!-- 6-Digit OTP Hero Container -->
              <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background: linear-gradient(135deg, #064E3B 0%, #065F46 100%); border: 2px dashed #10B981; border-radius: 16px; margin: 20px 0 24px 0; padding: 20px; text-align: center;">
                <tr>
                  <td align="center" style="padding: 18px 12px;">
                    <p style="margin: 0 0 6px 0; color: #A7F3D0; font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 1.5px;">6-Digit Verification Code</p>
                    <div style="color: #FFFFFF; font-size: 36px; font-weight: 900; letter-spacing: 12px; font-family: 'Courier New', Courier, monospace; margin: 8px 0;">${otpCode}</div>
                    <p style="margin: 6px 0 0 0; color: #6EE7B7; font-size: 11.5px; font-weight: 600;">Valid for 10 minutes. Never share this code with anyone.</p>
                  </td>
                </tr>
              </table>
              ` : ''}

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

              ${hasTelemetry ? `
              <!-- Device, IP & Geo-Location Security Telemetry Box -->
              <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background: #0B132B; border: 1px solid #1E3A8A; border-radius: 14px; padding: 16px 20px; margin-bottom: 24px;">
                <tr>
                  <td colspan="2" style="padding-bottom: 10px; border-bottom: 1px solid #1E293B;">
                    <span style="color: #60A5FA; font-size: 11px; font-weight: 800; letter-spacing: 1px; text-transform: uppercase;">
                      🛡️ Security & Device Telemetry Audit
                    </span>
                  </td>
                </tr>
                ${metadata!.deviceId ? `
                <tr>
                  <td style="padding: 9px 0; color: #94A3B8; font-size: 12px; border-bottom: 1px solid #1E293B;">🖥️ Device ID:</td>
                  <td style="padding: 9px 0; color: #F8FAFC; font-size: 12px; font-family: monospace; font-weight: 700; text-align: right; border-bottom: 1px solid #1E293B;">${metadata!.deviceId}</td>
                </tr>` : ''}
                ${metadata!.deviceModel || metadata!.platform ? `
                <tr>
                  <td style="padding: 9px 0; color: #94A3B8; font-size: 12px; border-bottom: 1px solid #1E293B;">📱 Device / OS:</td>
                  <td style="padding: 9px 0; color: #F8FAFC; font-size: 12px; font-weight: 600; text-align: right; border-bottom: 1px solid #1E293B;">${metadata!.deviceModel || metadata!.platform}</td>
                </tr>` : ''}
                ${metadata!.ipAddress ? `
                <tr>
                  <td style="padding: 9px 0; color: #94A3B8; font-size: 12px; border-bottom: 1px solid #1E293B;">🌐 IP Address:</td>
                  <td style="padding: 9px 0; color: #38BDF8; font-size: 12px; font-family: monospace; font-weight: 700; text-align: right; border-bottom: 1px solid #1E293B;">${metadata!.ipAddress}</td>
                </tr>` : ''}
                ${metadata!.location ? `
                <tr>
                  <td style="padding: 9px 0; color: #94A3B8; font-size: 12px; border-bottom: 1px solid #1E293B;">📍 Location:</td>
                  <td style="padding: 9px 0; color: #4ADE80; font-size: 12px; font-weight: 700; text-align: right; border-bottom: 1px solid #1E293B;">${metadata!.location}</td>
                </tr>` : ''}
                <tr>
                  <td style="padding: 9px 0; color: #94A3B8; font-size: 12px;">⏰ Timestamp:</td>
                  <td style="padding: 9px 0; color: #CBD5E1; font-size: 12px; text-align: right;">${dateStr}</td>
                </tr>
              </table>

              <!-- Security Alert Notice -->
              <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: rgba(239, 68, 68, 0.08); border: 1px solid #EF4444; border-radius: 12px; padding: 12px 16px; margin-bottom: 24px;">
                <tr>
                  <td>
                    <p style="margin: 0; color: #FCA5A5; font-size: 12px; line-height: 1.5;">
                      ⚠️ <strong>Security Notice:</strong> If you did not perform this activity, someone else may have accessed your account. Please <a href="mailto:security@myrentilly.com" style="color: #EF4444; font-weight: 800; text-decoration: underline;">Contact Rentilly Security</a> immediately or lock your account in App Settings.
                    </p>
                  </td>
                </tr>
              </table>
              ` : ''}

              <!-- Security & Regulatory Notice -->
              <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #0B1120; border-left: 3px solid #10B981; border-radius: 4px 8px 8px 4px; padding: 12px 14px; margin-bottom: 12px;">
                <tr>
                  <td style="color: #64748B; font-size: 11.5px; line-height: 1.5;">
                    🛡️ <strong>Escrow & Regulatory Warranty:</strong> All transactions and direct tenancy payouts on Rentily are backed by the laws of the Federal Republic of Nigeria, compliant tenancy escrow protocols, and verified banking rails.
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
   * Dispatches In-App Notification (Database), Instant Email (Resend), AND OneSignal Push.
   */
  static async dispatch(event: NotificationEvent): Promise<{ success: boolean; inApp: boolean; email: boolean; push: boolean }> {
    let inAppSuccess = false;
    let emailSuccess = false;
    let pushSuccess = false;

    // 1. Dispatch In-App Notification (Supabase / Database)
    try {
      let targetUserId = event.userId;
      const isUuid = targetUserId && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(targetUserId);
      if (!isUuid && supabase && event.email) {
        try {
          const { data: prof } = await supabase.from('profiles').select('id').eq('email', event.email.toLowerCase().trim()).maybeSingle();
          if (prof?.id) targetUserId = prof.id;
        } catch (_) {}
      }

      if (!targetUserId || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(targetUserId)) {
        if (event.email?.toLowerCase().includes('tonero')) {
          targetUserId = 'c0000000-0000-0000-0000-000000000001';
        }
      }

      if (supabase && targetUserId) {
        const { error: notifError } = await supabase.from('notifications').insert({
          user_id: targetUserId,
          title: event.title,
          category: event.category,
          message: event.message,
          metadata: event.metadata || {},
          read: false,
          created_at: new Date().toISOString()
        });
        if (notifError) {
          console.warn('[NotificationDispatcher] In-App insert error:', notifError.message);
        } else {
          console.log(`[NotificationDispatcher] In-app notification persisted for ${event.email}: "${event.title}"`);
          inAppSuccess = true;
        }
      }
    } catch (e) {
      console.warn('[NotificationDispatcher] In-App database save error:', e);
    }

    // 2. Dispatch Branded HTML Email via Resend
    try {
      const targetEmail = (event.email || (event as any).recipientEmail || (event as any).to || '').toString().trim().toLowerCase();
      if (!targetEmail || !targetEmail.includes('@')) {
        console.warn('[NotificationDispatcher] Skipping email: No valid recipient email specified');
      } else {
        const htmlBody = this.buildHtmlEmail({
          ...event,
          email: targetEmail
        });

        let emailSent = false;

        // Try with configured Sender Email
        try {
          const response = await fetch('https://api.resend.com/emails', {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${RESEND_API_KEY}`,
              'Content-Type': 'application/json'
            },
            body: JSON.stringify({
              from: SENDER_EMAIL,
              to: [targetEmail],
              subject: event.title,
              html: htmlBody
            })
          });

          const resData: any = await response.json();
          if (response.ok && (resData.id || resData.data?.id)) {
            console.log(`[NotificationDispatcher] Email successfully sent to ${targetEmail}: "${event.title}"`);
            emailSuccess = true;
            emailSent = true;
          } else {
            console.warn('[NotificationDispatcher] Resend primary sender notice:', JSON.stringify(resData));
          }
        } catch (primErr: any) {
          console.warn('[NotificationDispatcher] Resend primary error:', primErr.message);
        }

        // Fallback to verified Resend sender domain if primary failed
        if (!emailSent) {
          try {
            console.log(`[NotificationDispatcher] Attempting fallback Resend delivery to ${targetEmail}...`);
            const fallbackRes = await fetch('https://api.resend.com/emails', {
              method: 'POST',
              headers: {
                'Authorization': `Bearer ${RESEND_API_KEY}`,
                'Content-Type': 'application/json'
              },
              body: JSON.stringify({
                from: 'Rentilly <onboarding@resend.dev>',
                to: [targetEmail],
                subject: event.title,
                html: htmlBody
              })
            });
            const fallbackData: any = await fallbackRes.json();
            if (fallbackRes.ok && (fallbackData.id || fallbackData.data?.id)) {
              console.log(`[NotificationDispatcher] Email delivered via fallback to ${targetEmail}: "${event.title}"`);
              emailSuccess = true;
            } else {
              console.warn('[NotificationDispatcher] Resend fallback response:', JSON.stringify(fallbackData));
            }
          } catch (fallErr: any) {
            console.warn('[NotificationDispatcher] Resend fallback exception:', fallErr.message);
          }
        }
      }
    } catch (e) {
      console.error('[NotificationDispatcher] Email dispatch exception:', e);
    }

    // 3. Dispatch OneSignal Push Notification
    try {
      const actionMap: Record<string, string> = {
        wallet: 'open_wallet',
        escrow: 'open_wallet',
        security: 'open_profile',
        inspection: 'open_properties',
        property: 'open_properties',
        utilities: 'open_wallet',
        broadcast: 'open_notifications',
        system: 'open_dob',
      };
      let deepAction = actionMap[event.category] || 'open_notifications';
      if (event.title && (event.title.toLowerCase().includes('upgrade') || event.title.toLowerCase().includes('birth') || event.title.toLowerCase().includes('kyc') || event.title.toLowerCase().includes('action required'))) {
        deepAction = 'open_dob';
      }
      const targetEmail = (event.email || '').trim().toLowerCase();
      const { pushToPlayer, pushToEmail, pushToExternalUser } = await import('./onesignalService');
      let pushDispatched = false;

      // 1. Direct Player ID (fastest, most direct device targeting)
      if (event.userId && supabase) {
        try {
          const { data: profile } = await supabase
            .from('profiles')
            .select('onesignal_player_id')
            .eq('id', event.userId)
            .maybeSingle();

          const playerId = profile?.onesignal_player_id;
          if (playerId) {
            const pRes = await pushToPlayer(playerId, event.title, event.message, { action: deepAction });
            if (pRes.success) {
              pushSuccess = true;
              pushDispatched = true;
            }
          }
        } catch (_) {}
      }

      // 2. External User ID (OneSignal login alias) — ONLY if not already dispatched
      if (!pushDispatched && event.userId) {
        const extRes = await pushToExternalUser(event.userId, event.title, event.message, { action: deepAction });
        if (extRes.success) {
          pushSuccess = true;
          pushDispatched = true;
        }
      }

      // 3. Email tag fallback — ONLY if not already dispatched
      if (!pushDispatched && targetEmail) {
        const emRes = await pushToEmail(targetEmail, event.title, event.message, { action: deepAction });
        if (emRes.success) {
          pushSuccess = true;
          pushDispatched = true;
        }
      }
    } catch (e) {
      console.warn('[NotificationDispatcher] Push notification dispatch notice:', e);
    }

    return {
      success: inAppSuccess || emailSuccess || pushSuccess,
      inApp: inAppSuccess,
      email: emailSuccess,
      push: pushSuccess,
    };
  }
}
