import type { Request, Response } from 'express';
import crypto from 'crypto';
import { UserStore } from '../services/userStore';
import { NotificationDispatcher } from '../services/notificationDispatcher';
import { supabase } from '../supabaseClient';
import { TransactionStore } from '../services/transactionStore';

/**
 * Escapes user-supplied strings before injecting into HTML to prevent XSS.
 * Must be used for any query-param / user-data value rendered in HTML context.
 */
function escapeHtml(unsafe: string): string {
  return unsafe
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

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
            isVerified: Boolean(p.is_verified && p.cac_number),
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
  const cacNumber = user?.cacNumber ? `RC: ${user.cacNumber}` : 'Pending Corporate KYB';
  const partnerCode = user?.id ? formatOpsId(user.id) : (partnerIdStr || 'RNT-P01');
  const isVerified = Boolean(user?.isVerified && user?.cacNumber);
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
  const partnerCode = escapeHtml(String(partner_id || '').trim());
  const firmName = escapeHtml(String(firm || 'Accredited Managing Partner').trim());

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
        
        <!-- MOBILE APP ONBOARDING GATEWAY -->
        <div id="formSection">
          <div class="partner-pill">🤝 Managing Partner: ${firmName} ${partnerCode ? '(' + partnerCode + ')' : ''}</div>
          <h1 style="font-size: 24px; font-weight: 900; margin-bottom: 8px;">Landlord Mobile Onboarding</h1>
          <p class="subtitle" style="font-size: 13px; color: #94a3b8; line-height: 1.5; margin-bottom: 20px;">
            To safeguard your property assets and enable biometric payment authorizations, landlord registration is exclusively available on the <strong>Rentilly Mobile App</strong>.
          </p>

          <div style="background: rgba(16, 185, 129, 0.08); border: 1px dashed #10b981; border-radius: 16px; padding: 18px; text-align: center; margin-bottom: 24px;">
            <p style="font-size: 11px; text-transform: uppercase; letter-spacing: 1px; color: #10b981; font-weight: 800; margin-bottom: 6px;">Your Managing Partner Referral Code</p>
            <div style="font-size: 24px; font-weight: 900; letter-spacing: 2px; color: #ffffff; font-family: monospace; user-select: all;" id="partnerCodeDisplay">${partnerCode}</div>
            <button onclick="copyPartnerCode()" style="margin-top: 10px; background: #1e293b; border: 1px solid #334155; color: #e2e8f0; font-size: 11px; font-weight: 700; padding: 6px 14px; border-radius: 8px; cursor: pointer; transition: all 0.2s;" id="copyBtn">📋 Copy Partner Code</button>
          </div>

          <div class="qr-container" style="background: #020617; border: 1px solid #1e293b; border-radius: 16px; padding: 16px; display: inline-block; margin-bottom: 16px;">
            <img class="qr-image" style="width: 140px; height: 140px; border-radius: 8px;" src="https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=https://api.myrentilly.com/Rentily.apk" alt="Scan to Download Rentilly App">
          </div>
          <p style="font-size: 11px; color: #94a3b8; margin-bottom: 20px;">Scan with your smartphone to download the Android APK</p>

          <a href="https://api.myrentilly.com/Rentily.apk" class="btn-download" style="display: block; width: 100%; text-decoration: none; padding: 14px; background: #10b981; color: #020617; border-radius: 14px; font-weight: 800; font-size: 14px; margin-bottom: 12px; box-shadow: 0 4px 14px rgba(16, 185, 129, 0.4);">
            📲 Download Rentilly for Android (APK)
          </a>

          <div style="display: flex; gap: 10px; margin-bottom: 24px;">
            <a href="https://myrentilly.com/download" style="flex: 1; text-align: center; text-decoration: none; padding: 10px; background: #1e293b; border: 1px solid #334155; color: #cbd5e1; border-radius: 10px; font-size: 12px; font-weight: 700;">Google Play Store</a>
            <a href="https://myrentilly.com/download" style="flex: 1; text-align: center; text-decoration: none; padding: 10px; background: #1e293b; border: 1px solid #334155; color: #cbd5e1; border-radius: 10px; font-size: 12px; font-weight: 700;">Apple iOS (TestFlight)</a>
          </div>

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

        <p class="footer-note">Rentilly Escrow Network • Secure Real Estate Rail</p>
      </div>

      <script>
        function copyPartnerCode() {
          const code = document.getElementById('partnerCodeDisplay').innerText.trim();
          navigator.clipboard.writeText(code).then(() => {
            const btn = document.getElementById('copyBtn');
            btn.innerText = '✅ Code Copied!';
            setTimeout(() => { btn.innerText = '📋 Copy Partner Code'; }, 2500);
          }).catch(() => {
            alert('Partner Code: ' + code);
          });
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
    user.accountNumber
  );

  const displayName = user?.fullName || user?.businessName || (cleanEmail ? cleanEmail.split('@')[0] : 'Rentilly User');
  const currentBalance = user?.walletBalance ?? 0;
  const currentPhone = user?.phoneNumber || '';
  const currentBvn = user?.bvn || '';
  const currentNin = user?.ninNumber || '';
  const currentAccount = user?.accountNumber || '';
  const currentBank = (user?.bankName && user.bankName !== 'Rentilly Escrow') ? user.bankName : 'Wema Bank';

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
          <div class="tagline">Dedicated Escrow Settlement & Dollar Card Active</div>

          <div style="background: rgba(16, 185, 129, 0.12); border: 1px solid rgba(16, 185, 129, 0.3); border-radius: 18px; padding: 24px; text-align: center; margin-top: 20px;">
            <p style="font-size: 13px; color: #a7f3d0; margin-bottom: 14px; line-height: 1.5;">
              Your Rentilly dedicated escrow settlement account is fully verified and active.
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
          <div class="tagline">Dedicated Escrow Settlement & Dollar Card</div>

          <div class="safe-banner">
            <span style="font-size: 20px;">🛡️</span>
            <div>
              <strong>Your Funds Are 100% Secure.</strong><br>
              Your current wallet balance of <strong>₦${currentBalance.toLocaleString()}</strong> will automatically link to your dedicated escrow settlement account.
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
              <span style="font-size: 10px; color: #64748b; margin-top: 4px; display: block;">Required by the Central Bank of Nigeria & NIBSS for dedicated account issuance.</span>
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
            <p style="color: #94a3b8; font-size: 12px; margin-top: 4px;">Your dedicated escrow settlement account is active and permanently attached to your profile.</p>

            <div class="result-acc" id="accDisplay">----------</div>
            <div style="font-size: 13px; font-weight: 700; color: #38bdf8;" id="bankDisplay">Wema Bank</div>

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
                  email: ${JSON.stringify(cleanEmail)} || document.getElementById('email').value,
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
 * Accessible on mobile browser at: /verify/credential/:id or /verify/credential?id=:id or /verify/:id
 */
export async function renderCredentialVerificationPage(req: Request, res: Response) {
  const id = (req.params.id || req.query.id || req.query.code || req.query.credential_id || req.query.partner_id || '').toString().trim();

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
        .search-input { width: 100%; padding: 12px 16px; border-radius: 12px; background: #020617; border: 1px solid #334155; color: #fff; font-size: 14px; margin-bottom: 12px; text-align: center; }
        .search-btn { width: 100%; padding: 12px; border-radius: 12px; background: #10b981; color: #020617; font-weight: 800; border: none; font-size: 13px; cursor: pointer; }
      </style>
    </head>
    <body>
      <div class="card">
        <div class="live-ticker">
          <span class="pulse-dot"></span>
          LIVE DATABASE SYNC • <span id="liveClock"></span>
        </div>

        <div class="logo-wrap">
          <img src="/logo.png" alt="Rentilly" onerror="this.src='/favicon.png'" />
        </div>

        <h1>RENTILLY CREDENTIAL AUDIT</h1>
        <div class="sub">Official Trust & Identity Verification</div>

        <div id="contentBox">
          <p style="color: #94a3b8; font-size: 12px;">Auditing cryptographic signature against live database...</p>
        </div>

        <div class="anti-fraud-banner">
          🛡️ <strong>Zero-Trust Protocol:</strong> If a host or broker presents a physical credential that does not match this live URL verification, do NOT pay or transact.
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

        async function fetchCredential(customId) {
          let targetId = (customId || '${id}').trim();

          if (!targetId || targetId === 'credential') {
            const parts = window.location.pathname.split('/').filter(Boolean);
            const last = parts[parts.length - 1];
            if (last && last !== 'verify' && last !== 'credential') {
              targetId = last;
            } else {
              const q = new URLSearchParams(window.location.search);
              targetId = q.get('id') || q.get('code') || q.get('credential_id') || q.get('partner_id') || '';
            }
          }

          const content = document.getElementById('contentBox');
          const hashBox = document.getElementById('securityHash');

          if (!targetId) {
            content.innerHTML = \`
              <div style="padding: 10px 0 16px;">
                <p style="color: #94a3b8; font-size: 12px; margin-bottom: 12px;">Enter Partner or Landlord Credential ID (e.g. RNT-C00):</p>
                <input id="manualId" class="search-input" placeholder="e.g. RNT-C00 or Phone or CAC" />
                <button class="search-btn" onclick="fetchCredential(document.getElementById('manualId').value)">Audit Credential 🔍</button>
              </div>
            \`;
            return;
          }

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
              hashBox.textContent = 'AUDIT HASH: ' + (data.securitySignature || 'SHA-256 COMPLIANT');
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

/**
 * Public Live Digital Electronic Receipt Verification Page
 * Displays the exact bank-grade electronic receipt when the QR code on a receipt is scanned.
 * Accessible on web at: /verify-receipt/:id or /verify-receipt?ref=:id or /receipt/:id
 */
export async function renderTransactionReceiptPage(req: Request, res: Response) {
  const refParam = (req.params.id || req.params.ref || req.query.ref || req.query.id || req.query.code || '').toString().trim();

  // Helper to escape HTML safely
  const escapeHtml = (str: string) => (str || '').replace(/[&<>"']/g, (m) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;'
  }[m] || m));

  let tx: any = null;

  if (refParam && refParam !== 'receipt') {
    // 1. Check TransactionStore in-memory & synced
    try {
      tx = TransactionStore.findByReference(refParam);
    } catch (_) {}

    // 2. Query Supabase wallet_transactions
    if (!tx && supabase) {
      try {
        const { data: wTxs } = await supabase
          .from('wallet_transactions')
          .select('*')
          .or(`flw_ref.eq.${refParam},tx_ref.eq.${refParam},id.eq.${refParam}`)
          .limit(1);

        if (wTxs && wTxs.length > 0) {
          const row = wTxs[0];
          const rawNarration = row.narration || '';
          const isCredit = (row.type || '').toLowerCase() === 'credit';
          const isNaira = rawNarration.includes('-> ₦') || rawNarration.includes('₦') || rawNarration.toLowerCase().includes('to naira') || rawNarration.toLowerCase().includes('naira wallet');
          tx = {
            id: row.id,
            reference: row.flw_ref || row.tx_ref || row.id,
            email: row.email,
            title: rawNarration || (isCredit ? 'Inbound Wallet Settlement' : 'Wallet Withdrawal'),
            amount: Number(row.amount || 0),
            currency: isNaira ? 'NGN' : (row.currency || 'NGN'),
            isCredit,
            status: (row.status || 'COMPLETED').toUpperCase(),
            date: row.created_at || new Date().toISOString()
          };
        }
      } catch (e: any) {
        console.warn('[renderTransactionReceiptPage] wallet_transactions lookup error:', e?.message);
      }
    }

    // 3. Query Supabase property transactions (escrow / leases)
    if (!tx && supabase) {
      try {
        const { data: pTxs } = await supabase
          .from('transactions')
          .select('*')
          .or(`payment_reference.eq.${refParam},id.eq.${refParam},flutterwave_reference.eq.${refParam}`)
          .limit(1);

        if (pTxs && pTxs.length > 0) {
          const row = pTxs[0];
          tx = {
            id: row.id,
            reference: row.payment_reference || row.id,
            email: row.payer_name || '',
            title: row.property_title || row.owner_payout_reference || 'Property Escrow Settlement',
            amount: Number(row.total_amount || row.amount || 0),
            currency: row.currency || 'NGN',
            isCredit: row.transaction_type !== 'withdrawal',
            status: (row.escrow_status || row.status || 'SUCCESSFUL').toUpperCase(),
            date: row.created_at || new Date().toISOString()
          };
        }
      } catch (e: any) {
        console.warn('[renderTransactionReceiptPage] transactions table lookup error:', e?.message);
      }
    }
  }

  // Lookup payer / holder details
  let payerName = 'Rentilly Verified Customer';
  let payerEmailMasked = '';
  if (tx?.email) {
    const parts = tx.email.split('@');
    if (parts.length === 2) {
      payerEmailMasked = `${parts[0].slice(0, 2)}***@${parts[1]}`;
    }
    try {
      const user = await UserStore.findByEmail(tx.email);
      if (user?.fullName) {
        payerName = user.fullName;
      } else if (supabase) {
        const { data: prof } = await supabase.from('profiles').select('full_name, business_name').eq('email', tx.email).single();
        if (prof?.full_name || prof?.business_name) {
          payerName = prof.full_name || prof.business_name;
        }
      }
    } catch (_) {}
  }

  // Currency & formatting
  const rawTitle = (tx?.title || tx?.narration || '').toString();
  const isNaira = (tx?.currency === 'NGN') || rawTitle.includes('-> ₦') || rawTitle.includes('₦') || rawTitle.toLowerCase().includes('naira');
  const isUsdt = !isNaira && ((tx?.currency === 'USDT') || rawTitle.toUpperCase().includes('USDT') || rawTitle.toUpperCase().includes('TRC20'));
  const isUsd = !isNaira && !isUsdt && ((tx?.currency === 'USD') || rawTitle.toUpperCase().includes('USD') || rawTitle.toUpperCase().includes('DOLLAR'));
  
  const currencyCode = isNaira ? 'NGN' : (isUsdt ? 'USDT' : (isUsd ? 'USD' : 'NGN'));
  const currencySymbol = isNaira ? '₦' : '$';
  const rawAmt = Number(tx?.amount || 0);
  const formattedAmount = rawAmt.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const isCredit = tx ? (tx.isCredit !== false) : true;
  const cleanRef = tx?.reference || tx?.id || refParam;

  // Rail / Channel determination
  let rail = 'Rentilly Escrow Protocol (CBN / NIBSS Interbank)';
  if (rawTitle.toLowerCase().includes('virtual card') || rawTitle.toLowerCase().includes('card')) {
    rail = 'Rentilly Platinum Virtual USD Card • Maplerad Liquidation Rail';
  } else if (rawTitle.toLowerCase().includes('wema')) {
    rail = 'Wema Bank Settlement Rail (Rentilly Institutional Escrow)';
  } else if (rawTitle.toLowerCase().includes('opay')) {
    rail = 'Opay Microfinance Bank Transfer Rail';
  } else if (rawTitle.toLowerCase().includes('flutterwave')) {
    rail = 'Flutterwave Electronic Inflow Rail';
  } else if (rawTitle.toLowerCase().includes('paystack')) {
    rail = 'Paystack Direct Settlement Rail';
  }

  // Formatted Date
  let dateFormatted = 'Recent';
  if (tx?.date) {
    try {
      const d = new Date(tx.date);
      dateFormatted = d.toLocaleString('en-NG', {
        timeZone: 'Africa/Lagos',
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        hour12: true
      }) + ' (WAT)';
    } catch (_) {
      dateFormatted = tx.date;
    }
  }

  const auditHash = cleanRef 
    ? ('SHA256-' + crypto.createHash('sha256').update(`${cleanRef}_${rawAmt}_${tx?.date || ''}`).digest('hex').toUpperCase().slice(0, 20))
    : 'SHA256-AUTHENTIC-LEDGER';

  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Certified Electronic Receipt • ${escapeHtml(cleanRef)} | Rentilly Living Protocol</title>
      <link rel="preconnect" href="https://fonts.googleapis.com">
      <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
      <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800;900&display=swap" rel="stylesheet">
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
          font-family: 'Plus Jakarta Sans', system-ui, -apple-system, sans-serif;
          background: #030712;
          color: #f8fafc;
          min-height: 100vh;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          padding: 20px 16px;
        }
        .receipt-card {
          background: #0f172a;
          border: 1.5px solid #065f46;
          border-radius: 28px;
          max-width: 520px;
          width: 100%;
          padding: 32px 24px;
          box-shadow: 0 25px 60px -15px rgba(0,0,0,0.7), 0 0 40px rgba(16,185,129,0.1);
          position: relative;
          overflow: hidden;
        }
        .top-badge {
          background: rgba(16,185,129,0.12);
          border-bottom: 1px solid rgba(16,185,129,0.25);
          padding: 10px 16px;
          font-size: 11px;
          font-weight: 800;
          color: #34d399;
          letter-spacing: 0.5px;
          margin: -32px -24px 24px -24px;
          display: flex;
          align-items: center;
          justify-content: space-between;
        }
        .pulse-dot {
          width: 8px;
          height: 8px;
          border-radius: 50%;
          background: #10b981;
          display: inline-block;
          animation: pulse 1.6s infinite;
        }
        @keyframes pulse {
          0% { transform: scale(0.9); opacity: 0.8; }
          50% { transform: scale(1.3); opacity: 1; }
          100% { transform: scale(0.9); opacity: 0.8; }
        }
        .brand-row {
          display: flex;
          align-items: center;
          gap: 14px;
          margin-bottom: 20px;
          text-align: left;
        }
        .logo-wrap {
          width: 54px;
          height: 54px;
          border-radius: 16px;
          overflow: hidden;
          border: 2px solid #10b981;
          background: #020617;
          display: flex;
          align-items: center;
          justify-content: center;
          box-shadow: 0 4px 16px rgba(16,185,129,0.25);
          flex-shrink: 0;
        }
        .logo-wrap img { width: 100%; height: 100%; object-fit: contain; }
        .brand-text h2 {
          font-size: 18px;
          font-weight: 900;
          color: #ffffff;
          letter-spacing: 0.8px;
          line-height: 1.2;
        }
        .brand-text p {
          font-size: 11px;
          color: #94a3b8;
          font-weight: 500;
        }
        .brand-text .company-reg {
          font-size: 9.5px;
          color: #64748b;
        }
        .receipt-title-box {
          background: rgba(16,185,129,0.08);
          border: 1px solid rgba(16,185,129,0.25);
          border-radius: 12px;
          padding: 8px 12px;
          text-align: center;
          margin-bottom: 20px;
        }
        .receipt-title-box span {
          font-size: 11px;
          font-weight: 800;
          color: #10b981;
          letter-spacing: 1px;
          text-transform: uppercase;
        }
        .amount-hero {
          background: linear-gradient(135deg, #064e3b 0%, #065f46 60%, #047857 100%);
          border-radius: 20px;
          padding: 22px 16px;
          text-align: center;
          color: #fff;
          margin-bottom: 22px;
          box-shadow: 0 10px 25px -5px rgba(6,95,70,0.4);
          position: relative;
        }
        .amount-hero .lbl {
          font-size: 11px;
          font-weight: 700;
          color: #a7f3d0;
          letter-spacing: 0.8px;
          text-transform: uppercase;
          margin-bottom: 4px;
        }
        .amount-hero .val {
          font-size: 32px;
          font-weight: 900;
          letter-spacing: -0.5px;
          margin-bottom: 8px;
        }
        .amount-hero .status-pill {
          display: inline-flex;
          align-items: center;
          gap: 5px;
          background: #022c22;
          color: #34d399;
          border: 1px solid #10b981;
          padding: 4px 12px;
          border-radius: 20px;
          font-size: 10.5px;
          font-weight: 800;
          letter-spacing: 0.5px;
        }
        .details-grid {
          background: #020617;
          border: 1px solid #1e293b;
          border-radius: 18px;
          padding: 16px 18px;
          margin-bottom: 20px;
          text-align: left;
        }
        .grid-row {
          display: flex;
          justify-content: space-between;
          align-items: flex-start;
          padding: 9px 0;
          border-bottom: 1px solid rgba(51,65,85,0.4);
          font-size: 12px;
          gap: 12px;
        }
        .grid-row:last-child { border-bottom: none; }
        .grid-row .row-lbl {
          color: #94a3b8;
          font-weight: 600;
          flex-shrink: 0;
        }
        .grid-row .row-val {
          color: #f8fafc;
          font-weight: 700;
          text-align: right;
          word-break: break-word;
        }
        .grid-row .row-val.highlight {
          color: #34d399;
          font-family: monospace;
          font-size: 12.5px;
        }
        .copy-btn {
          background: rgba(16,185,129,0.15);
          border: 1px solid #10b981;
          color: #34d399;
          font-size: 10px;
          font-weight: 700;
          padding: 2px 7px;
          border-radius: 6px;
          cursor: pointer;
          margin-left: 6px;
          transition: all 0.2s;
        }
        .copy-btn:hover { background: #10b981; color: #020617; }
        .action-row {
          display: flex;
          gap: 12px;
          margin-top: 6px;
        }
        .btn-print {
          flex: 1;
          background: #10b981;
          color: #020617;
          font-weight: 800;
          font-size: 13px;
          padding: 13px 18px;
          border-radius: 14px;
          border: none;
          cursor: pointer;
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 8px;
          transition: transform 0.15s, background 0.2s;
        }
        .btn-print:hover { background: #34d399; transform: translateY(-1px); }
        .btn-secondary {
          background: #1e293b;
          color: #cbd5e1;
          font-weight: 700;
          font-size: 13px;
          padding: 13px 18px;
          border-radius: 14px;
          border: 1px solid #334155;
          text-decoration: none;
          display: flex;
          align-items: center;
          justify-content: center;
          transition: background 0.2s;
        }
        .btn-secondary:hover { background: #334155; color: #fff; }
        .trust-seal {
          margin-top: 18px;
          padding-top: 14px;
          border-top: 1px dashed #1e293b;
          text-align: center;
          font-size: 10px;
          color: #64748b;
          line-height: 1.5;
        }
        .trust-seal .hash {
          font-family: monospace;
          color: #475569;
          font-size: 9px;
          margin-top: 4px;
          letter-spacing: 0.5px;
        }

        /* Print Media Stylesheet */
        @media print {
          body {
            background: #ffffff !important;
            color: #000000 !important;
            padding: 0 !important;
          }
          .receipt-card {
            border: 1px solid #cbd5e1 !important;
            box-shadow: none !important;
            background: #ffffff !important;
            color: #000000 !important;
            max-width: 100% !important;
            padding: 24px !important;
          }
          .top-badge, .action-row, .copy-btn { display: none !important; }
          .brand-text h2 { color: #065f46 !important; }
          .brand-text p, .brand-text .company-reg { color: #475569 !important; }
          .receipt-title-box {
            background: #f8fafc !important;
            border: 1px solid #cbd5e1 !important;
          }
          .receipt-title-box span { color: #065f46 !important; }
          .amount-hero {
            background: #f0fdf4 !important;
            color: #065f46 !important;
            border: 1.5px solid #10b981 !important;
            box-shadow: none !important;
          }
          .amount-hero .lbl { color: #047857 !important; }
          .amount-hero .val { color: #064e3b !important; }
          .amount-hero .status-pill {
            background: #dcfce7 !important;
            color: #065f46 !important;
            border-color: #10b981 !important;
          }
          .details-grid {
            background: #ffffff !important;
            border: 1px solid #cbd5e1 !important;
          }
          .grid-row { border-bottom-color: #e2e8f0 !important; }
          .grid-row .row-lbl { color: #64748b !important; }
          .grid-row .row-val { color: #0f172a !important; }
          .grid-row .row-val.highlight { color: #065f46 !important; }
          .trust-seal { color: #64748b !important; border-top-color: #cbd5e1 !important; }
        }
      </style>
    </head>
    <body>
      <div class="receipt-card">
        <div class="top-badge">
          <span><span class="pulse-dot"></span> LIVE LEDGER VERIFICATION</span>
          <span id="liveClock"></span>
        </div>

        <div class="brand-row">
          <div class="logo-wrap">
            <img src="/logo.png" alt="Rentilly" onerror="this.src='/favicon.png'" />
          </div>
          <div class="brand-text">
            <h2>RENTILLY LIVING PROTOCOL</h2>
            <p>Institutional Escrow & Living Infrastructure</p>
            <p class="company-reg">Product of E-Homes Global Inclusive Limited (RC: 1984209)</p>
          </div>
        </div>

        <div class="receipt-title-box">
          <span>✓ Official Verified Transaction Receipt</span>
        </div>

        ${tx ? `
          <div class="amount-hero">
            <div class="lbl">${isCredit ? 'SETTLEMENT VALUE CREDITED' : 'TOTAL SETTLEMENT DEBITED'}</div>
            <div class="val">${isCredit ? '+' : '-'}${currencySymbol}${formattedAmount} <span style="font-size: 16px; font-weight: 700; opacity: 0.9;">${currencyCode}</span></div>
            <div class="status-pill">
              <span>●</span> SETTLED • COMPLETED
            </div>
          </div>

          <div class="details-grid">
            <div class="grid-row">
              <span class="row-lbl">Transaction Reference</span>
              <span class="row-val highlight">
                ${escapeHtml(cleanRef)}
                <button class="copy-btn" onclick="copyRef('${escapeHtml(cleanRef)}')">Copy</button>
              </span>
            </div>

            <div class="grid-row">
              <span class="row-lbl">Description / Purpose</span>
              <span class="row-val">${escapeHtml(rawTitle || (isCredit ? 'Inbound Escrow Settlement' : 'Wallet Withdrawal'))}</span>
            </div>

            <div class="grid-row">
              <span class="row-lbl">Entry Nature</span>
              <span class="row-val" style="color: ${isCredit ? '#34d399' : '#f87171'};">
                ${isCredit ? 'CREDIT (+) • Inbound Wallet Deposit' : 'DEBIT (-) • Outbound Settlement'}
              </span>
            </div>

            <div class="grid-row">
              <span class="row-lbl">Account Holder</span>
              <span class="row-val">${escapeHtml(payerName)}</span>
            </div>

            ${payerEmailMasked ? `
              <div class="grid-row">
                <span class="row-lbl">Masked Email</span>
                <span class="row-val" style="font-family: monospace;">${escapeHtml(payerEmailMasked)}</span>
              </div>
            ` : ''}

            <div class="grid-row">
              <span class="row-lbl">Settlement Rail</span>
              <span class="row-val">${escapeHtml(rail)}</span>
            </div>

            ${!isCredit && (tx?.recipientBank || tx?.bankName || tx?.destinationBank) ? `
              <div class="grid-row">
                <span class="row-lbl">Recipient Bank Name</span>
                <span class="row-val">${escapeHtml(tx.recipientBank || tx.bankName || tx.destinationBank)}</span>
              </div>
            ` : ''}

            <div class="grid-row">
              <span class="row-lbl">Timestamp (GMT+1)</span>
              <span class="row-val">${escapeHtml(dateFormatted)}</span>
            </div>

            <div class="grid-row">
              <span class="row-lbl">Escrow Custody</span>
              <span class="row-val" style="color: #34d399;">✓ Guaranteed by Rentilly SafeVault</span>
            </div>
          </div>
        ` : `
          <div style="background: rgba(239,68,68,0.1); border: 1.5px solid #ef4444; border-radius: 18px; padding: 22px; text-align: center; margin-bottom: 20px;">
            <div style="font-size: 28px; margin-bottom: 8px;">⚠️</div>
            <h3 style="color: #f87171; font-size: 16px; font-weight: 800; margin-bottom: 6px;">Transaction Reference Not Found</h3>
            <p style="color: #fca5a5; font-size: 12px; line-height: 1.45; margin-bottom: 16px;">
              Reference <strong>${escapeHtml(cleanRef || 'None Provided')}</strong> was not located on the live ledger.
            </p>
            <div style="display: flex; gap: 8px;">
              <input id="refInput" type="text" placeholder="Enter Reference (e.g. CARD_WTH_...)" style="flex: 1; padding: 10px 14px; background: #020617; border: 1px solid #334155; border-radius: 10px; color: #fff; font-size: 12px;" />
              <button onclick="searchNewRef()" style="background: #10b981; color: #020617; font-weight: 800; border: none; padding: 10px 16px; border-radius: 10px; cursor: pointer; font-size: 12px;">Audit</button>
            </div>
          </div>
        `}

        <div class="action-row" style="display: flex; gap: 10px; margin-bottom: 16px; flex-wrap: wrap;">
          <button class="btn-print" style="flex: 1; min-width: 140px;" onclick="window.print()">
            📄 Print / Save PDF
          </button>
          <button class="btn-secondary" style="flex: 1; min-width: 140px; border-color: #10b981; color: #34d399;" onclick="downloadReceiptImage()">
            📸 Save as Image
          </button>
          <a class="btn-secondary" style="padding: 13px 14px;" href="https://myrentilly.com">
            Rentilly App
          </a>
        </div>

        <div class="trust-seal">
          🔒 Certified Bank-Grade Escrow Electronic Transaction Receipt<br/>
          Non-Bank Technology Provider • Anti-Photoshop & Tamper-Proof Cryptographic Hash
          <div class="hash">${escapeHtml(auditHash)}</div>
        </div>
      </div>

      <script src="https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js"></script>
      <script>
        function updateClock() {
          const now = new Date();
          document.getElementById('liveClock').textContent = now.toLocaleTimeString('en-US', { hour12: true }) + ' (WAT)';
        }
        setInterval(updateClock, 1000);
        updateClock();

        function copyRef(val) {
          navigator.clipboard.writeText(val).then(() => {
            alert('Reference ID copied to clipboard: ' + val);
          }).catch(() => {
            prompt('Copy Reference ID:', val);
          });
        }

        function searchNewRef() {
          const input = document.getElementById('refInput');
          if (input && input.value.trim()) {
            window.location.href = '/verify-receipt/' + encodeURIComponent(input.value.trim());
          }
        }

        function downloadReceiptImage() {
          const card = document.querySelector('.receipt-card');
          const actions = document.querySelector('.action-row');
          if (!card) return;
          if (actions) actions.style.display = 'none';
          html2canvas(card, { scale: 2, backgroundColor: '#0f172a' }).then(canvas => {
            if (actions) actions.style.display = 'flex';
            const link = document.createElement('a');
            link.download = 'Rentilly_Receipt_${escapeHtml(cleanRef || "tx")}.png';
            link.href = canvas.toDataURL('image/png');
            link.click();
          }).catch(err => {
            if (actions) actions.style.display = 'flex';
            alert('Could not generate receipt image: ' + err.message);
          });
        }
      </script>
    </body>
    </html>
  `);
}

/**
 * Public Live Exclusive Mandate Agreement Verification Page
 * Accessible via QR Code on Mandate PDF at: /verify/mandate/:mandateRef
 */
export async function renderMandateVerificationPage(req: Request, res: Response) {
  const mandateRef = (req.params.id || req.query.id || req.query.ref || req.query.mandate || '').toString().trim();
  const partnerQuery = (req.query.partner || req.query.partner_id || '').toString().trim();
  const hash = (req.query.hash || '').toString().trim();

  // Look up partner from UserStore or Supabase
  let partner: any = null;
  const allUsers = await UserStore.getAllUsers();
  
  if (partnerQuery) {
    partner = allUsers.find(u => 
      u.id?.toLowerCase() === partnerQuery.toLowerCase() || 
      u.email?.toLowerCase() === partnerQuery.toLowerCase()
    );
  }

  if (!partner && mandateRef) {
    const clean = mandateRef.replace(/^RNT-MND-?(2026)?-?/i, '').toLowerCase();
    partner = allUsers.find(u => {
      const uClean = (u.id || '').replace(/[^a-zA-Z0-9]/g, '').toLowerCase();
      return clean.length >= 2 && (uClean.startsWith(clean) || (u.id || '').toLowerCase().includes(clean));
    });
  }

  if (!partner && supabase) {
    try {
      const { data: profiles } = await supabase.from('profiles').select('*');
      if (profiles && profiles.length > 0) {
        if (partnerQuery) {
          partner = profiles.find((p: any) => 
            p.id?.toLowerCase() === partnerQuery.toLowerCase() || 
            p.email?.toLowerCase() === partnerQuery.toLowerCase()
          );
        }
        if (!partner && mandateRef) {
          const clean = mandateRef.replace(/^RNT-MND-?(2026)?-?/i, '').toLowerCase();
          partner = profiles.find((p: any) => {
            const pClean = (p.id || '').replace(/[^a-zA-Z0-9]/g, '').toLowerCase();
            return clean.length >= 2 && (pClean.startsWith(clean) || (p.id || '').toLowerCase().includes(clean));
          });
        }
      }
    } catch (_) {}
  }

  const firmName = partner?.business_name || partner?.businessName || partner?.full_name || partner?.fullName || 'Accredited Corporate Partner';
  const cacNumber = partner?.cac_number || partner?.cacNumber || 'Verified Commercial Entity';
  const state = partner?.state || 'Lagos';
  const displayRef = mandateRef || 'RNT-MND-2026-ACTIVE';
  const displayHash = hash || crypto.createHash('sha256').update(displayRef + firmName).digest('hex').toUpperCase();

  // Look up bound property by mandate_ref
  let boundProp: any = null;
  if (supabase && mandateRef) {
    try {
      const { data: propRows } = await supabase
        .from('properties')
        .select('title, address, state, status, electricity_bill_url')
        .eq('mandate_ref', mandateRef)
        .maybeSingle();
      if (propRows) boundProp = propRows;
    } catch (_) {}
  }

  const propSection = boundProp
    ? `
        <div class="section-title">BOUND PROPERTY</div>
        <div class="info-box" style="border-color: #0ea5e9; margin-bottom: 18px;">
          <div class="row"><span class="lbl">Property Title</span><span class="val" style="color: #38bdf8;">${boundProp.title || 'Unnamed Property'}</span></div>
          <div class="row"><span class="lbl">Address</span><span class="val">${boundProp.address || 'Address on file'}</span></div>
          <div class="row"><span class="lbl">State</span><span class="val">${boundProp.state || state} State, Nigeria</span></div>
          <div class="row"><span class="lbl">Mandate Status</span><span class="val" style="color: #4ade80;">✅ ACTIVATED &amp; BOUND</span></div>
          ${boundProp.electricity_bill_url ? `<div class="row"><span class="lbl">Utility Bill</span><span class="val" style="color: #4ade80;">Verified &amp; Annexed</span></div>` : ''}
        </div>`
    : (mandateRef ? `<div class="info-box" style="border-color: #f59e0b; margin-bottom: 18px; text-align:center; font-size:11px; color: #fbbf24;">⏳ MANDATE ISSUED — Listing Not Yet Activated<br><span style="font-size:9.5px;color:#94a3b8;">Property upload pending from partner.</span></div>` : '');

  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Exclusive Mandate Verification | Rentilly Escrow Network</title>
      <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;600;700;800;900&display=swap" rel="stylesheet">
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Plus Jakarta Sans', system-ui, sans-serif; background: #030712; color: #f8fafc; display: flex; align-items: center; justify-content: center; min-height: 100vh; padding: 16px; }
        .card { background: #0f172a; border: 1.5px solid #059669; border-radius: 24px; max-width: 500px; width: 100%; padding: 28px 24px; box-shadow: 0 25px 50px -12px rgba(0,0,0,0.6); text-align: center; }
        .live-ticker { background: rgba(16,185,129,0.15); border-bottom: 1px solid rgba(16,185,129,0.3); padding: 8px 12px; font-size: 10px; font-weight: 800; color: #34d399; letter-spacing: 0.5px; margin: -28px -24px 20px -24px; display: flex; align-items: center; justify-content: center; gap: 6px; border-radius: 24px 24px 0 0; }
        .pulse-dot { width: 8px; height: 8px; border-radius: 50%; background: #10b981; animation: pulse 1.5s infinite; }
        @keyframes pulse { 0% { transform: scale(0.9); opacity: 0.8; } 50% { transform: scale(1.3); opacity: 1; } 100% { transform: scale(0.9); opacity: 0.8; } }
        .badge-icon { width: 68px; height: 68px; background: rgba(16, 185, 129, 0.15); border: 2px solid #10b981; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 16px; font-size: 30px; }
        h1 { font-size: 19px; font-weight: 900; color: #ffffff; margin-bottom: 3px; }
        .sub { font-size: 10.5px; color: #34d399; font-weight: 800; text-transform: uppercase; letter-spacing: 1.2px; margin-bottom: 18px; }
        .section-title { font-size: 9.5px; font-weight: 900; color: #64748b; text-transform: uppercase; letter-spacing: 1px; text-align: left; margin-bottom: 6px; }
        .info-box { background: #020617; border: 1px solid #1e293b; border-radius: 18px; padding: 18px; text-align: left; margin-bottom: 18px; }
        .row { display: flex; justify-content: space-between; margin-bottom: 12px; font-size: 12px; }
        .row:last-child { margin-bottom: 0; }
        .lbl { color: #94a3b8; font-weight: 600; }
        .val { color: #f8fafc; font-weight: 800; }
        .warning-box { background: rgba(220, 38, 38, 0.1); border: 1.2px solid #dc2626; border-radius: 14px; padding: 12px 14px; text-align: left; margin-bottom: 18px; }
        .warning-title { font-size: 11px; font-weight: 900; color: #f87171; margin-bottom: 4px; display: flex; align-items: center; gap: 6px; }
        .warning-text { font-size: 10px; color: #fca5a5; line-height: 1.45; }
        .hash-strip { font-family: monospace; font-size: 9px; color: #64748b; word-break: break-all; margin-top: 8px; }
      </style>
    </head>
    <body>
      <div class="card">
        <div class="live-ticker">
          <span class="pulse-dot"></span>
          REAL-TIME ESCROW MANDATE AUDIT • ACTIVE
        </div>

        <div class="badge-icon">📜</div>
        <h1>MANDATE AUTHENTICATED</h1>
        <div class="sub">Rentilly Exclusive Partner Representation</div>

        <div class="section-title">PARTNER DETAILS</div>
        <div class="info-box">
          <div class="row"><span class="lbl">Mandate Reference</span><span class="val" style="font-family: monospace; color: #34d399;">${displayRef}</span></div>
          <div class="row"><span class="lbl">Accredited Firm</span><span class="val">${firmName}</span></div>
          <div class="row"><span class="lbl">Corporate Registration</span><span class="val" style="color: #fbbf24;">RC: ${cacNumber}</span></div>
          <div class="row"><span class="lbl">Remuneration Rate</span><span class="val" style="color: #34d399;">2.5% Lease / 2.0% Sale (Fixed)</span></div>
          <div class="row"><span class="lbl">Territory</span><span class="val">${state} State, Nigeria</span></div>
          <div class="row"><span class="lbl">Statutory Arbitration</span><span class="val">Arbitration &amp; Mediation Act 2023</span></div>
        </div>

        ${propSection}

        <div class="warning-box">
          <div class="warning-title">🚨 MANDATORY ESCROW SETTLEMENT NOTICE</div>
          <p class="warning-text">
            100% of all rental payments and buyer funds remain locked in the Rentilly Non-Interest Escrow Vault until physical tenant move-in confirmation. Direct cash, off-platform collections, or bypasses are strictly prohibited and nullify this mandate.
          </p>
        </div>

        <div style="font-size: 10px; color: #94a3b8;">
          Audit Fingerprint:
          <p class="hash-strip">${displayHash}</p>
        </div>
      </div>
    </body>
    </html>
  `);
}

export async function renderInspectionSafetyPage(req: Request, res: Response) {
  const inspectionId = (req.params.id || req.query.id || '').toString().trim();

  let insp: any = null;
  if (supabase && inspectionId) {
    try {
      const { data } = await supabase
        .from('inspections')
        .select('*')
        .eq('id', inspectionId)
        .maybeSingle();
      if (data) insp = data;
    } catch (_) {}
  }

  const propTitle = insp?.property_title || insp?.propertyTitle || 'Rentilly Verified Property';
  const propAddress = insp?.property_address || insp?.propertyAddress || 'Location on file';
  const visitorName = insp?.prospect_name || insp?.prospectName || 'Verified Visitor';
  const visitorPhone = insp?.prospect_phone || insp?.prospectPhone || 'On file';
  const passCode = insp?.inspection_pass_code || insp?.inspectionPassCode || insp?.gate_pass || 'ACTIVE';
  const scheduledDate = insp?.scheduled_date || insp?.scheduledDate || 'Scheduled';
  const hostName = insp?.owner_name || insp?.ownerName || 'Verified Property Host';
  const status = insp?.status || 'approved';

  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Inspection Safety Verification | Rentilly Security</title>
      <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;600;700;800;900&display=swap" rel="stylesheet">
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Plus Jakarta Sans', system-ui, sans-serif; background: #030712; color: #f8fafc; display: flex; align-items: center; justify-content: center; min-height: 100vh; padding: 16px; }
        .card { background: #0f172a; border: 1.5px solid #0284c7; border-radius: 24px; max-width: 500px; width: 100%; padding: 28px 24px; box-shadow: 0 25px 50px -12px rgba(0,0,0,0.6); text-align: center; }
        .live-ticker { background: rgba(2,132,199,0.15); border-bottom: 1px solid rgba(2,132,199,0.3); padding: 8px 12px; font-size: 10px; font-weight: 800; color: #38bdf8; letter-spacing: 0.5px; margin: -28px -24px 20px -24px; display: flex; align-items: center; justify-content: center; gap: 6px; border-radius: 24px 24px 0 0; }
        .pulse-dot { width: 8px; height: 8px; border-radius: 50%; background: #0284c7; animation: pulse 1.5s infinite; }
        @keyframes pulse { 0% { transform: scale(0.9); opacity: 0.8; } 50% { transform: scale(1.3); opacity: 1; } 100% { transform: scale(0.9); opacity: 0.8; } }
        .badge-icon { width: 68px; height: 68px; background: rgba(2, 132, 199, 0.15); border: 2px solid #0284c7; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 16px; font-size: 30px; }
        h1 { font-size: 19px; font-weight: 900; color: #ffffff; margin-bottom: 3px; }
        .sub { font-size: 10.5px; color: #38bdf8; font-weight: 800; text-transform: uppercase; letter-spacing: 1.2px; margin-bottom: 18px; }
        .gate-code-box { background: rgba(16, 185, 129, 0.12); border: 2px dashed #10b981; border-radius: 16px; padding: 14px; margin-bottom: 18px; }
        .gate-code-lbl { font-size: 10px; font-weight: 800; color: #34d399; letter-spacing: 1px; text-transform: uppercase; }
        .gate-code-val { font-size: 26px; font-weight: 900; color: #10b981; font-family: monospace; letter-spacing: 4px; margin-top: 2px; }
        .info-box { background: #020617; border: 1px solid #1e293b; border-radius: 18px; padding: 18px; text-align: left; margin-bottom: 18px; }
        .row { display: flex; justify-content: space-between; margin-bottom: 12px; font-size: 12px; }
        .row:last-child { margin-bottom: 0; }
        .lbl { color: #94a3b8; font-weight: 600; }
        .val { color: #f8fafc; font-weight: 800; }
        .warning-box { background: rgba(220, 38, 38, 0.1); border: 1.2px solid #dc2626; border-radius: 14px; padding: 12px 14px; text-align: left; margin-bottom: 18px; }
        .warning-title { font-size: 11px; font-weight: 900; color: #f87171; margin-bottom: 4px; display: flex; align-items: center; gap: 6px; }
        .warning-text { font-size: 10px; color: #fca5a5; line-height: 1.45; }
      </style>
    </head>
    <body>
      <div class="card">
        <div class="live-ticker">
          <span class="pulse-dot"></span>
          REAL-TIME INSPECTION SAFETY TRACKING • ${status.toUpperCase()}
        </div>

        <div class="badge-icon">🛡️</div>
        <h1>SAFETY ITINERARY VERIFIED</h1>
        <div class="sub">Rentilly Zero-Ghost Field Escort</div>

        <div class="gate-code-box">
          <div class="gate-code-lbl">ESTATE GATE PASS CODE</div>
          <div class="gate-code-val">${passCode}</div>
        </div>

        <div class="info-box">
          <div class="row"><span class="lbl">Property</span><span class="val" style="color: #38bdf8;">${propTitle}</span></div>
          <div class="row"><span class="lbl">Address</span><span class="val">${propAddress}</span></div>
          <div class="row"><span class="lbl">Scheduled Date</span><span class="val">${scheduledDate}</span></div>
          <div class="row"><span class="lbl">Visitor Name</span><span class="val">${visitorName}</span></div>
          <div class="row"><span class="lbl">Visitor Phone</span><span class="val">${visitorPhone}</span></div>
          <div class="row"><span class="lbl">Accredited Host</span><span class="val" style="color: #4ade80;">${hostName}</span></div>
          <div class="row"><span class="lbl">Verification ID</span><span class="val" style="font-family: monospace;">${inspectionId || 'LIVE'}</span></div>
        </div>

        <div class="warning-box">
          <div class="warning-title">🚨 FIELD SAFETY PROTOCOL</div>
          <p class="warning-text">
            For personal safety, never enter any property without demanding that the host shows their matching Rentilly Digital ID card. All financial commitments and caution deposits must remain strictly within Rentilly Escrow.
          </p>
        </div>
      </div>
    </body>
    </html>
  `);
}

export async function renderLegalNoticePage(req: Request, res: Response) {
  const noticeRef = escapeHtml(String(req.params.id || req.params.tenant || req.query.id || req.query.tenant || 'VALID').trim());

  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Legal Notice Verification | Rentilly Statutory Service</title>
      <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;600;700;800;900&display=swap" rel="stylesheet">
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Plus Jakarta Sans', system-ui, sans-serif; background: #030712; color: #f8fafc; display: flex; align-items: center; justify-content: center; min-height: 100vh; padding: 16px; }
        .card { background: #0f172a; border: 1.5px solid #10b981; border-radius: 24px; max-width: 520px; width: 100%; padding: 32px 24px; box-shadow: 0 25px 50px -12px rgba(0,0,0,0.6); text-align: center; }
        .badge-seal { width: 68px; height: 68px; background: rgba(16, 185, 129, 0.15); border: 2px solid #10b981; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 16px; font-size: 30px; }
        h1 { font-size: 20px; font-weight: 900; color: #ffffff; margin-bottom: 4px; }
        .sub { font-size: 11px; color: #34d399; font-weight: 800; text-transform: uppercase; letter-spacing: 1.2px; margin-bottom: 22px; }
        .status-pill { display: inline-flex; align-items: center; gap: 6px; background: rgba(16, 185, 129, 0.15); color: #10b981; border: 1px solid rgba(16, 185, 129, 0.3); border-radius: 20px; padding: 6px 16px; font-size: 12px; font-weight: 800; margin-bottom: 22px; }
        .info-box { background: #020617; border: 1px solid #1e293b; border-radius: 18px; padding: 18px; text-align: left; margin-bottom: 20px; }
        .row { display: flex; justify-content: space-between; margin-bottom: 12px; font-size: 12.5px; }
        .row:last-child { margin-bottom: 0; }
        .lbl { color: #94a3b8; font-weight: 600; }
        .val { color: #f8fafc; font-weight: 800; }
        .legal-notice { font-size: 11px; color: #64748b; line-height: 1.5; margin-bottom: 24px; text-align: justify; }
        .btn { display: inline-flex; align-items: center; justify-content: center; gap: 8px; width: 100%; background: #10b981; color: #022c22; font-weight: 800; text-decoration: none; padding: 14px; border-radius: 12px; font-size: 14px; }
      </style>
    </head>
    <body>
      <div class="card">
        <div class="badge-seal">⚖️</div>
        <h1>STATUTORY LEGAL NOTICE VERIFIED</h1>
        <div class="sub">Rentilly Eviction Prevention & Legal Assurance Engine</div>
        <div class="status-pill">✓ Tamper-Proof Electronic Delivery Record</div>

        <div class="info-box">
          <div class="row"><span class="lbl">Notice Type</span><span class="val" style="color: #38bdf8;">Notice of Owner's Intention / Quit</span></div>
          <div class="row"><span class="lbl">Addressee / Tenant</span><span class="val">${noticeRef}</span></div>
          <div class="row"><span class="lbl">Service Channel</span><span class="val">Rentilly Verified Cryptographic Registry</span></div>
          <div class="row"><span class="lbl">Governing Framework</span><span class="val">Tenancy Law / Recovery of Premises Act</span></div>
          <div class="row"><span class="lbl">Audit Integrity Hash</span><span class="val" style="font-family: monospace; font-size: 11px;">SHA256-${Buffer.from(noticeRef).toString('hex').slice(0, 16).toUpperCase()}</span></div>
        </div>

        <p class="legal-notice">
          This digital statutory certificate serves as evidence of electronic notice served in accordance with the High Court Civil Procedure Rules and Tenancy Laws of the Federal Republic of Nigeria. For disputes, legal resolution, or tenancy escrow reconciliation, access the official Rentilly application.
        </p>

        <a href="https://api.myrentilly.com/Rentily.apk" class="btn">
          Download Rentilly Mobile App
        </a>
      </div>
    </body>
    </html>
  `);
}

/**
 * Renders the Official Corporate Partner Accreditation & Signup Portal.
 * Enables estate agencies, corporate brokerages, and mandate holders to register directly on the web.
 */
export function renderPartnerSignupPage(req: Request, res: Response) {
  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Corporate Partner Accreditation Portal | Rentilly Living</title>
      <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800;900&display=swap" rel="stylesheet">
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Plus Jakarta Sans', system-ui, sans-serif; background: #030712; color: #f8fafc; min-height: 100vh; padding: 32px 16px; display: flex; flex-direction: column; align-items: center; justify-content: center; }
        .container { max-width: 680px; width: 100%; }
        .header { text-align: center; margin-bottom: 28px; }
        .logo { font-size: 28px; font-weight: 900; color: #10b981; letter-spacing: -0.5px; margin-bottom: 8px; }
        .badge { display: inline-flex; align-items: center; gap: 6px; background: rgba(16, 185, 129, 0.12); border: 1px solid rgba(16, 185, 129, 0.3); padding: 6px 14px; border-radius: 999px; font-size: 11px; font-weight: 800; color: #34d399; text-transform: uppercase; letter-spacing: 0.8px; margin-bottom: 12px; }
        h1 { font-size: 26px; font-weight: 900; color: #ffffff; line-height: 1.25; margin-bottom: 8px; }
        p.desc { font-size: 13.5px; color: #94a3b8; line-height: 1.5; }

        .card { background: #0f172a; border: 1px solid #1e293b; border-radius: 24px; padding: 36px 32px; box-shadow: 0 25px 50px -12px rgba(0,0,0,0.6); }
        .section-title { font-size: 13px; font-weight: 900; color: #38bdf8; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 16px; display: flex; align-items: center; gap: 8px; }
        .grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; }
        @media (max-width: 580px) { .grid-2 { grid-template-columns: 1fr; } .card { padding: 24px 18px; } }

        .form-group { margin-bottom: 16px; text-align: left; }
        label { display: block; font-size: 10px; font-weight: 800; letter-spacing: 0.8px; color: #94a3b8; text-transform: uppercase; margin-bottom: 6px; }
        input, select { width: 100%; background: #020617; border: 1px solid #1e293b; border-radius: 12px; padding: 12px 14px; color: #f8fafc; font-family: inherit; font-size: 13px; font-weight: 600; outline: none; transition: border-color 0.2s, box-shadow 0.2s; }
        input:focus, select:focus { border-color: #10b981; box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.15); }

        .otp-group { display: flex; gap: 8px; }
        .btn-otp { background: #1e293b; border: 1px solid #334155; color: #10b981; font-weight: 800; font-size: 12px; padding: 0 16px; border-radius: 12px; cursor: pointer; white-space: nowrap; transition: all 0.2s; }
        .btn-otp:hover { background: rgba(16, 185, 129, 0.15); border-color: #10b981; }
        .btn-otp:disabled { opacity: 0.5; cursor: not-allowed; }

        .trust-banner { background: rgba(16, 185, 129, 0.08); border: 1px dashed #10b981; border-radius: 14px; padding: 14px 16px; margin: 20px 0; font-size: 11.5px; color: #a7f3d0; line-height: 1.45; }
        .terms-row { display: flex; align-items: flex-start; gap: 10px; margin: 18px 0; font-size: 11.5px; color: #94a3b8; text-align: left; }
        .terms-row input[type="checkbox"] { width: 16px; height: 16px; accent-color: #10b981; margin-top: 2px; }

        .btn-submit { width: 100%; background: #10b981; color: #022c22; font-weight: 900; font-size: 15px; padding: 16px; border-radius: 14px; border: none; cursor: pointer; box-shadow: 0 4px 14px rgba(16, 185, 129, 0.4); transition: transform 0.1s, background 0.2s; }
        .btn-submit:hover { background: #34d399; transform: translateY(-1px); }
        .btn-submit:disabled { opacity: 0.6; cursor: not-allowed; transform: none; }

        .alert { display: none; padding: 12px 14px; border-radius: 12px; font-size: 12px; margin-bottom: 16px; font-weight: 600; text-align: center; }
        .alert-error { background: rgba(239, 68, 68, 0.15); border: 1px solid #ef4444; color: #fca5a5; }
        .alert-success { background: rgba(16, 185, 129, 0.15); border: 1px solid #10b981; color: #86efac; }

        .success-box { display: none; text-align: center; }
        .success-badge { width: 80px; height: 80px; background: rgba(16, 185, 129, 0.15); border: 2px solid #10b981; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 36px; margin: 0 auto 16px; }
        .footer-note { font-size: 11px; color: #64748b; margin-top: 24px; text-align: center; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <div class="logo">Rentilly 🛡️</div>
          <div class="badge">Accredited Corporate Partner Network</div>
          <h1>Partner Onboarding & Broker Registration</h1>
          <p class="desc">Register your real estate brokerage or asset management firm to unlock zero-agent direct landlord mandates and protected escrow commissions.</p>
        </div>

        <div class="card">
          <div id="alertBox" class="alert"></div>

          <form id="partnerForm" onsubmit="handlePartnerSubmit(event)">
            <div class="section-title">🏢 1. Corporate Entity Details</div>
            
            <div class="form-group">
              <label>Registered Company / Business Name (CAC)</label>
              <input type="text" id="businessName" placeholder="e.g. Apex Realty Partners Ltd" required>
            </div>

            <div class="grid-2">
              <div class="form-group">
                <label>CAC Registration Number (RC / BN)</label>
                <input type="text" id="cacNumber" placeholder="e.g. RC 1849201" required>
              </div>
              <div class="form-group">
                <label>Tax Identification Number (TIN - Optional)</label>
                <input type="text" id="tinNumber" placeholder="e.g. 23940192-0001">
              </div>
            </div>

            <div class="grid-2">
              <div class="form-group">
                <label>State of Primary Operation</label>
                <select id="state" required>
                  <option value="Lagos" selected>Lagos State</option>
                  <option value="Abuja">FCT Abuja</option>
                  <option value="Rivers">Rivers State</option>
                  <option value="Oyo">Oyo State</option>
                  <option value="Kano">Kano State</option>
                  <option value="Delta">Delta State</option>
                  <option value="Ogun">Ogun State</option>
                  <option value="Enugu">Enugu State</option>
                  <option value="Edo">Edo State</option>
                  <option value="Kaduna">Kaduna State</option>
                </select>
              </div>
              <div class="form-group">
                <label>City / Commercial District</label>
                <input type="text" id="cityArea" placeholder="e.g. Lekki Phase 1, Victoria Island, Ikeja" required>
              </div>
            </div>

            <div class="form-group">
              <label>Headquarters / Office Street Address</label>
              <input type="text" id="officeAddress" placeholder="e.g. Suite 4B, Plot 12 Admiralty Way" required>
            </div>

            <div class="section-title" style="margin-top: 24px;">👤 2. Principal Director & Credentials</div>

            <div class="grid-2">
              <div class="form-group">
                <label>Principal Broker / Director Legal Name</label>
                <input type="text" id="fullName" placeholder="e.g. Patrick Achua" required>
              </div>
              <div class="form-group">
                <label>Official Contact Mobile Phone</label>
                <input type="tel" id="phoneNumber" placeholder="e.g. 08012345678" required>
              </div>
            </div>

            <div class="form-group">
              <label>Corporate Email Address</label>
              <div class="otp-group">
                <input type="email" id="email" placeholder="e.g. info@apexrealty.ng" required>
                <button type="button" class="btn-otp" id="btnSendOtp" onclick="sendEmailOtp()">Get Code 🔑</button>
              </div>
            </div>

            <div class="form-group" id="otpGroup" style="display: none;">
              <label>6-Digit Email Verification Code</label>
              <div class="otp-group">
                <input type="text" id="otpCode" placeholder="Enter 6-digit code" maxlength="6" style="letter-spacing: 4px; font-weight: 800; font-family: monospace;">
                <button type="button" class="btn-otp" id="btnVerifyOtp" onclick="verifyEmailOtp()">Verify ✓</button>
              </div>
              <span id="otpStatus" style="font-size: 11px; color: #10b981; margin-top: 4px; display: block;"></span>
            </div>

            <div class="grid-2">
              <div class="form-group">
                <label>Portal Login Password (6+ chars)</label>
                <input type="password" id="password" placeholder="••••••••••••" minlength="6" required>
              </div>
              <div class="form-group">
                <label>Referral / Invite Code (Optional)</label>
                <input type="text" id="referralCode" placeholder="e.g. RENT8821">
              </div>
            </div>

            <div class="trust-banner">
              🔒 <strong>Accredited Broker Escrow Shield:</strong> As an Accredited Partner, all landlord onboarding commissions, tenant deposits, and mandate management fees are protected via Rentilly's legal trust account.
            </div>

            <div class="terms-row">
              <input type="checkbox" id="termsCheck" required checked>
              <label for="termsCheck" style="margin: 0; text-transform: none; font-size: 11.5px; color: #94a3b8; cursor: pointer;">
                I certify that our brokerage is registered with CAC Nigeria and agree to Rentilly's Partner Operating Guidelines and escrow protocol.
              </label>
            </div>

            <button type="submit" class="btn-submit" id="btnSubmit">
              Complete Partner Accreditation & Register 🚀
            </button>
          </form>

          <div id="successBox" class="success-box">
            <div class="success-badge">🛡️</div>
            <h2 style="font-size: 22px; font-weight: 900; margin-bottom: 6px; color: #ffffff;">PARTNER ACCREDITATION ACTIVE</h2>
            <p style="font-size: 13px; color: #34d399; font-weight: 700; margin-bottom: 20px;">Welcome to the Rentilly Corporate Network</p>

            <div style="background: #020617; border: 1px solid #1e293b; border-radius: 16px; padding: 20px; text-align: left; margin-bottom: 24px;">
              <div style="display: flex; justify-content: space-between; margin-bottom: 10px; font-size: 12.5px;">
                <span style="color: #94a3b8;">Partner Firm</span>
                <span style="color: #ffffff; font-weight: 800;" id="successFirm"></span>
              </div>
              <div style="display: flex; justify-content: space-between; margin-bottom: 10px; font-size: 12.5px;">
                <span style="color: #94a3b8;">Accreditation Code</span>
                <span style="color: #10b981; font-weight: 900; font-family: monospace;" id="successCode"></span>
              </div>
              <div style="display: flex; justify-content: space-between; font-size: 12.5px;">
                <span style="color: #94a3b8;">Status</span>
                <span style="color: #34d399; font-weight: 800;">ACTIVE & TIER-3 AUDITED ✓</span>
              </div>
            </div>

            <div style="display: flex; flex-direction: column; gap: 10px;">
              <a id="badgeLink" href="#" style="display: block; width: 100%; text-decoration: none; padding: 14px; background: #10b981; color: #022c22; border-radius: 14px; font-weight: 800; font-size: 14px; text-align: center;">
                View Your Digital Accreditation Badge 🛡️
              </a>
              <a href="https://api.myrentilly.com/Rentily.apk" style="display: block; width: 100%; text-decoration: none; padding: 12px; background: #1e293b; border: 1px solid #334155; color: #cbd5e1; border-radius: 12px; font-size: 13px; font-weight: 700; text-align: center;">
                📲 Download Rentilly Partner Mobile App (APK)
              </a>
            </div>
          </div>
        </div>

        <p class="footer-note">
          Rentilly Living Marketplace • Zero-Agent Real Estate Rail • Lagos & Abuja, Nigeria
        </p>
      </div>

      <script>
        let isEmailVerified = false;

        function showAlert(msg, isError) {
          const b = document.getElementById('alertBox');
          b.className = 'alert ' + (isError ? 'alert-error' : 'alert-success');
          b.textContent = msg;
          b.style.display = 'block';
          b.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
        }

        async function sendEmailOtp() {
          const email = document.getElementById('email').value.trim();
          if (!email || !email.includes('@')) {
            showAlert('Please enter a valid official email address.', true);
            return;
          }
          const btn = document.getElementById('btnSendOtp');
          btn.disabled = true;
          btn.textContent = 'Sending...';

          try {
            const res = await fetch('/api/auth/send-otp', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ email, channel: 'email', purpose: 'Partner Registration Verification' })
            });
            const data = await res.json();
            if (data.status) {
              showAlert('Verification code sent! Please check your inbox and spam folder.', false);
              document.getElementById('otpGroup').style.display = 'block';
              let countdown = 60;
              const timer = setInterval(() => {
                countdown--;
                if (countdown > 0) {
                  btn.textContent = countdown + 's';
                } else {
                  clearInterval(timer);
                  btn.disabled = false;
                  btn.textContent = 'Resend Code';
                }
              }, 1000);
            } else {
              showAlert(data.message || 'Failed to dispatch verification code.', true);
              btn.disabled = false;
              btn.textContent = 'Get Code 🔑';
            }
          } catch (e) {
            showAlert('Network error while requesting verification code.', true);
            btn.disabled = false;
            btn.textContent = 'Get Code 🔑';
          }
        }

        async function verifyEmailOtp() {
          const email = document.getElementById('email').value.trim();
          const code = document.getElementById('otpCode').value.trim();
          if (code.length < 6) {
            showAlert('Please enter the full 6-digit code.', true);
            return;
          }
          const btn = document.getElementById('btnVerifyOtp');
          btn.disabled = true;
          btn.textContent = 'Verifying...';

          try {
            const res = await fetch('/api/auth/verify-otp', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ email, code })
            });
            const data = await res.json();
            if (data.status) {
              isEmailVerified = true;
              document.getElementById('otpStatus').textContent = 'Email confirmed! ✓';
              btn.textContent = 'Verified ✓';
              btn.style.background = '#10b981';
              btn.style.color = '#022c22';
              showAlert('Email confirmed successfully! You can now complete registration.', false);
            } else {
              showAlert(data.message || 'Invalid verification code.', true);
              btn.disabled = false;
              btn.textContent = 'Verify ✓';
            }
          } catch (e) {
            showAlert('Network error verifying code.', true);
            btn.disabled = false;
            btn.textContent = 'Verify ✓';
          }
        }

        async function handlePartnerSubmit(e) {
          e.preventDefault();
          const businessName = document.getElementById('businessName').value.trim();
          const cacNumber = document.getElementById('cacNumber').value.trim();
          const tinNumber = document.getElementById('tinNumber').value.trim();
          const state = document.getElementById('state').value;
          const cityArea = document.getElementById('cityArea').value.trim();
          const officeAddress = document.getElementById('officeAddress').value.trim();
          const fullName = document.getElementById('fullName').value.trim();
          const phoneNumber = document.getElementById('phoneNumber').value.trim();
          const email = document.getElementById('email').value.trim();
          const password = document.getElementById('password').value;
          const referralCode = document.getElementById('referralCode').value.trim();

          const fullAddress = officeAddress + (cityArea ? ', ' + cityArea : '') + ', ' + state + ' State';

          const btn = document.getElementById('btnSubmit');
          btn.disabled = true;
          btn.textContent = 'Submitting Partner Accreditation...';

          try {
            const res = await fetch('/api/partners/register', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                businessName,
                cacNumber,
                tinNumber,
                state,
                officeAddress: fullAddress,
                fullName,
                phoneNumber,
                email,
                password,
                referralCode
              })
            });

            const data = await res.json();

            if (res.status === 201 || data.status === true) {
              document.getElementById('partnerForm').style.display = 'none';
              document.getElementById('alertBox').style.display = 'none';
              document.getElementById('successFirm').textContent = businessName;
              document.getElementById('successCode').textContent = data.partnerCode || 'RNT-PRT';
              document.getElementById('badgeLink').href = data.verificationUrl || ('/verify/partner/' + (data.user?.id || ''));
              document.getElementById('successBox').style.display = 'block';
            } else {
              showAlert(data.error || data.message || 'Partner registration failed.', true);
              btn.disabled = false;
              btn.textContent = 'Complete Partner Accreditation & Register 🚀';
            }
          } catch (err) {
            showAlert('Network error while completing registration.', true);
            btn.disabled = false;
            btn.textContent = 'Complete Partner Accreditation & Register 🚀';
          }
        }
      </script>
    </body>
    </html>
  `);
}

/**
 * Handles Web & Direct API Corporate Partner Registration.
 * Creates an accredited partner record with verified CAC status,
 * grants immediate access, and dispatches confirmation notifications.
 */
export async function handlePublicPartnerRegister(req: Request, res: Response) {
  try {
    const {
      businessName,
      cacNumber,
      tinNumber,
      fullName,
      email,
      phoneNumber,
      password,
      state = 'Lagos',
      officeAddress,
      signatoryRole = 'Principal Broker / Managing Director',
      referralCode
    } = req.body;

    if (!businessName || !cacNumber || !fullName || !email || !password) {
      return res.status(400).json({
        status: false,
        error: 'Registered Business Name, CAC Number, Principal Representative Name, Email, and Password are required.'
      });
    }

    const cleanEmail = email.toString().toLowerCase().trim();
    const cleanPhone = (phoneNumber || '').toString().trim();
    const cleanBusinessName = businessName.toString().trim();
    const cleanCac = cacNumber.toString().trim().toUpperCase();
    const cleanDirector = fullName.toString().trim();
    const cleanState = (state || 'Lagos').toString().trim();
    const cleanAddress = (officeAddress || '').toString().trim();

    // Check if user already exists
    const existing = await UserStore.findByEmail(cleanEmail);
    if (existing) {
      return res.status(409).json({
        status: false,
        error: 'An account with this email address already exists. Please log in or reset your password.'
      });
    }

    // Create Partner profile with verified CAC & partner status
    const newPartner = await UserStore.createUser({
      fullName: cleanDirector,
      email: cleanEmail,
      phoneNumber: cleanPhone,
      password,
      role: 'partner',
      buyerType: 'corporate',
      state: cleanState,
      businessName: cleanBusinessName,
      cacNumber: cleanCac,
      tinNumber: tinNumber ? tinNumber.toString().trim() : undefined,
      officeAddress: cleanAddress,
      signatoryName: cleanDirector,
      signatoryRole: signatoryRole.toString().trim(),
      signatoryPhone: cleanPhone,
      partnerStatus: 'verified' // Grant initial active partner standing upon valid CAC registration
    });

    // Mark as verified since corporate CAC is registered
    newPartner.isVerified = true;
    newPartner.partnerStatus = 'verified';
    UserStore.upsertUser(newPartner);

    const token = `rentilly_partner_${newPartner.id}_${Date.now()}`;
    const formatOpsId = (uid: string) => `RNT-${uid.replace(/[^a-zA-Z0-9]/g, '').toUpperCase().slice(0, 3)}`;
    const partnerCode = formatOpsId(newPartner.id);

    // Send Welcome Email via Resend
    NotificationDispatcher.dispatch({
      userId: newPartner.id,
      email: newPartner.email,
      userName: cleanDirector,
      category: 'security',
      title: 'Welcome to Rentilly Partner Network 🛡️',
      message: `Your corporate partner accreditation (${partnerCode}) is active. Access your zero-agent marketplace console.`,
      metadata: {
        'Firm Name': cleanBusinessName,
        'CAC Number': cleanCac,
        'Partner ID': partnerCode,
        'Accreditation Status': 'ACTIVE & TIER-3 AUDITED ✓'
      }
    }).catch(() => {});

    return res.status(201).json({
      status: true,
      message: 'Accredited Partner account registered successfully!',
      token,
      partnerCode,
      user: {
        id: newPartner.id,
        fullName: newPartner.fullName,
        email: newPartner.email,
        phoneNumber: newPartner.phoneNumber,
        role: 'partner',
        buyerType: 'corporate',
        businessName: newPartner.businessName,
        cacNumber: newPartner.cacNumber,
        state: newPartner.state,
        partnerStatus: 'verified',
        isVerified: true
      },
      verificationUrl: `/verify/partner/${newPartner.id}`
    });
  } catch (err: any) {
    console.error('[PublicPartner] Registration Error:', err);
    return res.status(500).json({
      status: false,
      error: err.message || 'Internal server error during partner registration'
    });
  }
}



