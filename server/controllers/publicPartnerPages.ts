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

// 3. User Self-Service Re-KYC / Date of Birth Addition Web Portal
export async function renderReKycPage(req: Request, res: Response) {
  const { email } = req.query;
  const cleanEmail = (email || '').toString().toLowerCase().trim();

  const allUsers = await UserStore.getAllUsers();
  const user = allUsers.find(u => u.email.toLowerCase() === cleanEmail);

  const displayName = user?.fullName || user?.businessName || (cleanEmail ? cleanEmail.split('@')[0] : 'Rentilly User');
  const currentBalance = user?.walletBalance ?? 0;
  const currentPhone = user?.phoneNumber || '';
  const currentNin = user?.ninNumber || '';
  const currentAccount = user?.accountNumber || '';

  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Account Activation & Verification | Rentilly</title>
      <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;600;700;800;900&display=swap" rel="stylesheet">
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Plus Jakarta Sans', system-ui, sans-serif; background: #030712; color: #f8fafc; display: flex; align-items: center; justify-content: center; min-height: 100vh; padding: 20px; }
        .card { background: #0f172a; border: 1px solid #1e293b; border-radius: 24px; max-width: 500px; width: 100%; padding: 32px; box-shadow: 0 25px 50px -12px rgba(0,0,0,0.5); }
        .badge-icon { width: 64px; height: 64px; background: rgba(16, 185, 129, 0.15); border: 2px solid #10b981; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 16px; font-size: 28px; }
        h1 { font-size: 20px; font-weight: 900; color: #ffffff; text-align: center; margin-bottom: 6px; }
        .tagline { font-size: 11px; font-weight: 800; letter-spacing: 1px; color: #10b981; text-transform: uppercase; text-align: center; margin-bottom: 20px; }
        .safe-banner { background: rgba(16, 185, 129, 0.12); border: 1px solid rgba(16, 185, 129, 0.3); border-radius: 14px; padding: 14px; font-size: 11.5px; color: #a7f3d0; line-height: 1.5; margin-bottom: 20px; display: flex; align-items: center; gap: 10px; }
        .form-group { margin-bottom: 16px; }
        label { display: block; font-size: 11px; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 6px; }
        input { width: 100%; background: #020617; border: 1px solid #1e293b; border-radius: 12px; padding: 12px 14px; color: #f8fafc; font-family: inherit; font-size: 13px; font-weight: 600; outline: none; transition: border-color 0.2s; }
        input:focus { border-color: #10b981; }
        input:disabled { background: #0b1120; color: #64748b; }
        .btn-submit { display: block; width: 100%; background: #10b981; color: #ffffff; font-weight: 800; font-size: 14px; padding: 16px; border-radius: 14px; border: none; cursor: pointer; text-align: center; transition: background 0.2s; margin-top: 24px; box-shadow: 0 4px 14px rgba(16, 185, 129, 0.4); }
        .btn-submit:hover { background: #059669; }
        .btn-submit:disabled { opacity: 0.6; cursor: not-allowed; }
        .alert { display: none; padding: 12px 14px; border-radius: 12px; font-size: 12px; margin-bottom: 16px; font-weight: 600; }
        .alert-error { background: rgba(239, 68, 68, 0.15); border: 1px solid #ef4444; color: #fca5a5; }
        .alert-success { background: rgba(16, 185, 129, 0.15); border: 1px solid #10b981; color: #6ee7b7; }
        .result-box { display: none; background: #020617; border: 1px solid #10b981; border-radius: 18px; padding: 24px; text-align: center; }
        .result-acc { font-size: 26px; font-weight: 900; letter-spacing: 3px; color: #10b981; font-family: monospace; margin: 12px 0; }
        .btn-app { display: inline-block; background: #10b981; color: #ffffff; font-weight: 800; font-size: 13px; padding: 12px 24px; border-radius: 12px; text-decoration: none; margin-top: 16px; }
      </style>
    </head>
    <body>
      <div class="card">
        <div class="badge-icon">🎂</div>
        <h1>ACCOUNT VERIFICATION & UPGRADE</h1>
        <div class="tagline">Dedicated 9PSB Settlement & Dollar Card</div>

        <div class="safe-banner">
          <span style="font-size: 20px;">🛡️</span>
          <div>
            <strong>Your Funds Are 100% Secure.</strong><br>
            Your current wallet balance of <strong>₦${currentBalance.toLocaleString()}</strong> will automatically link to your dedicated 9PSB settlement account.
          </div>
        </div>

        <div id="errorAlert" class="alert alert-error"></div>

        <form id="rekycForm">
          <div class="form-group">
            <label>Registered Email Address</label>
            <input type="email" id="email" value="${cleanEmail}" readonly disabled style="opacity: 0.8;" />
          </div>

          <div class="form-group">
            <label>Legal Full Name / Entity</label>
            <input type="text" id="fullName" value="${displayName}" required />
          </div>

          <div class="form-group">
            <label>Date of Birth <span style="color: #10b981;">*</span></label>
            <input type="date" id="dob" required max="${new Date(new Date().getFullYear() - 18, 11, 31).toISOString().split('T')[0]}" />
            <span style="font-size: 10px; color: #64748b; margin-top: 4px; display: block;">Required for dedicated 9PSB account & virtual card issuance. Must be at least 18 years old.</span>
          </div>

          <div class="form-group">
            <label>National Identity Number (NIN) / BVN</label>
            <input type="text" id="nin" placeholder="11-digit NIN or BVN" value="${currentNin}" maxlength="11" />
          </div>

          <div class="form-group">
            <label>Phone Number</label>
            <input type="tel" id="phoneNumber" placeholder="e.g. 08012345678" value="${currentPhone}" />
          </div>

          <button type="submit" id="submitBtn" class="btn-submit">
            Submit & Activate Dedicated Account ⚡
          </button>
        </form>

        <div id="resultBox" class="result-box">
          <div style="font-size: 40px; margin-bottom: 8px;">🎉</div>
          <h2 style="color: #ffffff; font-size: 18px; font-weight: 800;">Dedicated Account Activated!</h2>
          <p style="color: #94a3b8; font-size: 12px; margin-top: 4px;">Your dedicated 9PSB settlement account is active and permanently attached to your profile.</p>

          <div class="result-acc" id="accDisplay">----------</div>
          <div style="font-size: 13px; font-weight: 700; color: #38bdf8;" id="bankDisplay">9PSB (Rentilly Settlement)</div>

          <div style="margin-top: 16px; padding: 12px; background: rgba(16, 185, 129, 0.1); border-radius: 10px; font-size: 12px; color: #a7f3d0;">
            💳 Virtual Dollar Card: <strong>Active</strong><br>
            💰 Preserved Wallet Balance: <strong>₦${currentBalance.toLocaleString()}</strong>
          </div>

          <a href="rentilly://wallet" class="btn-app">Open Rentilly Mobile App 📱</a>
        </div>
      </div>

      <script>
        const form = document.getElementById('rekycForm');
        const submitBtn = document.getElementById('submitBtn');
        const errorAlert = document.getElementById('errorAlert');
        const resultBox = document.getElementById('resultBox');
        const accDisplay = document.getElementById('accDisplay');
        const bankDisplay = document.getElementById('bankDisplay');

        form.addEventListener('submit', async (e) => {
          e.preventDefault();
          errorAlert.style.display = 'none';

          const dobVal = document.getElementById('dob').value;
          if (!dobVal) {
            errorAlert.textContent = 'Please select your Date of Birth.';
            errorAlert.style.display = 'block';
            return;
          }

          // Format to DD-MM-YYYY
          const parts = dobVal.split('-');
          const formattedDob = parts[2] + '-' + parts[1] + '-' + parts[0];

          submitBtn.disabled = true;
          submitBtn.textContent = 'Connecting with Banking Engine... ⏳';

          try {
            const res = await fetch('/api/verification/complete-maplerad-kyc', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                email: '${cleanEmail}' || document.getElementById('email').value,
                dob: formattedDob,
                fullName: document.getElementById('fullName').value,
                nin: document.getElementById('nin').value,
                phoneNumber: document.getElementById('phoneNumber').value
              })
            });

            const data = await res.json();
            submitBtn.disabled = false;
            submitBtn.textContent = 'Submit & Activate Dedicated Account ⚡';

            if (res.ok && data.status && data.accountNumber) {
              form.style.display = 'none';
              document.querySelector('.safe-banner').style.display = 'none';
              accDisplay.textContent = data.accountNumber;
              bankDisplay.textContent = data.bankName || '9PSB (Rentilly)';
              resultBox.style.display = 'block';
            } else {
              errorAlert.textContent = data.message || data.error || 'Verification failed. Please check your details and try again.';
              errorAlert.style.display = 'block';
            }
          } catch (err) {
            submitBtn.disabled = false;
            submitBtn.textContent = 'Submit & Activate Dedicated Account ⚡';
            errorAlert.textContent = 'Network error connecting to server. Please try again.';
            errorAlert.style.display = 'block';
          }
        });
      </script>
    </body>
    </html>
  `);
}

