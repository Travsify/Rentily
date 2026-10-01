import { supabase } from '../supabaseClient';
import { UserStore, StoredUser } from './userStore';
import { TransactionStore } from './transactionStore';
import { NotificationDispatcher } from './notificationDispatcher';

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
        const partnerBlockMsg = 'To withdraw your ₦5,000 Partner Bonus, your corporate firm must add at least 1 verified property listing or mandate to Rentilly. Upload a property to unlock immediate withdrawal!';
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
}
