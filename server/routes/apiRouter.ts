import { Router } from 'express';
import * as authController from '../controllers/authController';
import * as propertyController from '../controllers/propertyController';
import * as kypController from '../controllers/kypController';
import * as inspectionController from '../controllers/inspectionController';
import * as escrowController from '../controllers/escrowController';
import * as legalController from '../controllers/legalController';
import * as analyticsController from '../controllers/analyticsController';
import * as verificationController from '../controllers/verificationController';
import * as paymentController from '../controllers/paymentController';
import * as fraudController from '../controllers/fraudController';
import * as otpController from '../controllers/otpController';
import * as rnplController from '../controllers/rnplController';
import * as supportController from '../controllers/supportController';
import * as feeController from '../controllers/feeController';
import * as ledgerController from '../controllers/ledgerController';
import * as chatOversightController from '../controllers/chatOversightController';
import * as broadcastController from '../controllers/broadcastController';
import * as cautionController from '../controllers/cautionController';
import * as legalNoticesController from '../controllers/legalNoticesController';
import * as renewalController from '../controllers/renewalController';
import * as reconciliationController from '../controllers/reconciliationController';
import * as featureFlagController from '../controllers/featureFlagController';
import { isSupabaseConfigured, reconfigureSupabase, supabase } from '../supabaseClient';
import { IdentitypassService } from '../services/identitypassService';
import { FlutterwaveService } from '../services/flutterwaveService';
export const apiRouter = Router();

// 1. Health & Third-Party Service Status
apiRouter.get('/health', (_req, res) => {
  res.json({
    status: 'healthy',
    platform: 'Rentilly Admin & Core API',
    version: '1.0.0',
    supabaseConnected: isSupabaseConfigured(),
    identitypassConfigured: IdentitypassService.isConfigured(),
    flutterwaveConfigured: FlutterwaveService.isConfigured(),
    timestamp: new Date().toISOString()
  });
});

// 1a. Dynamic Supabase Configuration & Validation
apiRouter.post('/config/supabase', async (req, res) => {
  try {
    const { url, anonKey, serviceRoleKey } = req.body;
    const keyToUse = (serviceRoleKey || anonKey || '').trim();
    const cleanUrl = (url || '').trim();

    if (!cleanUrl || !keyToUse) {
      return res.status(400).json({ error: 'Supabase URL and API Key are required.' });
    }

    const configured = reconfigureSupabase(cleanUrl, keyToUse);
    if (!configured || !supabase) {
      return res.status(400).json({ error: 'Invalid URL or Key format. URL must start with https://.' });
    }

    // Ping Supabase
    try {
      const { error } = await supabase.from('users').select('id').limit(1);
      return res.json({
        success: true,
        connected: !error,
        message: error ? `Connected with note: ${error.message}` : 'Connected to Supabase PostgreSQL successfully!'
      });
    } catch (pingErr: any) {
      return res.json({
        success: true,
        connected: false,
        message: `Connection test note: ${pingErr.message}`
      });
    }
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

// 1b. Debug: verify AdminDataStore seed data loading (lazy import to avoid circular crash)
apiRouter.get('/debug/store', (_req, res) => {
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const { AdminDataStore } = require('../services/adminDataStore');
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const { TransactionStore } = require('../services/transactionStore');
    const properties = AdminDataStore.getProperties();
    const kyp = AdminDataStore.getKYP();
    const inspections = AdminDataStore.getInspections();
    const legal = AdminDataStore.getLegalAgreements();
    const walletTxs = TransactionStore.getAllTransactions();
    res.json({
      propertiesCount: properties.length,
      kypCount: kyp.length,
      inspectionsCount: inspections.length,
      legalCount: legal.length,
      walletTransactionsCount: walletTxs.length,
      firstProperty: properties[0]?.title || 'none',
      firstKYP: kyp[0]?.propertyTitle || 'none',
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message, stack: err.stack });
  }
});

// 2. Authentication & Multi-Channel OTP (Resend + Twilio)
apiRouter.post('/auth/register', authController.register);
apiRouter.post('/auth/login', authController.login);
apiRouter.post('/auth/login-otp', authController.loginWithOtp);
apiRouter.get('/auth/me', authController.getMe);
apiRouter.get('/users', authController.listUsers);
apiRouter.post('/auth/send-otp', otpController.sendOtp);
apiRouter.post('/auth/verify-otp', otpController.verifyOtp);
apiRouter.post('/auth/forgot-password/request-otp', authController.requestPasswordResetOtp);
apiRouter.post('/auth/forgot-password/reset', authController.resetPasswordWithOtp);
apiRouter.post('/auth/change-password', authController.changePassword);
apiRouter.patch('/auth/update-profile', authController.updateProfile); // update name/phone without re-registering
apiRouter.post('/users/create', authController.adminCreateUser);
apiRouter.post('/users/:id/reset-password', authController.adminResetPassword);
apiRouter.patch('/users/:id/role', authController.adminUpdateUserRole);
apiRouter.get('/auth/tier-status', authController.getTierStatus);
apiRouter.post('/auth/upgrade-tier2', authController.upgradeTier2);
apiRouter.post('/auth/upgrade-tier3', authController.upgradeTier3);

// 3. Analytics & GMV
apiRouter.get('/analytics/metrics', analyticsController.getMetrics);

// 4. Properties
apiRouter.get('/properties', propertyController.getProperties);
apiRouter.get('/properties/:id', propertyController.getPropertyById);
apiRouter.post('/properties', propertyController.createProperty);
apiRouter.patch('/properties/:id/status', propertyController.updatePropertyStatus);

// 5. KYP Verification Desk
apiRouter.get('/kyp/records', kypController.getKYPRecords);
apiRouter.post('/kyp/:id/review', kypController.reviewKYP);

// 6. Identitypass / Prembly Verification (NIN, BVN, CAC) & Maplerad Banking & Card Provisioning
apiRouter.post('/verification/verify-and-provision', verificationController.verifyAndProvision);
apiRouter.post('/verification/sync-nuban', verificationController.syncNuban);
apiRouter.post('/verify/nin', verificationController.verifyNIN);
apiRouter.post('/verify/bvn', verificationController.verifyBVN);
apiRouter.post('/verify/cac', verificationController.verifyCAC);
apiRouter.get('/verification/rekyc-status', verificationController.getVerificationStatus);
apiRouter.post('/verification/complete-maplerad-kyc', verificationController.completeMapleradKyc);
apiRouter.post('/admin/request-rekyc', verificationController.requestReKyc);

// 7. Flutterwave Virtual Bank Accounts & Utility Bills
apiRouter.post('/payments/create-virtual-account', paymentController.createVirtualAccount);
apiRouter.post('/bills/validate-meter', paymentController.validateDiscoMeter);
apiRouter.post('/bills/purchase-electricity', paymentController.purchaseElectricityToken);
apiRouter.post('/payments/pay-bill', paymentController.payBill);
apiRouter.get('/payments/transactions', paymentController.getUserTransactions);
apiRouter.post('/webhooks/flutterwave', paymentController.flutterwaveWebhook);
apiRouter.post('/webhooks/maplerad', paymentController.mapleradWebhook);
apiRouter.post('/webhooks/paystack', paymentController.paystackWebhook);
apiRouter.post('/webhooks/korapay', paymentController.korapayWebhook);
apiRouter.post('/webhooks/fincra', paymentController.fincraWebhook);
apiRouter.get('/payments/vault-accounts', paymentController.getVaultAccounts);
apiRouter.post('/payments/provision-commercial-account', paymentController.provisionCommercialAccount);
apiRouter.post('/payments/fincra/initialize-escrow-deposit', paymentController.initializeHighValueDeposit);
apiRouter.get('/payments/fincra/verify/:reference', paymentController.verifyFincraPayment);
apiRouter.get('/payments/fincra/verify', paymentController.verifyFincraPayment);
apiRouter.post('/payments/korapay/initialize-escrow-deposit', paymentController.initializeHighValueDeposit);
apiRouter.get('/system/outbound-ip', async (req, res) => {
  try {
    const r = await fetch('https://api.ipify.org');
    const ip = await r.text();
    res.json({ outboundIp: ip });
  } catch (e: any) {
    res.status(500).json({ error: e.message });
  }
});

// 8. Paystack / Maplerad Bank Settlements, Balance Sync & Instant Withdrawals
apiRouter.get('/wallet/balance', paymentController.getWalletBalance);
apiRouter.get('/wallet/crypto-address', paymentController.getUserCryptoAddress);
apiRouter.get('/payments/paystack-banks', paymentController.getPaystackBanks);
apiRouter.get('/payments/resolve-account', paymentController.resolvePaystackAccount);
apiRouter.post('/payments/withdraw-paystack', paymentController.withdrawWithPaystack);
apiRouter.post('/payments/withdraw-crypto', paymentController.withdrawCrypto);
apiRouter.post('/payments/reconcile', paymentController.adminReconcileBalance);
apiRouter.post('/payments/register-and-credit', paymentController.adminRegisterAndCreditUser);
apiRouter.get('/fx/spread-rates', paymentController.getFxSpreadRates);
apiRouter.post('/fx/spread-rates', paymentController.updateFxSpreadConfig);
apiRouter.post('/wallet/swap', paymentController.executeCurrencySwap);

// 8. Fraud Blacklist & Rogue Agent Registry
apiRouter.get('/fraud/blacklist', fraudController.getBlacklist);
apiRouter.post('/fraud/blacklist', fraudController.addToBlacklist);
apiRouter.delete('/fraud/blacklist/:id', fraudController.deleteFromBlacklist);
apiRouter.post('/fraud/check', fraudController.checkBlacklist);

// 9. Inspections
apiRouter.get('/inspections', inspectionController.getInspections);
apiRouter.post('/inspections/book', inspectionController.bookInspection);
apiRouter.patch('/inspections/:id/status', inspectionController.updateInspectionStatus);

// 10. Escrow & Transactions
apiRouter.get('/escrow/transactions', escrowController.getTransactions);
apiRouter.get('/escrow/partner-commissions', escrowController.getPartnerCommissions);
apiRouter.post('/escrow/:id/release-payout', escrowController.releaseEscrowPayout);

// 11. Legal Agreements
apiRouter.get('/legal/agreements', legalController.getLegalAgreements);
apiRouter.post('/legal/generate-agreement', legalController.generateAgreement);

// 12. Partner & User Support / Dispute Tickets (legacy one-way tickets)
apiRouter.post('/support/tickets', supportController.submitTicket);
apiRouter.get('/support/tickets', supportController.listTickets);

// 12b. In-App Live Support Chat (Supabase realtime, two-way)
import * as supportChatController from '../controllers/supportChatController';
apiRouter.post('/support/conversations', supportChatController.createOrGetConversation);
apiRouter.get('/support/conversations', supportChatController.listConversations);
apiRouter.get('/support/conversations/user/:email', supportChatController.getUserConversations);
apiRouter.get('/support/conversations/:id/messages', supportChatController.getMessages);
apiRouter.post('/support/conversations/:id/messages', supportChatController.sendMessage);
apiRouter.patch('/support/conversations/:id', supportChatController.updateConversation);

// 12c. Support Agent Management (multi-agent team)
import * as supportAgentController from '../controllers/supportAgentController';
apiRouter.post('/support/agents', supportAgentController.createAgent);
apiRouter.get('/support/agents', supportAgentController.listAgents);
apiRouter.post('/support/agents/login', supportAgentController.loginAgent);
apiRouter.post('/support/agents/:id/heartbeat', supportAgentController.heartbeat);
apiRouter.patch('/support/agents/:id', supportAgentController.updateAgent);
apiRouter.get('/support/conversations/agent/:agentEmail', supportAgentController.getAgentConversations);

// 12d. Direct Tenant-Owner/Partner Messaging (Supabase-backed, two-way)
import * as directChatController from '../controllers/directChatController';
apiRouter.post('/direct-chat/conversations', directChatController.createOrGetConversation);
apiRouter.get('/direct-chat/conversations/tenant/:tenantId', directChatController.getTenantConversations);
apiRouter.get('/direct-chat/conversations/owner/:ownerId', directChatController.getOwnerConversations);
apiRouter.get('/direct-chat/conversations/:id/messages', directChatController.getMessages);
apiRouter.post('/direct-chat/conversations/:id/messages', directChatController.sendMessage);
apiRouter.patch('/direct-chat/conversations/:id', directChatController.updateConversation);
apiRouter.post('/direct-chat/scan', directChatController.scanMessage);
// Override the broken chat oversight endpoint to use real direct_messages data
apiRouter.get('/chat/oversight', directChatController.getFlaggedMessages);


// 13. Platform Fee & Tariff Configuration
apiRouter.get('/config/fees', feeController.getFees);
apiRouter.get('/platform/fees', feeController.getFees);
apiRouter.post('/config/fees', feeController.updateFees);

// 13b. Dynamic Remote Feature Flags & App Rollout
apiRouter.get('/config/features', featureFlagController.getFeatureFlagsHandler);
apiRouter.post('/config/features', featureFlagController.updateFeatureFlagsHandler);

// 14. Master Financial Ledger & Wallet Movement
apiRouter.get('/ledger/transactions', ledgerController.getMasterLedger);
apiRouter.get('/ledger/stats', ledgerController.getLedgerStats);
apiRouter.get('/bills/transactions', ledgerController.getUtilityTransactions);

// 15. Chat Oversight & Anti-Circumvention
apiRouter.get('/chat/oversight', chatOversightController.getChatOversight);

// 16. Broadcast & Push Communications
apiRouter.post('/broadcast/send', broadcastController.sendBroadcast);
apiRouter.get('/broadcast/history', broadcastController.getBroadcastHistory);

// 17. Caution Deposit & Move-Out Damage Claims
apiRouter.get('/caution/deposits', cautionController.getCautionDeposits);
apiRouter.post('/caution/claim', cautionController.submitDamageClaim);
apiRouter.post('/caution/resolve', cautionController.resolveCautionDeposit);

// 18. Statutory Tenancy Legal Notices Generator
apiRouter.post('/legal/statutory-notice', legalNoticesController.generateStatutoryNotice);
apiRouter.get('/legal/statutory-notices', legalNoticesController.listStatutoryNotices);

// 19. Lease Expiry & Tenancy Renewal Calendar
apiRouter.get('/renewals/upcoming', renewalController.getUpcomingRenewals);
apiRouter.post('/renewals/dispatch-reminder', renewalController.dispatchRenewalReminder);

// 20. Daily Banking Reconciliation Audit
apiRouter.get('/reconciliation/audit', reconciliationController.runReconciliationAudit);

// 21. Multi-Currency Global Vault
apiRouter.get('/wallet/multi-currency-accounts', paymentController.getMultiCurrencyAccounts);
apiRouter.post('/wallet/convert-currency', paymentController.convertVaultCurrency);
apiRouter.get('/wallet/fx-rates', paymentController.getFxRatesHandler);
apiRouter.post('/wallet/fx-rates', paymentController.updateFxRatesHandler);

// 22. Virtual Card Issuing & Management
apiRouter.get('/cards/pricing', paymentController.getCardPricingHandler);
apiRouter.post('/cards/pricing', paymentController.updateCardPricingHandler);
apiRouter.get('/cards/user-cards', paymentController.getUserCards);
apiRouter.get('/cards/all', paymentController.getAllCardsHandler);
apiRouter.post('/cards/create', paymentController.issueVirtualCard);
apiRouter.post('/cards/fund', paymentController.fundVirtualCard);
apiRouter.post('/cards/withdraw', paymentController.withdrawVirtualCard);
apiRouter.post('/cards/toggle-freeze', paymentController.toggleFreezeVirtualCard);
apiRouter.post('/cards/delete', paymentController.deleteVirtualCard);
apiRouter.post('/cards/set-pin', paymentController.setCardPin);
apiRouter.post('/cards/reveal-details', paymentController.revealCardDetails);
apiRouter.get('/cards/transactions/:cardId', paymentController.getCardTransactions);

// 23. Client Push & Email Notification Dispatch Trigger
apiRouter.post('/notifications/dispatch', paymentController.clientDispatchNotification);

// 24. Server-Encapsulated Notification Mutations
apiRouter.get('/notifications', paymentController.getUserNotifications);
apiRouter.post('/notifications/mark-read', paymentController.markNotificationRead);
apiRouter.post('/notifications/mark-all-read', paymentController.markAllNotificationsRead);

// 25. Server-Encapsulated OneSignal Player ID Registration
apiRouter.post('/users/onesignal-player', paymentController.registerOneSignalPlayer);

// 26. Dedicated Security Activity Alert Dispatch
apiRouter.post('/security/activity-alert', paymentController.clientDispatchNotification);

// 27. Outbound Server IP Utility (For Maplerad IP Whitelisting)
apiRouter.get('/admin/outbound-ip', async (_req, res) => {
  try {
    const ipRes = await fetch('https://api.ipify.org?format=json');
    const data = await ipRes.json();
    res.json({ status: true, outboundIp: data.ip, message: 'Current server public egress IP for Maplerad whitelist' });
  } catch (err: any) {
    res.status(500).json({ status: false, error: err.message });
  }
});

// 28. Automated Continuous Deployment Endpoint (Git pull -> Build -> PM2 reload)
import * as deployController from '../controllers/deployController';
apiRouter.post('/deploy', deployController.handleDeploy);
apiRouter.get('/deploy', deployController.handleDeploy);
apiRouter.get('/deploy/status', deployController.getDeployStatus);
apiRouter.get('/system/logs', deployController.getLogs);
apiRouter.get('/system/test-maplerad', deployController.testMaplerad);



