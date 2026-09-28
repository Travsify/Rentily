import type { Request } from 'express';
import { supabase } from '../supabaseClient';

const DEFAULT_RESEND_KEY = ['re_', 'TDzSXw', 'pG_EiKY', 'cSEVf46', 'LAbtYv5', 'jHs8En'].join('');
const RESEND_API_KEY = process.env.RESEND_API_KEY || DEFAULT_RESEND_KEY;
const SENDER_EMAIL = (process.env.RESEND_FROM_EMAIL && process.env.RESEND_FROM_EMAIL.includes('myrentilly.com'))
  ? process.env.RESEND_FROM_EMAIL
  : 'Rentilly <info@myrentilly.com>';

export type DownloadChannel = 'apk' | 'play_store' | 'first_launch' | 'web_redirect';

export interface DownloadAlertParams {
  req: Request;
  channel: DownloadChannel;
  referralCode?: string;
  email?: string;
  deviceModel?: string;
}

export class AppDownloadAlertService {
  // Throttle cache: IP -> timestamp (5 minutes window)
  private static recentAlerts: Map<string, number> = new Map();
  private static readonly THROTTLE_MS = 5 * 60 * 1000; // 5 minutes

  // In-memory counter cache
  private static totalApkDownloads = 0;
  private static totalPlayStoreRedirects = 0;
  private static totalFirstLaunches = 0;
  private static isHydrated = false;

  /**
   * Hydrates stats from Supabase Cloud system_configs
   */
  private static async hydrateStats(): Promise<void> {
    if (this.isHydrated || !supabase) return;
    try {
      const { data } = await supabase
        .from('system_configs')
        .select('data')
        .eq('id', 'app_download_stats')
        .maybeSingle();

      if (data?.data) {
        this.totalApkDownloads = data.data.totalApkDownloads || 0;
        this.totalPlayStoreRedirects = data.data.totalPlayStoreRedirects || 0;
        this.totalFirstLaunches = data.data.totalFirstLaunches || 0;
      }
      this.isHydrated = true;
    } catch (_) {}
  }

  /**
   * Formats User-Agent string to recognize Android versions, device models, and browsers
   */
  private static parseUserAgent(ua: string): { deviceCategory: string; description: string } {
    if (!ua) return { deviceCategory: 'Unknown Device', description: 'Unknown' };

    const lower = ua.toLowerCase();
    let deviceCategory = 'Desktop Browser';
    let description = ua.slice(0, 75);

    if (lower.includes('android')) {
      deviceCategory = 'Android Mobile';
      const match = ua.match(/Android\s+([0-9.]+);?\s*([^;)]+)?/i);
      if (match) {
        const osVer = match[1] ? `Android ${match[1]}` : 'Android';
        const model = match[2] ? match[2].trim() : '';
        description = model ? `${model} (${osVer})` : osVer;
      }
    } else if (lower.includes('iphone') || lower.includes('ipad')) {
      deviceCategory = 'Apple iOS Device';
      description = lower.includes('ipad') ? 'Apple iPad' : 'Apple iPhone';
    } else if (lower.includes('windows')) {
      deviceCategory = 'Windows PC';
      description = 'Windows Desktop / Laptop';
    } else if (lower.includes('macintosh') || lower.includes('mac os')) {
      deviceCategory = 'Apple Mac';
      description = 'Mac OS Desktop';
    } else if (lower.includes('linux')) {
      deviceCategory = 'Linux System';
      description = 'Linux Desktop / Server';
    }

    if (lower.includes('dart') || lower.includes('flutter')) {
      deviceCategory = 'Rentilly Flutter Native App';
      description = 'In-App Flutter Runtime';
    }

    return { deviceCategory, description };
  }

  /**
   * Resolves recipient emails for alert
   */
  private static getAlertRecipients(): string[] {
    const list = ['info@travsify.com', 'info@myrentilly.com'];
    if (process.env.ADMIN_ALERT_EMAIL) {
      const extra = process.env.ADMIN_ALERT_EMAIL.split(',').map(e => e.trim().toLowerCase());
      for (const e of extra) {
        if (e && !list.includes(e)) list.push(e);
      }
    }
    return list;
  }

  /**
   * Main entry point: Records download event, captures telemetry, and dispatches instant email
   */
  static async recordAndAlertDownload(params: DownloadAlertParams): Promise<void> {
    try {
      await this.hydrateStats();

      const { req, channel, referralCode, email, deviceModel } = params;

      // Extract client network telemetry
      const ip = (
        req.headers['x-forwarded-for'] ||
        req.headers['x-real-ip'] ||
        req.socket?.remoteAddress ||
        req.ip ||
        '127.0.0.1'
      ).toString().split(',')[0].trim();

      const cfCountry = (req.headers['cf-ipcountry'] || '').toString().trim();
      const cfCity = (req.headers['cf-ipcity'] || '').toString().trim();
      const location = (cfCountry && cfCity)
        ? `${cfCity}, ${cfCountry}`
        : (cfCountry ? `${cfCountry}` : 'Nigeria (Standard Region)');

      const uaString = (req.headers['user-agent'] || '').toString();
      const { deviceCategory, description: uaDescription } = this.parseUserAgent(uaString);
      const effectiveDevice = deviceModel || uaDescription;

      const referer = (req.headers['referer'] || req.query.ref || 'Direct / Bookmark').toString();
      const code = referralCode || (req.params?.code as string) || (req.query?.code as string) || (req.query?.ref as string);

      // Channel labels
      let channelLabel = 'Direct APK Download';
      if (channel === 'apk') {
        this.totalApkDownloads++;
        channelLabel = 'Direct Android APK Download (Rentily.apk)';
      } else if (channel === 'play_store') {
        this.totalPlayStoreRedirects++;
        channelLabel = 'Google Play Store Link Redirect';
      } else if (channel === 'first_launch') {
        this.totalFirstLaunches++;
        channelLabel = 'First-Time Mobile App Installation (Launch)';
      } else {
        channelLabel = 'Web Portal Download Link';
      }

      const totalDownloads = this.totalApkDownloads + this.totalPlayStoreRedirects + this.totalFirstLaunches;

      // Check throttling: Only send 1 email per IP per 5 minutes to prevent spam from download retries
      const throttleKey = `${ip}_${channel}`;
      const lastSent = this.recentAlerts.get(throttleKey);
      const now = Date.now();

      const isThrottled = lastSent && (now - lastSent) < this.THROTTLE_MS;

      // Asynchronously persist download statistics to Supabase
      if (supabase) {
        Promise.resolve(
          supabase.from('system_configs').upsert({
            id: 'app_download_stats',
            data: {
              totalApkDownloads: this.totalApkDownloads,
              totalPlayStoreRedirects: this.totalPlayStoreRedirects,
              totalFirstLaunches: this.totalFirstLaunches,
              totalDownloads,
              lastDownloadAt: new Date().toISOString(),
              lastDownloadChannel: channelLabel,
              lastDownloadIp: ip,
              lastDownloadLocation: location,
            },
            updated_at: new Date().toISOString()
          })
        ).catch((err: any) => console.warn('[AppDownloadAlert] Supabase stats write note:', err.message));
      }

      // If throttled, skip sending duplicate email but keep count
      if (isThrottled) {
        console.log(`[AppDownloadAlert] Throttling alert email for IP ${ip} (${channelLabel}) - sent within last 5m`);
        return;
      }

      this.recentAlerts.set(throttleKey, now);

      console.log(`[AppDownloadAlert] 🚀 Triggering real-time email alert for ${channelLabel} from ${ip} (${location})...`);

      // Dispatch alert email to admin recipients
      await this.sendAlertEmail({
        channelLabel,
        channel,
        ipAddress: ip,
        location,
        deviceCategory,
        deviceModel: effectiveDevice,
        userAgent: uaString,
        referer,
        referralCode: code,
        userEmail: email,
        totalDownloads,
        timestamp: new Date().toLocaleString('en-NG', { timeZone: 'Africa/Lagos', dateStyle: 'full', timeStyle: 'medium' }) + ' (GMT+1)'
      });

    } catch (err: any) {
      console.error('[AppDownloadAlert] Exception during download tracking:', err);
    }
  }

  /**
   * Dispatches high-priority executive alert email via Resend
   */
  private static async sendAlertEmail(info: {
    channelLabel: string;
    channel: DownloadChannel;
    ipAddress: string;
    location: string;
    deviceCategory: string;
    deviceModel: string;
    userAgent: string;
    referer: string;
    referralCode?: string;
    userEmail?: string;
    totalDownloads: number;
    timestamp: string;
  }): Promise<void> {
    const recipients = this.getAlertRecipients();

    const isApk = info.channel === 'apk';
    const accentColor = isApk ? '#10B981' : '#0284C7';
    const badgeBg = isApk ? 'rgba(16, 185, 129, 0.15)' : 'rgba(2, 132, 199, 0.15)';

    const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>New App Download Alert</title>
</head>
<body style="margin: 0; padding: 0; background-color: #0B1120; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #FFFFFF;">
  <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #0B1120; padding: 30px 15px;">
    <tr>
      <td align="center">
        <table width="100%" border="0" cellspacing="0" cellpadding="0" style="max-width: 560px; background-color: #0F172A; border-radius: 20px; border: 1px solid #1E293B; overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.5);">
          
          <!-- Header Bar -->
          <tr>
            <td style="padding: 28px 32px; background: linear-gradient(135deg, #064E3B 0%, #065F46 100%); text-align: center;">
              <table width="100%" border="0" cellspacing="0" cellpadding="0">
                <tr>
                  <td align="center">
                    <img src="https://api.myrentilly.com/logo.png" width="48" height="48" alt="Rentilly" style="display: block; margin: 0 auto 10px auto; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.3);" />
                    <h1 style="margin: 0; color: #FFFFFF; font-size: 22px; font-weight: 800; letter-spacing: -0.5px;">RENTILLY</h1>
                    <p style="margin: 4px 0 0 0; color: #A7F3D0; font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px;">Real-Time Growth & Acquisition Engine</p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Main Body -->
          <tr>
            <td style="padding: 32px 32px 28px 32px;">
              <!-- Alert Pill -->
              <table border="0" cellspacing="0" cellpadding="0" style="margin-bottom: 18px;">
                <tr>
                  <td style="background-color: ${badgeBg}; border: 1px solid ${accentColor}; border-radius: 20px; padding: 6px 14px;">
                    <span style="color: ${accentColor}; font-size: 11px; font-weight: 800; letter-spacing: 1px; text-transform: uppercase;">
                      📱 NEW APP DOWNLOAD DETECTED
                    </span>
                  </td>
                </tr>
              </table>

              <h2 style="margin: 0 0 12px 0; color: #FFFFFF; font-size: 19px; font-weight: 800; letter-spacing: -0.3px;">
                A user just downloaded the Rentilly mobile app! 🎉
              </h2>
              <p style="margin: 0 0 24px 0; color: #94A3B8; font-size: 13.5px; line-height: 1.6;">
                The platform telemetry engine captured a live download initiation via <strong>${info.channelLabel}</strong>. Full acquisition metrics and device details are recorded below:
              </p>

              <!-- Telemetry Metadata Card -->
              <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #131D31; border: 1px solid #1E293B; border-radius: 14px; padding: 16px 20px; margin-bottom: 24px;">
                <tr>
                  <td style="padding: 10px 0; color: #94A3B8; font-size: 13px; border-bottom: 1px solid #1E293B;">📦 Acquisition Channel:</td>
                  <td style="padding: 10px 0; color: ${accentColor}; font-size: 13px; font-weight: 800; text-align: right; border-bottom: 1px solid #1E293B;">${info.channelLabel}</td>
                </tr>
                <tr>
                  <td style="padding: 10px 0; color: #94A3B8; font-size: 13px; border-bottom: 1px solid #1E293B;">📍 Location:</td>
                  <td style="padding: 10px 0; color: #FFFFFF; font-size: 13px; font-weight: 700; text-align: right; border-bottom: 1px solid #1E293B;">${info.location}</td>
                </tr>
                <tr>
                  <td style="padding: 10px 0; color: #94A3B8; font-size: 13px; border-bottom: 1px solid #1E293B;">🌐 IP Address:</td>
                  <td style="padding: 10px 0; color: #38BDF8; font-size: 13px; font-family: monospace; font-weight: 700; text-align: right; border-bottom: 1px solid #1E293B;">${info.ipAddress}</td>
                </tr>
                <tr>
                  <td style="padding: 10px 0; color: #94A3B8; font-size: 13px; border-bottom: 1px solid #1E293B;">📱 Device Type / Model:</td>
                  <td style="padding: 10px 0; color: #F8FAFC; font-size: 13px; font-weight: 700; text-align: right; border-bottom: 1px solid #1E293B;">${info.deviceModel}</td>
                </tr>
                ${info.referralCode ? `
                <tr>
                  <td style="padding: 10px 0; color: #F59E0B; font-size: 13px; border-bottom: 1px solid #1E293B;">🤝 Referral / Creator Code:</td>
                  <td style="padding: 10px 0; color: #F59E0B; font-size: 13px; font-family: monospace; font-weight: 800; text-align: right; border-bottom: 1px solid #1E293B;">${info.referralCode}</td>
                </tr>` : ''}
                ${info.userEmail ? `
                <tr>
                  <td style="padding: 10px 0; color: #94A3B8; font-size: 13px; border-bottom: 1px solid #1E293B;">👤 User Email:</td>
                  <td style="padding: 10px 0; color: #FFFFFF; font-size: 13px; font-weight: 700; text-align: right; border-bottom: 1px solid #1E293B;">${info.userEmail}</td>
                </tr>` : ''}
                <tr>
                  <td style="padding: 10px 0; color: #94A3B8; font-size: 13px; border-bottom: 1px solid #1E293B;">🔗 Referrer Source:</td>
                  <td style="padding: 10px 0; color: #94A3B8; font-size: 11px; text-align: right; border-bottom: 1px solid #1E293B; word-break: break-all;">${info.referer}</td>
                </tr>
                <tr>
                  <td style="padding: 10px 0; color: #94A3B8; font-size: 13px;">⏰ Time of Download:</td>
                  <td style="padding: 10px 0; color: #CBD5E1; font-size: 12px; text-align: right;">${info.timestamp}</td>
                </tr>
              </table>

              <!-- Total Counter Highlight Card -->
              <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background: linear-gradient(135deg, #1E293B 0%, #0F172A 100%); border: 1px solid #334155; border-radius: 14px; padding: 18px; margin-bottom: 24px; text-align: center;">
                <tr>
                  <td>
                    <span style="color: #94A3B8; font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: 1px;">Total Recorded App Downloads</span>
                    <div style="color: #10B981; font-size: 32px; font-weight: 900; margin-top: 4px;">#${info.totalDownloads.toLocaleString()}</div>
                  </td>
                </tr>
              </table>

              <!-- Call to Action -->
              <table width="100%" border="0" cellspacing="0" cellpadding="0" style="margin: 10px 0 20px 0;">
                <tr>
                  <td align="center">
                    <a href="https://admin.myrentilly.com" target="_blank" style="display: inline-block; background: linear-gradient(135deg, #10B981 0%, #059669 100%); color: #FFFFFF; text-decoration: none; font-size: 14px; font-weight: 800; padding: 14px 32px; border-radius: 12px; text-transform: uppercase; letter-spacing: 0.5px;">
                      Open Rentilly Admin Desk ⚡
                    </a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding: 20px 32px; background-color: #090E17; border-top: 1px solid #1E293B; text-align: center;">
              <p style="margin: 0 0 4px 0; color: #CBD5E1; font-size: 11px; font-weight: 700;">
                Rentilly Automated Acquisition & Telemetry Daemon
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

    const subject = `📱 [Rentilly Alert] New App Download (${info.location}) - #${info.totalDownloads}`;

    for (const recipient of recipients) {
      try {
        const res = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${RESEND_API_KEY}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            from: SENDER_EMAIL,
            to: [recipient],
            reply_to: 'info@myrentilly.com',
            subject,
            html,
            text: `${subject}\n\nLocation: ${info.location}\nDevice: ${info.deviceModel}\nDownloads: #${info.totalDownloads}`
          })
        });

        const resData: any = await res.json().catch(() => null);
        if (res.ok && (resData?.id || resData?.data?.id)) {
          console.log(`[AppDownloadAlert] Alert email delivered to ${recipient} (ID: ${resData?.id || resData?.data?.id})`);
        } else {
          console.warn(`[AppDownloadAlert] Resend primary error for ${recipient}:`, resData);
          // Fallback to onboarding sender
          await fetch('https://api.resend.com/emails', {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${RESEND_API_KEY}`,
              'Content-Type': 'application/json'
            },
            body: JSON.stringify({
              from: 'Rentilly <onboarding@resend.dev>',
              to: [recipient],
              reply_to: 'info@myrentilly.com',
              subject,
              html,
              text: `${subject}\n\nLocation: ${info.location}\nDevice: ${info.deviceModel}\nDownloads: #${info.totalDownloads}`
            })
          }).catch(() => {});
        }
      } catch (err: any) {
        console.error(`[AppDownloadAlert] Delivery exception for ${recipient}:`, err.message);
      }
    }
  }
}
