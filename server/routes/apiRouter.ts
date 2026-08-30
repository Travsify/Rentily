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
import { isSupabaseConfigured } from '../supabaseClient';
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

// 2. Authentication
apiRouter.post('/auth/login', authController.login);
apiRouter.get('/auth/me', authController.getMe);

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

// 6. Identitypass / Prembly Verification (NIN, BVN, CAC)
apiRouter.post('/verify/nin', verificationController.verifyNIN);
apiRouter.post('/verify/bvn', verificationController.verifyBVN);
apiRouter.post('/verify/cac', verificationController.verifyCAC);

// 7. Flutterwave Virtual Bank Accounts & Escrow Transfers
apiRouter.post('/payments/create-virtual-account', paymentController.createVirtualAccount);
apiRouter.post('/payments/transfer-landlord', paymentController.transferToLandlord);
apiRouter.get('/payments/banks', paymentController.getBanks);
apiRouter.post('/webhooks/flutterwave', paymentController.flutterwaveWebhook);

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
apiRouter.post('/escrow/:id/release-payout', escrowController.releaseEscrowPayout);

// 11. Legal Agreements
apiRouter.get('/legal/agreements', legalController.getLegalAgreements);
apiRouter.post('/legal/generate-agreement', legalController.generateAgreement);
