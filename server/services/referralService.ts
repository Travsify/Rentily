import crypto from 'crypto';
import { supabase } from '../supabaseClient';
import { UserStore, StoredUser } from './userStore';
import { TransactionStore } from './transactionStore';
import { NotificationDispatcher } from './notificationDispatcher';

export interface ReferralConfig {
  enabled: boolean;
  instantEarning: boolean;
  signupBonusAmount: number; // Default 1000 NGN
  referrerBonusAmount: number; // Default 500 NGN
  requireKycForPayout: boolean; // Default true
  updatedAt?: string;
}

export interface ReferralRecord {
  id: string;
  referrerId: string;
  referrerEmail: string;
  referrerName: string;
  referrerCode: string;
  refereeId: string;
  refereeEmail: string;
  refereeName: string;
  refereeBuyerType?: string;
  referrerRewardAmount: number;
  refereeRewardAmount: number;
  referrerRewardStatus: 'paid' | 'pending_kyc' | 'disabled';
  refereeRewardStatus: 'paid' | 'pending_kyc' | 'disabled';
  kycCompleted: boolean;
  createdAt: string;
  paidAt?: string;
}

let _inMemoryReferralConfig: ReferralConfig = {
  enabled: true,
  instantEarning: true,
  signupBonusAmount: 1000,
  referrerBonusAmount: 500,
  requireKycForPayout: false,
  updatedAt: new Date().toISOString()
};

let _inMemoryReferralLogs: ReferralRecord[] = [];

export class ReferralService {
  /**
   * Generates a deterministic or unique Referral Code for any user
   */
  /**
   * Generates a deterministic or unique Referral Code for any user
   */
  static generateReferralCode(user: { id?: string; email?: string; fullName?: string }): string {
    const raw = (user.email || user.fullName || user.id || 'RENTILLY').toUpperCase().replace(/[^A-Z0-9]/g, '');
    const prefix = raw.length >= 4 ? raw.substring(0, 4) : 'RENT';
    
    // Hash-based 4-character suffix
    let hash = 0;
    const str = `${user.email || user.id || 'USER'}_rentilly_ref`;
    for (let i = 0; i < str.length; i++) {
      hash = ((hash << 5) - hash) + str.charCodeAt(i);
      hash |= 0;
    }
    const suffix = Math.abs(hash).toString(36).toUpperCase().padStart(4, '0').slice(-4);
    return `${prefix}${suffix}`;
  }

  /**
   * Legacy Dart-compatible hash generator for backward compatibility
   */
  static generateReferralCodeDart(user: { id?: string; email?: string; fullName?: string }): string {
    const raw = (user.email || user.fullName || user.id || 'RENTILLY').toUpperCase().replace(/[^A-Z0-9]/g, '');
    const prefix = raw.length >= 4 ? raw.substring(0, 4) : 'RENT';
    let hash = 5381;
    const str = `${user.email || user.id || 'USER'}_rentilly_ref`;
    for (let i = 0; i < str.length; i++) {
      hash = ((hash << 5) + hash) + str.charCodeAt(i);
      hash = (hash & 0xFFFFFFFF) >>> 0;
    }
    const suffix = Math.abs(hash).toString(36).toUpperCase().padStart(4, '0').slice(-4);
    return `${prefix}${suffix}`;
  }

  private static _logsLoaded = false;

  /**
   * Ensures logs are synchronized from Supabase cloud system_configs
   */
  private static async ensureLogsLoaded(force = false): Promise<void> {
    if (this._logsLoaded && !force) return;
    if (supabase) {
      try {
        const { data: cfgData, error } = await supabase
          .from('system_configs')
          .select('id, data')
          .like('id', 'ref_log_%');

        if (!error && cfgData && cfgData.length > 0) {
          const loaded: ReferralRecord[] = [];
          for (const item of cfgData) {
            if (item.data && item.data.id) {
              loaded.push(item.data as ReferralRecord);
            }
          }
          if (loaded.length > 0) {
            const map = new Map<string, ReferralRecord>();
            for (const r of loaded) map.set(r.id, r);
            for (const r of _inMemoryReferralLogs) map.set(r.id, r);
            _inMemoryReferralLogs = Array.from(map.values()).sort(
              (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
            );
          }
        }
      } catch (err: any) {
        console.warn('[ReferralService] Cloud log hydration error:', err?.message);
      }
    }
    this._logsLoaded = true;
  }

  /**
   * Loads global referral settings from Supabase system_configs
   */
  static async getConfig(): Promise<ReferralConfig> {
    if (supabase) {
      try {
        const { data } = await supabase
          .from('system_configs')
          .select('data')
          .eq('id', 'referral_system_config')
          .single();
        if (data?.data) {
          _inMemoryReferralConfig = {
            ..._inMemoryReferralConfig,
            ...data.data,
            updatedAt: data.data.updatedAt || new Date().toISOString()
          };
        }
      } catch (_) {}
    }
    return _inMemoryReferralConfig;
  }

  /**
   * Updates global referral settings from Admin
   */
  static async updateConfig(newConfig: Partial<ReferralConfig>): Promise<ReferralConfig> {
    _inMemoryReferralConfig = {
      ..._inMemoryReferralConfig,
      ...newConfig,
      updatedAt: new Date().toISOString()
    };

    if (supabase) {
      try {
        await supabase.from('system_configs').upsert({
          id: 'referral_system_config',
          data: _inMemoryReferralConfig,
          updated_at: new Date().toISOString()
        });
      } catch (err: any) {
        console.error('[ReferralService] Failed to persist config to Supabase:', err.message);
      }
    }

    return _inMemoryReferralConfig;
  }

  /**
   * Finds user by their unique referral code, promo alias, email, or phone number
   */
  static async findUserByReferralCode(code: string): Promise<StoredUser | null> {
    if (!code) return null;
    const cleanCode = code.trim().toUpperCase();
    const allUsers = UserStore.getAllUsers();

    // 1. Official platform promo codes (aliased to official platform admin account)
    const masterAliases = ['RENTILLY', 'RENTILLY2026', 'RENTILLYVIP', 'RENT', 'ADMIN', 'WELCOME', 'PROMO', 'FREE1000'];
    if (masterAliases.includes(cleanCode)) {
      const admin = (await UserStore.findByEmail('admin@myrentilly.com')) ||
                    (await UserStore.findByEmail('support@myrentilly.com')) ||
                    allUsers.find(u => u.role === 'admin') ||
                    allUsers[0];
      if (admin) {
        return {
          ...admin,
          fullName: 'Rentilly Platform (Official Promo)'
        };
      }
    }

    // 2. Explicit referral code stored on user record
    for (const u of allUsers) {
      const explicitCode = ((u as any).referralCode || '').toString().trim().toUpperCase();
      if (explicitCode && explicitCode === cleanCode) {
        return u;
      }
    }

    // 3. Standard TypeScript deterministic referral code
    for (const u of allUsers) {
      const uCode = this.generateReferralCode(u);
      if (uCode === cleanCode) {
        return u;
      }
    }

    // 4. Legacy Dart deterministic referral code
    for (const u of allUsers) {
      const dartCode = this.generateReferralCodeDart(u);
      if (dartCode === cleanCode) {
        return u;
      }
    }

    // 5. Match by referrer's email address
    const byEmail = allUsers.find(u => u.email && u.email.toUpperCase() === cleanCode);
    if (byEmail) return byEmail;

    // 6. Match by referrer's phone number (supports local 080... or international +234...)
    const numericClean = cleanCode.replace(/[^0-9]/g, '');
    if (numericClean.length >= 7) {
      const coreDigits = numericClean.startsWith('234')
        ? numericClean.slice(3)
        : (numericClean.startsWith('0') ? numericClean.slice(1) : numericClean);

      const byPhone = allUsers.find(u => {
        if (!u.phoneNumber) return false;
        const uRaw = u.phoneNumber.replace(/[^0-9]/g, '');
        const uCore = uRaw.startsWith('234')
          ? uRaw.slice(3)
          : (uRaw.startsWith('0') ? uRaw.slice(1) : uRaw);
        return uCore === coreDigits || uRaw.includes(coreDigits) || numericClean.includes(uCore);
      });
      if (byPhone) return byPhone;
    }

    // 7. Supabase cloud profiles table fallback
    if (supabase) {
      try {
        const { data } = await supabase
          .from('profiles')
          .select('*')
          .or(`referral_code.eq.${cleanCode},email.eq.${cleanCode.toLowerCase()}`)
          .limit(1)
          .maybeSingle();

        if (data) {
          return UserStore.findById(data.id) || UserStore.findByEmail(data.email);
        }
      } catch (_) {}
    }

    return null;
  }

  /**
   * Records a referral association when a new user registers with a code
   */
  static async recordReferralOnSignup(params: {
    refereeUser: StoredUser;
    referralCode?: string;
  }): Promise<{ success: boolean; message: string; record?: ReferralRecord }> {
    await this.ensureLogsLoaded();
    const config = await this.getConfig();
    const cleanCode = (params.referralCode || '').trim().toUpperCase();

    let referrer: StoredUser | null = null;
    if (cleanCode) {
      referrer = await this.findUserByReferralCode(cleanCode);
      // Prevent self-referral
      if (referrer && params.refereeUser && (
        referrer.id === params.refereeUser.id || 
        (referrer.email && params.refereeUser.email && referrer.email.toLowerCase() === params.refereeUser.email.toLowerCase())
      )) {
        referrer = null;
      }
    }

    // Calculate role-based reward tiers per policy:
    // 1. Renter: Gets ₦1,000 instant (with or without code). Referrer gets ₦500 instant (if code used).
    // 2. Partner / Agent: If code used, both get ₦5,000 instant. If NO code used, partner gets ₦0.
    // 3. Landlord: Gets ₦1,000 instant. Referrer gets ₦500 instant (if code used).
    const role = (params.refereeUser.role || 'renter').toLowerCase().trim();
    const hasReferrer = Boolean(referrer);

    let refereeRewardAmount = 0;
    let referrerRewardAmount = 0;

    if (role === 'partner' || role === 'agent') {
      if (hasReferrer) {
        refereeRewardAmount = 5000;
        referrerRewardAmount = 5000;
      } else {
        refereeRewardAmount = 0;
        referrerRewardAmount = 0;
      }
    } else if (role === 'landlord' || role === 'owner') {
      refereeRewardAmount = 1000;
      referrerRewardAmount = hasReferrer ? 500 : 0;
    } else {
      // Renter
      refereeRewardAmount = 1000;
      referrerRewardAmount = hasReferrer ? 500 : 0;
    }

    const newRecord: ReferralRecord = {
      id: crypto.randomUUID(),
      referrerId: referrer?.id || '',
      referrerEmail: referrer?.email || '',
      referrerName: referrer?.fullName || referrer?.businessName || (cleanCode && referrer ? `Referrer (${cleanCode})` : 'Direct'),
      referrerCode: cleanCode || '',
      refereeId: params.refereeUser.id,
      refereeEmail: params.refereeUser.email,
      refereeName: params.refereeUser.fullName || params.refereeUser.businessName || params.refereeUser.email,
      refereeBuyerType: params.refereeUser.buyerType || 'personal',
      referrerRewardAmount: referrerRewardAmount,
      refereeRewardAmount: refereeRewardAmount,
      referrerRewardStatus: !config.enabled ? 'disabled' : (hasReferrer && referrerRewardAmount > 0 ? 'pending_kyc' : 'disabled'),
      refereeRewardStatus: !config.enabled ? 'disabled' : (refereeRewardAmount > 0 ? 'pending_kyc' : 'disabled'),
      kycCompleted: true,
      createdAt: new Date().toISOString()
    };

    _inMemoryReferralLogs.unshift(newRecord);

    // Save to Supabase system_configs for guaranteed cloud permanence
    if (supabase) {
      try {
        await supabase.from('system_configs').upsert({
          id: `ref_log_${newRecord.id}`,
          data: newRecord,
          updated_at: new Date().toISOString()
        });
      } catch (err: any) {
        console.error('[ReferralService] Cloud log save failed:', err?.message);
      }
    }

    // Disburse rewards immediately upon registration
    await this.disburseRewards(newRecord);

    return {
      success: true,
      message: referrer ? `Referred by ${referrer.fullName}` : 'Welcome bonus registered',
      record: newRecord
    };
  }

  /**
   * Called when a user completes KYC or KYB verification to disburse ₦1,000 and ₦500
   */
  static async processKycRewards(userId: string, email: string): Promise<void> {
    await this.ensureLogsLoaded();
    const config = await this.getConfig();
    if (!config.enabled) return;

    const cleanEmail = email.toLowerCase().trim();

    // Check if user already got a welcome bonus previously to prevent duplicate payouts
    const existingTxs = await TransactionStore.getTransactionsByEmail(cleanEmail);
    const alreadyReceivedWelcome = existingTxs.some(t => 
      t.reference?.startsWith('REF-WELCOME-') || 
      (t.description && t.description.includes('Welcome Reward')) ||
      (t.title && t.title.includes('Welcome Reward'))
    );

    // Find all referral records where this user is the referee
    const pendingLogs = _inMemoryReferralLogs.filter(
      r => (r.refereeEmail.toLowerCase() === cleanEmail || r.refereeId === userId) &&
           (r.refereeRewardStatus === 'pending_kyc' || r.referrerRewardStatus === 'pending_kyc')
    );

    if (pendingLogs.length > 0) {
      for (const log of pendingLogs) {
        log.kycCompleted = true;
        await this.disburseRewards(log);
      }
      return;
    }

    // Standalone verified user without prior referral record: only pay once if not already credited
    if (!alreadyReceivedWelcome) {
      const user = await UserStore.findById(userId) || await UserStore.findByEmail(cleanEmail);
      if (user && user.isVerified) {
        await this.creditWelcomeBonus(user, config.signupBonusAmount);
      }
    }
  }

  /**
   * Disburses the actual monetary credits into wallet accounts & emits ledger transactions
   */
  private static async disburseRewards(record: ReferralRecord): Promise<void> {
    const config = await this.getConfig();
    if (!config.enabled) return;

    const now = new Date().toISOString();

    // 1. Credit Referee (+₦1,000 Welcome Bonus)
    if (record.refereeRewardStatus === 'pending_kyc' && record.refereeRewardAmount > 0) {
      const referee = await UserStore.findByEmail(record.refereeEmail) || await UserStore.findById(record.refereeId);
      if (referee) {
        const prevBal = referee.walletBalance || 0;
        referee.walletBalance = prevBal + record.refereeRewardAmount;
        UserStore.upsertUserForced(referee);

        // Direct Supabase Cloud balance sync
        if (supabase) {
          try {
            await supabase.from('profiles').update({
              wallet_balance: referee.walletBalance,
              updated_at: now
            }).eq('id', referee.id);
          } catch (_) {}
        }

        // Record in transaction store
        try {
          await TransactionStore.addTransaction({
            id: `tx_welcome_${referee.id.slice(0, 8)}_${Date.now()}`,
            userId: referee.id,
            email: referee.email.toLowerCase().trim(),
            title: '🎉 Rentilly Welcome Reward',
            description: `Instant Welcome Bonus (₦${record.refereeRewardAmount.toLocaleString()})`,
            type: 'credit',
            category: 'wallet_funding',
            amount: record.refereeRewardAmount,
            currency: 'NGN',
            isCredit: true,
            reference: `REF-WELCOME-${Date.now().toString().slice(-6)}`,
            status: 'SUCCESSFUL',
            date: now
          });
        } catch (_) {}

        // Send Push & Email Notification
        try {
          NotificationDispatcher.dispatch({
            userId: referee.id,
            email: referee.email,
            userName: referee.fullName,
            category: 'wallet',
            title: `₦${record.refereeRewardAmount.toLocaleString()} Welcome Bonus Credited! 🎉`,
            message: `Congratulations ${referee.fullName || 'there'}! ₦${record.refereeRewardAmount.toLocaleString()} has been credited to your Rentilly wallet.`
          });
        } catch (_) {}

        record.refereeRewardStatus = 'paid';
      }
    }

    // 2. Credit Referrer (+₦500 or +₦5,000 Referral Reward)
    if (record.referrerRewardStatus === 'pending_kyc' && record.referrerRewardAmount > 0 && record.referrerId) {
      const referrer = await UserStore.findByEmail(record.referrerEmail) || await UserStore.findById(record.referrerId);
      if (referrer) {
        const prevBal = referrer.walletBalance || 0;
        referrer.walletBalance = prevBal + record.referrerRewardAmount;
        UserStore.upsertUserForced(referrer);

        // Direct Supabase Cloud balance sync
        if (supabase) {
          try {
            await supabase.from('profiles').update({
              wallet_balance: referrer.walletBalance,
              updated_at: now
            }).eq('id', referrer.id);
          } catch (_) {}
        }

        // Record in transaction store
        try {
          await TransactionStore.addTransaction({
            id: `tx_ref_${referrer.id.slice(0, 8)}_${Date.now()}`,
            userId: referrer.id,
            email: referrer.email.toLowerCase().trim(),
            title: '🎁 Referral Bonus Earned',
            description: `🎁 Referral Bonus - Invited ${record.refereeName || record.refereeEmail} (₦${record.referrerRewardAmount.toLocaleString()})`,
            type: 'credit',
            category: 'wallet_funding',
            amount: record.referrerRewardAmount,
            currency: 'NGN',
            isCredit: true,
            reference: `REF-BONUS-${Date.now().toString().slice(-6)}`,
            status: 'SUCCESSFUL',
            date: now
          });
        } catch (_) {}

        // Send Push & Email Notification to Referrer
        try {
          NotificationDispatcher.dispatch({
            userId: referrer.id,
            email: referrer.email,
            userName: referrer.fullName,
            category: 'wallet',
            title: `₦${record.referrerRewardAmount.toLocaleString()} Referral Bonus Earned! 🎁`,
            message: `Your invitee ${record.refereeName || 'a new user'} just registered with your code. ₦${record.referrerRewardAmount.toLocaleString()} has been credited to your wallet!`
          });
        } catch (_) {}

        record.referrerRewardStatus = 'paid';
      }
    }

    record.paidAt = now;

    // Update record in Supabase cloud system_configs
    if (supabase) {
      try {
        await supabase.from('system_configs').upsert({
          id: `ref_log_${record.id}`,
          data: record,
          updated_at: new Date().toISOString()
        });
      } catch (err: any) {
        console.error('[ReferralService] Cloud log disburse update failed:', err?.message);
      }
    }
  }

  /**
   * Credits a standalone welcome bonus
   */
  private static async creditWelcomeBonus(user: StoredUser, amount: number): Promise<void> {
    const prevBal = user.walletBalance || 0;
    user.walletBalance = prevBal + amount;
    UserStore.upsertUserForced(user);

    try {
      await TransactionStore.addTransaction({
        id: `tx_welcome_${user.id.slice(0, 8)}_${Date.now()}`,
        userId: user.id,
        email: user.email.toLowerCase().trim(),
        title: '🎉 Rentilly Welcome Reward (KYC Verified)',
        description: 'Welcome Bonus for completing identity verification',
        type: 'credit',
        category: 'wallet_funding',
        amount,
        currency: 'NGN',
        isCredit: true,
        reference: `REF-WELCOME-${Date.now().toString().slice(-6)}`,
        status: 'SUCCESSFUL',
        date: new Date().toISOString()
      });
    } catch (_) {}

    try {
      NotificationDispatcher.dispatch({
        userId: user.id,
        email: user.email,
        userName: user.fullName,
        category: 'wallet',
        title: '₦1,000 Welcome Bonus Credited! 🎉',
        message: `Congratulations ${user.fullName || 'there'}! ₦${amount.toLocaleString()} has been credited to your Rentilly wallet.`
      });
    } catch (_) {}
  }

  /**
   * Returns user referral stats and referred friends list
   */
  static async getUserReferralStats(identifier: string): Promise<{
    referralCode: string;
    shareLink: string;
    totalEarned: number;
    totalReferred: number;
    totalReferrals: number;
    successfulReferrals: number;
    pendingReferrals: number;
    referralLogs: ReferralRecord[];
    recentReferrals: Array<{
      id: string;
      name: string;
      email: string;
      status: string;
      amount: number;
      date: string;
      paidAt?: string;
      kycCompleted: boolean;
    }>;
  }> {
    await this.ensureLogsLoaded();
    const clean = identifier.toLowerCase().trim();
    const user = await UserStore.findByEmail(clean) || await UserStore.findById(identifier);
    const code = user ? this.generateReferralCode(user) : 'RENTILLY';
    const shareLink = `https://myrentilly.com/signup?ref=${code}`;

    const userLogs = _inMemoryReferralLogs.filter(
      r => r.referrerEmail.toLowerCase() === clean || r.referrerId === identifier || r.referrerCode === code
    );

    const paidLogs = userLogs.filter(r => r.referrerRewardStatus === 'paid');
    const totalEarned = paidLogs.reduce((acc, curr) => acc + (curr.referrerRewardAmount || 0), 0);

    const recentReferrals = userLogs.map(r => ({
      id: r.id,
      name: r.refereeName || r.refereeEmail,
      email: r.refereeEmail,
      status: r.referrerRewardStatus,
      amount: r.referrerRewardAmount,
      date: r.createdAt,
      paidAt: r.paidAt,
      kycCompleted: r.kycCompleted
    }));

    return {
      referralCode: code,
      shareLink,
      totalEarned,
      totalReferred: userLogs.length,
      totalReferrals: userLogs.length,
      successfulReferrals: paidLogs.length,
      pendingReferrals: userLogs.filter(r => r.referrerRewardStatus === 'pending_kyc').length,
      referralLogs: userLogs,
      recentReferrals
    };
  }

  /**
   * Returns all referral logs for Admin Dashboard
   */
  static async getAllReferralsForAdmin(): Promise<{
    config: ReferralConfig;
    totalReferralsCount: number;
    totalPayoutAmount: number;
    pendingPayoutCount: number;
    logs: ReferralRecord[];
  }> {
    const config = await this.getConfig();
    await this.ensureLogsLoaded(true);

    const totalPayoutAmount = _inMemoryReferralLogs.reduce((acc, curr) => {
      let sum = 0;
      if (curr.refereeRewardStatus === 'paid') sum += curr.refereeRewardAmount;
      if (curr.referrerRewardStatus === 'paid') sum += curr.referrerRewardAmount;
      return acc + sum;
    }, 0);

    const pendingPayoutCount = _inMemoryReferralLogs.filter(
      r => r.refereeRewardStatus === 'pending_kyc' || r.referrerRewardStatus === 'pending_kyc'
    ).length;

    return {
      config,
      totalReferralsCount: _inMemoryReferralLogs.length,
      totalPayoutAmount,
      pendingPayoutCount,
      logs: _inMemoryReferralLogs
    };
  }
}
