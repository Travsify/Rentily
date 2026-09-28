import type { Request, Response, NextFunction } from 'express';
import { UserStore } from '../services/userStore';
import { verifyAdminSessionToken, ADMIN_EMAIL } from '../controllers/authController';
import { supabase } from '../supabaseClient';
import { BotSentinelService } from '../services/botSentinelService';
import { isMobileAppRequest } from './mobileAppOnlyMiddleware';

export interface AuthenticatedUser {
  id: string;
  email: string;
  fullName: string;
  role: string;
  isVerified: boolean;
  walletBalance: number;
  isBanned?: boolean;
  isSuspended?: boolean;
  status?: string;
  redFlagged?: boolean;
}

/**
 * Middleware ensuring a valid user or admin session token is present
 */
export async function requireUserAuth(req: Request, res: Response, next: NextFunction): Promise<any> {
  try {
    const authHeader = req.headers.authorization;
    let token = authHeader ? authHeader.replace(/^Bearer\s+/i, '').trim() : '';
    if (!token) {
      token = ((req.headers['x-auth-token'] as string) || req.body?.token || req.query?.token || '').toString().trim();
    }

    let user: any = null;

    if (!token) {
      const isMobile = isMobileAppRequest(req);
      const email = (req.body?.email || req.query?.email || '').toString().toLowerCase().trim();
      const uid = (req.body?.userId || req.query?.userId || '').toString().trim();

      if (isMobile && (email || uid)) {
        let mobileUser = email ? await UserStore.findByEmail(email) : await UserStore.findById(uid);
        if (!mobileUser && supabase) {
          const { data: prof } = await supabase.from('profiles').select('*').or(`email.eq.${email},id.eq.${uid}`).maybeSingle();
          if (prof) {
            mobileUser = {
              id: prof.id,
              email: prof.email,
              fullName: prof.full_name,
              role: prof.role || 'renter',
              isVerified: prof.is_verified || false,
              walletBalance: Number(prof.wallet_balance || 0),
              isBanned: prof.is_banned,
              isSuspended: prof.is_suspended,
              status: prof.status,
              redFlagged: prof.red_flagged,
            } as any;
          }
        }
        if (mobileUser) {
          user = mobileUser;
        }
      }
      if (!user) {
        return res.status(401).json({ error: 'Unauthorized: Session authorization token required.' });
      }
    }

    if (token) {
      // 1. Check if it is an admin token
      const adminSession = verifyAdminSessionToken(token);
      if (adminSession.valid) {
        (req as any).user = {
          id: 'admin_root',
          email: adminSession.email || ADMIN_EMAIL,
          fullName: 'Rentilly Executive Admin',
          role: 'admin',
          isVerified: true,
          walletBalance: 999999999,
        };
        return next();
      }

      // 2. Parse rentilly_jwt_<userId>_<timestamp>
      const parts = token.split('_');
      let userId = '';
      if (parts.length >= 3 && parts[0] === 'rentilly' && parts[1] === 'jwt') {
        userId = parts.slice(2, -1).join('_');
        const timestamp = parseInt(parts[parts.length - 1], 10);
        // Enforce 30-day token expiration
        if (isNaN(timestamp) || Date.now() - timestamp > 30 * 24 * 60 * 60 * 1000) {
          return res.status(401).json({ error: 'Unauthorized: Session token has expired. Please log in again.' });
        }
      }

      if (!userId) {
        // Fallback: check if raw token is a valid Supabase UUID id
        if (/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(token)) {
          userId = token;
        } else {
          return res.status(401).json({ error: 'Unauthorized: Invalid authentication token signature.' });
        }
      }

      user = await UserStore.findById(userId);
      if (!user && supabase) {
        const { data: prof } = await supabase.from('profiles').select('*').eq('id', userId).maybeSingle();
        if (prof) {
          user = {
            id: prof.id,
            email: prof.email,
            fullName: prof.full_name,
            role: prof.role || 'renter',
            isVerified: prof.is_verified || false,
            walletBalance: Number(prof.wallet_balance || 0),
            isBanned: prof.is_banned,
            isSuspended: prof.is_suspended,
            status: prof.status,
            redFlagged: prof.red_flagged,
          } as any;
        }
      }
    }

    if (!user) {
      return res.status(401).json({ error: 'Unauthorized: User account not found or access revoked.' });
    }

    // 3. Security Sentinel: Enforce Banned & Suspended Account Lockdown
    const clientIp = ((req.headers['x-forwarded-for'] as string) || req.socket.remoteAddress || req.ip || '').split(',')[0].trim();
    const deviceId = (req.headers['x-device-id'] || '').toString().trim();

    if (
      user.isBanned ||
      user.isSuspended ||
      user.status === 'banned' ||
      user.redFlagged ||
      BotSentinelService.isEntityBanned(user.email, clientIp, deviceId)
    ) {
      console.warn(`🛑 [AuthBlocked] Blocked request from banned/suspended account: ${user.email} (IP: ${clientIp})`);
      return res.status(403).json({
        status: false,
        error: 'Your account has been suspended and permanently banned due to suspicious activity and security violations. Please contact support@myrentilly.com.',
        banned: true
      });
    }

    (req as any).user = user;
    return next();
  } catch (err: any) {
    return res.status(500).json({ error: `Authentication error: ${err.message}` });
  }
}
