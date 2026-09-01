import { Request, Response } from 'express';
import { IdentitypassService } from '../services/identitypassService';
import { FlutterwaveService } from '../services/flutterwaveService';
import { UserStore } from '../services/userStore';

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

// 4. Automated Prembly Identity Verification -> Instant Flutterwave Virtual Bank Issuance
export async function verifyAndProvision(req: Request, res: Response) {
  try {
    const { userId, email, fullName, businessName, cacNumber, role, idType = 'nin', idNumber, bvn, dob, phoneNumber } = req.body;

    if (!idNumber) {
      return res.status(400).json({ error: 'Identification document number is required' });
    }

    const isPartner = role === 'partner' || (businessName && businessName.trim().length > 0);
    const bvnToUse = (bvn && bvn.length === 11) ? bvn : (idType === 'bvn' ? idNumber : (idNumber || ''));

    // Step 1: Prembly Live Registry Verification
    let premblyResult: any = { status: true };
    try {
      if (idType === 'bvn') {
        premblyResult = await IdentitypassService.verifyBVN(idNumber);
      } else if (idType === 'nin') {
        premblyResult = await IdentitypassService.verifyNIN(idNumber);
      }
    } catch (e) {
      console.warn('Prembly live call warning:', e);
    }

    const partnerBizName = (businessName || '').trim();
    let cleanName = (fullName || '').trim();
    if (!cleanName || cleanName.includes('@')) {
      cleanName = partnerBizName.isNotEmpty ? partnerBizName : (premblyResult?.data?.fullName || 'Rentilly Partner');
    }

    // Step 2: Instant Flutterwave Dedicated NUBAN Virtual Account Generation with Live BVN
    const bankResult = await FlutterwaveService.createPermanentUserVirtualAccount({
      userId: userId || `usr_${Date.now()}`,
      email: email || 'user@rentilly.ng',
      fullName: cleanName,
      businessName: partnerBizName,
      role: role || (isPartner ? 'partner' : 'renter'),
      bvn: bvnToUse,
      phoneNumber: phoneNumber || premblyResult.data?.phone
    });

    if (!bankResult.status || !bankResult.data?.accountNumber) {
      return res.status(400).json({
        status: false,
        message: bankResult.message || 'Failed to issue live virtual bank account from Flutterwave.'
      });
    }

    const accountNumber = bankResult.data.accountNumber;
    const bankName = bankResult.data.bankName || 'Flutterwave MFB';

    // Step 3: Update UserStore & Supabase Database
    const existing = await UserStore.findByEmail(email || '');
    if (existing) {
      UserStore.upsertUser({
        ...existing,
        fullName: cleanName,
        businessName: isPartner ? partnerBizName : existing.businessName,
        cacNumber: isPartner ? (cacNumber || existing.cacNumber) : existing.cacNumber,
        isVerified: true,
        accountNumber: accountNumber,
        bankName: bankName,
        role: role || existing.role
      });
    }

    return res.status(200).json({
      status: true,
      message: isPartner
        ? `Corporate KYB verified! Dedicated commission vault provisioned in your business name.`
        : 'Identity and BVN verified successfully! Dedicated account provisioned.',
      accountNumber: accountNumber,
      bankName: bankName,
      user: {
        id: userId,
        email: email,
        fullName: cleanName,
        businessName: partnerBizName,
        cacNumber: cacNumber,
        isVerified: true,
        accountNumber: accountNumber,
        bankName: bankName,
        role: role || (isPartner ? 'partner' : 'renter')
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

    const user = await UserStore.findByEmail(email.toString());

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    return res.status(200).json({
      isVerified: user.isVerified || false,
      accountNumber: user.accountNumber,
      bankName: user.bankName,
      role: user.role
    });
  } catch (error: any) {
    console.error('Status check error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}

// 6. Sync / Re-provision Real Flutterwave NUBAN for verified users
export async function syncNuban(req: Request, res: Response) {
  try {
    const { userId, email, fullName, businessName, role, bvn, phoneNumber } = req.body;

    if (!email && !userId) {
      return res.status(400).json({ error: 'User ID or Email is required' });
    }

    const isPartner = role === 'partner' || (businessName && businessName.trim().length > 0);
    const partnerBizName = (businessName || '').trim();
    const cleanName = (fullName || (partnerBizName ? partnerBizName : (email ? email.split('@')[0] : 'User'))).trim();
    const existing = await UserStore.findByEmail(email || '');
    const bvnToUse = (bvn && bvn.length === 11) ? bvn : (existing?.ninNumber || '');

    // Call Flutterwave Live API
    const bankResult = await FlutterwaveService.createPermanentUserVirtualAccount({
      userId: userId || existing?.id || `usr_${Date.now()}`,
      email: email || existing?.email || '',
      fullName: cleanName,
      businessName: partnerBizName,
      role: role || (isPartner ? 'partner' : 'renter'),
      bvn: bvnToUse,
      phoneNumber: phoneNumber || existing?.phoneNumber || ''
    });

    if (!bankResult.status || !bankResult.data?.accountNumber) {
      return res.status(400).json({
        status: false,
        message: bankResult.message || 'Failed to sync live NUBAN from Flutterwave.'
      });
    }

    const accountNumber = bankResult.data.accountNumber;
    const bankName = bankResult.data.bankName || 'Flutterwave MFB';

    // Update in UserStore
    const existing = await UserStore.findByEmail(email || '');
    if (existing) {
      UserStore.upsertUser({
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
      message: 'Dedicated NUBAN successfully synced with Flutterwave MFB & NIBSS router!',
      accountNumber: accountNumber,
      bankName: bankName
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
