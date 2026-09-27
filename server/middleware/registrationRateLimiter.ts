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
const MAX_REGISTRATIONS_PER_IP_WINDOW = 3;
const WINDOW_DURATION_MS = 24 * 60 * 60 * 1000; // 24 hours

export function getClientIp(req: Request): string {
  const forwarded = req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string') {
    return forwarded.split(',')[0].trim();
  }
  return req.socket.remoteAddress || req.ip || '127.0.0.1';
}

export function registrationRateLimiter(req: Request, res: Response, next: NextFunction) {
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
        error: 'Too many accounts have been created from this network. For security reasons, please retry after 24 hours or contact support.'
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
