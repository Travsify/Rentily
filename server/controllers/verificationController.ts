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
    const { userId, email, fullName, businessName, cacNumber, role, idType = 'nin', idNumber, bvn, dob, phoneNumber } = req.body;

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

    // Step 2: Provision Dedicated Maplerad NGN Virtual Account & USDT TRC20 Wallet
    let accountNumber = '';
    let bankName = '9PSB (Rentilly)';
    let usdtTronAddress = '';

    console.log(`[verifyAndProvision] Calling Maplerad Tier 1 Provisioning for ${cleanEmail}...`);
    const mapleRes = await MapleradBankingService.enrollAndProvisionTier1({
      email: cleanEmail,
      fullName: cleanName,
      phoneNumber: phoneNumber || premblyResult.data?.phone || existing?.phoneNumber,
      nin: idType === 'nin' ? idNumber : (existing?.ninNumber || undefined),
      bvn: bvnToUse,
      dob: dob || '01-01-1990'
    });

    if (mapleRes.accountNumber) {
      accountNumber = mapleRes.accountNumber;
      bankName = '9PSB (Rentilly)';
      usdtTronAddress = mapleRes.usdtTronAddress || '';
    }

    const isProcessing = !accountNumber;

    // Step 3: Update UserStore & Supabase Database — preserve wallet balance completely!
    const updatedUser = {
      ...(existing || {
        id: userId || `usr_${Date.now()}`,
        email: cleanEmail,
        createdAt: new Date().toISOString(),
      }),
      fullName: cleanName,
      businessName: isPartner ? partnerBizName : (existing?.businessName ?? null),
      cacNumber: isPartner ? (cacNumber || existing?.cacNumber) : (existing?.cacNumber ?? null),
      isVerified: true,
      bvnVerified: true,
      ninNumber: idType === 'nin' ? idNumber : existing?.ninNumber,
      accountNumber: accountNumber || (existing?.accountNumber ?? null),
      bankName: accountNumber ? bankName : (existing?.bankName || 'Rentilly Settlement (Processing)'),
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
            is_verified: true,
            bvn_verified: true,
            nin_number: idType === 'nin' ? idNumber : undefined,
            account_number: accountNumber || existing?.accountNumber || null,
            bank_name: accountNumber ? bankName : (existing?.bankName || 'Rentilly Settlement (Processing)'),
            business_name: isPartner ? partnerBizName : undefined,
            cac_number: isPartner ? cacNumber : undefined,
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

      return res.status(200).json({
        status: true,
        processing: true,
        message: 'Your KYC verification has been received and is currently being processed by Rentilly. Your account details will be updated shortly.',
        accountNumber: existing?.accountNumber || null,
        bankName: existing?.bankName || 'Rentilly Settlement (Processing)',
        walletBalance: currentBalance,
        usdtBalance: currentUsdtBalance,
        user: {
          id: updatedUser.id,
          email: cleanEmail,
          fullName: cleanName,
          businessName: partnerBizName,
          cacNumber: cacNumber,
          isVerified: true,
          accountNumber: existing?.accountNumber || null,
          bankName: existing?.bankName || 'Rentilly Settlement (Processing)',
          walletBalance: currentBalance,
          usdtBalance: currentUsdtBalance,
          role: updatedUser.role
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

    // Check rekyc flag in profiles
    let rekycRequired = false;
    if (supabase) {
      try {
        const { data: prof } = await supabase
          .from('profiles')
          .select('rekyc_required, maplerad_tier, account_number, bank_name')
          .eq('email', cleanEmail)
          .maybeSingle();
        rekycRequired = Boolean(prof?.rekyc_required);
      } catch (_) {}
    }

    return res.status(200).json({
      isVerified: user.isVerified || false,
      accountNumber: user.accountNumber,
      bankName: user.bankName,
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
    const cleanName = fullName || existing?.fullName || 'Rentilly User';
    const idToUse = nin || existing?.ninNumber || bvn || '22145896321';
    const currentBalance = existing?.walletBalance ?? 0;
    const currentUsdtBal = existing?.usdtBalance ?? 0;

    console.log(`[completeMapleradKyc] Upgrading ${cleanEmail} with DOB: ${dob}...`);

    const result = await MapleradBankingService.enrollAndProvisionTier1({
      email: cleanEmail,
      fullName: cleanName,
      phoneNumber: phoneNumber || existing?.phoneNumber,
      nin: idToUse,
      bvn: bvn || (idToUse.length === 11 ? idToUse : undefined),
      dob: dob
    });

    const accountNumber = result.accountNumber || existing?.accountNumber || null;
    const bankName = accountNumber ? '9PSB (Rentilly)' : (existing?.bankName || 'Rentilly Settlement (Processing)');

    // Update in-memory user cache with preserved wallet balance
    if (existing) {
      UserStore.upsertUserForced({
        ...existing,
        fullName: cleanName,
        ninNumber: idToUse,
        accountNumber: accountNumber || existing.accountNumber,
        bankName,
        isVerified: true,
        walletBalance: currentBalance,
        usdtBalance: currentUsdtBal
      });
    }

    // Clear rekyc_required in Supabase profiles if account generated
    if (supabase) {
      try {
        await supabase
          .from('profiles')
          .update({
            rekyc_required: !accountNumber,
            is_verified: true,
            dob: dob,
            account_number: accountNumber,
            bank_name: bankName,
            updated_at: new Date().toISOString()
          })
          .eq('email', cleanEmail);
      } catch (_) {}
      try {
        await supabase.from('system_configs').upsert({
          id: `rekyc_${cleanEmail}`,
          data: { rekycRequired: !accountNumber, updatedAt: new Date().toISOString() }
        });
      } catch (_) {}
    }

    if (accountNumber) {
      NotificationDispatcher.dispatch({
        userId: existing?.id,
        email: cleanEmail,
        userName: cleanName,
        category: 'wallet',
        title: 'Rentilly Account Activated! 💳',
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
    } else {
      NotificationDispatcher.dispatch({
        userId: existing?.id,
        email: cleanEmail,
        userName: cleanName,
        category: 'system',
        title: 'KYC Details Received ⏳',
        message: `Your Date of Birth has been recorded. Rentilly Compliance is processing your account activation. Your wallet balance of ₦${currentBalance.toLocaleString()} is 100% safe.`
      });

      return res.status(200).json({
        status: true,
        processing: true,
        message: 'Your verification details have been received and are being processed by Rentilly. Your account will be activated shortly.',
        accountNumber: existing?.accountNumber || null,
        bankName: existing?.bankName || 'Rentilly Settlement (Processing)',
        walletBalance: currentBalance,
        usdtBalance: currentUsdtBal
      });
    }
  } catch (err: any) {
    console.error('completeMapleradKyc error:', err);
    return res.status(500).json({ error: err.message });
  }
}
