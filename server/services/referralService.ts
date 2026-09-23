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
  requireKycForPayout: true,
  updatedAt: new Date().toISOString()
};

let _inMemoryReferralLogs: ReferralRecord[] = [];

export class ReferralService {
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
   * Finds user by their unique referral code
   */
  static async findUserByReferralCode(code: string): Promise<StoredUser | null> {
    if (!code) return null;
    const cleanCode = code.trim().toUpperCase();
    const allUsers = UserStore.getAllUsers();

    // Check direct matching or generated code
    for (const u of allUsers) {
      const uCode = this.generateReferralCode(u);
      if (uCode === cleanCode) {
        return u;
      }
    }

    // Check Supabase profiles table
    if (supabase) {
      try {
        const { data } = await supabase
          .from('profiles')
          .select('*')
          .or(`referral_code.eq.${cleanCode}`)
          .limit(1)
          .maybeSingle();

        if (data) {
          return UserStore.findById(data.id);
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
    const config = await this.getConfig();
    const cleanCode = (params.referralCode || '').trim().toUpperCase();

    let referrer: StoredUser | null = null;
    if (cleanCode) {
      referrer = await this.findUserByReferralCode(cleanCode);
      // Prevent self-referral
      if (referrer && (referrer.id === params.refereeUser.id || referrer.email.toLowerCase() === params.refereeUser.email.toLowerCase())) {
        referrer = null;
      }
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
      referrerRewardAmount: config.referrerBonusAmount,
      refereeRewardAmount: config.signupBonusAmount,
      referrerRewardStatus: !config.enabled ? 'disabled' : (referrer ? 'pending_kyc' : 'disabled'),
      refereeRewardStatus: !config.enabled ? 'disabled' : 'pending_kyc',
      kycCompleted: Boolean(params.refereeUser.isVerified),
      createdAt: new Date().toISOString()
    };

    _inMemoryReferralLogs.unshift(newRecord);

    // Save to Supabase system_configs or referrals table
    if (supabase) {
      try {
        await supabase.from('referrals').upsert({
          id: newRecord.id,
          referrer_id: newRecord.referrerId || null,
          referrer_email: newRecord.referrerEmail || null,
          referrer_name: newRecord.referrerName || null,
          referrer_code: newRecord.referrerCode || null,
          referee_id: newRecord.refereeId,
          referee_email: newRecord.refereeEmail,
          referee_name: newRecord.refereeName,
          referee_buyer_type: newRecord.refereeBuyerType,
          referrer_reward_amount: newRecord.referrerRewardAmount,
          referee_reward_amount: newRecord.refereeRewardAmount,
          referrer_reward_status: newRecord.referrerRewardStatus,
          referee_reward_status: newRecord.refereeRewardStatus,
          kyc_completed: newRecord.kycCompleted,
          created_at: newRecord.createdAt
        }).catch(async () => {
          // Fallback to system_configs storage if custom table is not created yet
          await supabase?.from('system_configs').upsert({
            id: `ref_log_${newRecord.id}`,
            data: newRecord,
            updated_at: new Date().toISOString()
          });
        });
      } catch (_) {}
    }

    // If instant earning is active and KYC is not strictly required on signup
    if (config.enabled && config.instantEarning && !config.requireKycForPayout) {
      await this.disburseRewards(newRecord);
    }

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

        // Record in transaction store
        try {
          await TransactionStore.addTransaction({
            id: `tx_welcome_${referee.id.slice(0, 8)}_${Date.now()}`,
            userId: referee.id,
            email: referee.email.toLowerCase().trim(),
            title: '🎉 Rentilly Welcome Reward (KYC Verified)',
            description: 'Welcome Bonus for completing identity verification',
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
            title: '₦1,000 Welcome Bonus Credited! 🎉',
            message: `Congratulations ${referee.fullName || 'there'}! ₦${record.refereeRewardAmount.toLocaleString()} has been credited to your Rentilly wallet.`
          });
        } catch (_) {}

        record.refereeRewardStatus = 'paid';
      }
    }

    // 2. Credit Referrer (+₦500 Referral Reward)
    if (record.referrerRewardStatus === 'pending_kyc' && record.referrerRewardAmount > 0 && record.referrerId) {
      const referrer = await UserStore.findByEmail(record.referrerEmail) || await UserStore.findById(record.referrerId);
      if (referrer) {
        const prevBal = referrer.walletBalance || 0;
        referrer.walletBalance = prevBal + record.referrerRewardAmount;
        UserStore.upsertUserForced(referrer);

        // Record in transaction store
        try {
          await TransactionStore.addTransaction({
            id: `tx_ref_${referrer.id.slice(0, 8)}_${Date.now()}`,
            userId: referrer.id,
            email: referrer.email.toLowerCase().trim(),
            title: '🎁 Referral Bonus Earned',
            description: `🎁 Referral Bonus - Invited ${record.refereeName || record.refereeEmail}`,
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
            title: '₦500 Referral Bonus Earned! 🎁',
            message: `Your invitee ${record.refereeName || 'a friend'} just completed verification. ₦${record.referrerRewardAmount.toLocaleString()} has been credited to your wallet!`
          });
        } catch (_) {}

        record.referrerRewardStatus = 'paid';
      }
    }

    record.paidAt = now;

    // Update record in Supabase
    if (supabase) {
      try {
        await supabase.from('referrals').update({
          referrer_reward_status: record.referrerRewardStatus,
          referee_reward_status: record.refereeRewardStatus,
          kyc_completed: true,
          paid_at: record.paidAt
        }).eq('id', record.id).catch(() => {});
      } catch (_) {}
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
    successfulReferrals: number;
    pendingReferrals: number;
    referralLogs: ReferralRecord[];
  }> {
    const clean = identifier.toLowerCase().trim();
    const user = await UserStore.findByEmail(clean) || await UserStore.findById(identifier);
    const code = user ? this.generateReferralCode(user) : 'RENTILLY';
    const shareLink = `https://myrentilly.com/signup?ref=${code}`;

    const userLogs = _inMemoryReferralLogs.filter(
      r => r.referrerEmail.toLowerCase() === clean || r.referrerId === identifier || r.referrerCode === code
    );

    const paidLogs = userLogs.filter(r => r.referrerRewardStatus === 'paid');
    const totalEarned = paidLogs.reduce((acc, curr) => acc + (curr.referrerRewardAmount || 0), 0);

    return {
      referralCode: code,
      shareLink,
      totalEarned,
      totalReferred: userLogs.length,
      successfulReferrals: paidLogs.length,
      pendingReferrals: userLogs.filter(r => r.referrerRewardStatus === 'pending_kyc').length,
      referralLogs: userLogs
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

    // Sync from Supabase if available
    if (supabase) {
      try {
        const { data } = await supabase
          .from('referrals')
          .select('*')
          .order('created_at', { ascending: false });

        if (data && data.length > 0) {
          _inMemoryReferralLogs = data.map((d: any) => ({
            id: d.id,
            referrerId: d.referrer_id,
            referrerEmail: d.referrer_email,
            referrerName: d.referrer_name,
            referrerCode: d.referrer_code,
            refereeId: d.referee_id,
            refereeEmail: d.referee_email,
            refereeName: d.referee_name,
            refereeBuyerType: d.referee_buyer_type,
            referrerRewardAmount: Number(d.referrer_reward_amount || 500),
            refereeRewardAmount: Number(d.referee_reward_amount || 1000),
            referrerRewardStatus: d.referrer_reward_status || 'pending_kyc',
            refereeRewardStatus: d.referee_reward_status || 'pending_kyc',
            kycCompleted: Boolean(d.kyc_completed),
            createdAt: d.created_at,
            paidAt: d.paid_at
          }));
        }
      } catch (_) {}
    }

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
