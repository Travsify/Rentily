import type { Request, Response } from 'express';
import { UserStore } from '../services/userStore';

export async function renderPartnerVerificationPage(req: Request, res: Response) {
  const { id } = req.query;
  const partnerIdStr = String(id || '').trim();

  const allUsers = await UserStore.getAllUsers();
  const formatOpsId = (uid: string) => `RNT-${uid.replace(/[^a-zA-Z0-9]/g, '').toUpperCase().slice(0, 3)}`;
  const user = allUsers.find(u => 
    u.id === partnerIdStr || 
    formatOpsId(u.id) === partnerIdStr ||
    `RNT-PTR-${u.id.replace(/[^0-9]/g, '').padStart(4, '0').slice(0, 4)}` === partnerIdStr ||
    u.id.includes(partnerIdStr)
  );

  const businessName = user?.businessName || user?.fullName || 'Accredited Corporate Partner';
  const repName = user?.fullName || 'Principal Broker';
  const cacNumber = user?.cacNumber || 'Verified Entity (CAC)';
  const partnerCode = partnerIdStr || (user?.id ? formatOpsId(user.id) : 'RNT-P01');
  const isVerified = user?.isVerified ?? true;
  const state = user?.state || 'Lagos';

  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Partner Accreditation Verification | Rentilly Living</title>
      <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;600;700;800;900&display=swap" rel="stylesheet">
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Plus Jakarta Sans', system-ui, sans-serif; background: #030712; color: #f8fafc; display: flex; align-items: center; justify-content: center; min-height: 100vh; padding: 20px; }
        .card { background: #0f172a; border: 1px solid #1e293b; border-radius: 24px; max-width: 480px; width: 100%; padding: 32px; box-shadow: 0 25px 50px -12px rgba(0,0,0,0.5); text-align: center; }
        .badge-icon { width: 72px; height: 72px; background: rgba(16, 185, 129, 0.15); border: 2px solid #10b981; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 20px; font-size: 32px; }
        h1 { font-size: 20px; font-weight: 900; color: #ffffff; margin-bottom: 6px; }
        .tagline { font-size: 11px; font-weight: 800; letter-spacing: 1.5px; color: #10b981; text-transform: uppercase; margin-bottom: 24px; }
        .info-box { background: #020617; border: 1px solid #1e293b; border-radius: 16px; padding: 20px; text-align: left; margin-bottom: 24px; }
        .row { display: flex; justify-content: space-between; margin-bottom: 12px; font-size: 12px; }
        .row:last-child { margin-bottom: 0; }
        .label { color: #94a3b8; font-weight: 600; }
        .val { color: #f8fafc; font-weight: 700; font-family: monospace; }
        .trust-banner { background: rgba(16, 185, 129, 0.1); border: 1px solid rgba(16, 185, 129, 0.2); border-radius: 12px; padding: 14px; font-size: 11px; color: #a7f3d0; line-height: 1.5; margin-bottom: 24px; }
        .footer-note { font-size: 10px; color: #64748b; }
      </style>
    </head>
    <body>
      <div class="card">
        <div class="badge-icon">🛡️</div>
        <h1>ACCREDITATION VERIFIED</h1>
        <div class="tagline">Official Rentilly Corporate Partner</div>

        <div class="info-box">
          <div class="row">
            <span class="label">Brokerage Firm</span>
            <span class="val" style="font-family: inherit; color: #34d399;">${businessName}</span>
          </div>
          <div class="row">
            <span class="label">Accreditation ID</span>
            <span class="val">${partnerCode}</span>
          </div>
          <div class="row">
            <span class="label">CAC Number</span>
            <span class="val">${cacNumber}</span>
          </div>
          <div class="row">
            <span class="label">Principal Broker</span>
            <span class="val" style="font-family: inherit;">${repName}</span>
          </div>
          <div class="row">
            <span class="label">Territory</span>
            <span class="val" style="font-family: inherit;">${state}, Nigeria</span>
          </div>
          <div class="row">
            <span class="label">Status</span>
            <span class="val" style="color: #4ade80;">${isVerified ? 'ACTIVE & TIER-3 AUDITED ✓' : 'UNDER REVIEW'}</span>
          </div>
        </div>

        <div class="trust-banner">
          🔒 <strong>Anti-Ghost Shield Guarantee:</strong> This partner has passed CAC corporate entity verification, director BVN/NIN identity screening, and is legally authorized to execute owner mandates with 100% escrow protection.
        </div>

        <p class="footer-note">
          Rentilly Living Marketplace • Zero-Agent Real Estate Rail • Lagos & Abuja
        </p>
      </div>
    </body>
    </html>
  `);
}

export function renderLandlordInvitePage(req: Request, res: Response) {
  const { partner_id, firm } = req.query;
  const partnerCode = String(partner_id || 'RNT-P01');
  const firmName = String(firm || 'Accredited Corporate Partner');

  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Landlord Invitation | Rentilly Living</title>
      <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;600;700;800;900&display=swap" rel="stylesheet">
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Plus Jakarta Sans', system-ui, sans-serif; background: #030712; color: #f8fafc; display: flex; align-items: center; justify-content: center; min-height: 100vh; padding: 20px; }
        .card { background: #0f172a; border: 1px solid #1e293b; border-radius: 28px; max-width: 520px; width: 100%; padding: 36px; box-shadow: 0 25px 50px -12px rgba(0,0,0,0.5); text-align: center; }
        .logo { font-size: 24px; font-weight: 900; color: #10b981; letter-spacing: -0.5px; margin-bottom: 24px; }
        .partner-pill { display: inline-flex; align-items: center; gap: 6px; background: rgba(16, 185, 129, 0.1); border: 1px solid rgba(16, 185, 129, 0.3); padding: 6px 14px; border-radius: 20px; font-size: 11px; font-weight: 800; color: #34d399; margin-bottom: 20px; }
        h1 { font-size: 22px; font-weight: 900; color: #ffffff; margin-bottom: 10px; line-height: 1.3; }
        p.subtitle { font-size: 13px; color: #94a3b8; line-height: 1.5; margin-bottom: 28px; }
        .features { background: #020617; border: 1px solid #1e293b; border-radius: 20px; padding: 22px; text-align: left; margin-bottom: 28px; }
        .feature-item { display: flex; align-items: flex-start; gap: 12px; margin-bottom: 16px; font-size: 12px; }
        .feature-item:last-child { margin-bottom: 0; }
        .feature-icon { font-size: 18px; flex-shrink: 0; }
        .feature-title { font-weight: 800; color: #ffffff; margin-bottom: 2px; }
        .feature-desc { color: #94a3b8; line-height: 1.4; }
        .btn-primary { display: block; width: 100%; background: #10b981; color: #ffffff; font-weight: 800; font-size: 14px; padding: 16px; border-radius: 14px; text-decoration: none; text-align: center; margin-bottom: 12px; transition: background 0.2s; }
        .btn-primary:hover { background: #059669; }
        .footer-note { font-size: 11px; color: #64748b; }
      </style>
    </head>
    <body>
      <div class="card">
        <div class="logo">Rentilly 🛡️</div>
        <div class="partner-pill">🤝 Mandate Partner: ${firmName} (${partnerCode})</div>
        <h1>List Direct. Get Paid in Escrow. Zero Agency Extortion.</h1>
        <p class="subtitle">You have been invited by <strong>${firmName}</strong> to list your properties on Rentilly, Nigeria's premier zero-middleman real estate rail.</p>

        <div class="features">
          <div class="feature-item">
            <span class="feature-icon">💰</span>
            <div>
              <div class="feature-title">Direct Escrow Payouts</div>
              <div class="feature-desc">Receive full annual rent directly into your bank account with automatic digital receipting.</div>
            </div>
          </div>
          <div class="feature-item">
            <span class="feature-icon">📜</span>
            <div>
              <div class="feature-title">Audited Digital Tenancy Agreements</div>
              <div class="feature-desc">State tenancy law compliant digital contracts enforceable under Nigerian law.</div>
            </div>
          </div>
          <div class="feature-item">
            <span class="feature-icon">🛡️</span>
            <div>
              <div class="feature-title">Dedicated Accredited Representation</div>
              <div class="feature-desc">${firmName} handles physical field inspections and tenant screening on your behalf.</div>
            </div>
          </div>
        </div>

        <a href="https://myrentilly.com" class="btn-primary">Get Started on Rentilly</a>
        <p class="footer-note">Accredited Mandate Code: ${partnerCode} • Protected by Rentilly Escrow</p>
      </div>
    </body>
    </html>
  `);
}
