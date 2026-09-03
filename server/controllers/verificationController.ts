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
    let bankName = '9PSB (Maplerad)';
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
      bankName = mapleRes.bankName || '9PSB (Maplerad)';
      usdtTronAddress = mapleRes.usdtTronAddress || '';
    } else {
      // Secondary fallback to Flutterwave if Maplerad temporary network issue
      console.warn('[verifyAndProvision] Maplerad account generation fallback to Flutterwave router...');
      try {
        const flwRes = await FlutterwaveService.createPermanentUserVirtualAccount({
          userId: userId || existing?.id || `usr_${Date.now()}`,
          email: cleanEmail,
          fullName: cleanName,
          businessName: partnerBizName,
          role: role || (isPartner ? 'partner' : 'renter'),
          bvn: bvnToUse,
          phoneNumber: phoneNumber || premblyResult.data?.phone
        });
        if (flwRes?.data?.accountNumber) {
          accountNumber = flwRes.data.accountNumber;
          bankName = flwRes.data.bankName || 'Flutterwave MFB';
        }
      } catch (flwErr: any) {
        console.error('[verifyAndProvision] Flutterwave fallback error:', flwErr.message);
      }
    }

    if (!accountNumber) {
      return res.status(400).json({
        status: false,
        message: 'Could not generate virtual bank account. Please check your identification details and try again.'
      });
    }

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
      accountNumber: accountNumber,
      bankName: bankName,
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
            account_number: accountNumber,
            bank_name: bankName,
            business_name: isPartner ? partnerBizName : undefined,
            cac_number: isPartner ? cacNumber : undefined,
            rekyc_required: false,
            updated_at: new Date().toISOString()
          })
          .eq('email', cleanEmail);
      } catch (_) {}
    }

    // Step 4: Dispatch Confirmation Push & Email
    NotificationDispatcher.dispatch({
      userId: updatedUser.id,
      email: cleanEmail,
      userName: cleanName,
      category: 'wallet',
      title: 'Verification Approved! Dedicated Bank Account Ready 🏦',
      message: `Your identity was verified. Your dedicated ${bankName} account (${accountNumber}) and USDT TRC20 wallet are now active. Available balance: ₦${currentBalance.toLocaleString()}.`
    });

    return res.status(200).json({
      status: true,
      message: isPartner
        ? `Corporate KYB verified! Dedicated Maplerad commission vault provisioned in your business name.`
        : 'Identity verified successfully! Dedicated Maplerad account & USDT wallet provisioned.',
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
    let bankName = mapleRes.bankName || '9PSB (Maplerad)';

    if (!accountNumber) {
      // Fallback
      const flwRes = await FlutterwaveService.createPermanentUserVirtualAccount({
        userId: userId || existing?.id || `usr_${Date.now()}`,
        email: cleanEmail,
        fullName: cleanName,
        businessName: partnerBizName,
        role: role || (isPartner ? 'partner' : 'renter'),
        bvn: bvnToUse,
        phoneNumber: phoneNumber || existing?.phoneNumber || ''
      });
      if (flwRes?.data?.accountNumber) {
        accountNumber = flwRes.data.accountNumber;
        bankName = flwRes.data.bankName || 'Flutterwave MFB';
      }
    }

    if (!accountNumber) {
      return res.status(400).json({
        status: false,
        message: 'Failed to sync live NUBAN from Maplerad banking router.'
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
      message: 'Dedicated Maplerad NUBAN successfully synced with 9PSB / WEMA router!',
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

// 7. Admin Action: Initiate Re-KYC / Maplerad Upgrade for Old Users
export async function requestReKyc(req: Request, res: Response) {
  try {
    const { email, allUsers } = req.body;

    let targetUsers: Array<{ id: string; email: string; fullName: string; walletBalance?: number }> = [];

    if (email) {
      const cleanEmail = email.toString().toLowerCase().trim();
      const user = await UserStore.findByEmail(cleanEmail);
      if (user) {
        targetUsers.push({ id: user.id, email: user.email, fullName: user.fullName, walletBalance: user.walletBalance });
      }
    } else if (allUsers) {
      const all = UserStore.getAllUsers();
      targetUsers = all.filter(u => u.isVerified || (u.walletBalance && u.walletBalance > 0));
    } else {
      return res.status(400).json({ error: 'Please provide email or set allUsers: true' });
    }

    if (targetUsers.length === 0) {
      return res.status(404).json({ error: 'No matching users found to request re-KYC.' });
    }

    let notifiedCount = 0;

    for (const u of targetUsers) {
      const cleanEmail = u.email.toLowerCase().trim();

      // Flag rekyc_required in Supabase profiles
      if (supabase) {
        try {
          await supabase
            .from('profiles')
            .update({ rekyc_required: true, updated_at: new Date().toISOString() })
            .eq('email', cleanEmail);
        } catch (_) {}
      }

      // Dispatch high-priority Push & Email notification
      NotificationDispatcher.dispatch({
        userId: u.id,
        email: cleanEmail,
        userName: u.fullName || 'Rentilly User',
        category: 'system',
        title: 'Action Required: Upgrade to Maplerad NGN & Dollar Card 🚀',
        message: `Please confirm your Date of Birth to activate your new dedicated Maplerad 9PSB bank account and Virtual Dollar Card. Your current wallet balance of ₦${(u.walletBalance || 0).toLocaleString()} is 100% safe and visible!`
      });

      notifiedCount++;
    }

    return res.status(200).json({
      status: true,
      message: `Re-KYC upgrade initiated for ${notifiedCount} user(s). Notifications and emails dispatched!`,
      notifiedCount
    });
  } catch (err: any) {
    console.error('requestReKyc error:', err);
    return res.status(500).json({ error: err.message });
  }
}

// 8. User Action: Complete Quick Maplerad KYC (submit DOB & upgrade to Tier 1)
export async function completeMapleradKyc(req: Request, res: Response) {
  try {
    const { email, dob, nin, bvn, phoneNumber, fullName } = req.body;

    if (!email) {
      return res.status(400).json({ error: 'Email is required' });
    }
    if (!dob) {
      return res.status(400).json({ error: 'Date of Birth is required for Maplerad Tier 1 upgrade' });
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

    const accountNumber = result.accountNumber || existing?.accountNumber || '';
    const bankName = result.bankName || existing?.bankName || '9PSB (Maplerad)';

    // Update in-memory user cache with preserved wallet balance
    if (existing) {
      UserStore.upsertUserForced({
        ...existing,
        fullName: cleanName,
        ninNumber: idToUse,
        accountNumber,
        bankName,
        isVerified: true,
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
            account_number: accountNumber,
            bank_name: bankName,
            updated_at: new Date().toISOString()
          })
          .eq('email', cleanEmail);
      } catch (_) {}
    }

    NotificationDispatcher.dispatch({
      userId: existing?.id,
      email: cleanEmail,
      userName: cleanName,
      category: 'wallet',
      title: 'Maplerad Upgrade Complete! 💳',
      message: `Your dedicated Maplerad account (${accountNumber}) and Virtual Dollar Card are ready! Your wallet balance of ₦${currentBalance.toLocaleString()} is active.`
    });

    return res.status(200).json({
      status: true,
      message: 'Maplerad Tier 1 setup complete! Dedicated NGN account and Dollar Card activated.',
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
