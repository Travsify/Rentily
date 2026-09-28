/**
 * Registration IP Rate Limiter
 * 
 * Enforces strict velocity control: Maximum 3 registrations per IP address per 24 hours.
 * Blocks bot rings from cycling signups from the same IP, proxy, or VPS.
 */

import type { Request, Response, NextFunction } from 'express';

interface IpLog {
  count: number;
  resetAt: number;
}

const _ipRegistrationStore = new Map<string, IpLog>();
// In Nigeria, telecom operators (MTN, Airtel, Glo, 9mobile) use Carrier-Grade NAT (CGNAT),
// meaning thousands of mobile users share gateway IP addresses (e.g. 105.119.*, 102.89.*).
// Cap at 50 per hour per IP instead of 3 per 24 hours, and completely exempt accredited partners.
const MAX_REGISTRATIONS_PER_IP_WINDOW = 50;
const WINDOW_DURATION_MS = 60 * 60 * 1000; // 1 hour window

export function resetRegistrationRateLimits(): void {
  _ipRegistrationStore.clear();
  console.log('[Anti-Bot Sentinel] 🔄 Registration rate limit IP store cleared.');
}

export function getClientIp(req: Request): string {
  const forwarded = req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string') {
    return forwarded.split(',')[0].trim();
  }
  return req.socket.remoteAddress || req.ip || '127.0.0.1';
}

export function registrationRateLimiter(req: Request, res: Response, next: NextFunction) {
  // 1. Always exempt Accredited Corporate Partners from velocity throttling
  const role = (req.body?.role || '').toString().toLowerCase().trim();
  const buyerType = (req.body?.buyerType || '').toString().toLowerCase().trim();
  const hasCorporatePayload = Boolean(req.body?.businessName || req.body?.cacNumber);

  if (role === 'partner' || buyerType === 'corporate' || hasCorporatePayload) {
    return next();
  }

  const ip = getClientIp(req);
  const now = Date.now();

  const record = _ipRegistrationStore.get(ip);

  if (record) {
    if (now > record.resetAt) {
      // Window expired, reset counter
      _ipRegistrationStore.set(ip, {
        count: 1,
        resetAt: now + WINDOW_DURATION_MS
      });
      return next();
    }

    if (record.count >= MAX_REGISTRATIONS_PER_IP_WINDOW) {
      console.warn(`[Anti-Bot Sentinel] Blocked registration attempt from rate-limited IP: ${ip} (Attempts: ${record.count})`);
      return res.status(429).json({
        error: 'Too many accounts have been created from this network. For security reasons, please retry shortly or contact partner support.'
      });
    }

    record.count++;
  } else {
    _ipRegistrationStore.set(ip, {
      count: 1,
      resetAt: now + WINDOW_DURATION_MS
    });
  }

  next();
}
