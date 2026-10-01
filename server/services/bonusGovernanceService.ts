import { supabase } from '../supabaseClient';
import { UserStore, StoredUser } from './userStore';
import { TransactionStore } from './transactionStore';
import { NotificationDispatcher } from './notificationDispatcher';
import { AdminDataStore } from './adminDataStore';

export interface VerificationCheckResult {
  verified: boolean;
  reason?: string;
  isPartner?: boolean;
}

export interface BankAccountCheckResult {
  hasAccount: boolean;
  accountNumber?: string;
  bankName?: string;
  isFincraWema?: boolean;
  reason?: string;
}

export interface BonusBalances {
  totalBalance: number;
  promotionalBonusTotal: number;
  organicCashBalance: number;
  cumulativeBonusEarned: number;
  bonusMilestoneUnlocked: boolean;
  bonusSpendUnlocked: boolean;
  maxBonusSpendApp: number;
  minBonusWithdrawalMilestone: number;
}

export interface BonusUtilizationResult {
  allowed: boolean;
  error?: string;
  statusCode?: number;
  bonusDrawn: number;
  organicCashBalance: number;
  promotionalBonusTotal: number;
  remainingToMilestone: number;
  bonusSpendCapped?: boolean;
  maxBonusSpend?: number;
  personalCashNeeded?: number;
  remainingPersonalCashNeeded?: number;
  bonusMilestoneUnlocked?: boolean;
  bonusSpendUnlocked?: boolean;
  maxBonusSpendApp?: number;
  minBonusWithdrawalMilestone?: number;
}

export interface WithdrawalEligibilityResult {
  eligibleForOrganicWithdrawal: boolean;
  eligibleForBonusWithdrawal: boolean;
  canWithdrawAny: boolean;
  is100PercentVerified: boolean;
  hasFincraAccount: boolean;
  verificationReason?: string;
  accountReason?: string;
  totalBalance: number;
  promotionalBonusTotal: number;
  organicCashBalance: number;
  cumulativeBonusEarned: number;
  bonusMilestoneUnlocked: boolean;
  bonusSpendUnlocked: boolean;
  maxBonusSpendApp: number;
  minBonusWithdrawalMilestone: number;
  minOrganicWithdrawal: number;
  remainingBonusToMilestone: number;
  reasons: string[];
}

const ADMIN_EMAILS = new Set([
  'patrickachua3@gmail.com',
  'info@myrentilly.com',
  'admin@myrentilly.com',
  'support@myrentilly.com'
]);

export class BonusGovernanceService {
  public static readonly MAX_BONUS_SPEND_APP: number = 3000;
  public static readonly MIN_BONUS_WITHDRAWAL_MILESTONE: number = 5000;
  public static readonly MIN_BONUS_SPEND_MILESTONE: number = 3000;
  public static readonly MIN_ORGANIC_WITHDRAWAL: number = 100;
  public static readonly PARTNER_MANDATE_BOUNTY: number = 20000; // ₦20,000 Verified Property Mandate Bounty
  /**
   * Checks if an email belongs to a system administrator
   */
  public static isAdmin(email?: string, user?: StoredUser): boolean {
    const clean = (email || user?.email || '').toLowerCase().trim();
    if (ADMIN_EMAILS.has(clean)) return true;
    if (user?.role === 'admin') return true;
    return false;
  }

  /**
   * 1. 100% Identity Verification Check:
   * - Individuals/Renters/Owners: Must have isVerified === true AND (bvnVerified === true OR valid 11-digit ninNumber)
   * - Corporate Partners/Brokers: Must have isVerified === true AND partnerStatus === 'verified' AND valid CAC format
   */
  public static isUser100PercentVerified(user?: StoredUser | null, profile?: any): VerificationCheckResult {
    if (!user && !profile) {
      return { verified: false, reason: 'User record not found.' };
    }

    const email = (user?.email || profile?.email || '').toLowerCase().trim();
    if (this.isAdmin(email, user || undefined)) {
      return { verified: true };
    }

    const isPartner = user?.role === 'partner' || 
                      user?.role === 'broker' || 
                      user?.buyerType === 'corporate' || 
                      Boolean(user?.businessName || profile?.business_name);

    if (isPartner) {
      const rawCac = (user?.cacNumber || profile?.cac_number || '').toString().trim().replace(/\s+/g, '');
      const hasValidCac = /^(RC|BN|IT|LLP)?[0-9]{6,8}$/i.test(rawCac) && rawCac.length >= 6 && !/^(.)\1+$/.test(rawCac);
      const isVerified = Boolean(user?.isVerified || profile?.is_verified);
      const isPartnerStatusVerified = (user?.partnerStatus === 'verified') || (profile?.is_verified && Boolean(user?.accountNumber || profile?.account_number));

      if (!hasValidCac) {
        return {
          verified: false,
          isPartner: true,
          reason: 'Corporate Partner accounts require a valid Corporate Affairs Commission (CAC) registration number before bonuses can be utilised.'
        };
      }

      if (!isVerified || !isPartnerStatusVerified) {
        return {
          verified: false,
          isPartner: true,
          reason: 'Corporate Partner account is not fully verified. KYB partner accreditation is required before bonuses can be utilised.'
        };
      }

      return { verified: true, isPartner: true };
    }

    // Individual / Renter / Landlord verification
    const isVerified = Boolean(user?.isVerified || profile?.is_verified);
    const bvnVerified = Boolean(user?.bvnVerified || profile?.bvn_verified);
    const rawNin = (user?.ninNumber || profile?.nin_number || '').toString().trim();
    const hasValidNin = /^\d{11}$/.test(rawNin);

    if (!isVerified) {
      return {
        verified: false,
        isPartner: false,
        reason: '100% Identity Verification (KYC) is strictly required before bonus funds can be utilised. Please complete identity verification in your profile.'
      };
    }

    if (!bvnVerified && !hasValidNin) {
      return {
        verified: false,
        isPartner: false,
        reason: 'Full Tier-2 verification requires a verified BVN or 11-digit NIN before bonus funds can be utilised.'
      };
    }

    return { verified: true, isPartner: false };
  }

  /**
   * 2. Fincra Provisioned Dedicated Bank Account Check:
   * Must have an authentic 10-digit NUBAN (Wema Bank 035), non-synthetic (not starting with 990).
   */
  public static hasFincraProvisionedAccount(user?: StoredUser | null, profile?: any): BankAccountCheckResult {
    if (!user && !profile) {
      return { hasAccount: false, reason: 'User record not found.' };
    }

    const email = (user?.email || profile?.email || '').toLowerCase().trim();
    if (this.isAdmin(email, user || undefined)) {
      return { hasAccount: true, accountNumber: 'ADMIN_NUBAN', bankName: 'Wema Bank', isFincraWema: true };
    }

    const rawAcc = (
      user?.accountNumber || 
      profile?.account_number || 
      (user as any)?.commercialAccountNumber ||
      ''
    ).toString().trim().replace(/[^0-9]/g, '');

    const bankName = (user?.bankName || profile?.bank_name || 'Wema Bank').toString().trim();

    if (!rawAcc) {
      return {
        hasAccount: false,
        reason: 'You do not have a dedicated Fincra bank account provisioned. An authentic 10-digit Wema Bank NUBAN must be provisioned before bonus funds can be utilised.'
      };
    }

    // Must be exactly 10 digits
    if (rawAcc.length !== 10) {
      return {
        hasAccount: false,
        accountNumber: rawAcc,
        reason: 'The provisioned account number is invalid (must be an authentic 10-digit NUBAN).'
      };
    }

    // Synthetic 990 accounts are strictly prohibited
    if (rawAcc.startsWith('990')) {
      return {
        hasAccount: false,
        accountNumber: rawAcc,
        reason: 'Virtual placeholder account detected (990...). A genuine Fincra Wema Bank NUBAN is required before bonus funds can be utilised.'
      };
    }

    const isWema = bankName.toLowerCase().includes('wema');

    return {
      hasAccount: true,
      accountNumber: rawAcc,
      bankName: bankName || 'Wema Bank',
      isFincraWema: isWema
    };
  }

  /**
   * 3. Calculates exact split between Organic Cash vs. Promotional Bonus
   * and verifies the ₦3,000 Milestone requirements.
   */
  public static async getBonusAndCashBalances(
    email: string,
    user?: StoredUser | null,
    profile?: any
  ): Promise<BonusBalances> {
    const cleanEmail = (email || user?.email || profile?.email || '').toLowerCase().trim();

    // 1. Total wallet balance
    let totalBalance = 0;
    if (profile?.wallet_balance != null) {
      totalBalance = Number(profile.wallet_balance);
    } else if (user?.walletBalance != null) {
      totalBalance = Number(user.walletBalance);
    } else {
      totalBalance = TransactionStore.computeNetBalance(cleanEmail);
    }

    // 2. Fetch all transaction records
    let bonusCredits = 0;
    let debitsSpent = 0;

    // Check transactions from TransactionStore
    try {
      const allTx = TransactionStore.getAllTransactions();
      const userTx = allTx.filter((t: any) => 
        (t.email && t.email.toLowerCase().trim() === cleanEmail) ||
        (t.userId && user?.id && t.userId === user.id)
      );

      for (const t of userTx) {
        const title = (t.title || t.narration || t.description || '').toLowerCase();
        const ref = (t.reference || t.flw_ref || t.tx_ref || '').toUpperCase();
        const type = (t.type || '').toLowerCase();
        const cat = (t.category || '').toLowerCase();
        const amt = Number(t.amount || 0);

        const isBonusCredit = 
          cat === 'promotional_bonus' ||  // Primary: explicit category tag
          ref.startsWith('REF-') ||
          ref.startsWith('BONUS_') ||
          ref.startsWith('KYC_') ||
          title.includes('bonus') ||
          title.includes('reward') ||
          title.includes('referral') ||
          title.includes('welcome') ||
          title.includes('cashback') ||
          title.includes('promo');

        if (type === 'credit' && isBonusCredit) {
          bonusCredits += amt;
        } else if (type === 'debit' && !title.includes('withdraw') && !title.includes('payout')) {
          debitsSpent += amt;
        }
      }
    } catch (_) {}

    // Check Supabase wallet_transactions if available
    if (supabase) {
      try {
        const { data: sbTx } = await supabase
          .from('wallet_transactions')
          .select('amount, type, category, flw_ref, tx_ref, narration') // category added for explicit bonus detection
          .eq('email', cleanEmail);

        if (sbTx && Array.isArray(sbTx)) {
          let sbBonus = 0;
          let sbDebits = 0;
          for (const t of sbTx) {
            const narr = (t.narration || '').toLowerCase();
            const ref = (t.flw_ref || t.tx_ref || '').toUpperCase();
            const type = (t.type || '').toLowerCase();
            const cat = (t.category || '').toLowerCase();
            const amt = Number(t.amount || 0);

            const isBonusCredit = 
              cat === 'promotional_bonus' ||  // Primary: explicit category tag
              ref.startsWith('REF-') ||
              ref.startsWith('BONUS_') ||
              ref.startsWith('KYC_') ||
              narr.includes('bonus') ||
              narr.includes('reward') ||
              narr.includes('referral') ||
              narr.includes('welcome') ||
              narr.includes('cashback') ||
              narr.includes('promo');

            if (type === 'credit' && isBonusCredit) {
              sbBonus += amt;
            } else if (type === 'debit' && !narr.includes('withdraw') && !narr.includes('payout')) {
              sbDebits += amt;
            }
          }
          bonusCredits = Math.max(bonusCredits, sbBonus);
          debitsSpent = Math.max(debitsSpent, sbDebits);
        }
      } catch (_) {}
    }

    const cumulativeBonusEarned = bonusCredits;
    // Promotional bonus remaining in wallet cannot exceed total balance
    const promotionalBonusTotal = Math.min(totalBalance, Math.max(0, bonusCredits - debitsSpent));
    const organicCashBalance = Math.max(0, totalBalance - promotionalBonusTotal);

    // Milestone is strictly unlocked for bank withdrawal if cumulative bonus earnings >= ₦5,000
    const bonusMilestoneUnlocked = cumulativeBonusEarned >= this.MIN_BONUS_WITHDRAWAL_MILESTONE;
    // Milestone is unlocked for in-app spending if cumulative bonus earnings >= ₦3,000
    const bonusSpendUnlocked = cumulativeBonusEarned >= this.MIN_BONUS_SPEND_MILESTONE;

    return {
      totalBalance,
      promotionalBonusTotal,
      organicCashBalance,
      cumulativeBonusEarned,
      bonusMilestoneUnlocked,
      bonusSpendUnlocked,
      maxBonusSpendApp: this.MAX_BONUS_SPEND_APP,
      minBonusWithdrawalMilestone: this.MIN_BONUS_WITHDRAWAL_MILESTONE
    };
  }

  /**
   * 4. Unified Bonus Utilization Gatekeeper:
   * Enforces:
   * - 100% Verification (Gate 1)
   * - Fincra Provisioned Bank Account (Gate 2)
   * - Bonus Milestone & Thresholds (Gate 3):
   *     • Withdrawal: minimum ₦5,000 bonus milestone required
   *     • Airtime / Bills / Utilities: minimum ₦3,000 bonus milestone required
   */
  public static async validateBonusUtilization(
    user: StoredUser | null,
    amountRequested: number,
    profile?: any,
    usageType: 'withdrawal' | 'bill' | 'swap' | 'escrow' = 'withdrawal'
  ): Promise<BonusUtilizationResult> {
    // Normalize usageType to lowercase to prevent type-confusion bypasses
    // (e.g. 'SWAP' passed at runtime would skip the swap-prohibition block)
    usageType = (usageType as string).toLowerCase() as typeof usageType;

    const cleanEmail = (user?.email || profile?.email || '').toLowerCase().trim();

    if (this.isAdmin(cleanEmail, user || undefined)) {
      return {
        allowed: true,
        bonusDrawn: 0,
        organicCashBalance: 999999999,
        promotionalBonusTotal: 0,
        remainingToMilestone: 0
      };
    }

    if (!amountRequested || amountRequested <= 0) {
      return {
        allowed: false,
        error: 'A valid amount greater than 0 is required.',
        statusCode: 400,
        bonusDrawn: 0,
        organicCashBalance: 0,
        promotionalBonusTotal: 0,
        remainingToMilestone: 0
      };
    }

    // Baseline minimum withdrawal is ₦100 for all users (direct or external funding)
    if (usageType === 'withdrawal' && amountRequested < 100) {
      return {
        allowed: false,
        error: 'The minimum bank withdrawal amount is ₦100 for direct or external funding.',
        statusCode: 400,
        bonusDrawn: 0,
        organicCashBalance: 0,
        promotionalBonusTotal: 0,
        remainingToMilestone: 0
      };
    }

    const balances = await this.getBonusAndCashBalances(cleanEmail, user, profile);
    const { totalBalance, promotionalBonusTotal, organicCashBalance, cumulativeBonusEarned, bonusMilestoneUnlocked } = balances;

    if (totalBalance < amountRequested) {
      const _insuffThreshold = usageType === 'withdrawal' ? 5000 : 3000;
      return {
        allowed: false,
        error: `Insufficient wallet balance. You have ₦${totalBalance.toLocaleString()}, but ₦${amountRequested.toLocaleString()} is required.`,
        statusCode: 400,
        bonusDrawn: 0,
        organicCashBalance,
        promotionalBonusTotal,
        remainingToMilestone: Math.max(0, _insuffThreshold - cumulativeBonusEarned)
      };
    }

    const bonusDrawn = Math.max(0, amountRequested - organicCashBalance);

    // If utilizing purely personal deposited organic cash
    if (bonusDrawn <= 0) {
      // For bank withdrawals, even organic cash requires 100% verification and Fincra account
      if (usageType === 'withdrawal') {
        const verCheck = this.isUser100PercentVerified(user, profile);
        if (!verCheck.verified) {
          return {
            allowed: false,
            error: verCheck.reason || '100% Identity Verification (KYC/KYB) is required before withdrawing funds.',
            statusCode: 403,
            bonusDrawn: 0,
            organicCashBalance,
            promotionalBonusTotal,
            remainingToMilestone: 0
          };
        }

        const accCheck = this.hasFincraProvisionedAccount(user, profile);
        if (!accCheck.hasAccount) {
          return {
            allowed: false,
            error: accCheck.reason || 'A provisioned Fincra bank account is required before requesting withdrawals.',
            statusCode: 403,
            bonusDrawn: 0,
            organicCashBalance,
            promotionalBonusTotal,
            remainingToMilestone: 0
          };
        }
      }

      return {
        allowed: true,
        bonusDrawn: 0,
        organicCashBalance,
        promotionalBonusTotal,
        remainingToMilestone: 0
      };
    }

    // --- USER IS ATTEMPTING TO UTILISE BONUS FUNDS ---

    // 1. Mandatory 100% Verification Gate
    const verCheck = this.isUser100PercentVerified(user, profile);
    if (!verCheck.verified) {
      const blockMsg = verCheck.reason || 'Bonus funds cannot be utilised until your account is 100% verified (KYC/KYB with valid BVN/NIN or CAC).';
      NotificationDispatcher.dispatch({
        userId: user?.id,
        email: cleanEmail,
        title: '🔒 Verification Required',
        category: 'wallet',
        message: blockMsg
      }).catch(() => {});
      return {
        allowed: false,
        error: blockMsg,
        statusCode: 403,
        bonusDrawn,
        organicCashBalance,
        promotionalBonusTotal,
        remainingToMilestone: Math.max(0, (usageType === 'withdrawal' ? 5000 : 3000) - cumulativeBonusEarned)
      };
    }

    // 2. Mandatory Fincra Provisioned Bank Account Gate
    const accCheck = this.hasFincraProvisionedAccount(user, profile);
    if (!accCheck.hasAccount) {
      const blockMsg = accCheck.reason || 'Bonus funds cannot be utilised until a dedicated Fincra bank account (Wema Bank NUBAN) has been provisioned to your profile.';
      NotificationDispatcher.dispatch({
        userId: user?.id,
        email: cleanEmail,
        title: '🏦 Bank Account Required',
        category: 'wallet',
        message: blockMsg
      }).catch(() => {});
      return {
        allowed: false,
        error: blockMsg,
        statusCode: 403,
        bonusDrawn,
        organicCashBalance,
        promotionalBonusTotal,
        remainingToMilestone: Math.max(0, (usageType === 'withdrawal' ? 5000 : 3000) - cumulativeBonusEarned)
      };
    }

    // 3. Prohibit Crypto / USDT Conversion of promotional bonus
    if (usageType === 'swap') {
      return {
        allowed: false,
        error: `Insufficient swappable Naira balance. Promotional bonuses (₦${promotionalBonusTotal.toLocaleString()}) cannot be converted to USDT. Only personal organic cash balances (₦${organicCashBalance.toLocaleString()}) can be swapped.`,
        statusCode: 400,
        bonusDrawn,
        organicCashBalance,
        promotionalBonusTotal,
        remainingToMilestone: Math.max(0, 3000 - cumulativeBonusEarned)
      };
    }

    // 4. In-App Bonus Spend Cap: Maximum ₦3,000 bonus amount to spend in-app (Bills, Utilities, Airtime, Data, Escrow)
    if ((usageType === 'bill' || usageType === 'escrow') && bonusDrawn > 3000) {
      const personalCashNeeded = bonusDrawn - 3000;
      const blockMsg = 'The maximum bonus amount that can be spent in-app is ₦3,000 per transaction. Please cover the remaining balance with your personal cash.';
      NotificationDispatcher.dispatch({
        userId: user?.id,
        email: cleanEmail,
        title: '⚠️ Bonus Spend Limit Exceeded',
        category: 'wallet',
        message: blockMsg
      }).catch(() => {});
      return {
        allowed: false,
        error: blockMsg,
        statusCode: 400,
        bonusSpendCapped: true,
        maxBonusSpend: 3000,
        personalCashNeeded,
        remainingPersonalCashNeeded: personalCashNeeded,
        bonusDrawn,
        organicCashBalance,
        promotionalBonusTotal,
        remainingToMilestone: Math.max(0, 3000 - cumulativeBonusEarned)
      };
    }

    // 5. Withdrawal Minimum for Bonus Funds: Enforce ₦5,000 minimum withdrawal
    if (usageType === 'withdrawal' && amountRequested < 5000) {
      const blockMsg = 'The minimum withdrawal amount for bonus funds is ₦5,000. (Direct or external deposits can be withdrawn from ₦100).';
      NotificationDispatcher.dispatch({
        userId: user?.id,
        email: cleanEmail,
        title: '💰 Bonus Withdrawal Blocked',
        category: 'wallet',
        message: blockMsg
      }).catch(() => {});
      return {
        allowed: false,
        error: blockMsg,
        statusCode: 400,
        bonusDrawn,
        organicCashBalance,
        promotionalBonusTotal,
        remainingToMilestone: Math.max(0, 5000 - cumulativeBonusEarned)
      };
    }

    // 6. Mandatory Bonus Milestone Requirement (split by usageType)
    // Withdrawal: ₦5,000 minimum | Airtime / Bills / Utilities / Escrow: ₦3,000 minimum
    const bonusMinimum = usageType === 'withdrawal' ? 5000 : 3000;
    if (!bonusMilestoneUnlocked || cumulativeBonusEarned < bonusMinimum) {
      const remainingToUnlock = Math.max(0, bonusMinimum - cumulativeBonusEarned);
      const thresholdLabel = usageType === 'withdrawal' ? '₦5,000' : '₦3,000';
      const actionLabel = usageType === 'withdrawal' ? 'withdraw bonus funds' : 'use bonus for in-app services';
      const blockMsg = `To ${actionLabel}, you need to achieve ${thresholdLabel} in cumulative bonus earnings. Cumulative bonus earned: ₦${cumulativeBonusEarned.toLocaleString()}, remaining to unlock: ₦${remainingToUnlock.toLocaleString()}. Refer friends to reach this milestone faster! Available personal cash: ₦${organicCashBalance.toLocaleString()}.`;
      NotificationDispatcher.dispatch({
        userId: user?.id,
        email: cleanEmail,
        title: usageType === 'withdrawal' ? '💸 Bonus Withdrawal Locked' : '📱 Bonus Spend Locked',
        category: 'wallet',
        message: blockMsg
      }).catch(() => {});
      return {
        allowed: false,
        error: blockMsg,
        statusCode: 400,
        bonusDrawn,
        organicCashBalance,
        promotionalBonusTotal,
        remainingToMilestone: remainingToUnlock
      };
    }

    // 7. Corporate Partner Commercial Activity Gate (₦5,000 Milestone Enforcement)
    // To withdraw ₦5,000 bonus, partners must perform real activity: have at least 1 verified property listing
    const isPartnerUser = user?.role === 'partner' || user?.role === 'broker' || Boolean(user?.cacNumber || profile?.cac_number);
    if (isPartnerUser && usageType === 'withdrawal') {
      let partnerHasListing = false;
      if (supabase) {
        try {
          const { data: props } = await supabase
            .from('properties')
            .select('id')
            .or(`owner_id.eq.${user?.id || ''},owner_id.eq.${profile?.id || ''}`)
            .limit(1);
          if (props && props.length > 0) partnerHasListing = true;
        } catch (_) {}
      }

      if (!partnerHasListing) {
        const partnerBlockMsg = 'To withdraw your ₦20,000 Partner Bounty, your corporate firm must add at least 1 verified property listing with signed mandate and utility bill. Upload your property to unlock immediate withdrawal!';
        NotificationDispatcher.dispatch({
          userId: user?.id,
          email: cleanEmail,
          title: '🏢 Mandate Listing Required',
          category: 'wallet',
          message: partnerBlockMsg
        }).catch(() => {});
        return {
          allowed: false,
          error: partnerBlockMsg,
          statusCode: 400,
          bonusDrawn,
          organicCashBalance,
          promotionalBonusTotal,
          remainingToMilestone: 0
        };
      }
    }

    return {
      allowed: true,
      bonusDrawn,
      organicCashBalance,
      promotionalBonusTotal,
      remainingToMilestone: 0
    };
  }

  /**
   * Automatically credits the ₦20,000 Verified Partner Mandate Bounty
   * when Admin approves a property that includes both a title mandate and utility bill.
   * Idempotent: Can only be paid once per partner/firm.
   */
  public static async creditPartnerMandateBounty(partnerIdOrEmail: string, propertyId: string, propertyTitle: string): Promise<boolean> {
    try {
      const clean = (partnerIdOrEmail || '').toLowerCase().trim();
      let user = (await UserStore.findByEmail(clean)) || (await UserStore.findById(clean));

      // Fetch profile from Supabase if not found locally
      if (!user && supabase) {
        const { data: prof } = await supabase
          .from('profiles')
          .select('*')
          .or(`id.eq.${clean},email.eq.${clean}`)
          .maybeSingle();
        if (prof) {
          user = {
            id: prof.id,
            email: prof.email,
            fullName: prof.full_name || prof.business_name || 'Rentilly Partner',
            phoneNumber: prof.phone_number || '',
            role: prof.role || 'partner',
            isVerified: prof.is_verified,
            bvnVerified: prof.bvn_verified,
            accountNumber: prof.account_number,
            bankName: prof.bank_name || 'Wema Bank',
            walletBalance: Number(prof.wallet_balance || 0),
            createdAt: prof.created_at
          } as any;
        }
      }

      if (!user) {
        console.warn(`[creditPartnerMandateBounty] ⚠️ User ${partnerIdOrEmail} not found`);
        return false;
      }

      const email = user.email.toLowerCase().trim();

      // Check role: strictly Corporate / Verified Partner (NOT direct landlord or renter)
      const role = (user.role || '').toLowerCase();
      const hasCac = Boolean((user as any).cacNumber || (user as any).cac_number || (user as any).businessName || (user as any).business_name);
      const isPartner = role === 'partner' || role === 'corporate_partner' || hasCac;

      if (!isPartner) {
        console.log(`[creditPartnerMandateBounty] ℹ️ User ${email} is not a partner (role: ${role}). ₦20,000 Mandate Bounty is exclusively for Corporate Partners.`);
        return false;
      }

      // Idempotency: Check if partner has already received the ₦20,000 mandate bounty
      const existingTxs = await TransactionStore.getTransactionsByEmail(email);
      const alreadyCredited = existingTxs.some(t =>
        (t.reference && t.reference.startsWith('RNT-BOUNTY-MANDATE-')) ||
        (t.title && t.title.includes('₦20,000 Verified Partner Mandate Bounty')) ||
        (t.description && t.description.includes('First Property Mandate Bounty'))
      );

      if (alreadyCredited) {
        console.log(`[creditPartnerMandateBounty] ℹ️ Partner ${email} already received their ₦20,000 first mandate bounty.`);
        return false;
      }

      // Also check cloud system_configs for guaranteed permanence
      if (supabase) {
        try {
          const { data: configCheck } = await supabase
            .from('system_configs')
            .select('id')
            .eq('id', `bounty_mandate_${user.id}`)
            .maybeSingle();
          if (configCheck) {
            console.log(`[creditPartnerMandateBounty] ℹ️ Cloud record exists for partner ${email} bounty.`);
            return false;
          }
        } catch (_) {}
      }

      // Mandate & Utility Bill Verification:
      let propRecord: any = AdminDataStore.getPropertyById(propertyId);
      let kypRecord: any = AdminDataStore.getKYP().find(k => k.propertyId === propertyId || k.id === propertyId);

      if ((!propRecord || !kypRecord) && supabase) {
        try {
          if (!propRecord) {
            const { data: pData } = await supabase.from('properties').select('*').eq('id', propertyId).maybeSingle();
            if (pData) propRecord = pData;
          }
          if (!kypRecord) {
            const { data: kData } = await supabase.from('kyp_verifications').select('*').eq('property_id', propertyId).maybeSingle();
            if (kData) kypRecord = kData;
          }
        } catch (_) {}
      }

      const hasMandate = Boolean(
        propRecord?.powerOfAttorneyUrl ||
        propRecord?.power_of_attorney_url ||
        propRecord?.mandateRef ||
        propRecord?.mandate_ref ||
        (kypRecord?.titleDocumentUrls && kypRecord.titleDocumentUrls.length > 0) ||
        (kypRecord?.title_document_urls && kypRecord.title_document_urls.length > 0) ||
        kypRecord?.title_document_number ||
        kypRecord?.titleDocumentNumber
      );

      const hasUtility = Boolean(
        propRecord?.electricityBillUrl ||
        propRecord?.electricity_bill_url ||
        propRecord?.utilityBillUrl ||
        propRecord?.utility_bill_url ||
        kypRecord?.utilityBillUrl ||
        kypRecord?.utility_bill_url ||
        kypRecord?.discoMeterNumber ||
        kypRecord?.disco_meter_number
      );

      if (!hasMandate || !hasUtility) {
        console.warn(`[creditPartnerMandateBounty] ⚠️ Property ${propertyId} missing mandate or utility bill (mandate: ${hasMandate}, utility: ${hasUtility})`);
        return false;
      }

      const bountyAmount = this.PARTNER_MANDATE_BOUNTY; // ₦20,000
      const prevBal = Number(user.walletBalance || 0);
      user.walletBalance = prevBal + bountyAmount;
      await UserStore.upsertUserForced(user);

      const now = new Date().toISOString();

      // Sync Supabase wallet balance
      if (supabase) {
        try {
          await supabase.from('profiles').update({
            wallet_balance: user.walletBalance,
            updated_at: now
          }).eq('id', user.id);

          await supabase.from('system_configs').upsert({
            id: `bounty_mandate_${user.id}`,
            data: {
              partnerId: user.id,
              partnerEmail: email,
              propertyId,
              propertyTitle,
              amount: bountyAmount,
              creditedAt: now
            },
            updated_at: now
          });
        } catch (dbErr: any) {
          console.error('[creditPartnerMandateBounty] Supabase update error:', dbErr?.message);
        }
      }

      // Record transaction
      const txRef = `RNT-BOUNTY-MANDATE-${Date.now().toString().slice(-6)}`;
      await TransactionStore.addTransaction({
        id: `tx_bounty_${Date.now()}`,
        userId: user.id,
        email,
        title: '🎉 ₦20,000 Verified Partner Mandate Bounty',
        description: `Certified First Property Mandate Bounty: "${propertyTitle}" (Title Mandate + Utility Bill Approved)`,
        type: 'credit',
        category: 'promotional_bonus',
        amount: bountyAmount,
        currency: 'NGN',
        isCredit: true,
        reference: txRef,
        status: 'SUCCESSFUL',
        date: now
      });

      if (supabase) {
        try {
          await supabase.from('wallet_transactions').insert({
            user_id: user.id,
            email,
            amount: bountyAmount,
            type: 'credit',
            category: 'promotional_bonus',
            narration: `Certified First Property Mandate Bounty: "${propertyTitle}" (Title Mandate + Utility Bill Approved)`,
            reference: txRef,
            flw_ref: txRef,
            tx_ref: txRef,
            status: 'successful',
            created_at: now
          });
        } catch (_) {}
      }

      // Dispatch Celebration Notification & Email
      NotificationDispatcher.dispatch({
        userId: user.id,
        email,
        userName: user.fullName,
        title: '🎉 ₦20,000 Partner Bounty Credited!',
        category: 'wallet',
        message: `Congratulations! Your property mandate for "${propertyTitle}" has been certified and verified by Rentilly Compliance. ₦20,000 has been credited to your Wema Bank Operating Vault and is immediately available for withdrawal!`
      }).catch(() => {});

      console.log(`[creditPartnerMandateBounty] 🚀 Successfully paid ₦20,000 Mandate Bounty to ${email} for listing ${propertyId}!`);
      return true;
    } catch (err: any) {
      console.error('[creditPartnerMandateBounty] Error:', err);
      return false;
    }
  }
}
