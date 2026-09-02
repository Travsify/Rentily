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
import { shippingRouter } from './shippingRouter';
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
apiRouter.get('/auth/me', authController.getMe);
apiRouter.get('/users', authController.listUsers);
apiRouter.post('/auth/send-otp', otpController.sendOtp);
apiRouter.post('/auth/verify-otp', otpController.verifyOtp);
apiRouter.post('/auth/change-password', authController.changePassword);

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

// 6. Identitypass / Prembly Verification (NIN, BVN, CAC) & Automated Flutterwave Issuance
apiRouter.post('/verification/verify-and-provision', verificationController.verifyAndProvision);
apiRouter.post('/verification/sync-nuban', verificationController.syncNuban);
apiRouter.post('/verify/nin', verificationController.verifyNIN);
apiRouter.post('/verify/bvn', verificationController.verifyBVN);
apiRouter.post('/verify/cac', verificationController.verifyCAC);

// 7. Flutterwave Virtual Bank Accounts & Utility Bills
apiRouter.post('/payments/create-virtual-account', paymentController.createVirtualAccount);
apiRouter.post('/bills/validate-meter', paymentController.validateDiscoMeter);
apiRouter.post('/bills/purchase-electricity', paymentController.purchaseElectricityToken);
apiRouter.post('/payments/pay-bill', paymentController.payBill);
apiRouter.get('/payments/transactions', paymentController.getUserTransactions);
apiRouter.post('/webhooks/flutterwave', paymentController.flutterwaveWebhook);

// 8. Paystack Bank Settlements, Balance Sync & Instant Withdrawals
apiRouter.get('/wallet/balance', paymentController.getWalletBalance);
apiRouter.get('/payments/paystack-banks', paymentController.getPaystackBanks);
apiRouter.get('/payments/resolve-account', paymentController.resolvePaystackAccount);
apiRouter.post('/payments/withdraw-paystack', paymentController.withdrawWithPaystack);
apiRouter.post('/payments/reconcile', paymentController.adminReconcileBalance);
apiRouter.post('/payments/register-and-credit', paymentController.adminRegisterAndCreditUser);

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

// 12. Rent Now Pay Later (RNPL) Direct Debit Financing
apiRouter.get('/rent-now-pay-later/eligibility/:userId', rnplController.checkEligibility);
apiRouter.post('/rent-now-pay-later/mandate', rnplController.submitMandate);

// 13. Cross-Border Multi-Carrier Shipping & Toy Manifest Engine (UK -> Dubai)
apiRouter.use('/shipping', shippingRouter);

// 14. Partner & User Support / Dispute Tickets
apiRouter.post('/support/tickets', supportController.submitTicket);
apiRouter.get('/support/tickets', supportController.listTickets);

