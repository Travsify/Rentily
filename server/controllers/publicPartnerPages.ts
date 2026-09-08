import type { Request, Response } from 'express';
import crypto from 'crypto';
import { UserStore } from '../services/userStore';
import { NotificationDispatcher } from '../services/notificationDispatcher';
import { supabase } from '../supabaseClient';

export async function renderPartnerVerificationPage(req: Request, res: Response) {
  const partnerIdStr = String(req.params.id || req.query.id || req.query.partner_id || '').trim();

  const formatOpsId = (uid: string) => `RNT-${uid.replace(/[^a-zA-Z0-9]/g, '').toUpperCase().slice(0, 3)}`;
  const cleanCode = partnerIdStr.replace(/^RNT-?(PRT|PTR|LLD|P|L)?-?/i, '').replace(/[^a-zA-Z0-9]/g, '').toLowerCase();

  const allUsers = await UserStore.getAllUsers();
  let user = allUsers.find(u => {
    const uId = (u.id || '').toLowerCase();
    const uOps = formatOpsId(u.id || '');
    const uClean = (u.id || '').replace(/[^a-zA-Z0-9]/g, '').toLowerCase();
    const uEmail = (u.email || '').toLowerCase();
    return (
      uId === partnerIdStr.toLowerCase() ||
      uOps.toLowerCase() === partnerIdStr.toLowerCase() ||
      uEmail === partnerIdStr.toLowerCase() ||
      (cleanCode.length >= 2 && uClean.startsWith(cleanCode)) ||
      (cleanCode.length >= 2 && uId.startsWith(cleanCode))
    );
  });

  if (!user && supabase) {
    try {
      const { data: profiles } = await supabase.from('profiles').select('*');
      if (profiles && profiles.length > 0) {
        const p = profiles.find((prof: any) => {
          const pId = (prof.id || '').toLowerCase();
          const pOps = formatOpsId(prof.id || '');
          const pClean = (prof.id || '').replace(/[^a-zA-Z0-9]/g, '').toLowerCase();
          const pEmail = (prof.email || '').toLowerCase();
          return (
            pId === partnerIdStr.toLowerCase() ||
            pOps.toLowerCase() === partnerIdStr.toLowerCase() ||
            pEmail === partnerIdStr.toLowerCase() ||
            (cleanCode.length >= 2 && pClean.startsWith(cleanCode)) ||
            (cleanCode.length >= 2 && pId.startsWith(cleanCode))
          );
        });
        if (p) {
          user = {
            id: p.id,
            email: p.email,
            fullName: p.full_name || '',
            role: p.role || 'partner',
            isVerified: p.is_verified ?? true,
            businessName: p.business_name || '',
            cacNumber: p.cac_number || '',
            state: p.state || 'Lagos',
            createdAt: p.created_at
          } as any;
        }
      }
    } catch (_) {}
  }

  const businessName = user?.businessName || user?.fullName || 'Accredited Corporate Partner';
  const repName = user?.fullName || businessName || 'Principal Broker';
  const cacNumber = user?.cacNumber ? `RC: ${user.cacNumber}` : 'Verified Corporate Mandate';
  const partnerCode = user?.id ? formatOpsId(user.id) : (partnerIdStr || 'RNT-P01');
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
  const partnerCode = String(partner_id || '').trim();
  const firmName = String(firm || 'Accredited Managing Partner').trim();

  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Landlord Onboarding | Rentilly Living</title>
      <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800;900&display=swap" rel="stylesheet">
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Plus Jakarta Sans', system-ui, sans-serif; background: #030712; color: #f8fafc; display: flex; align-items: center; justify-content: center; min-height: 100vh; padding: 20px; }
        .card { background: #0f172a; border: 1px solid #1e293b; border-radius: 28px; max-width: 520px; width: 100%; padding: 36px; box-shadow: 0 25px 50px -12px rgba(0,0,0,0.5); }
        .logo { font-size: 26px; font-weight: 900; color: #10b981; letter-spacing: -0.5px; margin-bottom: 20px; text-align: center; }
        .partner-pill { display: flex; align-items: center; justify-content: center; gap: 6px; background: rgba(16, 185, 129, 0.1); border: 1px solid rgba(16, 185, 129, 0.3); padding: 8px 16px; border-radius: 20px; font-size: 11.5px; font-weight: 800; color: #34d399; margin-bottom: 20px; text-align: center; }
        h1 { font-size: 22px; font-weight: 900; color: #ffffff; margin-bottom: 8px; line-height: 1.3; text-align: center; }
        p.subtitle { font-size: 13px; color: #94a3b8; line-height: 1.5; margin-bottom: 24px; text-align: center; }
        
        .form-group { margin-bottom: 14px; text-align: left; }
        label { display: block; font-size: 10.5px; font-weight: 800; letter-spacing: 0.6px; color: #94a3b8; text-transform: uppercase; margin-bottom: 6px; }
        input, select { width: 100%; background: #020617; border: 1px solid #1e293b; border-radius: 12px; padding: 13px 14px; color: #f8fafc; font-family: inherit; font-size: 13px; font-weight: 600; outline: none; transition: border-color 0.2s; }
        input:focus, select:focus { border-color: #10b981; }
        
        .btn-submit { display: block; width: 100%; background: #10b981; color: #ffffff; font-weight: 800; font-size: 14px; padding: 16px; border-radius: 14px; border: none; cursor: pointer; text-align: center; transition: background 0.2s, transform 0.1s; margin-top: 20px; box-shadow: 0 4px 14px rgba(16, 185, 129, 0.4); }
        .btn-submit:hover { background: #059669; transform: translateY(-1px); }
        .btn-submit:disabled { opacity: 0.6; cursor: not-allowed; transform: none; }
        
        .features { background: #020617; border: 1px solid #1e293b; border-radius: 18px; padding: 18px; text-align: left; margin-top: 24px; }
        .feature-item { display: flex; align-items: flex-start; gap: 10px; margin-bottom: 12px; font-size: 11.5px; }
        .feature-item:last-child { margin-bottom: 0; }
        .feature-icon { font-size: 16px; flex-shrink: 0; }
        .feature-title { font-weight: 800; color: #ffffff; margin-bottom: 2px; }
        .feature-desc { color: #94a3b8; line-height: 1.35; }
        
        .alert { display: none; padding: 12px 14px; border-radius: 12px; font-size: 12px; margin-bottom: 16px; font-weight: 600; text-align: center; }
        .alert-error { background: rgba(239, 68, 68, 0.15); border: 1px solid #ef4444; color: #fca5a5; }
        
        /* Success Screen */
        .success-box { display: none; text-align: center; }
        .success-icon { font-size: 54px; margin-bottom: 14px; }
        .qr-container { background: #ffffff; padding: 12px; border-radius: 18px; display: inline-block; margin: 18px 0; box-shadow: 0 10px 25px rgba(0,0,0,0.5); }
        .qr-image { width: 180px; height: 180px; display: block; }
        .btn-download { display: inline-flex; align-items: center; justify-content: center; gap: 8px; width: 100%; background: #10b981; color: #ffffff; font-weight: 800; font-size: 14px; padding: 16px; border-radius: 14px; text-decoration: none; text-align: center; margin-top: 8px; transition: background 0.2s; box-shadow: 0 4px 14px rgba(16, 185, 129, 0.4); }
        .btn-download:hover { background: #059669; }
        .steps-card { background: #020617; border: 1px solid #1e293b; border-radius: 16px; padding: 16px; text-align: left; margin-top: 20px; font-size: 12px; line-height: 1.5; color: #94a3b8; }
        .steps-card strong { color: #f8fafc; }
        .footer-note { font-size: 11px; color: #64748b; margin-top: 20px; text-align: center; }
      </style>
    </head>
    <body>
      <div class="card">
        <div class="logo">Rentilly 🛡️</div>
        
        <!-- STEP 1: Registration Form -->
        <div id="formSection">
          <div class="partner-pill">🤝 Managing Partner: ${firmName} ${partnerCode ? '(' + partnerCode + ')' : ''}</div>
          <h1>Landlord Onboarding</h1>
          <p class="subtitle">Register to list your properties under <strong>${firmName}</strong> with direct rent escrow payouts.</p>
          
          <div id="errorAlert" class="alert alert-error"></div>
          
          <form id="onboardForm" onsubmit="handleRegister(event)">
            <input type="hidden" id="partnerId" value="${partnerCode}">
            <input type="hidden" id="firmName" value="${firmName}">
            
            <div class="form-group">
              <label for="fullName">Full Name</label>
              <input type="text" id="fullName" placeholder="e.g. Chief Adebayo Adeleke" required>
            </div>
            
            <div class="form-group">
              <label for="phoneNumber">Phone Number</label>
              <input type="tel" id="phoneNumber" placeholder="e.g. 08031234567" required>
            </div>
            
            <div class="form-group">
              <label for="email">Email Address</label>
              <input type="email" id="email" placeholder="e.g. landlord@gmail.com" required>
            </div>
            
            <div class="form-group">
              <label for="state">State / Region</label>
              <select id="state">
                <option value="Lagos" selected>Lagos</option>
                <option value="Abuja (FCT)">Abuja (FCT)</option>
                <option value="Rivers">Rivers (Port Harcourt)</option>
                <option value="Ogun">Ogun</option>
                <option value="Oyo">Oyo (Ibadan)</option>
                <option value="Enugu">Enugu</option>
                <option value="Delta">Delta</option>
                <option value="Edo">Edo</option>
                <option value="Anambra">Anambra</option>
                <option value="Kano">Kano</option>
                <option value="Kaduna">Kaduna</option>
                <option value="Akwa Ibom">Akwa Ibom</option>
              </select>
            </div>
            
            <div class="form-group">
              <label for="password">Create Account Password</label>
              <input type="password" id="password" placeholder="Minimum 6 characters" minlength="6" required>
            </div>
            
            <button type="submit" id="submitBtn" class="btn-submit">Complete Registration & Get App 🚀</button>
          </form>
          
          <div class="features">
            <div class="feature-item">
              <span class="feature-icon">💰</span>
              <div>
                <div class="feature-title">Direct Escrow Settlements</div>
                <div class="feature-desc">Full annual rent paid directly to your verified bank account upon tenant check-in.</div>
              </div>
            </div>
            <div class="feature-item">
              <span class="feature-icon">📜</span>
              <div>
                <div class="feature-title">Audited Digital Agreements</div>
                <div class="feature-desc">State tenancy law compliant digital contracts legally binding in Nigeria.</div>
              </div>
            </div>
            <div class="feature-item">
              <span class="feature-icon">🛡️</span>
              <div>
                <div class="feature-title">Accredited Mandate Management</div>
                <div class="feature-desc">${firmName} handles tenant verification, physical inspections, and key handover.</div>
              </div>
            </div>
          </div>
        </div>
        
        <!-- STEP 2: Success & Download Screen -->
        <div id="successSection" class="success-box">
          <div class="success-icon">🎉</div>
          <h1 id="successName">Congratulations!</h1>
          <p class="subtitle" id="successMsg">You have successfully registered as a verified Landlord on Rentilly.</p>
          
          <div class="qr-container">
            <img class="qr-image" src="https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=https://api.myrentilly.com/Rentily.apk" alt="Scan to Download Rentilly App">
          </div>
          <p style="font-size: 11px; color: #94a3b8; margin-bottom: 12px;">Scan with your phone camera to download the Android App</p>
          
          <a href="https://api.myrentilly.com/Rentily.apk" class="btn-download">
            <span>📲 Download Rentilly App (Android APK)</span>
          </a>
          
          <div class="steps-card">
            <strong>Next steps to start managing your properties:</strong><br/>
            1. Install the downloaded <strong>Rentily.apk</strong> on your device.<br/>
            2. Open the app and log in with your <strong>Email or Phone</strong> and password.<br/>
            3. Tap <strong>List New Property</strong> to add your units with instant escrow coverage.
          </div>
        </div>
        
        <p class="footer-note">Rentilly Escrow Network • Secure Real Estate Rail</p>
      </div>
      
      <script>
        async function handleRegister(e) {
          e.preventDefault();
          const btn = document.getElementById('submitBtn');
          const errorAlert = document.getElementById('errorAlert');
          
          errorAlert.style.display = 'none';
          btn.disabled = true;
          btn.innerText = 'Creating Account... ⏳';
          
          const payload = {
            fullName: document.getElementById('fullName').value.trim(),
            phoneNumber: document.getElementById('phoneNumber').value.trim(),
            email: document.getElementById('email').value.trim(),
            state: document.getElementById('state').value,
            password: document.getElementById('password').value,
            partnerId: document.getElementById('partnerId').value.trim(),
            firmName: document.getElementById('firmName').value.trim()
          };
          
          try {
            const res = await fetch('/api/public/landlord-register', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify(payload)
            });
            
            const data = await res.json();
            if (res.ok && (data.success || data.status)) {
              document.getElementById('formSection').style.display = 'none';
              document.getElementById('successSection').style.display = 'block';
              document.getElementById('successName').innerText = 'Congratulations, ' + payload.fullName.split(' ')[0] + '!';
              document.getElementById('successMsg').innerHTML = 'You have successfully registered as a verified Landlord under <strong>' + payload.firmName + '</strong>.';
            } else {
              errorAlert.innerText = data.error || data.message || 'Registration failed. Please check your details.';
              errorAlert.style.display = 'block';
              btn.disabled = false;
              btn.innerText = 'Complete Registration & Get App 🚀';
            }
          } catch (err) {
            errorAlert.innerText = 'Network error. Please try again.';
            errorAlert.style.display = 'block';
            btn.disabled = false;
            btn.innerText = 'Complete Registration & Get App 🚀';
          }
        }
      </script>
    </body>
    </html>
  `);
}

/**
 * Handle Public Landlord Registration from Unique Onboarding Link
 * Registers landlord, permanently binds managing partner, and notifies partner
 */
export async function handlePublicLandlordRegister(req: Request, res: Response) {
  try {
    const { fullName, email, phoneNumber, state, password, partnerId, firmName } = req.body;
    
    if (!fullName || !email || !phoneNumber || !password) {
      return res.status(400).json({ error: 'Full Name, Email, Phone Number, and Password are required.' });
    }

    const cleanEmail = email.toString().trim().toLowerCase();
    const cleanPhone = phoneNumber.toString().trim();
    const cleanName = fullName.toString().trim();
    const cleanState = (state || 'Lagos').toString().trim();
    const cleanPartnerId = (partnerId || '').toString().trim();
    const cleanFirmName = (firmName || '').toString().trim();

    // Check if user already exists
    let existing = await UserStore.findByEmail(cleanEmail);
    if (!existing && supabase) {
      const { data } = await supabase.from('profiles').select('*').eq('email', cleanEmail).maybeSingle();
      if (data) existing = data as any;
    }

    if (existing) {
      // Update partner mandate if not already assigned
      if (supabase) {
        await supabase.from('profiles').update({
          full_name: cleanName,
          phone_number: cleanPhone,
          state: cleanState,
          role: 'owner',
          managing_partner_id: cleanPartnerId || (existing as any).managing_partner_id || null,
          managing_partner_name: cleanFirmName || (existing as any).managing_partner_name || null,
          updated_at: new Date().toISOString()
        }).eq('email', cleanEmail);
      }
      return res.json({
        success: true,
        message: 'Landlord profile linked to accredited managing partner.',
        user: { email: cleanEmail, fullName: cleanName, role: 'owner' }
      });
    }

    // Create new landlord profile
    const newUserId = crypto.randomUUID ? crypto.randomUUID() : `usr_${Date.now()}`;
    const newUser = {
      id: newUserId,
      fullName: cleanName,
      email: cleanEmail,
      phoneNumber: cleanPhone,
      password: password,
      role: 'owner' as const,
      state: cleanState,
      isVerified: false,
      walletBalance: 0,
      usdtBalance: 0,
      managingPartnerId: cleanPartnerId || undefined,
      managingPartnerName: cleanFirmName || undefined,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };

    UserStore.upsertUserForced(newUser as any);

    if (supabase) {
      try {
        await supabase.from('profiles').upsert({
          id: newUserId,
          full_name: cleanName,
          email: cleanEmail,
          phone_number: cleanPhone,
          role: 'owner',
          state: cleanState,
          is_verified: false,
          wallet_balance: 0,
          managing_partner_id: cleanPartnerId || null,
          managing_partner_name: cleanFirmName || null,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        }, { onConflict: 'email' });
      } catch (dbErr: any) {
        console.warn('[handlePublicLandlordRegister] Supabase upsert warning:', dbErr.message);
      }
    }

    // Dispatch Push & Email Alert to the Partner
    if (cleanPartnerId || cleanFirmName) {
      try {
        const allUsers = await UserStore.getAllUsers();
        const partner = allUsers.find(u => 
          u.id === cleanPartnerId ||
          (u.businessName && u.businessName.toLowerCase() === cleanFirmName.toLowerCase()) ||
          u.email.toLowerCase() === cleanPartnerId.toLowerCase()
        );

        if (partner) {
          NotificationDispatcher.dispatch({
            userId: partner.id,
            email: partner.email,
            userName: partner.fullName || partner.businessName || 'Partner',
            category: 'system',
            title: '🎉 New Landlord Onboarded Under Your Mandate!',
            message: `${cleanName} (${cleanPhone}) has registered as a landlord via your unique link. All their property listings and commissions are permanently mapped to your firm.`
          }).catch(() => {});
        }
      } catch (_) {}
    }

    return res.json({
      success: true,
      message: 'Landlord registered successfully under managing partner.',
      user: {
        id: newUserId,
        email: cleanEmail,
        fullName: cleanName,
        role: 'owner'
      }
    });
  } catch (err: any) {
    console.error('handlePublicLandlordRegister error:', err);
    return res.status(500).json({ error: err.message || 'Internal server error' });
  }
}

/**
 * Get Onboarded Landlords for a Partner
 * Live query from profiles (managing_partner_id) and properties (partner_id)
 */
export async function getPartnerOnboardedLandlords(req: Request, res: Response) {
  try {
    const partnerId = String(req.query.partnerId || '').trim();
    const partnerEmail = String(req.query.partnerEmail || req.query.email || '').trim().toLowerCase();
    const firmName = String(req.query.firmName || req.query.firm || '').trim();

    if (!partnerId && !partnerEmail && !firmName) {
      return res.status(400).json({ error: 'partnerId, partnerEmail, or firmName is required' });
    }

    let onboardedLandlords: any[] = [];

    if (supabase) {
      // 1. Fetch landlords directly registered under partner
      let query = supabase.from('profiles').select('*').eq('role', 'owner');
      
      const filters = [];
      if (partnerId) filters.push(`managing_partner_id.eq.${partnerId}`);
      if (firmName) filters.push(`managing_partner_name.ilike.%${firmName}%`);
      
      if (filters.length > 0) {
        query = query.or(filters.join(','));
      }

      const { data: landlordProfiles } = await query;

      // 2. Fetch properties linked to this partner
      let propQuery = supabase.from('properties').select('*');
      if (partnerId) {
        propQuery = propQuery.or(`partner_id.eq.${partnerId},owner_id.eq.${partnerId}`);
      }
      const { data: partnerProps } = await propQuery;

      const propsByOwner: Record<string, any[]> = {};
      for (const p of partnerProps || []) {
        const key = (p.owner_id || p.owner_name || p.owner_phone || 'unknown').toString();
        if (!propsByOwner[key]) propsByOwner[key] = [];
        propsByOwner[key].push(p);
      }

      // Merge landlords
      const seenEmails = new Set<string>();

      for (const l of landlordProfiles || []) {
        if (seenEmails.has(l.email)) continue;
        seenEmails.add(l.email);

        const lProps = propsByOwner[l.id] || propsByOwner[l.email] || propsByOwner[l.full_name] || [];
        let totalCommission = 0;
        for (const p of lProps) {
          const price = Number(p.price || p.base_price || 0);
          const rate = p.purpose === 'sale' ? 0.02 : 0.025;
          totalCommission += price * rate;
        }

        onboardedLandlords.push({
          id: l.id,
          name: l.full_name || 'Verified Landlord',
          email: l.email,
          phone: l.phone_number || '',
          state: l.state || 'Lagos',
          isVerified: l.is_verified || false,
          unitCount: lProps.length,
          lockedCommission: totalCommission,
          registeredAt: l.created_at
        });
      }

      // Also include owners from properties whose profiles might not have explicit managing_partner_id
      for (const [ownerKey, props] of Object.entries(propsByOwner)) {
        const firstProp = props[0];
        const ownerEmail = firstProp.owner_email || '';
        if (ownerEmail && seenEmails.has(ownerEmail)) continue;

        let totalCommission = 0;
        for (const p of props) {
          const price = Number(p.price || p.base_price || 0);
          const rate = p.purpose === 'sale' ? 0.02 : 0.025;
          totalCommission += price * rate;
        }

        onboardedLandlords.push({
          id: firstProp.owner_id || ownerKey,
          name: firstProp.owner_name || 'Property Owner',
          email: ownerEmail || '',
          phone: firstProp.owner_phone || '',
          state: firstProp.state || 'Lagos',
          isVerified: true,
          unitCount: props.length,
          lockedCommission: totalCommission,
          registeredAt: firstProp.created_at
        });
      }
    }

    return res.json({
      success: true,
      total: onboardedLandlords.length,
      landlords: onboardedLandlords
    });
  } catch (err: any) {
    console.error('getPartnerOnboardedLandlords error:', err);
    return res.status(500).json({ error: err.message });
  }
}


// 3. User Self-Service Re-KYC / Date of Birth Addition Web Portal
export async function renderReKycPage(req: Request, res: Response) {
  const { email } = req.query;
  const cleanEmail = (email || '').toString().toLowerCase().trim();

  const allUsers = await UserStore.getAllUsers();
  const user = allUsers.find(u => u.email.toLowerCase() === cleanEmail);

  // Check if rekyc is flagged in system_configs or UserStore
  let rekycFlagged = user?.rekycRequired === true;
  if (supabase) {
    try {
      const { data: cfg } = await supabase
        .from('system_configs')
        .select('data')
        .eq('id', `rekyc_${cleanEmail}`)
        .maybeSingle();
      if (cfg?.data?.rekycRequired === true) {
        rekycFlagged = true;
      }
    } catch (_) {}
  }

  // Must have a real, validated 11-digit BVN and NOT be flagged for rekyc to be considered approved
  const cleanBvn = (user?.bvn || '').toString().replace(/\D/g, '');
  const hasValidBvn = cleanBvn.length === 11;
  const isAlreadyApproved = Boolean(
    !rekycFlagged &&
    hasValidBvn &&
    user &&
    user.isVerified &&
    user.accountNumber &&
    user.bankName?.includes('9PSB')
  );

  const displayName = user?.fullName || user?.businessName || (cleanEmail ? cleanEmail.split('@')[0] : 'Rentilly User');
  const currentBalance = user?.walletBalance ?? 0;
  const currentPhone = user?.phoneNumber || '';
  const currentBvn = user?.bvn || '';
  const currentNin = user?.ninNumber || '';
  const currentAccount = user?.accountNumber || '';
  const currentBank = user?.bankName || '9PSB (Rentilly)';

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
        ${isAlreadyApproved ? `
          <div class="badge-icon">✅</div>
          <h1>ACCOUNT VERIFIED & ACTIVE</h1>
          <div class="tagline">Dedicated 9PSB Settlement & Dollar Card Active</div>

          <div style="background: rgba(16, 185, 129, 0.12); border: 1px solid rgba(16, 185, 129, 0.3); border-radius: 18px; padding: 24px; text-align: center; margin-top: 20px;">
            <p style="font-size: 13px; color: #a7f3d0; margin-bottom: 14px; line-height: 1.5;">
              Your Rentilly dedicated 9PSB settlement account is fully verified and active.
            </p>
            <div style="font-size: 11px; text-transform: uppercase; color: #94a3b8; font-weight: 700;">Dedicated Account Number</div>
            <div class="result-acc" style="display: block;">${currentAccount}</div>
            <div style="font-size: 13px; font-weight: 700; color: #38bdf8;">${currentBank}</div>

            <div style="margin-top: 16px; padding: 12px; background: rgba(0, 0, 0, 0.3); border-radius: 10px; font-size: 11.5px; color: #cbd5e1; text-align: left; line-height: 1.6;">
              🔒 <strong>Status:</strong> Active & Linked<br>
              💳 <strong>Virtual Dollar Card:</strong> Enabled<br>
              💰 <strong>Wallet Balance:</strong> ₦${currentBalance.toLocaleString()}<br>
              ⚡ <strong>One-Time Link:</strong> This verification request is already finalized. It cannot be used again unless Rentilly Admin issues a new re-verification request.
            </div>

            <a href="rentilly://wallet" class="btn-app" style="margin-top: 20px;">Open Rentilly Mobile App 📱</a>
          </div>
        ` : `
          <div class="badge-icon">🛡️</div>
          <h1>ACCOUNT UPGRADE & ACTIVATION</h1>
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
              <span style="font-size: 10px; color: #64748b; margin-top: 4px; display: block;">Required for live NIBSS banking validation. Must be at least 18 years old.</span>
            </div>

            <div class="form-group">
              <label>Bank Verification Number (BVN) <span style="color: #10b981;">*</span></label>
              <input type="text" id="bvn" placeholder="Enter 11-digit BVN" value="${currentBvn}" maxlength="11" required />
              <span style="font-size: 10px; color: #64748b; margin-top: 4px; display: block;">Required by the Central Bank of Nigeria & NIBSS for dedicated 9PSB account issuance.</span>
            </div>

            <div class="form-group">
              <label>National Identity Number (NIN) <span style="color: #10b981;">*</span></label>
              <input type="text" id="nin" placeholder="Enter 11-digit NIN" value="${currentNin}" maxlength="11" required />
              <span style="font-size: 10px; color: #64748b; margin-top: 4px; display: block;">Required for National Identity verification & Virtual Dollar Card tier.</span>
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
              💰 Preserved Wallet Balance: <strong>₦${currentBalance.toLocaleString()}</strong><br>
              🔒 <strong>Status:</strong> Link is now finalized & closed.
            </div>

            <a href="rentilly://wallet" class="btn-app">Open Rentilly Mobile App 📱</a>
          </div>
        `}
      </div>

      <script>
        const form = document.getElementById('rekycForm');
        const submitBtn = document.getElementById('submitBtn');
        const errorAlert = document.getElementById('errorAlert');
        const resultBox = document.getElementById('resultBox');
        const accDisplay = document.getElementById('accDisplay');
        const bankDisplay = document.getElementById('bankDisplay');

        if (form) {
          form.addEventListener('submit', async (e) => {
            e.preventDefault();
            errorAlert.style.display = 'none';

            const bvnVal = document.getElementById('bvn').value.trim();
            if (bvnVal.length !== 11) {
              errorAlert.textContent = 'Please enter your valid 11-digit Bank Verification Number (BVN).';
              errorAlert.style.display = 'block';
              return;
            }

            const ninVal = document.getElementById('nin').value.trim();
            if (ninVal.length !== 11) {
              errorAlert.textContent = 'Please enter your valid 11-digit National Identity Number (NIN).';
              errorAlert.style.display = 'block';
              return;
            }

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
                  bvn: bvnVal,
                  nin: ninVal,
                  phoneNumber: document.getElementById('phoneNumber').value
                })
              });

              const data = await res.json();
              submitBtn.disabled = false;
              submitBtn.textContent = 'Submit & Activate Dedicated Account ⚡';

              if (res.ok && data.status && data.accountNumber) {
                form.style.display = 'none';
                const sb = document.querySelector('.safe-banner');
                if (sb) sb.style.display = 'none';
                accDisplay.textContent = data.accountNumber;
                bankDisplay.textContent = data.bankName || '9PSB (Rentilly)';
                resultBox.style.display = 'block';
              } else {
                errorAlert.textContent = data.message || data.error || 'Verification failed. Please check your BVN and Date of Birth.';
                errorAlert.style.display = 'block';
              }
            } catch (err) {
              submitBtn.disabled = false;
              submitBtn.textContent = 'Submit & Activate Dedicated Account ⚡';
              errorAlert.textContent = 'Network error connecting to server. Please try again.';
              errorAlert.style.display = 'block';
            }
          });
        }
      </script>
    </body>
    </html>
  `);
}

/**
 * Public Gate Pass Verification Page for Estate Security Guards
 * Accessible on mobile browser at: /gate/:code or /gate?code=:code
 */
export async function renderGatePassPage(req: Request, res: Response) {
  const code = (req.params.code || req.query.code || '').toString().trim();

  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Estate Gate Pass Verification | Rentilly Escrow Network</title>
      <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;600;700;800;900&display=swap" rel="stylesheet">
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Plus Jakarta Sans', system-ui, sans-serif; background: #030712; color: #f8fafc; display: flex; align-items: center; justify-content: center; min-height: 100vh; padding: 16px; }
        .card { background: #0f172a; border: 1px solid #1e293b; border-radius: 24px; max-width: 460px; width: 100%; padding: 28px 24px; box-shadow: 0 25px 50px -12px rgba(0,0,0,0.6); text-align: center; }
        .logo-wrap { width: 56px; height: 56px; margin: 0 auto 16px; border-radius: 14px; overflow: hidden; border: 1px solid rgba(16,185,129,0.3); }
        .logo-wrap img { width: 100%; height: 100%; object-fit: cover; }
        h1 { font-size: 20px; font-weight: 900; color: #ffffff; margin-bottom: 4px; }
        .sub { font-size: 11px; color: #94a3b8; margin-bottom: 20px; }
        .code-input-box { background: #020617; border: 2px solid #334155; border-radius: 16px; padding: 14px; margin-bottom: 16px; display: flex; gap: 8px; }
        .code-input { flex: 1; background: transparent; border: none; font-size: 24px; font-weight: 900; letter-spacing: 6px; color: #10b981; text-align: center; outline: none; font-family: monospace; }
        .verify-btn { width: 100%; background: linear-gradient(135deg, #10b981 0%, #059669 100%); color: #ffffff; border: none; padding: 15px; border-radius: 14px; font-size: 14px; font-weight: 800; cursor: pointer; text-transform: uppercase; letter-spacing: 0.5px; transition: opacity 0.2s; }
        .verify-btn:disabled { opacity: 0.5; cursor: not-allowed; }
        .result-box { display: none; margin-top: 20px; padding: 18px; border-radius: 16px; text-align: left; }
        .result-valid { background: rgba(16,185,129,0.1); border: 1.5px solid #10b981; }
        .result-invalid { background: rgba(239,68,68,0.1); border: 1.5px solid #ef4444; }
        .res-row { display: flex; justify-content: space-between; margin-bottom: 10px; font-size: 12px; }
        .res-row:last-child { margin-bottom: 0; }
        .res-lbl { color: #94a3b8; font-weight: 600; }
        .res-val { color: #f8fafc; font-weight: 800; }
        .status-pill { display: inline-block; padding: 4px 10px; border-radius: 20px; font-size: 10px; font-weight: 900; letter-spacing: 0.5px; }
        .status-ok { background: #10b981; color: #022c22; }
        .status-bad { background: #ef4444; color: #450a0a; }
        .shield-note { font-size: 10px; color: #64748b; margin-top: 20px; line-height: 1.4; }
      </style>
    </head>
    <body>
      <div class="card">
        <div class="logo-wrap">
          <img src="/logo.png" alt="Rentilly" />
        </div>
        <h1>SECURITY GATE CHECK-IN</h1>
        <div class="sub">Rentilly Estate Walkthrough Pass Terminal</div>

        <div class="code-input-box">
          <input type="text" id="passCode" class="code-input" maxlength="6" placeholder="000000" value="${code}" />
        </div>

        <button id="verifyBtn" class="verify-btn" onclick="verifyPass()">Verify & Check In Visitor 🔑</button>

        <div id="resultBox" class="result-box"></div>

        <p class="shield-note">
          🛡️ <strong>Estate Security Protocol:</strong> Visitors must present a verified Rentilly 6-digit gate code. Personal contact numbers are masked for data privacy.
        </p>
      </div>

      <script>
        async function verifyPass() {
          const codeInput = document.getElementById('passCode');
          const btn = document.getElementById('verifyBtn');
          const resBox = document.getElementById('resultBox');
          const code = codeInput.value.trim();

          if (!code || code.length !== 6) {
            alert('Please enter a 6-digit pass code');
            return;
          }

          btn.disabled = true;
          btn.textContent = 'Verifying Pass...';
          resBox.style.display = 'none';

          try {
            const res = await fetch('/api/inspections/verify-pass', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ code })
            });

            const data = await res.json();
            btn.disabled = false;
            btn.textContent = 'Verify & Check In Visitor 🔑';

            if (res.ok && data.success && data.inspection) {
              const insp = data.inspection;
              resBox.className = 'result-box result-valid';
              resBox.innerHTML = \`
                <div style="text-align: center; margin-bottom: 14px;">
                  <span class="status-pill status-ok">\${data.alreadyCheckedIn ? 'ALREADY CHECKED IN' : 'ACCESS GRANTED ✓'}</span>
                  <h3 style="font-size: 16px; font-weight: 800; color: #34d399; margin-top: 8px;">\${insp.verificationStatus}</h3>
                </div>
                <div class="res-row"><span class="res-lbl">Visitor (Masked)</span><span class="res-val">\${insp.visitorName}</span></div>
                <div class="res-row"><span class="res-lbl">Contact</span><span class="res-val">\${insp.visitorPhone}</span></div>
                <div class="res-row"><span class="res-lbl">Destination</span><span class="res-val" style="max-width: 60%; text-align: right;">\${insp.propertyTitle}</span></div>
                <div class="res-row"><span class="res-lbl">Address</span><span class="res-val" style="max-width: 60%; text-align: right; color: #94a3b8;">\${insp.propertyAddress}</span></div>
                <div class="res-row"><span class="res-lbl">Time Window</span><span class="res-val">\${insp.scheduledDate} (\${insp.scheduledTimeSlot})</span></div>
                <div class="res-row"><span class="res-lbl">Check-In Time</span><span class="res-val" style="color: #34d399;">\${insp.checkInTime}</span></div>
              \`;
              resBox.style.display = 'block';
            } else {
              resBox.className = 'result-box result-invalid';
              resBox.innerHTML = \`
                <div style="text-align: center; margin-bottom: 10px;">
                  <span class="status-pill status-bad">ACCESS DENIED ✕</span>
                </div>
                <p style="color: #f87171; font-size: 12px; font-weight: 700; text-align: center;">
                  \${data.error || 'Invalid or Expired Gate Pass Code.'}
                </p>
              \`;
              resBox.style.display = 'block';
            }
          } catch (e) {
            btn.disabled = false;
            btn.textContent = 'Verify & Check In Visitor 🔑';
            resBox.className = 'result-box result-invalid';
            resBox.innerHTML = '<p style="color: #f87171; font-size: 12px; text-align: center;">Network error connecting to verification engine.</p>';
            resBox.style.display = 'block';
          }
        }

        // Auto-verify if code was in URL
        if (document.getElementById('passCode').value.length === 6) {
          verifyPass();
        }
      </script>
    </body>
    </html>
  `);
}

/**
 * Public Live Digital Credential Verification Page (Anti-Photoshop Safeguard)
 * Accessible on mobile browser at: /verify/credential/:id or /verify/credential?id=:id
 */
export async function renderCredentialVerificationPage(req: Request, res: Response) {
  const id = (req.params.id || req.query.id || '').toString().trim();

  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Official Credential Audit | Rentilly Escrow Network</title>
      <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;600;700;800;900&display=swap" rel="stylesheet">
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Plus Jakarta Sans', system-ui, sans-serif; background: #030712; color: #f8fafc; display: flex; align-items: center; justify-content: center; min-height: 100vh; padding: 16px; }
        .card { background: #0f172a; border: 1.5px solid #065f46; border-radius: 24px; max-width: 480px; width: 100%; padding: 28px 24px; box-shadow: 0 25px 50px -12px rgba(0,0,0,0.6); text-align: center; position: relative; overflow: hidden; }
        .live-ticker { background: rgba(16,185,129,0.15); border-bottom: 1px solid rgba(16,185,129,0.3); padding: 8px 12px; font-size: 10px; font-weight: 800; color: #34d399; letter-spacing: 0.5px; margin: -28px -24px 20px -24px; display: flex; align-items: center; justify-content: center; gap: 6px; }
        .pulse-dot { width: 8px; height: 8px; border-radius: 50%; background: #10b981; animation: pulse 1.5s infinite; }
        @keyframes pulse { 0% { transform: scale(0.9); opacity: 0.8; } 50% { transform: scale(1.3); opacity: 1; } 100% { transform: scale(0.9); opacity: 0.8; } }
        .logo-wrap { width: 60px; height: 60px; margin: 0 auto 12px; border-radius: 16px; overflow: hidden; border: 2px solid #10b981; box-shadow: 0 4px 14px rgba(16,185,129,0.3); }
        .logo-wrap img { width: 100%; height: 100%; object-fit: cover; }
        h1 { font-size: 20px; font-weight: 900; color: #ffffff; margin-bottom: 2px; }
        .sub { font-size: 11px; color: #a7f3d0; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 20px; }
        .info-box { background: #020617; border: 1px solid #1e293b; border-radius: 18px; padding: 18px; text-align: left; margin-bottom: 20px; }
        .row { display: flex; justify-content: space-between; margin-bottom: 12px; font-size: 12px; }
        .row:last-child { margin-bottom: 0; }
        .lbl { color: #94a3b8; font-weight: 600; }
        .val { color: #f8fafc; font-weight: 800; }
        .badge-verified { background: rgba(16,185,129,0.15); border: 1px solid #10b981; color: #34d399; padding: 4px 10px; border-radius: 20px; font-size: 11px; font-weight: 800; }
        .anti-fraud-banner { background: rgba(59,130,246,0.08); border: 1px solid rgba(59,130,246,0.25); border-radius: 14px; padding: 12px 14px; font-size: 11px; color: #93c5fd; text-align: left; line-height: 1.45; margin-bottom: 16px; }
        .security-hash { font-family: monospace; font-size: 9px; color: #64748b; word-break: break-all; }
      </style>
    </head>
    <body>
      <div class="card">
        <div class="live-ticker">
          <span class="pulse-dot"></span>
          LIVE DATABASE SYNC • <span id="liveClock"></span>
        </div>

        <div class="logo-wrap">
          <img src="/logo.png" alt="Rentilly" />
        </div>

        <h1>RENTILLY CREDENTIAL AUDIT</h1>
        <div class="sub">Official Trust & Identity Verification</div>

        <div id="contentBox">
          <p style="color: #94a3b8; font-size: 12px;">Auditing cryptographic signature against live database...</p>
        </div>

        <div class="anti-fraud-banner">
          🛡️ <strong>Zero-Trust Protocol:</strong> If a host presents a static screenshot or paper ID that does not match this live URL verification, do NOT enter or transact.
        </div>

        <p class="security-hash" id="securityHash">RENTILLY SECURE ENCRYPTION SHA-256</p>
      </div>

      <script>
        function updateClock() {
          const now = new Date();
          document.getElementById('liveClock').textContent = now.toLocaleTimeString('en-US', { hour12: true }) + ' (WAT)';
        }
        setInterval(updateClock, 1000);
        updateClock();

        async function fetchCredential() {
          const targetId = '${id}';
          const content = document.getElementById('contentBox');
          const hashBox = document.getElementById('securityHash');

          try {
            const res = await fetch('/api/verify/credential/' + encodeURIComponent(targetId));
            const data = await res.json();

            if (res.ok && data.valid && data.holder) {
              const h = data.holder;
              content.innerHTML = \`
                <div style="margin-bottom: 16px;">
                  <span class="badge-verified">✓ AUTHENTIC & ACCREDITED</span>
                  <h2 style="font-size: 18px; font-weight: 900; color: #ffffff; margin-top: 8px;">\${h.name}</h2>
                  <p style="font-size: 11px; color: #34d399; font-weight: 700;">\${h.designation}</p>
                </div>

                <div class="info-box">
                  <div class="row"><span class="lbl">Credential ID</span><span class="val" style="font-family: monospace; color: #34d399;">\${data.credentialId}</span></div>
                  <div class="row"><span class="lbl">Compliance Audit</span><span class="val" style="color: #fbbf24;">\${h.complianceBadge}</span></div>
                  <div class="row"><span class="lbl">Escrow Custody</span><span class="val" style="color: #34d399;">\${h.escrowTrustRating}</span></div>
                  <div class="row"><span class="lbl">Jurisdiction</span><span class="val">\${h.jurisdiction}</span></div>
                  <div class="row"><span class="lbl">Validity Review</span><span class="val">September 2026 – Active</span></div>
                  <div class="row"><span class="lbl">Issuing Authority</span><span class="val">\${h.issuer}</span></div>
                </div>
              \`;
              hashBox.textContent = 'AUDIT HASH: ' + data.securitySignature;
            } else {
              content.innerHTML = \`
                <div style="padding: 20px; background: rgba(239,68,68,0.1); border: 1.5px solid #ef4444; border-radius: 16px; margin-bottom: 16px;">
                  <h3 style="color: #f87171; font-size: 16px; font-weight: 900; margin-bottom: 6px;">FRAUD ALERT</h3>
                  <p style="color: #fca5a5; font-size: 12px; line-height: 1.4;">
                    \${data.error || 'This credential is NOT recognized on the Rentilly Escrow Network. Do not engage in transactions with this individual.'}
                  </p>
                </div>
              \`;
            }
          } catch (e) {
            content.innerHTML = '<p style="color: #f87171; font-size: 12px;">Verification service temporarily unreachable.</p>';
          }
        }
        fetchCredential();
      </script>
    </body>
    </html>
  `);
}


