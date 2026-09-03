import { Request, Response } from 'express';
import { IdentitypassService } from '../services/identitypassService';
import { FlutterwaveService } from '../services/flutterwaveService';
import { UserStore } from '../services/userStore';
import { MapleradBankingService } from '../services/mapleradBankingService';
import { NotificationDispatcher } from '../services/notificationDispatcher';
import { supabase } from '../supabaseClient';

// 1. Verify NIN
export async function verifyNIN(req: Request, res: Response) {
  try {
    const { ninNumber, firstname, lastname, dob } = req.body;

    if (!ninNumber) {
      return res.status(400).json({ error: 'NIN Number is required' });
    }

    const result = await IdentitypassService.verifyNIN(ninNumber);
    return res.status(200).json(result);
  } catch (error: any) {
    console.error('NIN verification error:', error);
    return res.status(500).json({
      error: 'NIN verification service unavailable',
      details: error.message
    });
  }
}

// 2. Verify BVN
export async function verifyBVN(req: Request, res: Response) {
  try {
    const { bvnNumber, firstname, lastname, dob } = req.body;

    if (!bvnNumber) {
      return res.status(400).json({ error: 'BVN Number is required' });
    }

    const result = await IdentitypassService.verifyBVN(bvnNumber);
    return res.status(200).json(result);
  } catch (error: any) {
    console.error('BVN verification error:', error);
    return res.status(500).json({
      error: 'BVN verification service unavailable',
      details: error.message
    });
  }
}

// 3. Verify CAC RC Number
export async function verifyCAC(req: Request, res: Response) {
  try {
    const { rcNumber, companyName, companyType } = req.body;

    if (!rcNumber) {
      return res.status(400).json({ error: 'CAC RC Number is required' });
    }

    const result = await IdentitypassService.verifyCAC(rcNumber, companyName, companyType);
    return res.status(200).json(result);
  } catch (error: any) {
    console.error('CAC verification error:', error);
    return res.status(500).json({
      error: 'CAC verification service unavailable',
      details: error.message
    });
  }
}

// 4. Automated Identity Verification -> Instant Maplerad Tier 1 Account, USDT Wallet & Card Provisioning
export async function verifyAndProvision(req: Request, res: Response) {
  try {
    const { email, fullName, phoneNumber, idType, idNumber, bvn, dob, role, businessName, cacNumber, officeAddress, state, city, lga, landmark } = req.body;

    if (!idNumber) {
      return res.status(400).json({ error: 'Identification document number is required' });
    }

    const cleanEmail = (email || '').toString().trim().toLowerCase();
    const isPartner = role === 'partner' || (businessName && businessName.trim().length > 0);
    const bvnToUse = (bvn && bvn.length === 11) ? bvn : (idType === 'bvn' ? idNumber : (idNumber || ''));

    // Step 1: Prembly / Identitypass Live Registry Verification
    let premblyResult: any = { status: true };
    try {
      if (idType === 'bvn') {
        premblyResult = await IdentitypassService.verifyBVN(idNumber);
      } else if (idType === 'nin') {
        premblyResult = await IdentitypassService.verifyNIN(idNumber);
      }
    } catch (e) {
      console.warn('[verifyAndProvision] Prembly live call warning:', e);
    }

    const partnerBizName = (businessName || '').trim();
    let cleanName = (fullName || '').trim();
    if (!cleanName || cleanName.includes('@')) {
      cleanName = partnerBizName.length > 0 ? partnerBizName : (premblyResult?.data?.fullName || 'Rentilly User');
    }

    // Existing user lookup — preserve wallet balance!
    const existing = await UserStore.findByEmail(cleanEmail);
    const currentBalance = existing?.walletBalance ?? 0;
    const currentUsdtBalance = existing?.usdtBalance ?? 0;

    // Step 2: Multi-Rail Account Provisioning:
    // - For KYB / Partners: Issue NGN Corporate Account via Flutterwave in the Registered Business Name
    // - For KYC / Individuals: Issue NGN Account via Maplerad Tier 1 (9PSB)
    // - For ALL users: Enroll Director on Maplerad for dedicated USDT TRON Wallet & Virtual Dollar Card
    let accountNumber = '';
    let bankName = 'Flutterwave MFB (Rentilly)';
    let usdtTronAddress = '';

    // A. Ensure Maplerad Tier 1 enrollment for Crypto & Virtual Dollar Card access
    console.log(`[verifyAndProvision] Calling Maplerad Tier 1 Provisioning for ${cleanEmail}...`);
    const mapleRes = await MapleradBankingService.enrollAndProvisionTier1({
      email: cleanEmail,
      fullName: cleanName,
      phoneNumber: phoneNumber || existing?.phoneNumber,
      nin: idType === 'nin' ? idNumber : (existing?.ninNumber || undefined),
      bvn: bvnToUse,
      dob: dob
    });

    if (mapleRes.usdtAddress) {
      usdtTronAddress = mapleRes.usdtAddress;
    }

    // B. If KYB / Partner: Provision dedicated Corporate Virtual Account in Business Name via Flutterwave
    if (isPartner && partnerBizName.length > 0) {
      console.log(`[verifyAndProvision] 🏢 Provisioning Corporate Account via Flutterwave for ${partnerBizName}...`);
      try {
        const flwRes = await FlutterwaveService.createPermanentUserVirtualAccount({
          userId: existing?.id || req.body.userId || `usr_${Date.now()}`,
          email: cleanEmail,
          fullName: cleanName,
          businessName: partnerBizName,
          role: 'partner',
          bvn: bvnToUse,
          phoneNumber: phoneNumber || existing?.phoneNumber
        });

        if (flwRes.status && flwRes.data?.accountNumber) {
          accountNumber = flwRes.data.accountNumber;
          bankName = `${flwRes.data.bankName || 'Flutterwave MFB'} (Rentilly)`;
          console.log(`[verifyAndProvision] ✅ Corporate Account provisioned in Business Name via Flutterwave: ${accountNumber} (${bankName}) for ${partnerBizName}`);
        }
      } catch (flwErr: any) {
        console.warn('[verifyAndProvision] Flutterwave corporate account warning:', flwErr.message);
      }
    }

    // C. Fallback to Maplerad account if corporate rail did not return, or if user is individual KYC
    if (!accountNumber && mapleRes.accountNumber) {
      accountNumber = mapleRes.accountNumber;
      bankName = mapleRes.bankName || '9PSB (Rentilly)';
      console.log(`[verifyAndProvision] ✅ Maplerad Account provisioned: ${accountNumber} (${bankName}) for ${cleanEmail}`);
    }

    const isProcessing = !accountNumber || accountNumber.length === 0;

    // Step 3: Update UserStore & Supabase Database — preserve wallet balance completely!
    const updatedUser = {
      ...(existing || {
        id: req.body.userId || `usr_${Date.now()}`,
        email: cleanEmail,
        createdAt: new Date().toISOString(),
      }),
      fullName: cleanName,
      phoneNumber: phoneNumber || existing?.phoneNumber || '',
      businessName: isPartner ? partnerBizName : (existing?.businessName ?? null),
      cacNumber: isPartner ? (cacNumber || existing?.cacNumber) : (existing?.cacNumber ?? null),
      officeAddress: officeAddress || existing?.officeAddress,
      state: state || existing?.state || 'Lagos',
      isVerified: !isProcessing,
      bvnVerified: !isProcessing,
      bvn: bvnToUse,
      ninNumber: idType === 'nin' ? idNumber : existing?.ninNumber,
      accountNumber: accountNumber || (existing?.accountNumber ?? null),
      bankName: accountNumber ? bankName : (existing?.bankName || '9PSB (Rentilly Processing)'),
      role: role || existing?.role || (isPartner ? 'partner' : 'renter'),
      walletBalance: currentBalance, // PRESERVE EXACT WALLET BALANCE
      usdtBalance: currentUsdtBalance,
      updatedAt: new Date().toISOString()
    };

    UserStore.upsertUserForced(updatedUser as any);

    if (supabase) {
      try {
        await supabase
          .from('profiles')
          .update({
            full_name: cleanName,
            is_verified: !isProcessing,
            bvn_verified: !isProcessing,
            nin_number: idType === 'nin' ? idNumber : undefined,
            account_number: accountNumber || existing?.accountNumber || null,
            bank_name: accountNumber ? bankName : (existing?.bankName || '9PSB (Rentilly Processing)'),
            business_name: isPartner ? partnerBizName : undefined,
            cac_number: isPartner ? cacNumber : undefined,
            office_address: officeAddress || existing?.officeAddress || undefined,
            state: state || existing?.state || undefined,
            rekyc_required: isProcessing,
            updated_at: new Date().toISOString()
          })
          .eq('email', cleanEmail);
      } catch (_) {}
    }

    // Step 4: Dispatch Push & Email Notification (Strictly Rentilly branded)
    if (!isProcessing) {
      NotificationDispatcher.dispatch({
        userId: updatedUser.id,
        email: cleanEmail,
        userName: cleanName,
        category: 'wallet',
        title: 'Verification Approved! Dedicated Account Ready 🏦',
        message: `Your identity was verified. Your dedicated ${bankName} account (${accountNumber}) and Dollar Card are now active. Available balance: ₦${currentBalance.toLocaleString()}.`
      });

      return res.status(200).json({
        status: true,
        message: isPartner
          ? `Corporate KYB verified! Dedicated Rentilly commission vault provisioned in your business name.`
          : 'Identity verified successfully! Dedicated Rentilly account & USDT wallet provisioned.',
        accountNumber: accountNumber,
        bankName: bankName,
        usdtTronAddress: usdtTronAddress,
        walletBalance: currentBalance,
        user: {
          id: updatedUser.id,
          email: cleanEmail,
          fullName: cleanName,
          businessName: partnerBizName,
          cacNumber: cacNumber,
          isVerified: true,
          accountNumber: accountNumber,
          bankName: bankName,
          walletBalance: currentBalance,
          usdtBalance: currentUsdtBalance,
          role: updatedUser.role
        }
      });
    } else {
      // Account generation pending — notify user that KYC is being processed
      NotificationDispatcher.dispatch({
        userId: updatedUser.id,
        email: cleanEmail,
        userName: cleanName,
        category: 'system',
        title: 'KYC Verification Received & In Progress ⏳',
        message: `Your KYC verification documents have been received and are currently being processed by Rentilly. Your existing wallet balance of ₦${currentBalance.toLocaleString()} is 100% safe and visible. You will receive an email the moment your dedicated account and dollar card are activated.`
      });

function sanitizeVerificationError(raw?: string): string {
  if (!raw) return 'Central Banking NIBSS Registry could not validate your identity details. Please check your BVN and Date of Birth.';
  
  if (raw.includes('dob_format') || raw.includes('TierOneCustomerUpgradeRequest.DOB') || raw.toLowerCase().includes('dob')) {
    return 'Invalid Date of Birth format. Please select your Date of Birth in DD-MM-YYYY format (e.g. 27-06-1990).';
  }
  
  if (raw.toLowerCase().includes('could not validate bvn') || raw.toLowerCase().includes('bvn')) {
    return 'Central Banking NIBSS Registry could not validate your 11-digit BVN against your Date of Birth. Please check that your BVN and Date of Birth match your official bank records.';
  }

  let cleaned = raw
    .replace(/Maplerad\s*/gi, 'Rentilly Settlement Rail ')
    .replace(/VBA notice:\s*/gi, '')
    .replace(/service is only available for Tier 1 customers/gi, 'Settlement account will be provisioned upon identity confirmation.')
    .replace(/USDT notice:\s*/gi, '')
    .trim();

  if (cleaned.includes('TierOneCustomerUpgradeRequest') || cleaned.includes('Field validation')) {
    return 'Please check that your 11-digit BVN and Date of Birth match your official bank records.';
  }

  return cleaned || 'Verification is being reviewed by Rentilly compliance.';
}

      const rawReason = mapleRes?.errors?.length
        ? mapleRes.errors.join('; ')
        : '9PSB BVN validation pending with NIBSS central banking registry';
      const failureReason = sanitizeVerificationError(rawReason);

      if (supabase) {
        try {
          await supabase
            .from('profiles')
            .update({
              rekyc_required: true,
              is_verified: false,
              kyc_failure_reason: failureReason
            })
            .eq('email', cleanEmail);
        } catch (_) {}
      }

      return res.status(200).json({
        status: true,
        processing: true,
        reason: failureReason,
        errors: mapleRes?.errors || [failureReason],
        message: `KYC verification pending: ${failureReason}. Please review your details and re-verify.`,
        accountNumber: null,
        bankName: '9PSB (Rentilly Processing)',
        walletBalance: currentBalance,
        usdtBalance: currentUsdtBalance,
        user: {
          id: updatedUser.id,
          email: cleanEmail,
          fullName: cleanName,
          businessName: partnerBizName,
          cacNumber: cacNumber,
          isVerified: false,
          accountNumber: null,
          bankName: '9PSB (Rentilly Processing)',
          walletBalance: currentBalance,
          usdtBalance: currentUsdtBalance,
          role: updatedUser.role,
          kycFailureReason: failureReason
        }
      });
    }
  } catch (error: any) {
    console.error('Verify and provision error:', error);
    return res.status(500).json({
      status: false,
      error: 'Identity provisioning service error',
      details: error.message
    });
  }
}

// 5. Verification Status Check
export async function getVerificationStatus(req: Request, res: Response) {
  try {
    const { email } = req.query;

    if (!email) {
      return res.status(400).json({ error: 'Email parameter is required' });
    }

    const cleanEmail = email.toString().toLowerCase().trim();
    const user = await UserStore.findByEmail(cleanEmail);

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Check rekyc flag in profiles and system_configs
    let rekycRequired = user.rekycRequired === true;
    if (supabase) {
      try {
        const { data: cfg } = await supabase
          .from('system_configs')
          .select('data')
          .eq('id', `rekyc_${cleanEmail}`)
          .maybeSingle();
        if (cfg?.data?.rekycRequired !== undefined) {
          rekycRequired = Boolean(cfg.data.rekycRequired);
        }
      } catch (_) {}
    }

    // If BVN is missing or not 11 digits, rekyc is mandatory for Maplerad Tier 1
    const cleanBvn = (user.bvn || '').toString().replace(/\D/g, '');
    if (cleanBvn.length !== 11 || !user.bankName?.includes('9PSB')) {
      rekycRequired = true;
    }

    return res.status(200).json({
      isVerified: user.isVerified || false,
      accountNumber: user.accountNumber,
      bankName: user.bankName,
      bvn: user.bvn,
      nin: user.ninNumber,
      role: user.role,
      rekycRequired,
      walletBalance: user.walletBalance ?? 0,
      usdtBalance: user.usdtBalance ?? 0
    });
  } catch (error: any) {
    console.error('Status check error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}

// 6. Sync / Re-provision Real Maplerad NUBAN for verified users
export async function syncNuban(req: Request, res: Response) {
  try {
    const { userId, email, fullName, businessName, role, bvn, phoneNumber, dob } = req.body;

    if (!email && !userId) {
      return res.status(400).json({ error: 'User ID or Email is required' });
    }

    const cleanEmail = (email || '').toString().toLowerCase().trim();
    const isPartner = role === 'partner' || (businessName && businessName.trim().length > 0);
    const partnerBizName = (businessName || '').trim();
    const existing = await UserStore.findByEmail(cleanEmail);
    const cleanName = (fullName || (partnerBizName ? partnerBizName : (existing?.fullName || 'Rentilly User'))).trim();
    const bvnToUse = (bvn && bvn.length === 11) ? bvn : (existing?.ninNumber || '');

    // Call Maplerad Tier 1 Provisioning
    const mapleRes = await MapleradBankingService.enrollAndProvisionTier1({
      email: cleanEmail,
      fullName: cleanName,
      phoneNumber: phoneNumber || existing?.phoneNumber,
      nin: existing?.ninNumber || undefined,
      bvn: bvnToUse,
      dob: dob || '01-01-1990'
    });

    let accountNumber = mapleRes.accountNumber;
    let bankName = '9PSB (Rentilly)';

    if (!accountNumber) {
      return res.status(200).json({
        status: true,
        processing: true,
        message: 'KYC is currently being processed by Rentilly Compliance. Your account will be updated automatically.',
        accountNumber: existing?.accountNumber || null,
        bankName: existing?.bankName || 'Rentilly Settlement (Processing)',
        walletBalance: existing?.walletBalance ?? 0
      });
    }

    // Update in UserStore while preserving wallet balance
    if (existing) {
      UserStore.upsertUserForced({
        ...existing,
        fullName: cleanName,
        businessName: isPartner ? (partnerBizName || existing.businessName) : existing.businessName,
        isVerified: true,
        accountNumber: accountNumber,
        bankName: bankName,
      });
    }

    return res.status(200).json({
      status: true,
      message: 'Dedicated Rentilly Settlement account successfully synced with 9PSB router!',
      accountNumber: accountNumber,
      bankName: bankName,
      usdtTronAddress: mapleRes.usdtTronAddress,
      walletBalance: existing?.walletBalance ?? 0
    });
  } catch (error: any) {
    console.error('NUBAN sync error:', error);
    return res.status(500).json({
      status: false,
      error: 'Failed to sync NUBAN',
      details: error.message
    });
  }
}

// 7. Admin Action: Resend Re-Verification / Rentilly Account Provisioning
export async function requestReKyc(req: Request, res: Response) {
  try {
    const { email, allUsers } = req.body;

    let targetUsers: Array<{ id: string; email: string; fullName: string; walletBalance?: number; ninNumber?: string; phoneNumber?: string }> = [];

    if (email) {
      const cleanEmail = email.toString().toLowerCase().trim();
      const user = await UserStore.findByEmail(cleanEmail);
      if (user) {
        targetUsers.push({
          id: user.id,
          email: user.email,
          fullName: user.fullName,
          walletBalance: user.walletBalance,
          ninNumber: user.ninNumber,
          phoneNumber: user.phoneNumber
        });
      }
    } else if (allUsers) {
      const all = UserStore.getAllUsers();
      targetUsers = all.filter(u => u.isVerified || (u.walletBalance && u.walletBalance > 0));
    } else {
      return res.status(400).json({ error: 'Please provide email or set allUsers: true' });
    }

    if (targetUsers.length === 0) {
      return res.status(404).json({ error: 'No matching users found to re-verify.' });
    }

    let activatedCount = 0;
    let pendingCount = 0;

    for (const u of targetUsers) {
      const cleanEmail = u.email.toLowerCase().trim();

      // Check if user already has NIN/DOB to attempt direct provisioning
      let userDob = '01-01-1990';
      if (supabase) {
        try {
          const { data: p } = await supabase.from('profiles').select('dob, nin_number').eq('email', cleanEmail).maybeSingle();
          if (p?.dob) userDob = p.dob;
        } catch (_) {}
      }

      console.log(`[requestReKyc] Attempting Rentilly account activation for ${cleanEmail}...`);
      const mapleRes = await MapleradBankingService.enrollAndProvisionTier1({
        email: cleanEmail,
        fullName: u.fullName || 'Rentilly User',
        phoneNumber: u.phoneNumber,
        nin: u.ninNumber,
        dob: userDob
      });

      if (mapleRes.accountNumber) {
        // Successfully generated live account!
        const memUser = await UserStore.findByEmail(cleanEmail);
        if (memUser) {
          UserStore.upsertUserForced({
            ...memUser,
            accountNumber: mapleRes.accountNumber,
            bankName: '9PSB (Rentilly)',
            isVerified: true
          });
        }

        if (supabase) {
          try {
            await supabase
              .from('profiles')
              .update({
                account_number: mapleRes.accountNumber,
                bank_name: '9PSB (Rentilly)',
                rekyc_required: false,
                is_verified: true,
                updated_at: new Date().toISOString()
              })
              .eq('email', cleanEmail);
          } catch (_) {}
        }

        NotificationDispatcher.dispatch({
          userId: u.id,
          email: cleanEmail,
          userName: u.fullName || 'Rentilly User',
          category: 'wallet',
          title: 'Rentilly Settlement Account Activated! 🏦',
          message: `Your dedicated Rentilly 9PSB settlement account (${mapleRes.accountNumber}) and Virtual Dollar Card are now active! Available balance: ₦${(u.walletBalance || 0).toLocaleString()}.`
        });

        activatedCount++;
      } else {
        // Still requires user to confirm details / DOB
        if (supabase) {
          try {
            await supabase
              .from('profiles')
              .update({ rekyc_required: true, updated_at: new Date().toISOString() })
              .eq('email', cleanEmail);
          } catch (_) {}
          try {
            await supabase.from('system_configs').upsert({
              id: `rekyc_${cleanEmail}`,
              data: { rekycRequired: true, updatedAt: new Date().toISOString() }
            });
          } catch (_) {}
        }

        const reqHost = req.get('host') || 'rentilly-admin-api.onrender.com';
        const reqProto = req.protocol || 'https';
        const webRekycUrl = reqHost.includes('localhost') 
          ? `http://${reqHost}/verify/re-kyc?email=${encodeURIComponent(cleanEmail)}`
          : `https://rentilly-admin-api.onrender.com/verify/re-kyc?email=${encodeURIComponent(cleanEmail)}`;

        NotificationDispatcher.dispatch({
          userId: u.id,
          email: cleanEmail,
          userName: u.fullName || 'Rentilly User',
          category: 'system',
          title: 'Action Required: Complete Your Rentilly Upgrade 🚀',
          message: `Please confirm your Date of Birth to activate your dedicated 9PSB settlement account and Virtual Dollar Card. Your current wallet balance of ₦${(u.walletBalance || 0).toLocaleString()} is 100% safe and visible!`,
          actionUrl: webRekycUrl,
          actionLabel: 'Confirm Date of Birth & Activate Account ⚡'
        });

        pendingCount++;
      }
    }

    return res.status(200).json({
      status: true,
      message: `Re-verification processed. ${activatedCount} account(s) activated directly, ${pendingCount} notified to confirm details.`,
      activatedCount,
      pendingCount
    });
  } catch (err: any) {
    console.error('requestReKyc error:', err);
    return res.status(500).json({ error: err.message });
  }
}

// 8. User Action: Complete Quick KYC Upgrade (submit DOB & upgrade to Tier 1)
export async function completeMapleradKyc(req: Request, res: Response) {
  try {
    const { email, dob, nin, bvn, phoneNumber, fullName } = req.body;

    if (!email) {
      return res.status(400).json({ error: 'Email is required' });
    }
    if (!dob) {
      return res.status(400).json({ error: 'Date of Birth is required for verification upgrade' });
    }

    const cleanEmail = email.toString().toLowerCase().trim();
    const existing = await UserStore.findByEmail(cleanEmail);

    const cleanBvn = (bvn || existing?.bvn || '').toString().replace(/\D/g, '');
    const cleanNin = (nin || existing?.ninNumber || '').toString().replace(/\D/g, '');

    if (cleanBvn.length !== 11) {
      return res.status(400).json({ status: false, error: 'Valid 11-digit Bank Verification Number (BVN) is required.' });
    }
    if (cleanNin.length !== 11) {
      return res.status(400).json({ status: false, error: 'Valid 11-digit National Identity Number (NIN) is required.' });
    }

    const cleanName = fullName || existing?.fullName || 'Rentilly User';
    const currentBalance = existing?.walletBalance ?? 0;
    const currentUsdtBal = existing?.usdtBalance ?? 0;

    console.log(`[completeMapleradKyc] Upgrading ${cleanEmail} with BVN: ${cleanBvn}, NIN: ${cleanNin}, DOB: ${dob}...`);

    const result = await MapleradBankingService.enrollAndProvisionTier1({
      email: cleanEmail,
      fullName: cleanName,
      phoneNumber: phoneNumber || existing?.phoneNumber,
      nin: cleanNin,
      bvn: cleanBvn,
      dob: dob
    });

    if (!result.accountNumber) {
      console.warn(`[completeMapleradKyc] ⚠️ Verification did not return a new account number for ${cleanEmail}:`, result.errors);
      const cleanErr = sanitizeVerificationError(result.errors?.join('; '));
      return res.status(400).json({
        status: false,
        error: cleanErr || 'Identity verification pending. Please ensure your 11-digit BVN matches your Date of Birth.'
      });
    }

    const accountNumber = result.accountNumber;
    const bankName = result.bankName || '9PSB (Rentilly)';

    // Update in-memory user cache with real Maplerad dedicated account
    if (existing) {
      UserStore.upsertUserForced({
        ...existing,
        fullName: cleanName,
        bvn: cleanBvn,
        ninNumber: cleanNin,
        accountNumber,
        bankName,
        isVerified: true,
        rekycRequired: false,
        walletBalance: currentBalance,
        usdtBalance: currentUsdtBal
      });
    }

    // Clear rekyc_required in Supabase profiles
    if (supabase) {
      try {
        await supabase
          .from('profiles')
          .update({
            rekyc_required: false,
            is_verified: true,
            dob: dob,
            bvn: cleanBvn,
            nin_number: cleanNin,
            account_number: accountNumber,
            bank_name: bankName,
            updated_at: new Date().toISOString()
          })
          .eq('email', cleanEmail);
      } catch (_) {}
      try {
        await supabase.from('system_configs').upsert({
          id: `rekyc_${cleanEmail}`,
          data: { rekycRequired: false, updatedAt: new Date().toISOString() }
        });
      } catch (_) {}
    }

    NotificationDispatcher.dispatch({
      userId: existing?.id,
      email: cleanEmail,
      userName: cleanName,
      category: 'wallet',
      title: 'Rentilly Dedicated 9PSB Account Activated! 💳',
      message: `Your dedicated Rentilly 9PSB account (${accountNumber}) and Virtual Dollar Card are ready! Your wallet balance of ₦${currentBalance.toLocaleString()} is active.`
    });

    return res.status(200).json({
      status: true,
      message: 'Rentilly setup complete! Dedicated NGN account and Dollar Card activated.',
      accountNumber,
      bankName,
      usdtTronAddress: result.usdtTronAddress,
      walletBalance: currentBalance,
      usdtBalance: currentUsdtBal
    });
  } catch (err: any) {
    console.error('completeMapleradKyc error:', err);
    return res.status(500).json({ error: err.message });
  }
}
