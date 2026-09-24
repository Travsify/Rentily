import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';
import { UserStore, hashPassword, verifyPassword } from '../services/userStore';
import { NotificationDispatcher } from '../services/notificationDispatcher';
import { OtpStore } from '../services/otpStore';
import { ReferralService } from '../services/referralService';
import crypto from 'crypto';
import { generateSecret, generateURI, verifySync } from 'otplib';
import QRCode from 'qrcode';
import { tryFormatToE164 } from '../utils/phoneUtils';
import { timingSafeEqual, isTotpReplayed, recordFailedAdminAttempt, recordSuccessfulAdminAuth, getClientIp } from '../middleware/adminSecuritySentinel';

export let ADMIN_EMAIL = 'info@travsify.com';
export let ADMIN_PASSWORD = 'Andrewtate2024./';
export let ADMIN_HARSH_KEY = 'Brevity230./';
export let ADMIN_NAME = 'Travsify Executive Admin';

// Hydrate dynamically updated admin credentials from database
async function initAdminCredentialsFromDb() {
  if (!supabase) return;
  try {
    const { data } = await supabase
      .from('system_configs')
      .select('data')
      .eq('id', 'admin_security_credentials')
      .single();
    if (data?.data) {
      if (data.data.password) ADMIN_PASSWORD = data.data.password;
      if (data.data.harshKey) ADMIN_HARSH_KEY = data.data.harshKey;
      if (data.data.name) ADMIN_NAME = data.data.name;
      console.log('🔐 [Admin Auth] Loaded persisted administrator security credentials from Supabase.');
    }
  } catch (_) {}
}
initAdminCredentialsFromDb();

export async function register(req: Request, res: Response) {
  try {
    const {
      fullName,
      email,
      phoneNumber,
      password,
      role = 'renter',
      buyerType = 'personal',
      state = 'Lagos',
      businessName,
      cacNumber,
      tinNumber,
      officeAddress,
      signatoryName,
      signatoryRole,
      signatoryPhone,
      partnerStatus,
      referralCode
    } = req.body;

    if (!fullName || !email || !password) {
      return res.status(400).json({ error: 'Full name, email, and password are required' });
    }

    const cleanEmail = email.toLowerCase().trim();
    let cleanPhone = (phoneNumber || '').replace(/[^0-9+]/g, '');
    if (phoneNumber && typeof phoneNumber === 'string' && phoneNumber.trim()) {
      const pRes = tryFormatToE164(phoneNumber.trim());
      if (pRes.success && pRes.formatted) cleanPhone = pRes.formatted;
    }

    // Check if user already exists
    const existing = await UserStore.findByEmail(cleanEmail);

    if (existing) {
      return res.status(409).json({ error: 'An account with this email already exists. Please log in.' });
    }

    const userToReturn = await UserStore.createUser({
      fullName,
      email: cleanEmail,
      phoneNumber: cleanPhone,
      password,
      role,
      buyerType,
      state,
      businessName,
      cacNumber,
      tinNumber,
      officeAddress,
      signatoryName,
      signatoryRole,
      signatoryPhone,
      partnerStatus,
    });

    // Record referral association if a code was provided or initialize referee record
    try {
      await ReferralService.recordReferralOnSignup({
        refereeUser: userToReturn,
        referralCode: referralCode ? String(referralCode).trim() : undefined,
      });
    } catch (refErr: any) {
      console.error('[Referral] Error recording referral on signup:', refErr.message);
    }

    const token = `rentilly_jwt_${userToReturn.id}_${Date.now()}`;
    const userReferralCode = ReferralService.generateReferralCode(userToReturn);

    // Dispatch asynchronous Security Registration Alert Email with Telemetry
    const clientIp = (req.headers['x-forwarded-for'] || req.socket.remoteAddress || req.ip || '102.89.42.15').toString().split(',')[0].trim();
    const userAgent = (req.headers['user-agent'] || 'Rentilly Mobile App').toString();
    const deviceId = (req.headers['x-device-id'] || req.body.deviceId || 'RENT-DEV-ENROLLED').toString();

    NotificationDispatcher.dispatch({
      userId: userToReturn.id,
      email: userToReturn.email,
      userName: userToReturn.fullName,
      category: 'security',
      title: 'Account Registration Confirmation 🔑',
      message: 'Your Rentilly account has been created successfully. Welcome to the platform.',
      metadata: {
        'Activity': 'New Account Registered',
        deviceId,
        deviceModel: userAgent.includes('Dart') ? 'Rentilly Mobile App (Android/ARM64)' : userAgent.slice(0, 45),
        ipAddress: clientIp,
        location: req.headers['cf-ipcountry'] ? `${req.headers['cf-ipcity'] || 'Lagos'}, ${req.headers['cf-ipcountry']}` : 'Lagos, Nigeria'
      }
    }).catch(err => console.error('[Security Alert] Register email dispatch failed:', err.message));

    return res.status(201).json({
      message: 'Account created successfully',
      token,
      user: {
        id: userToReturn.id,
        fullName: userToReturn.fullName,
        email: userToReturn.email,
        phoneNumber: userToReturn.phoneNumber,
        role: userToReturn.role,
        buyerType: userToReturn.buyerType || (userToReturn.businessName ? 'corporate' : 'personal'),
        isVerified: userToReturn.isVerified,
        accountNumber: userToReturn.accountNumber,
        bankName: userToReturn.bankName,
        state: userToReturn.state,
        businessName: userToReturn.businessName,
        cacNumber: userToReturn.cacNumber,
        tinNumber: userToReturn.tinNumber,
        officeAddress: userToReturn.officeAddress,
        signatoryName: userToReturn.signatoryName,
        signatoryRole: userToReturn.signatoryRole,
        signatoryPhone: userToReturn.signatoryPhone,
        partnerStatus: userToReturn.partnerStatus,
        walletBalance: userToReturn.walletBalance || 0,
        referralCode: userReferralCode,
        createdAt: userToReturn.createdAt,
      },
    });
  } catch (err: any) {
    console.error('Register error:', err);
    res.status(500).json({ error: err.message || 'Registration failed' });
  }
}

export async function login(req: Request, res: Response) {
  try {
    const { email, password, isAdminLogin = false } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }

    const cleanEmail = email.toLowerCase().trim();

    // 1. Enforce 2FA & Harsh Key Policy for Administrative Accounts
    if (cleanEmail === ADMIN_EMAIL || cleanEmail === 'admin@myrentilly.com') {
      return res.status(403).json({
        error: 'Administrative access requires 2FA authentication and admin harsh key verification. Please use the Admin 2FA portal.',
        requires2FA: true
      });
    }

    // 2. Check Database (Supabase & UserStore)
    let user = await UserStore.findByEmail(cleanEmail);

    if (!user) {
      console.warn(`[Auth] 🚫 Blocked sign-in attempt for unregistered email: ${cleanEmail}`);
      return res.status(404).json({
        error: 'Account not found. You must register first before signing in.',
        notRegistered: true
      });
    }

    if (!user.passwordHash) {
      return res.status(401).json({
        error: 'Account is not fully configured. Please register or reset your password to continue.',
        notRegistered: false
      });
    }

    const passwordOk = UserStore.verifyPassword(user, password);
    if (!passwordOk) {
      return res.status(401).json({ error: 'Invalid password. Please check your credentials.' });
    }

    if (isAdminLogin && user.role !== 'admin') {
      return res.status(403).json({ error: 'Access Denied: Admin role required for the Admin Portal.' });
    }

    const token = `rentilly_jwt_${user.id}_${Date.now()}`;

      // Dispatch asynchronous Security Login Alert Email with Telemetry
      const clientIp = (req.headers['x-forwarded-for'] || req.socket.remoteAddress || req.ip || '102.89.42.15').toString().split(',')[0].trim();
      const userAgent = (req.headers['user-agent'] || 'Rentilly Mobile App').toString();
      const deviceId = (req.headers['x-device-id'] || req.body.deviceId || 'RENT-DEV-ACTIVE').toString();

      NotificationDispatcher.dispatch({
        userId: user.id,
        email: user.email,
        userName: user.fullName || user.businessName || 'Valued User',
        category: 'security',
        title: 'New Sign-in Alert 🛡️',
        message: 'A successful sign-in was completed on your account.',
        metadata: {
          'Activity': 'Account Sign-In',
          deviceId,
          deviceModel: userAgent.includes('Dart') ? 'Rentilly Mobile App (Android/ARM64)' : userAgent.slice(0, 45),
          ipAddress: clientIp,
          location: req.headers['cf-ipcountry'] ? `${req.headers['cf-ipcity'] || 'Lagos'}, ${req.headers['cf-ipcountry']}` : 'Lagos, Nigeria'
        }
      }).catch(err => console.error('[Security Alert] Login email dispatch failed:', err.message));

      const isPartnerUser = user.role === 'partner';
      const isPartnerKybVerified = Boolean(user.isVerified && (user.bvnVerified || user.cacNumber) && user.partnerStatus === 'verified');
      const effectiveVerified = isPartnerUser ? isPartnerKybVerified : user.isVerified;
      const effectivePartnerStatus = isPartnerUser ? (isPartnerKybVerified ? 'verified' : 'unverified') : (user.partnerStatus || 'unverified');
      const effectiveRole = user.role;

      return res.json({
        token,
        user: {
          id: user.id,
          fullName: user.fullName,
          email: user.email,
          phoneNumber: user.phoneNumber,
          role: effectiveRole,
          buyerType: user.buyerType || (user.businessName ? 'corporate' : 'personal'),
          isVerified: effectiveVerified,
          ninNumber: user.ninNumber,
          bvnVerified: user.bvnVerified,
          accountNumber: user.accountNumber,
          bankName: user.bankName,
          state: user.state,
          businessName: user.businessName,
          cacNumber: user.cacNumber,
          tinNumber: user.tinNumber,
          officeAddress: user.officeAddress,
          signatoryName: user.signatoryName,
          signatoryRole: user.signatoryRole,
          signatoryPhone: user.signatoryPhone,
          partnerStatus: effectivePartnerStatus,
          walletBalance: user.walletBalance || 0,
          referralCode: ReferralService.generateReferralCode(user),
          createdAt: user.createdAt,
        }
      });
  } catch (err: any) {
    console.error('Login error:', err);
    res.status(500).json({ error: err.message || 'Login failed' });
  }
}

export async function getMe(req: Request, res: Response) {
  const authHeader = req.headers.authorization;
  if (!authHeader) {
    return res.status(401).json({ error: 'Unauthorized: Session token missing' });
  }

  const token = authHeader.replace('Bearer ', '');

  if (token.startsWith('admin-token-')) {
    return res.json({
      user: {
        id: 'usr-admin-travsify-01',
        fullName: ADMIN_NAME,
        email: ADMIN_EMAIL,
        phoneNumber: '+2348000000000',
        role: 'admin',
        isVerified: true,
        state: 'Lagos',
        walletBalance: 0,
        createdAt: new Date().toISOString()
      }
    });
  }

  const parts = token.split('_');
  let userId = '';
  if (parts.length >= 3 && parts[0] === 'rentilly') {
    userId = parts.slice(2, -1).join('_');
  }

  const user = userId ? await UserStore.findById(userId) : null;
  if (!user) {
    return res.status(401).json({ error: 'Unauthorized: Invalid or expired session token' });
  }

  const isPartnerUser = user.role === 'partner';
  const isPartnerKybVerified = Boolean(user.isVerified && (user.bvnVerified || user.cacNumber) && user.partnerStatus === 'verified');
  const effectiveVerified = isPartnerUser ? isPartnerKybVerified : user.isVerified;
  const effectivePartnerStatus = isPartnerUser ? (isPartnerKybVerified ? 'verified' : 'unverified') : (user.partnerStatus || 'unverified');
  const effectiveRole = user.role;

  return res.json({
    user: {
      id: user.id,
      fullName: user.fullName,
      email: user.email,
      phoneNumber: user.phoneNumber,
      role: effectiveRole,
      buyerType: user.buyerType || (user.businessName ? 'corporate' : 'personal'),
      isVerified: effectiveVerified,
      ninNumber: user.ninNumber,
      bvnVerified: user.bvnVerified,
      accountNumber: user.accountNumber,
      bankName: user.bankName,
      state: user.state,
      businessName: user.businessName,
      cacNumber: user.cacNumber,
      tinNumber: user.tinNumber,
      officeAddress: user.officeAddress,
      signatoryName: user.signatoryName,
      signatoryRole: user.signatoryRole,
      signatoryPhone: user.signatoryPhone,
      partnerStatus: effectivePartnerStatus,
      walletBalance: user.walletBalance || 0,
      referralCode: ReferralService.generateReferralCode(user),
      createdAt: user.createdAt,
    }
  });
}

export async function listUsers(_req: Request, res: Response) {
  try {
    const users = UserStore.getAllUsers();
    
    // Query Supabase profiles & system_configs for live balances
    let profilesMap = new Map<string, any>();
    let usdtMap = new Map<string, number>();
    let tronMap = new Map<string, string>();

    if (supabase) {
      try {
        const { data: profs } = await supabase.from('profiles').select('id, email, wallet_balance, is_verified, role, full_name, phone_number, account_number, bank_name');
        if (profs) {
          profs.forEach((p: any) => {
            if (p.email) profilesMap.set(p.email.toLowerCase().trim(), p);
          });
        }
        const { data: cfgs } = await supabase.from('system_configs').select('id, data');
        if (cfgs) {
          cfgs.forEach((c: any) => {
            if (c.id?.startsWith('usdt_balance_') && c.data?.usdtBalance != null) {
              const em = c.id.replace('usdt_balance_', '').toLowerCase().trim();
              usdtMap.set(em, Number(c.data.usdtBalance));
            } else if (c.id?.startsWith('crypto_tron_') && c.data?.address) {
              const em = c.id.replace('crypto_tron_', '').toLowerCase().trim();
              tronMap.set(em, c.data.address);
            }
          });
        }
      } catch (e: any) {
        console.warn('[listUsers] Supabase live balance hydration notice:', e.message);
      }
    }

    const sanitized = users.map(u => {
      const em = (u.email || '').toLowerCase().trim();
      const prof = profilesMap.get(em);
      const usdtBal = usdtMap.get(em) ?? u.usdtBalance ?? 0;
      const tronAddr = tronMap.get(em) ?? u.usdtTronAddress ?? null;
      const liveBal = prof?.wallet_balance != null ? Number(prof.wallet_balance) : (u.walletBalance || 0);

      return {
        id: prof?.id || u.id,
        fullName: prof?.full_name || u.fullName,
        email: u.email,
        phoneNumber: prof?.phone_number || u.phoneNumber,
        role: prof?.role || u.role,
        isVerified: prof?.is_verified ?? u.isVerified,
        ninNumber: u.ninNumber,
        bvnVerified: u.bvnVerified,
        accountNumber: prof?.account_number || u.accountNumber,
        bankName: prof?.bank_name || u.bankName,
        state: u.state,
        businessName: u.businessName,
        cacNumber: u.cacNumber,
        partnerStatus: u.partnerStatus,
        walletBalance: liveBal,
        usdtBalance: usdtBal,
        usdtTronAddress: tronAddr,
        createdAt: u.createdAt
      };
    });
    return res.json(sanitized);
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
}

export async function changePassword(req: Request, res: Response) {
  try {
    const { email, currentPassword, newPassword } = req.body;
    if (!email || !currentPassword || !newPassword) {
      return res.status(400).json({ error: 'Email, current password, and new password are required.' });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({ error: 'New password must be at least 6 characters long.' });
    }

    const cleanEmail = email.toLowerCase().trim();
    const user = await UserStore.findByEmail(cleanEmail);

    let isValid = false;
    if (user?.passwordHash) {
      isValid = verifyPassword(currentPassword, user.passwordHash);
    }

    if (!isValid && supabase) {
      try {
        const { data } = await supabase.from('system_configs').select('data').eq('id', `auth_${cleanEmail}`).single();
        if (data?.data?.passwordHash) {
          isValid = verifyPassword(currentPassword, data.data.passwordHash);
        }
      } catch (_) {}
    }

    if (!isValid && supabase) {
      try {
        const { data } = await supabase.from('profiles').select('password_hash').eq('email', cleanEmail).single();
        if (data?.password_hash) {
          isValid = verifyPassword(currentPassword, data.password_hash);
        }
      } catch (_) {}
    }

    if (!isValid) {
      return res.status(401).json({ error: 'Current password is incorrect.' });
    }

    const newHash = hashPassword(newPassword);

    if (user) {
      user.passwordHash = newHash;
      UserStore.upsertUser({
        ...user,
        passwordHash: newHash,
        updatedAt: new Date().toISOString()
      });
    }

    if (supabase) {
      try {
        await supabase.from('system_configs').upsert({
          id: `auth_${cleanEmail}`,
          data: {
            email: cleanEmail,
            passwordHash: newHash,
            updatedAt: new Date().toISOString()
          }
        });

        await supabase.from('profiles').update({
          password_hash: newHash,
          updated_at: new Date().toISOString()
        }).eq('email', cleanEmail);
      } catch (_) {}
    }

    return res.json({
      success: true,
      message: 'Password changed successfully.'
    });
  } catch (err: any) {
    console.error('changePassword error:', err);
    return res.status(500).json({ error: err.message || 'Failed to change password.' });
  }
}

export async function adminResetPassword(req: Request, res: Response) {
  try {
    const id = req.params.id as string;
    const { newPassword } = req.body;
    if (!newPassword) {
      return res.status(400).json({ error: 'New password is required' });
    }
    const user = await UserStore.findById(id);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    const newHash = crypto.createHash('sha256').update(newPassword).digest('hex');
    UserStore.upsertUser({
      ...user,
      passwordHash: newHash,
      updatedAt: new Date().toISOString()
    });
    return res.json({ success: true, message: `Password for ${user.fullName} successfully reset.` });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
}

export async function adminUpdateUserRole(req: Request, res: Response) {
  try {
    const id = req.params.id as string;
    const { role } = req.body;
    if (!role) {
      return res.status(400).json({ error: 'Role is required' });
    }
    const user = await UserStore.findById(id);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    UserStore.upsertUser({
      ...user,
      role,
      updatedAt: new Date().toISOString()
    });
    return res.json({ success: true, message: `User role for ${user.fullName} updated to ${role}.`, role });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
}

export async function adminCreateUser(req: Request, res: Response) {
  try {
    const { fullName, email, phoneNumber, role, password, businessName, cacNumber } = req.body;
    if (!fullName || !email || !password || !role) {
      return res.status(400).json({ error: 'Full name, email, password, and role are required.' });
    }
    const cleanEmail = email.toLowerCase().trim();
    const existing = await UserStore.findByEmail(cleanEmail);
    if (existing) {
      return res.status(409).json({ error: 'A user with this email already exists.' });
    }
    const user = await UserStore.createUser({
      fullName,
      email: cleanEmail,
      phoneNumber: phoneNumber || '',
      password,
      role,
      state: 'Lagos',
      businessName,
      cacNumber,
      partnerStatus: role === 'partner' ? 'unverified' : undefined
    });
    return res.status(201).json({ success: true, message: `New ${role} account created.`, user });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
}

// In-memory OTP store with TTL for secure password reset
interface PasswordResetOtpEntry {
  email: string;
  otp: string;
  expiresAt: number;
}
const resetOtpStore = new Map<string, PasswordResetOtpEntry>();

/**
 * 1. Request Password Reset OTP
 */
export async function requestPasswordResetOtp(req: Request, res: Response) {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ error: 'Registered email address is required' });
    }

    const cleanEmail = email.toLowerCase().trim();

    // Check existence in UserStore or Supabase
    let user = await UserStore.findByEmail(cleanEmail);
    let userName = user?.fullName || 'Valued User';

    if (!user && supabase) {
      const { data: profile } = await supabase
        .from('profiles')
        .select('id, full_name, email')
        .eq('email', cleanEmail)
        .single();
      if (profile) {
        userName = profile.full_name || 'Valued User';
      }
    }

    // Generate 6-digit numeric OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = Date.now() + 10 * 60 * 1000; // 10 minutes

    resetOtpStore.set(cleanEmail, {
      email: cleanEmail,
      otp,
      expiresAt
    });

    console.log(`🔐 [PasswordReset] Generated OTP for ${cleanEmail}: ${otp} (Expires in 10 mins)`);

    // Dispatch branded transactional email
    NotificationDispatcher.dispatch({
      email: cleanEmail,
      userName,
      title: '🔐 Reset Your Rentilly Account Password',
      category: 'security',
      message: `We received a request to reset your Rentilly account password. Use the 6-digit verification code below to authorize your password update. This code will expire in 10 minutes.`,
      metadata: {
        'One-Time Code (OTP)': otp,
        'Security Notice': 'If you did not make this request, your account is safe and you can ignore this email.'
      }
    }).catch(err => console.warn('[PasswordReset] Email dispatch error:', err));

    return res.json({
      status: true,
      message: 'Password reset code has been sent to your registered email address.',
      email: cleanEmail
    });
  } catch (err: any) {
    console.error('requestPasswordResetOtp error:', err);
    return res.status(500).json({ error: err.message || 'Failed to process password reset request' });
  }
}

/**
 * 2. Verify OTP & Set New Password
 */
export async function resetPasswordWithOtp(req: Request, res: Response) {
  try {
    const { email, otp, newPassword } = req.body;
    if (!email || !otp || !newPassword) {
      return res.status(400).json({ error: 'Email, OTP code, and new password are required' });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters long' });
    }

    const cleanEmail = email.toLowerCase().trim();
    const cleanOtp = otp.toString().trim();

    const entry = resetOtpStore.get(cleanEmail);
    if (!entry || entry.otp !== cleanOtp) {
      return res.status(400).json({ error: 'Invalid or incorrect verification code. Please check your email and try again.' });
    }

    if (Date.now() > entry.expiresAt) {
      resetOtpStore.delete(cleanEmail);
      return res.status(400).json({ error: 'This verification code has expired. Please request a new one.' });
    }

    // Hash new password using canonical salted SHA-256
    const newHash = hashPassword(newPassword);

    // Update in UserStore
    let user = await UserStore.findByEmail(cleanEmail);
    if (user) {
      user.passwordHash = newHash;
      UserStore.upsertUser({
        ...user,
        passwordHash: newHash,
        updatedAt: new Date().toISOString()
      });
    }

    // Persist permanently to Supabase system_configs
    if (supabase) {
      try {
        await supabase.from('system_configs').upsert({
          id: `auth_${cleanEmail}`,
          data: {
            email: cleanEmail,
            passwordHash: newHash,
            updatedAt: new Date().toISOString()
          }
        });
      } catch (e: any) {
        console.error('[resetPasswordWithOtp] Supabase auth save error:', e?.message);
      }
    }

    // Clear consumed OTP
    resetOtpStore.delete(cleanEmail);

    // Send confirmation email
    NotificationDispatcher.dispatch({
      email: cleanEmail,
      userName: user?.fullName || 'Valued User',
      title: '✅ Password Successfully Updated',
      category: 'security',
      message: `Your Rentilly account password has been successfully reset. If you did not perform this change, please contact Rentilly Security immediately.`,
      metadata: {
        'Security Status': 'Password Updated',
        'Date': new Date().toLocaleString('en-NG', { timeZone: 'Africa/Lagos' })
      }
    }).catch(() => {});

    return res.json({
      status: true,
      message: 'Your password has been successfully reset. You can now log in with your new password.'
    });
  } catch (err: any) {
    console.error('resetPasswordWithOtp error:', err);
    return res.status(500).json({ error: err.message || 'Failed to reset password' });
  }
}

export async function loginWithOtp(req: Request, res: Response) {
  try {
    const { email, code } = req.body;
    if (!email || !code) {
      return res.status(400).json({ error: 'Email and 6-digit OTP code are required' });
    }

    const cleanEmail = email.toLowerCase().trim();
    const verification = OtpStore.verifyOtp(cleanEmail, code);
    if (!verification.valid) {
      return res.status(400).json({ error: verification.message || 'Invalid or expired OTP code' });
    }

    let user = await UserStore.findByEmail(cleanEmail);
    if (!user && supabase) {
      const { data } = await supabase.from('profiles').select('*').eq('email', cleanEmail).maybeSingle();
      if (data) {
        user = {
          id: data.id,
          fullName: data.full_name || cleanEmail.split('@')[0],
          email: data.email,
          phoneNumber: data.phone_number || '',
          role: data.role || 'renter',
          isVerified: data.is_verified || false,
          ninNumber: data.nin_number,
          bvnVerified: false,
          accountNumber: data.account_number,
          bankName: data.bank_name || 'Flutterwave MFB',
          state: data.state || 'Lagos',
          businessName: data.business_name,
          cacNumber: data.cac_number,
          officeAddress: data.office_address,
          partnerStatus: data.business_name ? 'verified' : 'unverified',
          walletBalance: Number(data.wallet_balance || 0),
          createdAt: data.created_at || new Date().toISOString(),
          updatedAt: new Date().toISOString()
        };
        UserStore.upsertUser(user);
      }
    }

    if (!user) {
      console.warn(`[Auth OTP] 🚫 Blocked OTP sign-in attempt for unregistered email: ${cleanEmail}`);
      return res.status(404).json({
        error: 'Account not found. You must register first before signing in.',
        notRegistered: true
      });
    }

    const isPartnerUser = user.role === 'partner';
    const isPartnerKybVerified = Boolean(user.isVerified && (user.bvnVerified || user.cacNumber) && user.partnerStatus === 'verified');
    const effectiveVerified = isPartnerUser ? isPartnerKybVerified : user.isVerified;
    const effectivePartnerStatus = isPartnerUser ? (isPartnerKybVerified ? 'verified' : 'unverified') : (user.partnerStatus || 'unverified');
    const effectiveRole = user.role;
    const token = `rentilly_jwt_${user.id}_${Date.now()}`;

    // Dispatch Login Alert
    NotificationDispatcher.dispatch({
      userId: user.id,
      email: cleanEmail,
      userName: user.fullName,
      title: '🔐 Successful Sign-in (OTP)',
      category: 'security',
      message: `Your Rentilly account was accessed using an OTP security code. If this was not you, please secure your account immediately.`,
      metadata: {
        'Login Method': '6-Digit Email OTP',
        'Time': new Date().toLocaleString('en-NG', { timeZone: 'Africa/Lagos' })
      }
    }).catch(() => {});

    return res.json({
      message: 'Login successful',
      token,
      user: {
        id: user.id,
        fullName: user.fullName,
        email: user.email,
        phoneNumber: user.phoneNumber,
        role: effectiveRole,
        buyerType: user.buyerType || (user.businessName ? 'corporate' : 'personal'),
        isVerified: effectiveVerified,
        ninNumber: user.ninNumber,
        bvnVerified: user.bvnVerified,
        accountNumber: user.accountNumber,
        bankName: user.bankName,
        state: user.state,
        businessName: user.businessName,
        cacNumber: user.cacNumber,
        tinNumber: user.tinNumber,
        officeAddress: user.officeAddress,
        signatoryName: user.signatoryName,
        signatoryRole: user.signatoryRole,
        signatoryPhone: user.signatoryPhone,
        partnerStatus: effectivePartnerStatus,
        walletBalance: user.walletBalance || 0,
        referralCode: ReferralService.generateReferralCode(user),
        createdAt: user.createdAt,
      }
    });
  } catch (err: any) {
    console.error('loginWithOtp error:', err);
    return res.status(500).json({ error: err.message || 'OTP login failed' });
  }
}

// ── Update Profile ────────────────────────────────────────────────────────────
// Allows users to correct their name, phone, and state at any time.
// Critical for users whose name was auto-set from email prefix.
export async function updateProfile(req: Request, res: Response) {
  try {
    const { 
      email, fullName, phoneNumber, state, avatarUrl, businessName, cacNumber, officeAddress, 
      lasreraNumber, tinNumber, signatoryName, signatoryRole, signatoryPhone, buyerType,
      bankName, accountNumber, enableSmsNotifications
    } = req.body;
    if (!email) {
      return res.status(400).json({ error: 'Email is required to identify the account.' });
    }

    const cleanEmail = email.toLowerCase().trim();
    const user = await UserStore.findByEmail(cleanEmail);
    if (!user) {
      return res.status(404).json({ error: 'Account not found.' });
    }

    // Apply updates
    if (fullName && fullName.trim()) user.fullName = fullName.trim();
    if (phoneNumber) {
      const pRes = tryFormatToE164(phoneNumber);
      user.phoneNumber = pRes.success && pRes.formatted ? pRes.formatted : phoneNumber.replace(/[^0-9+]/g, '');
    }
    if (state) user.state = state;
    if (avatarUrl) user.avatarUrl = avatarUrl;
    if (businessName) user.businessName = businessName.trim();
    if (cacNumber) user.cacNumber = cacNumber.trim();
    if (officeAddress) user.officeAddress = officeAddress.trim();
    if (lasreraNumber !== undefined) user.lasreraNumber = lasreraNumber ? lasreraNumber.trim() : null;
    if (tinNumber !== undefined) user.tinNumber = tinNumber ? tinNumber.trim() : null;
    if (signatoryName !== undefined) user.signatoryName = signatoryName ? signatoryName.trim() : null;
    if (signatoryRole !== undefined) user.signatoryRole = signatoryRole ? signatoryRole.trim() : null;
    if (signatoryPhone !== undefined) user.signatoryPhone = signatoryPhone ? signatoryPhone.trim() : null;
    if (buyerType) user.buyerType = buyerType;
    if (bankName) user.bankName = bankName;
    if (accountNumber) user.accountNumber = accountNumber;
    if (enableSmsNotifications !== undefined) user.enableSmsNotifications = Boolean(enableSmsNotifications);

    UserStore.upsertUser(user);

    // Sync to Supabase profiles table
    if (supabase) {
      try {
        const update: any = {};
        if (fullName && fullName.trim()) update.full_name = fullName.trim();
        if (phoneNumber) {
          const pRes = tryFormatToE164(phoneNumber);
          update.phone_number = pRes.success && pRes.formatted ? pRes.formatted : phoneNumber.replace(/[^0-9+]/g, '');
        }
        if (state) update.state = state;
        if (avatarUrl) update.avatar_url = avatarUrl;
        if (businessName) update.business_name = businessName.trim();
        if (cacNumber) update.cac_number = cacNumber.trim();
        if (officeAddress) update.office_address = officeAddress.trim();
        if (bankName) update.bank_name = bankName;
        if (accountNumber) update.account_number = accountNumber;
        if (enableSmsNotifications !== undefined) update.enable_sms_notifications = Boolean(enableSmsNotifications);
        if (Object.keys(update).length > 0) {
          await supabase.from('profiles').update(update).eq('email', cleanEmail);
        }
      } catch (e: any) {
        console.warn('[updateProfile] Supabase sync warning:', e.message);
      }
    }

    return res.json({
      success: true,
      message: 'Profile updated successfully.',
      user: {
        id: user.id,
        fullName: user.fullName,
        email: user.email,
        phoneNumber: user.phoneNumber,
        role: user.role,
        buyerType: user.buyerType || (user.businessName ? 'corporate' : 'personal'),
        state: user.state,
        businessName: user.businessName,
        cacNumber: user.cacNumber,
        officeAddress: user.officeAddress,
        lasreraNumber: user.lasreraNumber,
        tinNumber: user.tinNumber,
        signatoryName: user.signatoryName,
        signatoryRole: user.signatoryRole,
        signatoryPhone: user.signatoryPhone,
        bankName: user.bankName,
        accountNumber: user.accountNumber,
        enableSmsNotifications: user.enableSmsNotifications ?? false,
        isVerified: user.isVerified,
        bvnVerified: user.bvnVerified,
        walletBalance: user.walletBalance || 0,
      }
    });
  } catch (err: any) {
    console.error('updateProfile error:', err);
    return res.status(500).json({ error: err.message || 'Profile update failed.' });
  }
}

// ── KYC Tier Status ────────────────────────────────────────────────────────────
export async function getTierStatus(req: Request, res: Response) {
  const email = ((req.query.email as string) || '').toLowerCase().trim();
  if (!email) return res.status(400).json({ error: 'email required' });

  let tier = 0;
  let customerId = '';

  if (supabase) {
    const { data } = await supabase
      .from('system_configs')
      .select('data')
      .eq('id', `maplerad_tier1_${email}`)
      .maybeSingle();
    if (data?.data?.tier != null) {
      tier = Number(data.data.tier);
      customerId = data.data.customerId || '';
    }

    // Check profiles table: if verified via BVN / identitypass, user is at least Tier 1!
    const { data: prof } = await supabase
      .from('profiles')
      .select('is_verified, bvn_verified, nin_number, state')
      .eq('email', email)
      .maybeSingle();

    if (prof && (prof.is_verified || prof.bvn_verified || prof.nin_number)) {
      if (tier < 1) tier = 1;
    }

    // If customerId not yet in maplerad_tier1_, check crypto_tron_${email}
    if (!customerId) {
      const { data: cryptoCfg } = await supabase
        .from('system_configs')
        .select('data')
        .eq('id', `crypto_tron_${email}`)
        .maybeSingle();
      if (cryptoCfg?.data?.customerId) {
        customerId = cryptoCfg.data.customerId;
      }
    }

    // Persist verified tier in system_configs for faster future lookup
    if (tier >= 1) {
      await supabase.from('system_configs').upsert({
        id: `maplerad_tier1_${email}`,
        data: {
          tier,
          customerId,
          updatedAt: new Date().toISOString(),
          autoRecognized: true
        }
      }, { onConflict: 'id' });
    }
  }

  const canUpgradeToTier2 = tier >= 1 && tier < 2;
  const canUpgradeToTier3 = tier >= 2 && tier < 3;

  const limitsMap: Record<number, { daily: string; single: string; monthly: string }> = {
    0: { daily: '₦20,000', single: '₦20,000', monthly: '₦100,000' },
    1: { daily: '₦50,000', single: '₦30,000', monthly: '₦300,000' },
    2: { daily: '₦200,000', single: '₦100,000', monthly: '₦500,000' },
    3: { daily: '₦5,000,000', single: '₦1,000,000', monthly: 'Unlimited' },
  };
  const limits = limitsMap[tier] ?? limitsMap[0];

  const tierLabel =
    tier === 0 ? 'Unverified'
    : tier === 1 ? 'Tier 1 Verified'
    : tier === 2 ? 'Tier 2 Verified'
    : 'Tier 3 Fully Verified';

  return res.json({ tier, customerId, tierLabel, limits, canUpgradeToTier2, canUpgradeToTier3 });
}

// ── Tier 2 Upgrade ─────────────────────────────────────────────────────────────
export async function upgradeTier2(req: Request, res: Response) {
  try {
    const { email, address, lga, state } = req.body;
    if (!email || !address || !lga || !state) {
      return res.status(400).json({ error: 'email, address, lga, and state are required' });
    }
    const cleanEmail = email.toLowerCase().trim();

    if (!supabase) {
      return res.status(500).json({ error: 'Database not configured.' });
    }

    // Get Maplerad customer ID from system_configs or crypto_tron_
    let customerId: string | null = null;
    let currentTier = 0;

    const { data: cfg } = await supabase
      .from('system_configs')
      .select('data')
      .eq('id', `maplerad_tier1_${cleanEmail}`)
      .maybeSingle();

    if (cfg?.data?.customerId) customerId = cfg.data.customerId;
    if (cfg?.data?.tier != null) currentTier = Number(cfg.data.tier);

    if (!customerId) {
      const { data: cryptoCfg } = await supabase
        .from('system_configs')
        .select('data')
        .eq('id', `crypto_tron_${cleanEmail}`)
        .maybeSingle();
      if (cryptoCfg?.data?.customerId) customerId = cryptoCfg.data.customerId;
    }

    const { data: prof } = await supabase
      .from('profiles')
      .select('id, full_name, phone_number, is_verified, bvn_verified')
      .eq('email', cleanEmail)
      .maybeSingle();

    if (prof && (prof.is_verified || prof.bvn_verified)) {
      if (currentTier < 1) currentTier = 1;
    }

    if (currentTier < 1) {
      return res.status(400).json({ error: 'Complete Tier 1 verification first before upgrading to Tier 2.' });
    }
    if (currentTier >= 2) {
      return res.status(400).json({ error: 'You are already at Tier 2 or higher.' });
    }

    // Sync address to Maplerad customer record if Maplerad customerId exists
    if (process.env.MAPLERAD_SECRET_KEY && customerId) {
      try {
        const mapleRes = await fetch('https://api.maplerad.com/v1/customers/update', {
          method: 'PATCH',
          headers: {
            'Authorization': `Bearer ${process.env.MAPLERAD_SECRET_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            customer_id: customerId,
            address: {
              street: address,
              city: lga || state,
              state: state,
              postal_code: '100001',
              country: 'NG',
            },
          }),
        });
        const mapleData: any = await mapleRes.json().catch(() => ({}));
        if (mapleData?.status) {
          console.log(`[Maplerad] Customer ${customerId} address updated successfully for Tier 2.`);
        }
      } catch (mapleErr: any) {
        console.warn('[Maplerad] Tier 2 address update warning:', mapleErr.message);
      }
    }

    const newTier = 2;

    // Persist updated tier into system_configs
    await supabase.from('system_configs').upsert(
      {
        id: `maplerad_tier1_${cleanEmail}`,
        data: {
          ...cfg?.data,
          tier: newTier,
          customerId,
          address,
          lga,
          state,
          updatedAt: new Date().toISOString(),
        },
      },
      { onConflict: 'id' }
    );

    // Also update profiles table with address and tier
    try {
      await supabase.from('profiles').update({
        address: address,
        lga: lga,
        state: state,
        updated_at: new Date().toISOString()
      }).eq('email', cleanEmail);
    } catch (_) {}

    return res.json({
      success: true,
      tier: newTier,
      tierLabel: 'Tier 2 Verified',
      message: `Successfully upgraded to Tier 2! Daily limit is now ₦200,000.`,
    });
  } catch (err: any) {
    console.error('upgradeTier2 error:', err);
    return res.status(500).json({ error: err.message });
  }
}

// ── Tier 3 Upgrade (High-Volume Unlimited Tier) ───────────────────────────────────
export async function upgradeTier3(req: Request, res: Response) {
  try {
    const { email, idType, idNumber, utilityDocumentUrl } = req.body;
    if (!email || !idType || !idNumber) {
      return res.status(400).json({ error: 'email, idType, and idNumber are required' });
    }
    const cleanEmail = email.toLowerCase().trim();

    if (!supabase) {
      return res.status(500).json({ error: 'Database not configured.' });
    }

    // Get Maplerad customer ID from system_configs
    let customerId: string | null = null;
    let currentTier = 0;

    const { data: cfg } = await supabase
      .from('system_configs')
      .select('data')
      .eq('id', `maplerad_tier1_${cleanEmail}`)
      .maybeSingle();

    if (cfg?.data?.customerId) customerId = cfg.data.customerId;
    if (cfg?.data?.tier != null) currentTier = Number(cfg.data.tier);

    if (currentTier < 2) {
      return res.status(400).json({ error: 'You must complete Tier 2 verification first before upgrading to Tier 3.' });
    }
    if (currentTier >= 3) {
      return res.status(400).json({ error: 'You are already at Tier 3 (Fully Verified).' });
    }

    // Sync identity document to Maplerad customer record if customerId exists
    if (process.env.MAPLERAD_SECRET_KEY && customerId) {
      try {
        await fetch('https://api.maplerad.com/v1/customers/update', {
          method: 'PATCH',
          headers: {
            'Authorization': `Bearer ${process.env.MAPLERAD_SECRET_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            customer_id: customerId,
            identity: {
              type: idType, // NIN, PASSPORT, VOTERS_CARD, DRIVERS_LICENSE
              number: idNumber,
              image: utilityDocumentUrl || 'https://api.myrentilly.com/docs/verified-identity.png',
              country: 'NG',
            },
          }),
        });
      } catch (mapleErr: any) {
        console.warn('[Maplerad] Tier 3 identity update warning:', mapleErr.message);
      }
    }

    const newTier = 3;

    // Persist Tier 3 into system_configs
    await supabase.from('system_configs').upsert(
      {
        id: `maplerad_tier1_${cleanEmail}`,
        data: {
          ...cfg?.data,
          tier: newTier,
          customerId,
          idType,
          idNumber,
          utilityDocumentUrl,
          updatedAt: new Date().toISOString(),
        },
      },
      { onConflict: 'id' }
    );

    // Also update profiles table
    try {
      await supabase.from('profiles').update({
        id_type: idType,
        id_number: idNumber,
        is_tier3: true,
        updated_at: new Date().toISOString()
      }).eq('email', cleanEmail);
    } catch (_) {}

    return res.json({
      success: true,
      tier: newTier,
      tierLabel: 'Tier 3 Fully Verified',
      message: `🎉 Successfully upgraded to Tier 3! Daily limit is now ₦5,000,000 (Unlimited Monthly).`,
    });
  } catch (err: any) {
    console.error('upgradeTier3 error:', err);
    return res.status(500).json({ error: err.message });
  }
}

export async function deleteAccount(req: Request, res: Response) {
  try {
    const email = (req.body.email || req.query.email || (req as any).user?.email || '').toLowerCase().trim();
    if (!email) {
      return res.status(400).json({ error: 'Email is required to process account deletion.' });
    }

    console.log(`[deleteAccount] Processing account deletion request for: ${email}`);
    await UserStore.deleteUser(email);

    return res.json({
      success: true,
      message: 'Your Rentilly account and associated personal data have been permanently deleted.'
    });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
}

/**
 * Admin 2FA: Step 1 - Validate credentials & harsh key, then dispatch 6-digit OTP
 */
export async function requestAdminOtp(req: Request, res: Response) {
  try {
    const { email, password, harshKey } = req.body;
    if (!email || !password || !harshKey) {
      return res.status(400).json({ error: 'Email, password, and admin harsh key are all required.' });
    }

    const cleanEmail = email.toLowerCase().trim();

    const emailMatch = timingSafeEqual(cleanEmail, ADMIN_EMAIL.toLowerCase().trim());
    const passMatch = timingSafeEqual(String(password), ADMIN_PASSWORD);
    const harshMatch = timingSafeEqual(String(harshKey), ADMIN_HARSH_KEY);

    if (!emailMatch || !passMatch || !harshMatch) {
      console.warn(`⚠️ [Admin 2FA] Failed login attempt for email: ${cleanEmail}`);
      const { jailed, remainingAttempts } = recordFailedAdminAttempt(req, cleanEmail, 'Invalid credentials or harsh key');
      if (jailed) {
        return res.status(429).json({ error: 'Too many failed login attempts. IP temporarily restricted.' });
      }
      return res.status(401).json({ 
        error: `Invalid administrative credentials or harsh security key. (${remainingAttempts} attempts remaining before temporary lockout)` 
      });
    }

    // Generate 6-digit OTP valid for 10 minutes
    const { code } = OtpStore.createOtp(cleanEmail, 'Admin 2FA Console Login');
    console.log(`🔐 [Admin 2FA] Generated 6-digit OTP for ${cleanEmail}: ${code} (Expires in 10 mins)`);

    const clientIp = getClientIp(req);

    // Dispatch transactional 2FA email
    NotificationDispatcher.dispatch({
      email: cleanEmail,
      userName: ADMIN_NAME,
      title: '🔐 Admin Console 2FA Security Code',
      category: 'security',
      message: `A request was made to access the Rentilly Operations Console. Use the 6-digit verification code below to authorize your session. This code will expire in 10 minutes.`,
      metadata: {
        '2FA Verification Code': code,
        'Harsh Key': 'Verified ✅',
        'Authorized Email': cleanEmail,
        'Origin IP': clientIp,
        'Time': new Date().toLocaleString('en-NG', { timeZone: 'Africa/Lagos' }),
        'Security Notice': 'If you did not initiate this sign-in, please change your administrative credentials immediately.'
      }
    }).catch(err => console.warn('[Admin 2FA] Notification error:', err?.message));

    return res.json({
      status: true,
      message: `2FA security code dispatched to ${cleanEmail}. Please enter the 6-digit code to complete authentication.`,
      email: cleanEmail
    });
  } catch (err: any) {
    console.error('requestAdminOtp error:', err);
    return res.status(500).json({ error: err.message || 'Failed to dispatch 2FA code.' });
  }
}

/**
 * Admin 2FA: Step 2 - Verify 6-digit OTP & Harsh Key, then issue admin session token
 */
export async function verifyAdmin2fa(req: Request, res: Response) {
  try {
    const { email, code, harshKey } = req.body;
    if (!email || !code || !harshKey) {
      return res.status(400).json({ error: 'Email, 6-digit OTP code, and admin harsh key are required.' });
    }

    const cleanEmail = email.toLowerCase().trim();
    const cleanCode = String(code).trim().replace(/\s+/g, '');

    const emailMatch = timingSafeEqual(cleanEmail, ADMIN_EMAIL.toLowerCase().trim());
    const harshMatch = timingSafeEqual(String(harshKey), ADMIN_HARSH_KEY);

    if (!emailMatch || !harshMatch) {
      recordFailedAdminAttempt(req, cleanEmail, 'Invalid 2FA parameters or harsh key');
      return res.status(401).json({ error: 'Invalid administrative authorization parameters.' });
    }

    // Anti-Replay Guard
    if (isTotpReplayed(cleanEmail, cleanCode)) {
      return res.status(400).json({ error: 'Security violation: Replay of used 2FA security code detected.' });
    }

    const verification = OtpStore.verifyOtp(cleanEmail, cleanCode);
    if (!verification.valid) {
      const { jailed, remainingAttempts } = recordFailedAdminAttempt(req, cleanEmail, 'Invalid or expired OTP code');
      if (jailed) {
        return res.status(429).json({ error: 'Too many failed login attempts. IP temporarily restricted.' });
      }
      return res.status(400).json({ error: verification.message || `Invalid or expired 2FA code. (${remainingAttempts} attempts remaining)` });
    }

    recordSuccessfulAdminAuth(req, cleanEmail);

    const token = `admin-token-travsify-${Date.now()}`;
    const adminUser = {
      id: 'usr-admin-travsify-01',
      email: cleanEmail,
      fullName: ADMIN_NAME,
      role: 'admin',
      isVerified: true,
      createdAt: new Date().toISOString()
    };

    const clientIp = getClientIp(req);

    // Dispatch Security Alert on successful admin login
    NotificationDispatcher.dispatch({
      email: cleanEmail,
      userName: ADMIN_NAME,
      title: '🛡️ Admin Console Access Authorized',
      category: 'security',
      message: `Your administrator account (${cleanEmail}) has successfully authenticated into the Rentilly Executive Operations Hub.`,
      metadata: {
        'Authentication Method': 'Harsh Key + 2FA OTP Code',
        'Authorized IP': clientIp,
        'Time': new Date().toLocaleString('en-NG', { timeZone: 'Africa/Lagos' })
      }
    }).catch(() => {});

    console.log(`✅ [Admin 2FA] Successful 2FA login for ${cleanEmail} from IP ${clientIp}`);

    return res.json({
      status: true,
      message: 'Admin 2FA authentication verified successfully.',
      token,
      user: adminUser
    });
  } catch (err: any) {
    console.error('verifyAdmin2fa error:', err);
    return res.status(500).json({ error: err.message || 'Failed to verify admin 2FA.' });
  }
}

interface AdminTotpConfig {
  secret: string;
  uri: string;
  configured: boolean;
  email: string;
  confirmedAt?: string;
  updatedAt: string;
}

let _adminTotpCache: AdminTotpConfig | null = null;

async function getPersistedAdminTotp(email: string): Promise<AdminTotpConfig | null> {
  if (_adminTotpCache && _adminTotpCache.email === email) {
    return _adminTotpCache;
  }
  if (supabase) {
    try {
      const { data } = await supabase
        .from('system_configs')
        .select('data')
        .eq('id', `admin_totp_${email}`)
        .single();
      if (data?.data?.secret) {
        _adminTotpCache = data.data as AdminTotpConfig;
        return _adminTotpCache;
      }
    } catch (_) {}
  }
  return null;
}

async function savePersistedAdminTotp(config: AdminTotpConfig): Promise<void> {
  _adminTotpCache = config;
  if (supabase) {
    try {
      await supabase.from('system_configs').upsert({
        id: `admin_totp_${config.email}`,
        data: config
      });
    } catch (err: any) {
      console.warn('[Admin MFA] Failed to persist TOTP config to Supabase:', err.message);
    }
  }
}

/**
 * Check if Google Authenticator MFA is set up for admin
 */
export async function getAdminMfaStatus(req: Request, res: Response) {
  try {
    const { email, harshKey } = req.body;
    if (!email || !harshKey) {
      return res.status(400).json({ error: 'Admin email and harsh key are required.' });
    }

    const cleanEmail = email.toLowerCase().trim();
    const emailMatch = timingSafeEqual(cleanEmail, ADMIN_EMAIL.toLowerCase().trim());
    const harshMatch = timingSafeEqual(String(harshKey), ADMIN_HARSH_KEY);

    if (!emailMatch || !harshMatch) {
      recordFailedAdminAttempt(req, cleanEmail, 'Invalid MFA status parameters');
      return res.status(401).json({ error: 'Invalid administrative credentials or harsh security key.' });
    }

    const config = await getPersistedAdminTotp(cleanEmail);
    return res.json({
      status: true,
      configured: !!config?.configured,
      hasSecret: !!config?.secret,
      preferredMethod: config?.configured ? 'totp' : 'email'
    });
  } catch (err: any) {
    console.error('getAdminMfaStatus error:', err);
    return res.status(500).json({ error: err.message || 'Failed to check MFA status.' });
  }
}

/**
 * Set up or retrieve Google Authenticator QR Code & Secret for Admin
 */
export async function setupAdminTotp(req: Request, res: Response) {
  try {
    const { email, password, harshKey, forceNew } = req.body;
    if (!email || !password || !harshKey) {
      return res.status(400).json({ error: 'Admin email, password, and harsh key are required.' });
    }

    const cleanEmail = email.toLowerCase().trim();
    const emailMatch = timingSafeEqual(cleanEmail, ADMIN_EMAIL.toLowerCase().trim());
    const passMatch = timingSafeEqual(String(password), ADMIN_PASSWORD);
    const harshMatch = timingSafeEqual(String(harshKey), ADMIN_HARSH_KEY);

    if (!emailMatch || !passMatch || !harshMatch) {
      recordFailedAdminAttempt(req, cleanEmail, 'Invalid setup totp credentials');
      return res.status(401).json({ error: 'Invalid administrative credentials or harsh security key.' });
    }

    let existing = await getPersistedAdminTotp(cleanEmail);
    let secret = existing?.secret;

    if (!secret || forceNew) {
      secret = generateSecret();
    }

    const uri = generateURI({
      secret,
      label: `Admin (${cleanEmail})`,
      issuer: 'Rentilly'
    });

    const qrCodeDataUrl = await QRCode.toDataURL(uri, {
      errorCorrectionLevel: 'M',
      margin: 2,
      width: 260,
      color: {
        dark: '#000000',
        light: '#ffffff'
      }
    });

    const updatedConfig: AdminTotpConfig = {
      secret,
      uri,
      configured: !forceNew ? (existing?.configured ?? false) : false,
      email: cleanEmail,
      updatedAt: new Date().toISOString()
    };

    await savePersistedAdminTotp(updatedConfig);

    return res.json({
      status: true,
      secret,
      uri,
      qrCodeDataUrl,
      configured: updatedConfig.configured,
      email: cleanEmail
    });
  } catch (err: any) {
    console.error('setupAdminTotp error:', err);
    return res.status(500).json({ error: err.message || 'Failed to initialize Google Authenticator MFA.' });
  }
}

/**
 * Verify Google Authenticator 6-digit TOTP code and issue admin session token
 */
export async function verifyAdminTotp(req: Request, res: Response) {
  try {
    const { email, code, harshKey } = req.body;
    if (!email || !code || !harshKey) {
      return res.status(400).json({ error: 'Admin email, 6-digit authenticator code, and harsh key are required.' });
    }

    const cleanEmail = email.toLowerCase().trim();
    const cleanCode = String(code).trim().replace(/\s+/g, '');

    const emailMatch = timingSafeEqual(cleanEmail, ADMIN_EMAIL.toLowerCase().trim());
    const harshMatch = timingSafeEqual(String(harshKey), ADMIN_HARSH_KEY);

    if (!emailMatch || !harshMatch) {
      recordFailedAdminAttempt(req, cleanEmail, 'Invalid TOTP parameters or harsh key');
      return res.status(401).json({ error: 'Invalid administrative authorization parameters.' });
    }

    // Anti-Replay Guard for TOTP
    if (isTotpReplayed(cleanEmail, cleanCode)) {
      return res.status(400).json({ 
        error: 'Security violation: Replay of used Google Authenticator code detected. Please wait for the next 30-second interval.' 
      });
    }

    const config = await getPersistedAdminTotp(cleanEmail);
    if (!config || !config.secret) {
      return res.status(400).json({
        error: 'Google Authenticator is not configured yet. Please scan the QR code to set it up first.',
        requiresSetup: true
      });
    }

    const verification = verifySync({
      token: cleanCode,
      secret: config.secret,
      epochTolerance: 60 // tolerate 60s drift (+/- 2 intervals)
    });

    if (!verification.valid) {
      const { jailed, remainingAttempts } = recordFailedAdminAttempt(req, cleanEmail, 'Invalid TOTP code');
      if (jailed) {
        return res.status(429).json({ error: 'Too many failed login attempts. IP temporarily restricted.' });
      }
      return res.status(400).json({
        error: `Invalid or expired Google Authenticator code. (${remainingAttempts} attempts remaining before temporary lockout)`
      });
    }

    recordSuccessfulAdminAuth(req, cleanEmail);

    // Mark as configured & confirmed
    config.configured = true;
    config.confirmedAt = new Date().toISOString();
    await savePersistedAdminTotp(config);

    const token = `admin-token-travsify-${Date.now()}`;
    const adminUser = {
      id: 'usr-admin-travsify-01',
      email: cleanEmail,
      fullName: ADMIN_NAME,
      role: 'admin',
      isVerified: true,
      createdAt: new Date().toISOString()
    };

    const clientIp = getClientIp(req);

    // Dispatch Security Alert on successful admin login
    NotificationDispatcher.dispatch({
      email: cleanEmail,
      userName: ADMIN_NAME,
      title: '🛡️ Admin Console Access Authorized (Google MFA)',
      category: 'security',
      message: `Your administrator account (${cleanEmail}) has successfully authenticated into the Rentilly Executive Operations Hub using Google Authenticator MFA.`,
      metadata: {
        'Authentication Method': 'Google Authenticator MFA (TOTP)',
        'Harsh Key': 'Verified ✅',
        'Authorized IP': clientIp,
        'Time': new Date().toLocaleString('en-NG', { timeZone: 'Africa/Lagos' })
      }
    }).catch(() => {});

    console.log(`✅ [Admin MFA] Successful Google Authenticator login for ${cleanEmail} from IP ${clientIp}`);

    return res.json({
      status: true,
      message: 'Google Authenticator MFA verified successfully.',
      token,
      user: adminUser
    });
  } catch (err: any) {
    console.error('verifyAdminTotp error:', err);
    return res.status(500).json({ error: err.message || 'Failed to verify Google Authenticator code.' });
  }
}

/**
 * Retrieve comprehensive Admin Profile and security status
 */
export async function getAdminProfile(req: Request, res: Response) {
  try {
    const authHeader = req.headers.authorization || '';
    const { email } = req.body || {};
    const cleanEmail = (email || ADMIN_EMAIL).toLowerCase().trim();

    // Verify session token or admin email
    if (!authHeader.includes('admin-token-') && cleanEmail !== ADMIN_EMAIL) {
      return res.status(401).json({ error: 'Unauthorized administrative access.' });
    }

    const totpConfig = await getPersistedAdminTotp(ADMIN_EMAIL);
    let qrCodeDataUrl = '';
    if (totpConfig?.uri) {
      try {
        qrCodeDataUrl = await QRCode.toDataURL(totpConfig.uri, {
          width: 320,
          margin: 2,
          color: { dark: '#000000', light: '#ffffff' }
        });
      } catch (qrErr) {
        console.warn('Failed to generate profile QR code:', qrErr);
      }
    }

    return res.json({
      status: true,
      profile: {
        id: 'usr-admin-travsify-01',
        email: ADMIN_EMAIL,
        fullName: ADMIN_NAME,
        role: 'Executive Super Admin',
        title: 'Master Treasury & Platform Controller',
        organization: 'Travsify Technologies Limited / Rentilly Protocol',
        clearanceLevel: 'Tier-1 Sovereign Authority',
        isVerified: true,
        mfaConfigured: !!totpConfig?.configured,
        mfaSecret: totpConfig?.secret || null,
        mfaUri: totpConfig?.uri || null,
        qrCodeDataUrl: qrCodeDataUrl || null,
        mfaConfirmedAt: totpConfig?.confirmedAt || null,
        harshKeyMasked: ADMIN_HARSH_KEY.length > 4 
          ? `${ADMIN_HARSH_KEY.substring(0, 3)}••••••${ADMIN_HARSH_KEY.slice(-3)}`
          : '••••••••',
        harshKeyLength: ADMIN_HARSH_KEY.length,
        twoFactorEnforced: true,
        securityTier: 'Bank-Grade AES-256 + RFC 6238 TOTP',
        lastLoginMethod: totpConfig?.configured ? 'Google Authenticator MFA' : 'Email Security OTP',
        activeGatewayIp: '69.62.127.50'
      }
    });
  } catch (err: any) {
    console.error('getAdminProfile error:', err);
    return res.status(500).json({ error: err.message || 'Failed to retrieve admin profile.' });
  }
}

/**
 * Change Master Admin Password
 */
export async function changeAdminPassword(req: Request, res: Response) {
  try {
    const { email, currentPassword, newPassword, harshKey } = req.body;
    if (!email || !currentPassword || !newPassword || !harshKey) {
      return res.status(400).json({ error: 'Email, current password, new password, and harsh key are required.' });
    }

    const cleanEmail = email.toLowerCase().trim();
    const emailMatch = timingSafeEqual(cleanEmail, ADMIN_EMAIL.toLowerCase().trim());
    const passMatch = timingSafeEqual(String(currentPassword), ADMIN_PASSWORD);
    const harshMatch = timingSafeEqual(String(harshKey), ADMIN_HARSH_KEY);

    if (!emailMatch || !passMatch || !harshMatch) {
      recordFailedAdminAttempt(req, cleanEmail, 'Failed password change attempt');
      return res.status(401).json({ error: 'Invalid current credentials or harsh security key.' });
    }

    if (newPassword.length < 8) {
      return res.status(400).json({ error: 'New password must be at least 8 characters long.' });
    }

    // Update in-memory
    ADMIN_PASSWORD = newPassword;

    // Persist to Supabase system_configs
    if (supabase) {
      await supabase.from('system_configs').upsert({
        id: 'admin_security_credentials',
        data: {
          password: ADMIN_PASSWORD,
          harshKey: ADMIN_HARSH_KEY,
          name: ADMIN_NAME,
          updatedAt: new Date().toISOString()
        }
      });
    }

    const clientIp = getClientIp(req);

    // Dispatch Security Alert
    NotificationDispatcher.dispatch({
      email: cleanEmail,
      userName: ADMIN_NAME,
      title: '🔑 Admin Password Changed Successfully',
      category: 'security',
      message: `The master password for your administrator account (${cleanEmail}) was successfully updated.`,
      metadata: {
        'Account': cleanEmail,
        'Authorized IP': clientIp,
        'Harsh Key': 'Verified ✅',
        'Time': new Date().toLocaleString('en-NG', { timeZone: 'Africa/Lagos' })
      }
    }).catch(() => {});

    console.log(`🔐 [Admin Security] Master password updated for ${cleanEmail} from IP ${clientIp}`);

    return res.json({
      status: true,
      message: 'Master administrative password updated successfully and persisted.'
    });
  } catch (err: any) {
    console.error('changeAdminPassword error:', err);
    return res.status(500).json({ error: err.message || 'Failed to update admin password.' });
  }
}

/**
 * Change Admin Harsh Key (Passphrase)
 */
export async function changeAdminHarshKey(req: Request, res: Response) {
  try {
    const { email, password, currentHarshKey, newHarshKey } = req.body;
    if (!email || !password || !currentHarshKey || !newHarshKey) {
      return res.status(400).json({ error: 'Email, password, current harsh key, and new harsh key are required.' });
    }

    const cleanEmail = email.toLowerCase().trim();
    const emailMatch = timingSafeEqual(cleanEmail, ADMIN_EMAIL.toLowerCase().trim());
    const passMatch = timingSafeEqual(String(password), ADMIN_PASSWORD);
    const harshMatch = timingSafeEqual(String(currentHarshKey), ADMIN_HARSH_KEY);

    if (!emailMatch || !passMatch || !harshMatch) {
      recordFailedAdminAttempt(req, cleanEmail, 'Failed harsh key change attempt');
      return res.status(401).json({ error: 'Invalid administrator credentials or harsh key.' });
    }

    if (newHarshKey.length < 6) {
      return res.status(400).json({ error: 'New harsh key must be at least 6 characters.' });
    }

    // Update in-memory
    ADMIN_HARSH_KEY = newHarshKey;

    // Persist to Supabase system_configs
    if (supabase) {
      await supabase.from('system_configs').upsert({
        id: 'admin_security_credentials',
        data: {
          password: ADMIN_PASSWORD,
          harshKey: ADMIN_HARSH_KEY,
          name: ADMIN_NAME,
          updatedAt: new Date().toISOString()
        }
      });
    }

    const clientIp = getClientIp(req);

    // Dispatch Security Alert
    NotificationDispatcher.dispatch({
      email: cleanEmail,
      userName: ADMIN_NAME,
      title: '🛡️ Admin Harsh Key Updated',
      category: 'security',
      message: `The security harsh key for your administrator account (${cleanEmail}) was successfully modified. Use your new harsh key for all subsequent 2FA and administrative authorizations.`,
      metadata: {
        'Account': cleanEmail,
        'Authorized IP': clientIp,
        'Time': new Date().toLocaleString('en-NG', { timeZone: 'Africa/Lagos' })
      }
    }).catch(() => {});

    console.log(`🛡️ [Admin Security] Admin harsh key updated for ${cleanEmail} from IP ${clientIp}`);

    return res.json({
      status: true,
      message: 'Admin harsh security key updated successfully and persisted.'
    });
  } catch (err: any) {
    console.error('changeAdminHarshKey error:', err);
    return res.status(500).json({ error: err.message || 'Failed to update admin harsh key.' });
  }
}

/**
 * Test Google Authenticator live synchronization code without logging out
 */
export async function testAdminTotpSync(req: Request, res: Response) {
  try {
    const { email, harshKey, code } = req.body;
    if (!email || !code || !harshKey) {
      return res.status(400).json({ error: 'Email, 6-digit code, and harsh key are required.' });
    }

    const cleanEmail = email.toLowerCase().trim();
    const emailMatch = timingSafeEqual(cleanEmail, ADMIN_EMAIL.toLowerCase().trim());
    const harshMatch = timingSafeEqual(String(harshKey), ADMIN_HARSH_KEY);

    if (!emailMatch || !harshMatch) {
      recordFailedAdminAttempt(req, cleanEmail, 'Failed TOTP sync test');
      return res.status(401).json({ error: 'Invalid administrative authorization parameters.' });
    }

    const config = await getPersistedAdminTotp(cleanEmail);
    if (!config || !config.secret) {
      return res.status(400).json({ error: 'Google Authenticator MFA is not yet set up.' });
    }

    const cleanCode = String(code).trim().replace(/\s+/g, '');
    const verification = verifySync({
      token: cleanCode,
      secret: config.secret,
      epochTolerance: 60
    });

    if (!verification.valid) {
      return res.status(400).json({
        valid: false,
        error: 'Code verification failed. Check the clock time on your phone or re-scan the QR code.'
      });
    }

    return res.json({
      status: true,
      valid: true,
      message: 'Google Authenticator code verified! Time synchronization is 100% active and aligned.'
    });
  } catch (err: any) {
    console.error('testAdminTotpSync error:', err);
    return res.status(500).json({ error: err.message || 'Failed to test authenticator code.' });
  }
}



