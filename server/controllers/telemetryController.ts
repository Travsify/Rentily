import type { Request, Response } from 'express';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { supabase } from '../supabaseClient';

export interface VisitorLogEntry {
  id: string;
  visitorId: string;
  sessionId?: string;
  page: string;
  referrer: string;
  channel: 'direct' | 'whatsapp' | 'tiktok' | 'instagram' | 'twitter_x' | 'google' | 'other';
  device: {
    os: string;
    type: 'mobile_android' | 'mobile_ios' | 'desktop' | 'tablet' | 'other';
    browser: string;
  };
  country: string;
  ipHash: string;
  timestamp: string;
}

export interface VisitorAnalyticsData {
  totalPageviews: number;
  uniqueVisitors: number;
  todayPageviews: number;
  todayUniqueVisitors: number;
  lastUpdated: string;
  sources: {
    direct: number;
    whatsapp: number;
    tiktok: number;
    instagram: number;
    twitter_x: number;
    google: number;
    other: number;
  };
  devices: {
    mobile_android: number;
    mobile_ios: number;
    desktop: number;
    tablet: number;
    other: number;
  };
  topPages: Record<string, number>;
  uniqueVisitorIds: string[];
  todayVisitorIds: string[];
  todayDateStr: string;
  recentLogs: VisitorLogEntry[];
}

const DATA_DIR = path.join(process.cwd(), 'server', 'data');
const DATA_FILE = path.join(DATA_DIR, 'visitor_telemetry.json');

const INITIAL_ANALYTICS: VisitorAnalyticsData = {
  totalPageviews: 0,
  uniqueVisitors: 0,
  todayPageviews: 0,
  todayUniqueVisitors: 0,
  lastUpdated: new Date().toISOString(),
  sources: {
    direct: 0,
    whatsapp: 0,
    tiktok: 0,
    instagram: 0,
    twitter_x: 0,
    google: 0,
    other: 0,
  },
  devices: {
    mobile_android: 0,
    mobile_ios: 0,
    desktop: 0,
    tablet: 0,
    other: 0,
  },
  topPages: {},
  uniqueVisitorIds: [],
  todayVisitorIds: [],
  todayDateStr: new Date().toISOString().slice(0, 10),
  recentLogs: [],
};

let memAnalytics: VisitorAnalyticsData = loadTelemetryData();
let activeSessions: Map<string, number> = new Map();

function loadTelemetryData(): VisitorAnalyticsData {
  try {
    if (!fs.existsSync(DATA_DIR)) {
      fs.mkdirSync(DATA_DIR, { recursive: true });
    }
    if (fs.existsSync(DATA_FILE)) {
      const parsed = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
      return { ...INITIAL_ANALYTICS, ...parsed };
    }
  } catch (err: any) {
    console.warn('[Telemetry] Error loading telemetry file:', err.message);
  }
  return { ...INITIAL_ANALYTICS };
}

let saveTimeout: NodeJS.Timeout | null = null;
function scheduleSave() {
  if (saveTimeout) return;
  saveTimeout = setTimeout(async () => {
    saveTimeout = null;
    try {
      if (!fs.existsSync(DATA_DIR)) {
        fs.mkdirSync(DATA_DIR, { recursive: true });
      }
      fs.writeFileSync(DATA_FILE, JSON.stringify(memAnalytics, null, 2), 'utf8');

      if (supabase) {
        await supabase.from('system_configs').upsert({
          id: 'visitor_imprint_analytics',
          data: {
            totalPageviews: memAnalytics.totalPageviews,
            uniqueVisitors: memAnalytics.uniqueVisitors,
            todayPageviews: memAnalytics.todayPageviews,
            todayUniqueVisitors: memAnalytics.todayUniqueVisitors,
            sources: memAnalytics.sources,
            devices: memAnalytics.devices,
            topPages: memAnalytics.topPages,
            lastUpdated: new Date().toISOString(),
          },
          updated_at: new Date().toISOString(),
        }).catch(() => {});
      }
    } catch (e: any) {
      console.warn('[Telemetry] Failed to persist analytics:', e.message);
    }
  }, 1000);
}

function parseChannel(referrer: string, utmSource?: string): VisitorLogEntry['channel'] {
  const ref = (referrer || '').toLowerCase();
  const utm = (utmSource || '').toLowerCase();

  if (utm === 'whatsapp' || ref.includes('whatsapp') || ref.includes('wa.me')) return 'whatsapp';
  if (utm === 'tiktok' || ref.includes('tiktok.com')) return 'tiktok';
  if (utm === 'instagram' || ref.includes('instagram.com') || ref.includes('l.instagram.com')) return 'instagram';
  if (utm === 'twitter' || utm === 'x' || ref.includes('t.co') || ref.includes('twitter.com') || ref.includes('x.com')) return 'twitter_x';
  if (utm === 'google' || ref.includes('google.com') || ref.includes('google.co')) return 'google';
  if (!ref || ref === 'direct' || ref.includes(process.env.APP_URL || 'myrentilly.com')) return 'direct';
  return 'other';
}

function parseDevice(userAgent: string): VisitorLogEntry['device'] {
  const ua = (userAgent || '').toLowerCase();
  let os = 'Unknown';
  let type: VisitorLogEntry['device']['type'] = 'desktop';

  if (ua.includes('android')) {
    os = 'Android';
    type = ua.includes('tablet') ? 'tablet' : 'mobile_android';
  } else if (ua.includes('iphone')) {
    os = 'iOS';
    type = 'mobile_ios';
  } else if (ua.includes('ipad')) {
    os = 'iOS iPad';
    type = 'tablet';
  } else if (ua.includes('windows')) {
    os = 'Windows';
    type = 'desktop';
  } else if (ua.includes('macintosh') || ua.includes('mac os')) {
    os = 'macOS';
    type = 'desktop';
  } else if (ua.includes('linux')) {
    os = 'Linux';
    type = 'desktop';
  }

  let browser = 'Unknown';
  if (ua.includes('chrome') && !ua.includes('edg')) browser = 'Chrome';
  else if (ua.includes('safari') && !ua.includes('chrome')) browser = 'Safari';
  else if (ua.includes('firefox')) browser = 'Firefox';
  else if (ua.includes('edg')) browser = 'Edge';
  else if (ua.includes('opera') || ua.includes('opr')) browser = 'Opera';

  return { os, type, browser };
}

export const telemetryController = {
  recordImprint: (req: Request, res: Response) => {
    try {
      const now = new Date();
      const todayDate = now.toISOString().slice(0, 10);

      if (memAnalytics.todayDateStr !== todayDate) {
        memAnalytics.todayDateStr = todayDate;
        memAnalytics.todayPageviews = 0;
        memAnalytics.todayUniqueVisitors = 0;
        memAnalytics.todayVisitorIds = [];
      }

      const clientIp = (req.headers['cf-connecting-ip'] ||
        req.headers['x-forwarded-for'] ||
        req.headers['x-real-ip'] ||
        req.socket.remoteAddress ||
        '127.0.0.1') as string;
      const ua = (req.headers['user-agent'] || '') as string;
      const country = (req.headers['cf-ipcountry'] || req.headers['x-country'] || 'NG') as string;

      const ipHash = crypto.createHash('sha256').update(clientIp + 'rentilly_salt_2026').digest('hex').substring(0, 12);

      const body = req.body || {};
      const visitorId = body.visitorId || ('v_' + ipHash);
      const page = (body.page || req.headers.referer || '/').split('?')[0];
      const referrer = body.referrer || (req.headers.referer as string) || '';
      const utmSource = body.utmSource;

      const channel = parseChannel(referrer, utmSource);
      const device = parseDevice(ua);

      memAnalytics.totalPageviews += 1;
      memAnalytics.todayPageviews += 1;

      if (!memAnalytics.uniqueVisitorIds.includes(visitorId)) {
        memAnalytics.uniqueVisitorIds.push(visitorId);
        if (memAnalytics.uniqueVisitorIds.length > 50000) {
          memAnalytics.uniqueVisitorIds = memAnalytics.uniqueVisitorIds.slice(-40000);
        }
        memAnalytics.uniqueVisitors += 1;
      }

      if (!memAnalytics.todayVisitorIds.includes(visitorId)) {
        memAnalytics.todayVisitorIds.push(visitorId);
        memAnalytics.todayUniqueVisitors += 1;
      }

      memAnalytics.sources[channel] = (memAnalytics.sources[channel] || 0) + 1;
      memAnalytics.devices[device.type] = (memAnalytics.devices[device.type] || 0) + 1;
      memAnalytics.topPages[page] = (memAnalytics.topPages[page] || 0) + 1;

      activeSessions.set(visitorId, Date.now());

      const logEntry: VisitorLogEntry = {
        id: 'imp_' + Date.now() + '_' + Math.random().toString(36).substring(2, 6),
        visitorId,
        sessionId: body.sessionId,
        page,
        referrer,
        channel,
        device,
        country,
        ipHash,
        timestamp: now.toISOString(),
      };

      memAnalytics.recentLogs.unshift(logEntry);
      if (memAnalytics.recentLogs.length > 100) {
        memAnalytics.recentLogs = memAnalytics.recentLogs.slice(0, 100);
      }

      memAnalytics.lastUpdated = now.toISOString();
      scheduleSave();

      const fiveMinAgo = Date.now() - 5 * 60 * 1000;
      let liveActive = 0;
      for (const [id, seen] of activeSessions.entries()) {
        if (seen >= fiveMinAgo) {
          liveActive++;
        } else {
          activeSessions.delete(id);
        }
      }

      return res.json({
        status: true,
        imprintId: logEntry.id,
        metrics: {
          totalPageviews: memAnalytics.totalPageviews,
          uniqueVisitors: memAnalytics.uniqueVisitors,
          todayPageviews: memAnalytics.todayPageviews,
          todayUniqueVisitors: memAnalytics.todayUniqueVisitors,
          liveActive: Math.max(1, liveActive),
        },
      });
    } catch (err: any) {
      console.error('[Telemetry] Error recording imprint:', err.message);
      return res.status(500).json({ status: false, error: err.message });
    }
  },

  getStats: (_req: Request, res: Response) => {
    try {
      const fiveMinAgo = Date.now() - 5 * 60 * 1000;
      let liveActive = 0;
      for (const [id, seen] of activeSessions.entries()) {
        if (seen >= fiveMinAgo) {
          liveActive++;
        } else {
          activeSessions.delete(id);
        }
      }

      return res.json({
        status: true,
        metrics: {
          totalPageviews: memAnalytics.totalPageviews,
          uniqueVisitors: memAnalytics.uniqueVisitors,
          todayPageviews: memAnalytics.todayPageviews,
          todayUniqueVisitors: memAnalytics.todayUniqueVisitors,
          liveActive: Math.max(1, liveActive),
          lastUpdated: memAnalytics.lastUpdated,
        },
        sources: memAnalytics.sources,
        devices: memAnalytics.devices,
        topPages: memAnalytics.topPages,
        recentLogs: memAnalytics.recentLogs.slice(0, 50),
      });
    } catch (err: any) {
      return res.status(500).json({ status: false, error: err.message });
    }
  },

  resetStats: (req: Request, res: Response) => {
    const token = req.headers['x-deploy-token'] || req.query.token;
    if (token !== 'rentilly_auto_deploy_secure_key_2026') {
      return res.status(401).json({ status: false, error: 'Unauthorized' });
    }

    memAnalytics = {
      ...INITIAL_ANALYTICS,
      lastUpdated: new Date().toISOString(),
    };
    activeSessions.clear();
    scheduleSave();

    return res.json({ status: true, message: 'Telemetry metrics reset successfully.' });
  },
};
