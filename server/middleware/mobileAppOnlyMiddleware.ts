import type { Request, Response, NextFunction } from 'express';
import { BotSentinelService } from '../services/botSentinelService';

/**
 * Detects whether a request originates from the Rentilly Mobile App (Android/iOS).
 * Supports modern builds (with X-Client-Platform/X-App-Source headers)
 * as well as legacy builds (Flutter/Dart User-Agent, absence of web browser signatures, valid app payload).
 */
export function isMobileAppRequest(req: Request): boolean {
  const clientPlatform = (req.headers['x-client-platform'] || '').toString().toLowerCase().trim();
  const appSource = (req.headers['x-app-source'] || '').toString().toLowerCase().trim();
  const origin = (req.headers['origin'] || req.headers['referer'] || '').toString().toLowerCase().trim();
  const secFetchMode = (req.headers['sec-fetch-mode'] || '').toString().toLowerCase().trim();
  const userAgent = (req.headers['user-agent'] || '').toString().toLowerCase().trim();

  // 1. Explicit modern mobile client headers
  if (
    clientPlatform === 'mobile_app' ||
    clientPlatform === 'mobile' ||
    clientPlatform === 'ios' ||
    clientPlatform === 'android' ||
    appSource === 'rentilly_mobile' ||
    appSource === 'mobile_app'
  ) {
    return true;
  }

  // 2. Mobile User-Agent signatures from Flutter / Dart / Native Mobile runtimes
  if (
    userAgent.includes('dart') ||
    userAgent.includes('flutter') ||
    userAgent.includes('okhttp') ||
    userAgent.includes('cfnetwork') ||
    userAgent.includes('dalvik')
  ) {
    return true;
  }

  // 3. Web browsers ALWAYS send sec-fetch-mode or browser origins (e.g. Mozilla/Chrome without Dart)
  const isWebBrowser = Boolean(
    secFetchMode ||
    clientPlatform === 'web' ||
    (origin && !origin.includes('localhost') && !userAgent.includes('dart')) ||
    (userAgent.includes('mozilla') && !userAgent.includes('dart') && !userAgent.includes('mobile'))
  );

  if (!isWebBrowser && (req.body?.userId || req.body?.email || req.query?.userId || req.query?.email)) {
    return true;
  }

  return false;
}

/**
 * Middleware: Strictly disables web withdrawals and enforces mobile app execution only.
 * Any web browser or scraping tool attempting to initiate withdrawals is blocked with HTTP 403
 * and reported to the Bot Sentinel.
 */
export async function requireMobileAppOnly(req: Request, res: Response, next: NextFunction): Promise<any> {
  const isMobile = isMobileAppRequest(req);
  const secFetchMode = (req.headers['sec-fetch-mode'] || '').toString().toLowerCase().trim();
  const clientPlatform = (req.headers['x-client-platform'] || '').toString().toLowerCase().trim();
  const appSource = (req.headers['x-app-source'] || '').toString().toLowerCase().trim();
  const userAgent = (req.headers['user-agent'] || '').toString().toLowerCase().trim();
  const origin = (req.headers['origin'] || req.headers['referer'] || '').toString().toLowerCase().trim();

  if (!isMobile || secFetchMode || clientPlatform === 'web') {
    const callerEmail = req.body?.email || (req as any).user?.email || req.query?.email;
    const ip = (req.headers['x-forwarded-for'] as string) || req.socket.remoteAddress || req.ip;

    console.warn(`🛑 [WebWithdrawalBlocked] Blocked web withdrawal attempt from IP: ${ip} | User: ${callerEmail || 'Anonymous'} | UA: ${userAgent}`);

    // If caller provided an account/email or is authenticated, flag and ban for suspicious automated bot attempt
    if (callerEmail) {
      BotSentinelService.flagAndBanAccount({
        email: callerEmail,
        ipAddress: ip,
        userAgent: req.headers['user-agent'] as string,
        reason: 'Attempted unauthorized web withdrawal. Web withdrawals are strictly disabled.',
        trigger: 'web_withdrawal_attempt',
        metadata: {
          clientPlatform,
          appSource,
          origin,
          secFetchMode
        }
      }).catch(() => {});
    }

    return res.status(403).json({
      status: false,
      error: 'Web withdrawals are strictly disabled. All withdrawals must be performed directly from the official Rentilly Mobile App (available on Android & iOS).',
      appDownloadUrl: 'https://myrentilly.com/download'
    });
  }

  return next();
}
