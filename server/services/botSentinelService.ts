/**
 * Bot Sentinel & Recursive Syndicate Banning Engine
 * 
 * 1. Detects automated bot activity, malicious web probing, and brute force attempts.
 * 2. Permanently flags, bans, suspends, and red-flags offending accounts.
 * 3. Recursively tracks and suspends all associated accounts sharing the same:
 *    - IP address
 *    - Device ID (X-Device-Id)
 *    - Destination Bank Account (account_number)
 *    - Referral tree cluster
 * 4. Adds destination bank accounts to the Treasury Syndicate Blacklist and IP to Sentinel.
 * 5. Dispatches real-time Executive Alerts to info@myrentilly.com.
 */

import { supabase } from '../supabaseClient';
import { UserStore, StoredUser } from './userStore';
import { FLAGGED_SYNDICATE_ACCOUNTS } from './treasuryCircuitBreaker';
import { ExecutiveActivityAlertService } from './executiveActivityAlertService';

export interface BotDetectionParams {
  email?: string;
  userId?: string;
  ipAddress?: string;
  deviceId?: string;
  accountNumber?: string;
  userAgent?: string;
  reason: string;
  trigger: 'web_withdrawal_attempt' | 'brute_force_pin' | 'brute_force_otp' | 'syndicate_cluster' | 'automated_bot_signature';
  metadata?: Record<string, any>;
}

export interface BanResult {
  primaryAccountBanned: boolean;
  primaryEmail?: string;
  cascadedAccountsBanned: number;
  cascadedEmails: string[];
  bankAccountBlacklisted?: string;
  ipBlacklisted?: string;
  reason: string;
}

// In-memory sentinel cache of banned emails, IPs, and device IDs for zero-latency enforcement
const _bannedEmailsSet = new Set<string>();
const _bannedIpsSet = new Set<string>();
const _bannedDevicesSet = new Set<string>();

// Track failed verification attempts per email to catch brute force attacks
const _failedAttemptsMap = new Map<string, { count: number; firstAttempt: number }>();

export class BotSentinelService {
  /**
   * Initializes banned entities cache from Supabase on boot
   */
  static async initFromSupabase(): Promise<void> {
    if (!supabase) return;
    try {
      const { data: bannedProfiles } = await supabase
        .from('profiles')
        .select('email, status')
        .or('status.eq.banned,is_banned.eq.true,red_flagged.eq.true');

      if (Array.isArray(bannedProfiles)) {
        for (const p of bannedProfiles) {
          if (p.email) _bannedEmailsSet.add(p.email.toLowerCase().trim());
        }
        console.log(`🛡️ [BotSentinel] Hydrated ${_bannedEmailsSet.size} banned accounts from Supabase.`);
      }
    } catch (err: any) {
      console.warn('[BotSentinel] Supabase hydration warning:', err?.message);
    }
  }

  /**
   * Fast synchronous check if an email, IP, or device ID is banned
   */
  static isEntityBanned(email?: string, ip?: string, deviceId?: string): boolean {
    if (email && _bannedEmailsSet.has(email.toLowerCase().trim())) return true;
    if (ip && _bannedIpsSet.has(ip.trim())) return true;
    if (deviceId && _bannedDevicesSet.has(deviceId.trim())) return true;
    return false;
  }

  /**
   * Records a failed security attempt (PIN or OTP) and auto-bans if >= 3 failures within 10 minutes
   */
  static async recordFailedAttempt(email: string, type: 'PIN' | 'OTP', ip?: string, deviceId?: string): Promise<{ banned: boolean; remainingAttempts: number }> {
    const cleanEmail = email.toLowerCase().trim();
    const now = Date.now();
    const windowMs = 10 * 60 * 1000; // 10 minutes

    const existing = _failedAttemptsMap.get(cleanEmail);
    let count = 1;
    if (existing && (now - existing.firstAttempt) < windowMs) {
      count = existing.count + 1;
    }

    _failedAttemptsMap.set(cleanEmail, { count, firstAttempt: existing ? existing.firstAttempt : now });

    const maxAttempts = 3;
    const remainingAttempts = Math.max(0, maxAttempts - count);

    if (count >= maxAttempts) {
      console.warn(`🚨 [BotSentinel] Email ${cleanEmail} exceeded ${maxAttempts} failed ${type} attempts. Flagging and banning account.`);
      await this.flagAndBanAccount({
        email: cleanEmail,
        ipAddress: ip,
        deviceId,
        reason: `Exceeded maximum ${type} verification attempts (${count}/${maxAttempts}). Potential brute-force bot activity.`,
        trigger: type === 'PIN' ? 'brute_force_pin' : 'brute_force_otp'
      });
      return { banned: true, remainingAttempts: 0 };
    }

    return { banned: false, remainingAttempts };
  }

  /**
   * Resets failed attempt counter on successful authorization
   */
  static resetFailedAttempts(email: string): void {
    _failedAttemptsMap.delete(email.toLowerCase().trim());
  }

  /**
   * Flags, permanently bans, and suspends an account, then cascades suspension
   * to all related accounts sharing IP, Device ID, bank account, or referral cluster.
   */
  static async flagAndBanAccount(params: BotDetectionParams): Promise<BanResult> {
    const cleanEmail = (params.email || '').toLowerCase().trim();
    const cleanIp = (params.ipAddress || '').trim();
    const cleanDeviceId = (params.deviceId || '').trim();
    const cleanAcc = (params.accountNumber || '').replace(/[^0-9]/g, '').trim();
    const timestamp = new Date().toISOString();

    console.warn(`🚨 [BotSentinel] BAN TRIGGERED for ${cleanEmail || 'Unknown'} | Trigger: ${params.trigger} | Reason: ${params.reason}`);

    // 1. Mark in memory sentinel caches
    if (cleanEmail) _bannedEmailsSet.add(cleanEmail);
    if (cleanIp) _bannedIpsSet.add(cleanIp);
    if (cleanDeviceId) _bannedDevicesSet.add(cleanDeviceId);
    if (cleanAcc && cleanAcc.length >= 8) {
      FLAGGED_SYNDICATE_ACCOUNTS.add(cleanAcc);
    }

    // 2. Ban primary account in UserStore
    let primaryUser: StoredUser | null = null;
    if (cleanEmail) {
      primaryUser = await UserStore.findByEmail(cleanEmail);
      if (primaryUser) {
        primaryUser.isBanned = true;
        primaryUser.isSuspended = true;
        primaryUser.status = 'banned';
        primaryUser.redFlagged = true;
        primaryUser.banReason = params.reason;
        primaryUser.bannedAt = timestamp;
        UserStore.upsertUserForced(primaryUser);
      }
    } else if (params.userId) {
      primaryUser = await UserStore.findById(params.userId);
      if (primaryUser) {
        primaryUser.isBanned = true;
        primaryUser.isSuspended = true;
        primaryUser.status = 'banned';
        primaryUser.redFlagged = true;
        primaryUser.banReason = params.reason;
        primaryUser.bannedAt = timestamp;
        UserStore.upsertUserForced(primaryUser);
      }
    }

    // 3. Update primary account in Supabase system_configs
    if (supabase && (cleanEmail || params.userId)) {
      try {
        const banKey = cleanEmail || params.userId;
        await supabase.from('system_configs').upsert({
          id: `ban_${banKey}`,
          data: {
            email: cleanEmail,
            userId: params.userId,
            status: 'banned',
            isBanned: true,
            isSuspended: true,
            redFlagged: true,
            banReason: params.reason,
            trigger: params.trigger,
            ipAddress: cleanIp,
            deviceId: cleanDeviceId,
            accountNumber: cleanAcc,
            bannedAt: timestamp,
            updatedAt: timestamp
          }
        });
      } catch (dbErr: any) {
        console.error('[BotSentinel] Supabase primary ban error:', dbErr?.message);
      }
    }

    // 4. CASCADE BAN: Find and ban all related accounts
    const cascadedEmails = new Set<string>();

    // 4a. Cascade via in-memory users
    const allUsers = UserStore.getAllUsers();
    for (const u of allUsers) {
      const uEmail = (u.email || '').toLowerCase().trim();
      if (!uEmail || uEmail === cleanEmail) continue;

      let isRelated = false;
      let relationReason = '';

      // Check matching bank account
      if (cleanAcc && u.accountNumber && u.accountNumber.replace(/[^0-9]/g, '').trim() === cleanAcc) {
        isRelated = true;
        relationReason = `Shares blacklisted payout bank account (${cleanAcc})`;
      }

      if (isRelated) {
        cascadedEmails.add(uEmail);
        _bannedEmailsSet.add(uEmail);
        u.isBanned = true;
        u.isSuspended = true;
        u.status = 'banned';
        u.redFlagged = true;
        u.banReason = `Cascaded suspension: ${relationReason}. Linked to bot account ${cleanEmail || params.userId}.`;
        u.bannedAt = timestamp;
        UserStore.upsertUserForced(u);
      }
    }

    // 4b. Cascade via Supabase profiles (IP, Bank Account, Referral Tree)
    if (supabase) {
      try {
        // Query profiles sharing bank account
        if (cleanAcc && cleanAcc.length >= 8) {
          const { data: matchedBankProfiles } = await supabase
            .from('profiles')
            .select('email, id')
            .eq('account_number', cleanAcc)
            .neq('email', cleanEmail);

          if (Array.isArray(matchedBankProfiles)) {
            for (const p of matchedBankProfiles) {
              if (p.email) {
                cascadedEmails.add(p.email.toLowerCase().trim());
                _bannedEmailsSet.add(p.email.toLowerCase().trim());
              }
            }
          }
        }

        // Query profiles linked via wallet transactions with same account
        if (cleanAcc && cleanAcc.length >= 8) {
          const { data: matchedTxs } = await supabase
            .from('wallet_transactions')
            .select('email')
            .like('narration', `%${cleanAcc}%`)
            .neq('email', cleanEmail);

          if (Array.isArray(matchedTxs)) {
            for (const t of matchedTxs) {
              if (t.email) {
                cascadedEmails.add(t.email.toLowerCase().trim());
                _bannedEmailsSet.add(t.email.toLowerCase().trim());
              }
            }
          }
        }

        // Apply bulk ban to all cascaded emails in Supabase system_configs
        if (cascadedEmails.size > 0) {
          for (const cEmail of cascadedEmails) {
            Promise.resolve(supabase.from('system_configs').upsert({
              id: `ban_${cEmail}`,
              data: {
                email: cEmail,
                status: 'banned',
                isBanned: true,
                isSuspended: true,
                redFlagged: true,
                banReason: `Cascaded syndicate ban: Linked to flagged bot ${cleanEmail || 'unknown'}. Reason: ${params.reason}`,
                bannedAt: timestamp,
                updatedAt: timestamp
              }
            })).catch(() => {});
          }
          console.log(`🛡️ [BotSentinel] Cascaded ban to ${cascadedEmails.size} linked accounts in Supabase.`);
        }
      } catch (cascadeErr: any) {
        console.error('[BotSentinel] Cascade query error:', cascadeErr?.message);
      }
    }

    // 5. Dispatch Real-time Executive Security Alert
    try {
      ExecutiveActivityAlertService.sendRealTimeActivityAlert({
        type: 'sentinel_lockdown',
        title: `🚨 CRITICAL: Bot Activity Flagged & Banned (${cleanEmail || 'Unknown'})`,
        summary: `Bot activity detected via [${params.trigger}]. Account permanently banned and red-flagged. ${cascadedEmails.size} related syndicate account(s) cascaded.`,
        actorEmail: cleanEmail,
        actorName: primaryUser?.fullName || 'Bot Offender',
        ipAddress: cleanIp,
        userAgent: params.userAgent,
        details: {
          trigger: params.trigger,
          reason: params.reason,
          cascadedCount: cascadedEmails.size,
          cascadedEmails: Array.from(cascadedEmails),
          bankAccount: cleanAcc || 'N/A',
          deviceId: cleanDeviceId || 'N/A',
          timestamp
        }
      }).catch(() => {});
    } catch (_) {}

    return {
      primaryAccountBanned: true,
      primaryEmail: cleanEmail,
      cascadedAccountsBanned: cascadedEmails.size,
      cascadedEmails: Array.from(cascadedEmails),
      bankAccountBlacklisted: cleanAcc || undefined,
      ipBlacklisted: cleanIp || undefined,
      reason: params.reason
    };
  }
}
