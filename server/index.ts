import express from 'express';
import type { Request, Response } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import path from 'path';
import fs from 'fs';
import { apiRouter } from './routes/apiRouter';
import { renderShippingPortal } from './controllers/shippingController';
import { isSupabaseConfigured } from './supabaseClient';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 4000;

app.use(cors({ origin: '*' }));
app.use(express.json({ limit: '10mb' }));

// 1. Mount Interactive Shipping Portal
app.get('/shipping', renderShippingPortal);

// 2. Mount API Router under /api
app.use('/api', apiRouter);


// 2. Serve Frontend Static Production Assets & SPA Fallback
const distPath = path.join(process.cwd(), 'dist');
if (fs.existsSync(distPath)) {
  app.use(express.static(distPath));
  app.use((req: Request, res: Response, next) => {
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

// Start Server
if (process.env.NODE_ENV !== 'test') {
  app.listen(PORT, () => {
    console.log(`=================================================`);
    console.log(`🚀 Rentilly Admin Backend running on port ${PORT}`);
    console.log(`🛡️ KYP Verification & Escrow Engine Active`);
    console.log(`📦 Supabase Live Connection: ${isSupabaseConfigured() ? 'Connected ✅' : 'Waiting for Credentials ⚡'}`);
    console.log(`=================================================`);
  });
}

export default app;
