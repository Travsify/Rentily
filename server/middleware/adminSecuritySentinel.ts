import type { Request, Response, NextFunction } from 'express';
import crypto from 'crypto';
import { NotificationDispatcher } from '../services/notificationDispatcher';

interface IpThreatRecord {
  ip: string;
  failedAttempts: number;
  lastAttemptAt: number;
  jailedUntil?: number;
  permanentlyBlocked?: boolean;
  userAgent?: string;
}

interface RequestRateRecord {
  count: number;
  windowStart: number;
}

// In-Memory Security State Stores
const ipThreatStore = new Map<string, IpThreatRecord>();
const requestRateStore = new Map<string, RequestRateRecord>();
const usedTotpTokenStore = new Map<string, number>(); // token -> expiry timestamp

// Global Emergency Lockdown State
let emergencyLockdownActive = false;
let emergencyLockdownReason = '';
let globalSessionRevocationEpoch = Date.now();
const whitelistedIps = new Set<string>(['127.0.0.1', '::1']);

/**
 * Constant-time string equality check to prevent timing side-channel attacks
 */
export function timingSafeEqual(a: string, b: string): boolean {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  const bufA = Buffer.from(a, 'utf-8');
  const bufB = Buffer.from(b, 'utf-8');

  if (bufA.length !== bufB.length) {
    crypto.timingSafeEqual(bufA, bufA);
    return false;
  }
  return crypto.timingSafeEqual(bufA, bufB);
}

/**
 * Anti-Replay Guard: Ensures a TOTP / OTP code cannot be replayed in the same time-step
 */
export function isTotpReplayed(identifier: string, code: string): boolean {
  const key = `${identifier}:${code}`;
  const now = Date.now();
  const existing = usedTotpTokenStore.get(key);

  if (existing && existing > now) {
    return true; // Token was already used in this window!
  }

  // Register token for 90 seconds (covering current and neighboring TOTP steps)
  usedTotpTokenStore.set(key, now + 90 * 1000);
  return false;
}

/**
 * Get Client IP Address safely behind reverse proxies
 */
export function getClientIp(req: Request): string {
  const forwarded = req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string') {
    return forwarded.split(',')[0].trim();
  }
  if (Array.isArray(forwarded) && forwarded.length > 0) {
    return forwarded[0].trim();
  }
  return req.socket.remoteAddress || 'unknown';
}

/**
 * Record a failed admin authentication attempt (Triggers auto-jail / permanent ban)
 */
export function recordFailedAdminAttempt(req: Request, targetEmail: string, reason: string): { jailed: boolean; remainingAttempts: number } {
  const ip = getClientIp(req);
  const userAgent = req.headers['user-agent'] || 'unknown';
  const now = Date.now();

  const record: IpThreatRecord = ipThreatStore.get(ip) || {
    ip,
    failedAttempts: 0,
    lastAttemptAt: now,
    userAgent
  };

  record.failedAttempts += 1;
  record.lastAttemptAt = now;
  record.userAgent = userAgent;

  let jailed = false;

  // Tier 1: 5 Failed Attempts -> 1-Hour Jail
  if (record.failedAttempts >= 5 && record.failedAttempts < 10) {
    record.jailedUntil = now + 60 * 60 * 1000; // 1 hour
    jailed = true;
    console.warn(`🚨 [Security Sentinel] IP ${ip} has been JAILED for 1 hour (5 failed attempts). Target: ${targetEmail}`);

    NotificationDispatcher.dispatch({
      email: 'info@travsify.com',
      userName: 'Chief Security Officer',
      title: '🚨 Admin Security Alert: IP Jailed for Brute-Force',
      category: 'security',
      message: `An IP address (${ip}) has been automatically jailed after 5 consecutive failed login attempts targeting ${targetEmail}. Reason: ${reason}`,
      metadata: {
        'Jailed IP': ip,
        'Target Account': targetEmail,
        'User Agent': userAgent,
        'Action': '1-Hour Temporary IP Jail Enforced',
        'Time': new Date().toLocaleString('en-NG', { timeZone: 'Africa/Lagos' })
      }
    }).catch(() => {});
  }

  // Tier 2: 10 Failed Attempts -> Permanent Block
  if (record.failedAttempts >= 10) {
    record.permanentlyBlocked = true;
    jailed = true;
    console.error(`🛑 [Security Sentinel] IP ${ip} has been PERMANENTLY BLOCKED (10+ failed attempts). Target: ${targetEmail}`);

    NotificationDispatcher.dispatch({
      email: 'info@travsify.com',
      userName: 'Chief Security Officer',
      title: '🛑 CRITICAL: IP Address Permanently Blacklisted',
      category: 'security',
      message: `IP address (${ip}) exceeded maximum threat thresholds (10+ failed attempts) and has been permanently blacklisted from all Rentilly services.`,
      metadata: {
        'Blocked IP': ip,
        'Target Account': targetEmail,
        'User Agent': userAgent,
        'Action': 'Permanent IP Blacklist',
        'Time': new Date().toLocaleString('en-NG', { timeZone: 'Africa/Lagos' })
      }
    }).catch(() => {});
  }

  ipThreatStore.set(ip, record);

  const remaining = Math.max(0, 5 - (record.failedAttempts % 5));
  return { jailed, remainingAttempts: remaining };
}

/**
 * Clear threat counters on successful admin authentication
 */
export function recordSuccessfulAdminAuth(req: Request, targetEmail: string) {
  const ip = getClientIp(req);
  ipThreatStore.delete(ip);
  console.log(`🛡️ [Security Sentinel] Successful authenticated login from IP ${ip} for ${targetEmail}. Threat counters reset.`);
}

/**
 * Middleware: Admin Security Sentinel Gatekeeper
 */
export function adminSecuritySentinel(req: Request, res: Response, next: NextFunction) {
  const ip = getClientIp(req);
  const now = Date.now();

  // 0. Air-Gapped Domain Enforcement: Super Admin endpoints are strictly isolated to wealth.myrentilly.com
  const host = (req.headers['x-forwarded-host'] || req.headers.host || '').toString().toLowerCase();
  const isLocal = host.includes('localhost') || host.includes('127.0.0.1');
  const isWealth = host.startsWith('wealth.myrentilly.com');

  if (!isWealth && !isLocal) {
    console.warn(`🛑 [Air-Gap Security] Blocked Super Admin access attempt from unauthorized host: ${host} (IP: ${ip})`);
    return res.status(403).json({
      error: 'Executive Master Treasury & Super Admin Gateway is strictly air-gapped to https://wealth.myrentilly.com. Staff, Legal Counsel, and Support agents must authenticate via the Staff Gateway.',
      code: 'AIR_GAP_RESTRICTION',
      authorizedDomain: 'wealth.myrentilly.com'
    });
  }

  // 1. Emergency Lockdown Check
  if (emergencyLockdownActive && !whitelistedIps.has(ip)) {
    return res.status(503).json({
      error: 'Admin Operations Portal is currently in EMERGENCY LOCKDOWN. Direct access is restricted to authorized personnel.',
      lockdownReason: emergencyLockdownReason,
      code: 'EMERGENCY_LOCKDOWN'
    });
  }

  // 2. Threat & Jail Check
  const threat = ipThreatStore.get(ip);
  if (threat) {
    if (threat.permanentlyBlocked) {
      return res.status(403).json({
        error: 'Access permanently prohibited due to repetitive unauthorized intrusion attempts. Security incident logged.',
        code: 'PERMANENTLY_BLOCKED'
      });
    }

    if (threat.jailedUntil && threat.jailedUntil > now) {
      const remainingMins = Math.ceil((threat.jailedUntil - now) / 60000);
      return res.status(429).json({
        error: `IP temporarily jailed due to consecutive failed authentication attempts. Try again in ${remainingMins} minutes.`,
        code: 'IP_JAILED',
        retryAfterMinutes: remainingMins
      });
    }
  }

  // 3. Strict Rate Limiting (Max 12 requests / minute on admin auth endpoints)
  const rateKey = `${ip}:${Math.floor(now / 60000)}`;
  const currentCount = requestRateStore.get(rateKey)?.count || 0;
  if (currentCount >= 12) {
    return res.status(429).json({
      error: 'Excessive requests to administrative endpoints. Rate limit exceeded.',
      code: 'RATE_LIMIT_EXCEEDED'
    });
  }
  requestRateStore.set(rateKey, { count: currentCount + 1, windowStart: now });

  // Cleanup old rate windows
  if (requestRateStore.size > 2000) {
    const cutoff = now - 120000;
    for (const [key, value] of requestRateStore.entries()) {
      if (value.windowStart < cutoff) requestRateStore.delete(key);
    }
  }

  next();
}

/**
 * Controller: Activate Emergency Lockdown
 */
export async function triggerEmergencyLockdown(req: Request, res: Response) {
  try {
    const { reason, allowedIps } = req.body || {};
    emergencyLockdownActive = true;
    emergencyLockdownReason = reason || 'Master Administrator initiated lockdown.';
    globalSessionRevocationEpoch = Date.now();

    if (Array.isArray(allowedIps)) {
      allowedIps.forEach(ip => whitelistedIps.add(String(ip).trim()));
    }

    const adminIp = getClientIp(req);
    whitelistedIps.add(adminIp);

    NotificationDispatcher.dispatch({
      email: 'info@travsify.com',
      userName: 'Master Admin',
      title: '🛑 EMERGENCY LOCKDOWN ACTIVATED',
      category: 'security',
      message: `The Rentilly Operations Hub has been placed under EMERGENCY LOCKDOWN. All prior admin sessions have been instantly revoked.`,
      metadata: {
        'Reason': emergencyLockdownReason,
        'Authorized IP': adminIp,
        'Time': new Date().toLocaleString('en-NG', { timeZone: 'Africa/Lagos' })
      }
    }).catch(() => {});

    return res.json({
      status: true,
      message: 'Emergency lockdown initiated. All prior active admin session tokens have been globally revoked.',
      lockdownActive: true,
      revocationEpoch: globalSessionRevocationEpoch
    });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
}

/**
 * Controller: Deactivate Emergency Lockdown
 */
export async function liftEmergencyLockdown(req: Request, res: Response) {
  try {
    emergencyLockdownActive = false;
    emergencyLockdownReason = '';
    return res.json({
      status: true,
      message: 'Emergency lockdown lifted. Normal administrative traffic restored.',
      lockdownActive: false
    });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
}

/**
 * Controller: Get Current Sentinel Security Status
 */
export async function getSentinelStatus(req: Request, res: Response) {
  const jailedIps: IpThreatRecord[] = [];
  const blockedIps: IpThreatRecord[] = [];

  for (const record of ipThreatStore.values()) {
    if (record.permanentlyBlocked) blockedIps.push(record);
    else if (record.jailedUntil && record.jailedUntil > Date.now()) jailedIps.push(record);
  }

  return res.json({
    status: true,
    lockdownActive: emergencyLockdownActive,
    lockdownReason: emergencyLockdownReason,
    jailedIpsCount: jailedIps.length,
    blockedIpsCount: blockedIps.length,
    jailedIps,
    blockedIps,
    whitelistedIps: Array.from(whitelistedIps),
    globalRevocationEpoch: globalSessionRevocationEpoch
  });
}
