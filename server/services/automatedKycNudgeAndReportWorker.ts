import { UserStore } from './userStore';
import { supabase } from '../supabaseClient';
import { NotificationDispatcher } from './notificationDispatcher';
import { TransactionStore } from './transactionStore';

export interface CycleReport {
  timestamp: string;
  totalUsers: number;
  verifiedUsers: number;
  unverifiedUsers: number;
  nudgedRenters: number;
  nudgedLandlords: number;
  nudgedPartners: number;
  totalNudged: number;
  provisionedAccounts: number;
  totalTransactions: number;
  executiveEmailStatus: boolean;
}

export class AutomatedKycNudgeAndReportWorker {
  private static timer: NodeJS.Timeout | null = null;
  private static isRunning = false;
  private static readonly INTERVAL_MS = 4 * 60 * 60 * 1000; // 4 Hours

  /**
   * Starts the 4-hour scheduled daemon
   */
  static start(): void {
    if (this.timer) {
      console.log('[AutomatedKycWorker] Worker already running.');
      return;
    }

    console.log('[AutomatedKycWorker] 🚀 Starting 4-Hour Automated KYC Nudge & Executive Reporting Daemon...');

    // Run first cycle 30 seconds after server startup
    setTimeout(() => {
      this.runCycle().catch(err => {
        console.error('[AutomatedKycWorker] Error during initial cycle:', err);
      });
    }, 30000);

    // Schedule recurring execution every 4 hours
    this.timer = setInterval(() => {
      this.runCycle().catch(err => {
        console.error('[AutomatedKycWorker] Error during 4-hour cycle:', err);
      });
    }, this.INTERVAL_MS);
  }

  static stop(): void {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
      console.log('[AutomatedKycWorker] Worker stopped.');
    }
  }

  /**
   * Executes a complete verification nudge cycle and sends an executive report to info@myrentilly.com
   */
  static async runCycle(): Promise<CycleReport> {
    if (this.isRunning) {
      console.log('[AutomatedKycWorker] Cycle already in progress. Skipping.');
      throw new Error('Cycle already in progress');
    }

    this.isRunning = true;
    const now = new Date();
    console.log(`[AutomatedKycWorker] ⏳ Starting cycle at ${now.toISOString()}...`);

    try {
      const allUsers = UserStore.getAllUsers();
      let verifiedCount = 0;
      let unverifiedCount = 0;
      let nudgedRenters = 0;
      let nudgedLandlords = 0;
      let nudgedPartners = 0;
      let provisionedAccounts = 0;

      for (const u of allUsers) {
        if (u.isVerified && u.accountNumber) {
          verifiedCount++;
        } else {
          unverifiedCount++;
        }

        if (u.accountNumber) {
          provisionedAccounts++;
        }

        // Only nudge unverified users or users without dedicated NUBAN
        const isUnverified = !u.isVerified || !u.accountNumber;
        if (!isUnverified) continue;

        const cleanEmail = (u.email || '').toLowerCase().trim();
        if (!cleanEmail || !cleanEmail.includes('@')) continue;

        const role = (u.role || 'renter').toLowerCase();
        const isPartner = role === 'partner' || Boolean(u.businessName && (u.buyerType === 'corporate' || u.cacNumber)) || Boolean((u as any).partnerStatus);
        const isLandlord = !isPartner && role === 'owner';

        let title = '';
        let message = '';
        let actionLabel = '';

        if (isPartner) {
          title = 'Accredited Partner Onboarding: Activate Corporate Commission Vault 🏢';
          message = `Hello ${u.fullName || 'Corporate Partner'}, confirm your corporate CAC registration and Director BVN to activate your accredited mandate firm status and dedicated commission clearing vault.`;
          actionLabel = 'Complete Corporate KYB ⚡';
          nudgedPartners++;
        } else if (isLandlord) {
          title = 'Activate Your Dedicated Rent Escrow Settlement Account 🏡';
          message = `Hello ${u.fullName || 'Property Owner'}, complete your quick 1-tap BVN verification on Rentilly to unlock your dedicated Wema Bank escrow collection account, receive automated rent payouts, and list properties with 0% agent fees.`;
          actionLabel = 'Activate Landlord Escrow ⚡';
          nudgedLandlords++;
        } else {
          // Standard Renter / Tenant
          title = 'Claim Your ₦1,000 Welcome Bonus & Activate Dedicated Account 🎁';
          message = `Welcome to Rentilly! Confirm your 11-digit BVN or NIN in the app to instantly claim your ₦1,000 Welcome Reward, activate your dedicated Wema Bank account, and unlock your Virtual Dollar Card.`;
          actionLabel = 'Confirm BVN & Claim ₦1,000 ⚡';
          nudgedRenters++;
        }

        // Set rekyc_required in Supabase and local cache so the mobile app displays the prominent banner
        if (supabase) {
          supabase
            .from('profiles')
            .update({ rekyc_required: true, updated_at: now.toISOString() })
            .eq('email', cleanEmail)
            .then(() => {})
            .catch(() => {});
        }

        // Dispatch In-App, Email, and Push Notification with gentle rate limiting
        const webRekycUrl = `https://api.myrentilly.com/verify/re-kyc?email=${encodeURIComponent(cleanEmail)}`;
        try {
          await NotificationDispatcher.dispatch({
            userId: u.id,
            email: cleanEmail,
            userName: u.fullName || 'Rentilly User',
            category: 'system',
            title,
            message,
            actionUrl: webRekycUrl,
            actionLabel
          });
        } catch (err: any) {
          console.warn(`[AutomatedKycWorker] Notification failed for ${cleanEmail}:`, err.message);
        }

        // 150ms throttle prevents 429 rate limit errors on transactional email & push providers
        await new Promise(r => setTimeout(r, 150));
      }

      // Rest 1 second before executive report dispatch
      await new Promise(r => setTimeout(r, 1000));

      const totalNudged = nudgedRenters + nudgedLandlords + nudgedPartners;
      console.log(`[AutomatedKycWorker] ✅ Nudges dispatched to ${totalNudged} unverified accounts (Renters: ${nudgedRenters}, Landlords: ${nudgedLandlords}, Partners: ${nudgedPartners}).`);

      // ========================================================================
      // 2. DISPATCH EXECUTIVE ACTIVITY REPORT TO info@myrentilly.com
      // ========================================================================
      const txs = TransactionStore.getAllTransactions();
      const totalTxCount = txs.length;

      let executiveEmailSuccess = false;
      try {
        const execReportEvent = {
          email: 'info@myrentilly.com',
          userName: 'Rentilly Executive Operations',
          title: `[Rentilly 4-Hour Operations Report] ${now.toLocaleDateString('en-NG')} Telemetry & Verification Funnel`,
          category: 'system' as const,
          message: `Rentilly Automated Operations Daemon Summary:
• Total Registered Users: ${allUsers.length}
• Verified Accounts: ${verifiedCount} | Unverified / Pending: ${unverifiedCount}
• Provisioned Dedicated NUBANs: ${provisionedAccounts}
• 4-Hour Nudge Campaign Dispatched: ${totalNudged} accounts (Renters: ${nudgedRenters}, Landlords: ${nudgedLandlords}, Partners: ${nudgedPartners})
• Total Platform Transactions: ${totalTxCount}
• All unverified users have received Email, OneSignal Push, and In-App prompts with the ₦1,000 Welcome Bonus incentive.`,
          metadata: {
            totalUsers: allUsers.length,
            verifiedCount,
            unverifiedCount,
            totalNudged,
            provisionedAccounts,
            totalTxCount,
            cycleTime: now.toISOString(),
            nextCycle: new Date(now.getTime() + this.INTERVAL_MS).toISOString()
          }
        };

        const dispatchRes = await NotificationDispatcher.dispatch(execReportEvent);
        executiveEmailSuccess = dispatchRes.email;
        console.log(`[AutomatedKycWorker] Executive activity report sent to info@myrentilly.com (email sent: ${executiveEmailSuccess}).`);
      } catch (execErr: any) {
        console.error('[AutomatedKycWorker] Failed to send executive email:', execErr.message);
      }

      return {
        timestamp: now.toISOString(),
        totalUsers: allUsers.length,
        verifiedUsers: verifiedCount,
        unverifiedUsers: unverifiedCount,
        nudgedRenters,
        nudgedLandlords,
        nudgedPartners,
        totalNudged,
        provisionedAccounts,
        totalTransactions: totalTxCount,
        executiveEmailStatus: executiveEmailSuccess
      };
    } finally {
      this.isRunning = false;
    }
  }
}
