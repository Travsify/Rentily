import type { Request, Response } from 'express';
import dotenv from 'dotenv';
import { FincraService } from '../services/fincraService';
import { supabase } from '../supabaseClient';

dotenv.config();

const FINCRA_SECRET_KEY = process.env.FINCRA_SECRET_KEY || 'k7jRtbW31oSn9naZ4ZIQCrLcjqV0o2zv';
const FINCRA_PUBLIC_KEY = process.env.FINCRA_PUBLIC_KEY || 'pk_NjkzYzU1MzM5NTdjOTAwMDEyMDExN2E2OjoyMDgyODA=';
const FINCRA_BUSINESS_ID = process.env.FINCRA_BUSINESS_ID || '693c5533957c9000120117a6';
const FINCRA_BASE_URL = process.env.FINCRA_BASE_URL || 'https://api.fincra.com';

const getHeaders = () => ({
  'api-key': FINCRA_SECRET_KEY,
  'x-pub-key': FINCRA_PUBLIC_KEY,
  'x-business-id': FINCRA_BUSINESS_ID,
  'Content-Type': 'application/json'
});

/**
 * 1. Comprehensive Fincra Master Ledger Overview
 * Returns business profile, multi-currency treasury wallets, approved virtual accounts, and payouts.
 */
export async function getFincraOverview(_req: Request, res: Response) {
  try {
    const headers = getHeaders();

    const [bizRes, walletsRes, vaRes, payoutsRes] = await Promise.all([
      fetch(`${FINCRA_BASE_URL}/profile/business/${FINCRA_BUSINESS_ID}`, { headers }).then(r => r.json()).catch(() => null),
      fetch(`${FINCRA_BASE_URL}/wallets?businessID=${FINCRA_BUSINESS_ID}`, { headers }).then(r => r.json()).catch(() => null),
      fetch(`${FINCRA_BASE_URL}/profile/virtual-accounts?currency=NGN`, { headers }).then(r => r.json()).catch(() => null),
      fetch(`${FINCRA_BASE_URL}/disbursements/payouts?business=${FINCRA_BUSINESS_ID}`, { headers }).then(r => r.json()).catch(() => null)
    ]);

    const business = bizRes?.data || null;
    const rawWallets: any[] = walletsRes?.data || [];
    const rawAccounts: any[] = vaRes?.data?.results || [];
    const rawPayouts: any[] = payoutsRes?.data?.results || payoutsRes?.data || [];

    // Map and format multi-currency wallets
    const wallets = rawWallets.map(w => ({
      id: w.id || w._id,
      currency: w.currency,
      ledgerBalance: Number(w.ledgerBalance || 0),
      availableBalance: Number(w.availableBalance || 0),
      lockedBalance: Number(w.lockedBalance || 0),
      rollingReserveBalance: Number(w.rollingReserveBalance || 0),
      walletNumber: w.walletNumber,
      status: w.status,
      updatedAt: w.updatedAt
    }));

    // Find primary NGN and USD wallets
    const ngnWallet = wallets.find(w => w.currency === 'NGN');
    const usdWallet = wallets.find(w => w.currency === 'USD');
    const eurWallet = wallets.find(w => w.currency === 'EUR');
    const gbpWallet = wallets.find(w => w.currency === 'GBP');

    // Cross-reference virtual accounts with Supabase profiles if available
    let localProfiles: any[] = [];
    let localConfigs: any[] = [];
    if (supabase) {
      try {
        const { data: profs } = await supabase.from('profiles').select('email, full_name, account_number, role');
        localProfiles = profs || [];
        const { data: cfgs } = await supabase.from('system_configs').select('id, data').like('id', 'fincra_va_%');
        localConfigs = cfgs || [];
      } catch (_) {}
    }

    const virtualAccounts = rawAccounts.map(acc => {
      const accNum = acc.accountNumber || acc.accountInformation?.accountNumber;
      const matchedProf = localProfiles.find(p => p.account_number === accNum);
      const matchedCfg = localConfigs.find(c => c.data?.accountNumber === accNum);
      const userEmail = matchedProf?.email || (matchedCfg?.id ? matchedCfg.id.replace('fincra_va_', '') : null);

      return {
        id: acc._id || acc.id,
        accountNumber: accNum,
        accountName: acc.accountInformation?.accountName || acc.accountName || acc.KYCInformation?.businessName || acc.KYCInformation?.bvnName || 'Rentilly Commercial Client',
        bankName: acc.accountInformation?.bankName || acc.bankName || 'Wema Bank',
        bankCode: acc.accountInformation?.bankCode || acc.bankCode || '035',
        currency: acc.currency || 'NGN',
        status: acc.status,
        isActive: acc.isActive ?? true,
        accountType: acc.accountType || 'corporate',
        entityType: acc.entityType || 'main_account',
        isPermanent: acc.isPermanent ?? true,
        assignedUserEmail: userEmail,
        assignedUserName: matchedProf?.full_name || null,
        createdAt: acc.createdAt
      };
    });

    const payouts = (Array.isArray(rawPayouts) ? rawPayouts : []).slice(0, 50).map(p => ({
      id: p.id || p._id,
      amount: Number(p.amountSent || p.amount || 0),
      currency: p.sourceCurrency || p.currency || 'NGN',
      fee: Number(p.fee || 0),
      beneficiaryName: p.beneficiaryName || p.beneficiary?.accountHolderName || 'Beneficiary',
      accountNumber: p.beneficiary?.accountNumber || p.accountNumber || '—',
      bankName: p.beneficiary?.bankCode || p.bankCode || 'NIP Bank',
      status: p.status,
      reference: p.reference,
      customerReference: p.customerReference,
      createdAt: p.createdAt
    }));

    const summary = {
      ngnAvailable: ngnWallet?.availableBalance || 0,
      ngnLedger: ngnWallet?.ledgerBalance || 0,
      usdAvailable: usdWallet?.availableBalance || 0,
      eurAvailable: eurWallet?.availableBalance || 0,
      gbpAvailable: gbpWallet?.availableBalance || 0,
      totalVirtualAccounts: virtualAccounts.length,
      totalPayoutsCount: payouts.length,
      isKYCApproved: Boolean(business?.isKYCApproved),
      businessName: business?.name || 'Ehomes Global Inclusive Limited',
      businessTag: business?.businessTag || 208280,
      webhookCallbackURL: business?.settings?.callbackURL || 'https://api.myrentilly.com/api/webhooks/fincra',
      isWebhookEnabled: Boolean(business?.settings?.enableWebhook)
    };

    return res.json({
      success: true,
      timestamp: new Date().toISOString(),
      summary,
      wallets,
      virtualAccounts,
      payouts
    });
  } catch (err: any) {
    console.error('[FincraAdmin] getFincraOverview error:', err.message);
    return res.status(500).json({ success: false, error: err.message });
  }
}

/**
 * 2. Get All Fincra Virtual Accounts
 */
export async function getFincraVirtualAccounts(_req: Request, res: Response) {
  try {
    const vaRes = await FincraService.getMerchantVirtualAccounts('NGN');
    return res.json(vaRes);
  } catch (err: any) {
    return res.status(500).json({ success: false, error: err.message });
  }
}

/**
 * 3. Create a New Virtual Account on Demand
 */
export async function createAdminVirtualAccount(req: Request, res: Response) {
  try {
    const { email, firstName, lastName, bvn, accountType, channel, businessName } = req.body;
    if (!email || !bvn) {
      return res.status(400).json({ error: 'email and bvn are required to provision Fincra virtual account' });
    }

    const cleanEmail = email.toLowerCase().trim();
    const result = await FincraService.createVirtualAccount({
      accountType: accountType || 'individual',
      channel: channel || 'wema',
      KYCInformation: {
        firstName: firstName || 'Rentilly',
        lastName: lastName || 'User',
        email: cleanEmail,
        bvn: bvn.toString().trim(),
        businessName: businessName
      }
    });

    if (result.status && result.data?.accountNumber && supabase) {
      await supabase.from('system_configs').upsert({
        id: `fincra_va_${cleanEmail}`,
        data: {
          accountNumber: result.data.accountNumber,
          bankName: result.data.bankName || 'Wema Bank (Rentilly)',
          bankCode: '035',
          accountName: result.data.accountName || `${firstName} ${lastName}`,
          provider: 'fincra',
          tier: 'Commercial Institutional Tier'
        },
        updated_at: new Date().toISOString()
      });

      await supabase.from('profiles').update({
        account_number: result.data.accountNumber,
        bank_name: 'Wema Bank (Rentilly)'
      }).eq('email', cleanEmail);
    }

    return res.json(result);
  } catch (err: any) {
    return res.status(500).json({ success: false, error: err.message });
  }
}

/**
 * 4. Get Fincra Payouts Audit Trail
 */
export async function getFincraPayouts(_req: Request, res: Response) {
  try {
    const headers = getHeaders();
    const resRaw = await fetch(`${FINCRA_BASE_URL}/disbursements/payouts?business=${FINCRA_BUSINESS_ID}`, { headers });
    const data = await resRaw.json();
    return res.json(data);
  } catch (err: any) {
    return res.status(500).json({ success: false, error: err.message });
  }
}

/**
 * 5. Disburse Instant Payout via Fincra
 */
export async function disburseAdminPayout(req: Request, res: Response) {
  try {
    const { amount, accountNumber, bankCode, accountHolderName, description } = req.body;
    if (!amount || !accountNumber || !bankCode) {
      return res.status(400).json({ error: 'amount, accountNumber, and bankCode are required' });
    }

    const nameParts = (accountHolderName || 'Rentilly Recipient').split(' ');
    const txRef = `ADMIN_DISB_${Date.now()}`;

    const result = await FincraService.initiatePayout({
      amount: Number(amount),
      reference: txRef,
      description: description || 'Rentilly Admin Disbursement',
      currency: 'NGN',
      beneficiary: {
        firstName: nameParts[0] || 'Rentilly',
        lastName: nameParts.slice(1).join(' ') || 'Recipient',
        accountHolderName: accountHolderName || 'Rentilly Recipient',
        accountNumber: accountNumber.toString(),
        bankCode: bankCode.toString(),
        type: 'individual'
      }
    });

    return res.json(result);
  } catch (err: any) {
    return res.status(500).json({ success: false, error: err.message });
  }
}
