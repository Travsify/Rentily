import type { Request } from 'express';
import { supabase } from '../supabaseClient';

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
   * Main entry point: Records download event silently (ALL email alerts permanently killed)
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

      // AUTO-KILL: Do NOT send email alerts on app downloads, installs, or link clicks.
      // Telemetry and download counts are saved silently in database/in-memory stats.
      console.log(`[AppDownloadAlert] Tracked ${channelLabel} from ${ip} (${location}). Alert email permanently auto-killed per user directive.`);

    } catch (err: any) {
      console.error('[AppDownloadAlert] Exception during download tracking:', err);
    }
  }

  /**
   * Dispatches high-priority executive alert email
   * AUTO-KILL: Permanently deactivated per user command.
   */
  private static async sendAlertEmail(_info: any): Promise<void> {
    // Permanently killed: No emails are ever dispatched for app downloads.
    return;
  }
}
