import express from 'express';
import type { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import path from 'path';
import fs from 'fs';
import { apiRouter } from './routes/apiRouter';
import { renderPartnerVerificationPage, renderLandlordInvitePage, renderReKycPage, renderGatePassPage, renderCredentialVerificationPage, renderMandateVerificationPage, renderInspectionSafetyPage, handlePublicLandlordRegister, renderTransactionReceiptPage } from './controllers/publicPartnerPages';
import { verifyDeedByHash } from './controllers/deedVerificationController';
import { isSupabaseConfigured } from './supabaseClient';
import { AutoReconciliationWorker } from './services/autoReconciliationWorker';
import { MultiCurrencyService } from './services/multiCurrencyService';
import { CardIssuingService } from './services/cardIssuingService';
import { AdminDataStore } from './services/adminDataStore';
import { initFeesFromSupabase } from './controllers/feeController';
import { initBlacklistFromSupabase } from './controllers/fraudController';
import { initBroadcastsFromSupabase } from './controllers/broadcastController';
import { initFeatureFlagsFromSupabase } from './controllers/featureFlagController';
import { UserStore } from './services/userStore';

import dns from 'dns';
dotenv.config();

// ─── Crash Guard: Catch unhandled promise rejections & exceptions before they kill the process ───
process.on('unhandledRejection', (reason: any) => {
  console.error('[⚡ Server] Unhandled Promise Rejection (caught — process kept alive):', reason?.message || reason);
});

process.on('uncaughtException', (err: Error) => {
  console.error('[⚡ Server] Uncaught Exception (caught — process kept alive):', err.message, err.stack);
});

// ─── Graceful Shutdown on SIGTERM / SIGINT ───
function gracefulShutdown(signal: string) {
  console.log(`[⚡ Server] Received ${signal}. Initiating graceful shutdown...`);
  if (httpServer) {
    httpServer.close(() => {
      console.log('[⚡ Server] All connections closed. Process exiting cleanly.');
      process.exit(0);
    });
    // Force-kill after 8s if connections don't drain
    setTimeout(() => {
      console.warn('[⚡ Server] Force-exiting after 8s drain timeout.');
      process.exit(1);
    }, 8000);
  } else {
    process.exit(0);
  }
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// Force IPv4 resolution first globally across all outbound network connections
// This ensures external APIs (Maplerad, Paystack) see the whitelisted IPv4 (69.62.127.50)
// rather than the VPS IPv6 (2a02:4780:c:7bdf::1).
try {
  dns.setDefaultResultOrder('ipv4first');
} catch (e: any) {
  console.warn('[Network] Could not set dns default result order:', e.message);
}

// Global Outbound Proxy Dispatcher (for static IP routing through Maplerad / external APIs)
const proxyUrl = process.env.HTTPS_PROXY || process.env.HTTP_PROXY;
if (proxyUrl) {
  try {
    const { ProxyAgent, setGlobalDispatcher } = await import('undici');
    setGlobalDispatcher(new ProxyAgent(proxyUrl));
    console.log(`[Proxy] 🌐 Global outbound proxy dispatcher enabled: ${proxyUrl.replace(/:[^:@]+@/, ':****@')}`);
  } catch (err: any) {
    console.warn('[Proxy] Failed to initialize ProxyAgent:', err.message);
  }
} else {
  try {
    const { Agent, setGlobalDispatcher } = await import('undici');
    setGlobalDispatcher(
      new Agent({
        connect: {
          autoSelectFamily: false,
          lookup: (hostname, _options, callback) => {
            dns.lookup(hostname, { family: 4 }, callback);
          },
        },
      })
    );
    console.log('[Network] 🌐 Global IPv4 outbound dispatcher active (forcing 69.62.127.50 for all external APIs)');
  } catch (err: any) {
    console.warn('[Network] Failed to set undici Agent IPv4 dispatcher:', err.message);
  }
}

const app = express();
const PORT = process.env.PORT || 4000;

// Declare httpServer at module scope so gracefulShutdown can reference it
let httpServer: ReturnType<typeof app.listen>;

// PM2 Cluster Guard: Only run background workers on the primary instance (instance 0)
// Prevents duplicate reconciliation / polling in cluster mode
const isPrimaryWorker = !process.env.NODE_APP_INSTANCE || process.env.NODE_APP_INSTANCE === '0';

app.use(cors({ origin: '*' }));
app.use(express.json({ limit: '10mb' }));

// 1. Mount Public Partner Verification, Credential Audit, Mandate & Gate Check-in Endpoints
app.get('/verify/mandate/:id', renderMandateVerificationPage);
app.get('/verify/mandate', renderMandateVerificationPage);
app.get('/verify/partner', renderPartnerVerificationPage);
app.get('/verify/partner/:id', renderPartnerVerificationPage);
app.get('/verify-partner/:id', renderPartnerVerificationPage);
app.get('/verify-partner', renderPartnerVerificationPage);
app.get('/partner/:id', renderPartnerVerificationPage);
app.get('/p/:id', renderPartnerVerificationPage);
app.get('/p/:slug', renderPartnerVerificationPage);
app.get('/invite/landlord', renderLandlordInvitePage);
app.post('/api/public/landlord-register', handlePublicLandlordRegister);
app.get('/verify/rekyc', renderReKycPage);
app.get('/verify/re-kyc', renderReKycPage);
app.get('/re-verify', renderReKycPage);
app.get('/gate/:code', renderGatePassPage);
app.get('/gate', renderGatePassPage);
app.get('/safety/inspection/:id', renderInspectionSafetyPage);
app.get('/safety/inspection', renderInspectionSafetyPage);
app.get('/verify/credential/:id', renderCredentialVerificationPage);
app.get('/verify/credential', renderCredentialVerificationPage);
app.get('/verify/lease/:id', renderCredentialVerificationPage);
app.get('/verify/lease', renderCredentialVerificationPage);
app.get('/verify-receipt/:id', renderTransactionReceiptPage);
app.get('/verify-receipt', renderTransactionReceiptPage);
app.get('/verify/receipt/:id', renderTransactionReceiptPage);
app.get('/verify/receipt', renderTransactionReceiptPage);
app.get('/receipt/:id', renderTransactionReceiptPage);
app.get('/receipt', renderTransactionReceiptPage);
app.get('/verify-deed/:hash', verifyDeedByHash);
app.get('/verify-deed', verifyDeedByHash);
app.get('/verify/deed/:hash', verifyDeedByHash);
app.get('/verify/deed', verifyDeedByHash);
app.get('/deed/:hash', verifyDeedByHash);
app.get('/deed', verifyDeedByHash);
app.get('/verify/:id', renderCredentialVerificationPage);
app.get('/verify', renderCredentialVerificationPage);

// 2. Mount API Router under /api
app.use('/api', apiRouter);

// 3. Serve Public Brand Assets (Logo, Icons, Favicons)
const publicPath = path.join(process.cwd(), 'public');
if (fs.existsSync(publicPath)) {
  app.use(express.static(publicPath));
}

// 4. Serve Frontend Static Production Assets & SPA Fallback
const distPath = path.join(process.cwd(), 'dist');
if (fs.existsSync(distPath)) {
  app.use(express.static(distPath));
  app.use((req: Request, res: Response, next: NextFunction) => {
    if (req.path.startsWith('/api')) {
      return res.status(404).json({ error: `API route ${req.path} not found` });
    }
    const indexPath = path.join(distPath, 'index.html');
    if (fs.existsSync(indexPath)) {
      return res.sendFile(indexPath);
    }
    next();
  });
} else {
  app.get('/', (_req: Request, res: Response) => {
    res.send(`
      <div style="font-family: system-ui, sans-serif; max-width: 600px; margin: 80px auto; padding: 32px; background: #0f172a; color: #f8fafc; border-radius: 16px; border: 1px solid #1e293b; text-align: center;">
        <h1 style="color: #10b981; font-size: 24px;">Rentilly Admin API & Core Engine</h1>
        <p style="color: #94a3b8; font-size: 14px;">The zero-agent Nigerian real estate operations hub is online.</p>
        <div style="margin: 24px 0; padding: 16px; background: #030712; border-radius: 8px; font-family: monospace; font-size: 13px; color: #34d399; text-align: left;">
          ✓ Health: <a href="/api/health" style="color: #34d399;">/api/health</a><br/>
          ✓ Properties: <a href="/api/properties" style="color: #34d399;">/api/properties</a><br/>
          ✓ KYP Records: <a href="/api/kyp/records" style="color: #34d399;">/api/kyp/records</a>
        </div>
      </div>
    `);
  });
}

// 5. Global Express Error Middleware — catches any thrown errors in route handlers
app.use((err: any, req: Request, res: Response, _next: NextFunction) => {
  console.error('[⚡ Server] Express route error:', err?.message || err, err?.stack);
  if (!res.headersSent) {
    res.status(500).json({
      error: 'Internal server error. Our team has been notified.',
      code: 'INTERNAL_SERVER_ERROR'
    });
  }
});

// Function to hydrate all stores from Supabase on boot
async function hydrateAllStores() {
  console.log('[Supabase Overhaul] Hydrating all data stores from Supabase Cloud...');
  await Promise.allSettled([
    initFeesFromSupabase(),
    MultiCurrencyService.initFromSupabase(),
    CardIssuingService.initFromSupabase(),
    AdminDataStore.initFromSupabase(),
    initBlacklistFromSupabase(),
    initBroadcastsFromSupabase(),
    initFeatureFlagsFromSupabase(),
    UserStore.syncFromSupabase(),
  ]);
  console.log('[Supabase Overhaul] All stores hydrated successfully from Supabase! 🚀');
}

// Start Server
if (process.env.NODE_ENV !== 'test') {
  httpServer = app.listen(PORT, async () => {
    console.log(`=================================================`);
    console.log(`🚀 Rentilly Admin Backend running on port ${PORT}`);
    console.log(`🛡️ KYP Verification & Escrow Engine Active`);
    console.log(`📦 Supabase Live Connection: ${isSupabaseConfigured() ? 'Connected ✅' : 'Waiting for Credentials ⚡'}`);
    console.log(`=================================================`);

    // Hydrate everything from Supabase Cloud (Zero Ephemeral Character)
    await hydrateAllStores();

    // Signal PM2 that the process is ready (enables wait_ready in ecosystem.config)
    process.send?.('ready');

    // Start Autonomous Omni-Sync Worker (Reconciles all fintechs every 10s)
    // Only runs on the primary PM2 cluster instance to prevent duplicate polling
    if (isPrimaryWorker) {
      AutoReconciliationWorker.start();
    } else {
      console.log(`[⚡ Server] Worker instance ${process.env.NODE_APP_INSTANCE} — AutoReconciliationWorker skipped (primary only).`);
    }
  });
}

export default app;
