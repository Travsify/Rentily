/**
 * Treasury Circuit Breaker & Syndicate Account Lock
 * 
 * 1. Global Hourly Velocity Cap: Limits automated disbursements across the platform.
 * 2. Syndicate Destination Lock: Ensures 1 bank account = 1 unique user profile.
 * 3. Permanent Fraud Syndicate Blacklist: Blocks known malicious payout accounts.
 */

import { supabase } from '../supabaseClient';
import { TransactionStore } from './transactionStore';

// Hourly cap for automated disbursements across the entire platform (₦100,000 per hour)
const GLOBAL_HOURLY_DISBURSEMENT_CAP = 100000;

// Permanent Blacklist of bank accounts identified in the September 27 bot exploit
const FLAGGED_SYNDICATE_ACCOUNTS = new Set([
  '7067990054', // ABDULMUTALIB ENESI AHMADU (Repeat hit x3)
  '8085627638', // JIMADA SAGIRU JIMADA (Repeat hit x2)
  '8143375948', // OLATUNJI DAVID ABODUNRIN
  '8138654529', // ANDREW AKPORS GOSPEL
  '8105068259', // abdulwadud oyetunji badrudeen
  '8132065611', // MUHAMMAD YUSUF
  '9077733116', // AHMED ABU ABUBAKAR
  '8108775472', // salihu idris
  '8107442282', // IKECHUKWU PHILIP EZEIGWE
  '9138972650', // ABDULAHI ADEBOLA ABDUSSALAM
  '8134544337', // SAMUEL BOLUWATIFE OLADOYE
  '9153052787', // SAMEUL OLUWASEUN ABRAHAM
  '9036560625', // MOSHOOD ABIOLA OWOIYA
  '7038526982', // ABUBAKAR SADIQ AHMAD
  '8169047906', // ABDULSALAM UMAR
  '8039699512', // EMMANUEL OCHOYO AUDU
  '7026289332', // BILAL HAMIDU HUSSAINI
  '7042605352', // OPEYEMI RIDWAN AKANDE
  '9017301312', // PIUS PRINCE OLORUNFEMI
  '7069390539', // ABUBAKAR ABDULLAHI
  '9076664177', // ABDULRAHMAN SANUSI
  '7035895450', // ABDULLAHI Sani Bala
  '2084798480', // NAIMA ALIYU
  '7046669291', // ALAMIN ABDULKADIR IBRAHIM
  '7025971162', // EMMANUEL CHUKWUMA ABANDY
  '8147684968', // SHUAIBU ABDULLAHI
  '9070025544', // EMMANUEL WILFRIED KANOUO
  '8024468111', // BANCHI JOSHUA MANDA
  '7063079026', // AHMAD ABUBAKAR
  '7025373083', // MAHMUD MUHAMMAD
  '9068774448', // JACHIKE MIRACLE OGBUONYE
  '8053080385'  // SEGUN JOSHUA OLADIPO
]);

interface HourlyDisbursementRecord {
  amount: number;
  timestamp: number;
}

// In-memory rolling window
const _recentDisbursements: HourlyDisbursementRecord[] = [];

export class TreasuryCircuitBreaker {
  /**
   * Evaluates if requested payout violates global platform velocity cap
   */
  static async checkHourlyDisbursementVelocity(requestedAmount: number): Promise<{
    allowed: boolean;
    currentHourlyTotal: number;
    limit: number;
    remaining: number;
  }> {
    const oneHourAgo = Date.now() - (60 * 60 * 1000);

    // Prune in-memory records older than 1 hour
    while (_recentDisbursements.length > 0 && _recentDisbursements[0].timestamp < oneHourAgo) {
      _recentDisbursements.shift();
    }

    let currentHourlyTotal = _recentDisbursements.reduce((sum, r) => sum + r.amount, 0);

    // Also verify against Supabase wallet_transactions in the last hour
    if (supabase) {
      try {
        const isoOneHourAgo = new Date(oneHourAgo).toISOString();
        const { data: dbTxs } = await supabase
          .from('wallet_transactions')
          .select('amount')
          .eq('type', 'debit')
          .gte('created_at', isoOneHourAgo);

        if (Array.isArray(dbTxs) && dbTxs.length > 0) {
          const dbTotal = dbTxs.reduce((sum, t) => sum + Number(t.amount || 0), 0);
          currentHourlyTotal = Math.max(currentHourlyTotal, dbTotal);
        }
      } catch (_) {}
    }

    const remaining = Math.max(0, GLOBAL_HOURLY_DISBURSEMENT_CAP - currentHourlyTotal);
    const allowed = (currentHourlyTotal + requestedAmount) <= GLOBAL_HOURLY_DISBURSEMENT_CAP;

    return {
      allowed,
      currentHourlyTotal,
      limit: GLOBAL_HOURLY_DISBURSEMENT_CAP,
      remaining
    };
  }

  /**
   * Records a successful disbursement to the rolling window
   */
  static recordDisbursement(amount: number): void {
    _recentDisbursements.push({
      amount,
      timestamp: Date.now()
    });
  }

  /**
   * Verifies destination bank account against syndicate blacklist and uniqueness constraints
   */
  static async verifyDestinationAccount(
    accountNumber: string,
    userEmail: string
  ): Promise<{ allowed: boolean; reason?: string }> {
    const cleanAcc = (accountNumber || '').replace(/[^0-9]/g, '').trim();
    const cleanEmail = (userEmail || '').toLowerCase().trim();

    if (!cleanAcc || cleanAcc.length < 8) {
      return { allowed: false, reason: 'Invalid destination bank account number.' };
    }

    // 1. Check permanent fraud syndicate blacklist
    if (FLAGGED_SYNDICATE_ACCOUNTS.has(cleanAcc)) {
      console.warn(`[Security Alert] Blocked withdrawal attempt to blacklisted syndicate account: ${cleanAcc} by ${cleanEmail}`);
      return {
        allowed: false,
        reason: 'This destination account has been flagged by our security Sentinel for policy violations and cannot receive funds.'
      };
    }

    // 2. Enforce 1 Bank Account = 1 Rentilly User (Syndicate Isolation)
    if (supabase) {
      try {
        const { data: matchedTxs } = await supabase
          .from('wallet_transactions')
          .select('email, narration')
          .like('narration', `%${cleanAcc}%`)
          .neq('email', cleanEmail)
          .limit(1);

        if (Array.isArray(matchedTxs) && matchedTxs.length > 0) {
          const priorEmail = matchedTxs[0].email;
          console.warn(`[Syndicate Block] Destination account ${cleanAcc} already used by ${priorEmail}. Blocked for ${cleanEmail}`);
          return {
            allowed: false,
            reason: 'This bank account is already associated with another Rentilly user profile. To prevent syndicate abuse, each bank account may only be linked to a single verified user.'
          };
        }
      } catch (_) {}
    }

    return { allowed: true };
  }
}
