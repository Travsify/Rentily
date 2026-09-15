import type { Request, Response } from 'express';
import dotenv from 'dotenv';
import { FincraService } from '../services/fincraService';
import { supabase } from '../supabaseClient';
import { AtomicLedgerService } from '../services/atomicLedgerService';
import { PayoutReversalService } from '../services/payoutReversalService';
import { PaystackService } from '../services/paystackService';
import { NotificationDispatcher } from '../services/notificationDispatcher';
import { UserStore } from '../services/userStore';
import { TransactionStore } from '../services/transactionStore';

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
 * Returns business profile, multi-currency treasury wallets, approved virtual accounts, payouts, and collections.
 */
export async function getFincraOverview(_req: Request, res: Response) {
  try {
    const headers = getHeaders();

    const [bizRes, walletsRes, vaRes, payoutsRes, collectionsRes] = await Promise.all([
      fetch(`${FINCRA_BASE_URL}/profile/business/${FINCRA_BUSINESS_ID}`, { headers, signal: AbortSignal.timeout(15000) }).then(r => r.json()).catch(() => null),
      fetch(`${FINCRA_BASE_URL}/wallets?businessID=${FINCRA_BUSINESS_ID}`, { headers, signal: AbortSignal.timeout(15000) }).then(r => r.json()).catch(() => null),
      fetch(`${FINCRA_BASE_URL}/profile/virtual-accounts/requests?businessID=${FINCRA_BUSINESS_ID}`, { headers, signal: AbortSignal.timeout(15000) }).then(r => r.json()).catch(() => null),
      fetch(`${FINCRA_BASE_URL}/disbursements/payouts?business=${FINCRA_BUSINESS_ID}&page=1&perPage=30`, { headers, signal: AbortSignal.timeout(15000) }).then(r => r.json()).catch(() => null),
      fetch(`${FINCRA_BASE_URL}/collections?business=${FINCRA_BUSINESS_ID}&page=1&perPage=30`, { headers, signal: AbortSignal.timeout(15000) }).then(r => r.json()).catch(() => null)
    ]);

    const business = bizRes?.data || null;
    const rawWallets: any[] = walletsRes?.data || [];
    const rawAccounts: any[] = vaRes?.data?.results || vaRes?.data || [];
    const rawPayouts: any[] = payoutsRes?.data?.results || payoutsRes?.data || [];
    const rawCollections: any[] = collectionsRes?.data?.results || collectionsRes?.data || [];

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

    // Find primary wallets
    const ngnWallet = wallets.find(w => w.currency === 'NGN');
    const usdWallet = wallets.find(w => w.currency === 'USD');
    const eurWallet = wallets.find(w => w.currency === 'EUR');
    const gbpWallet = wallets.find(w => w.currency === 'GBP');

    // Cross-reference with Supabase
    let localProfiles: any[] = [];
    let localConfigs: any[] = [];
    const refundedRefs = new Set<string>();

    if (supabase) {
      try {
        const [profsRes, cfgsRes, refundRes] = await Promise.all([
          supabase.from('profiles').select('id, email, full_name, account_number, role'),
          supabase.from('system_configs').select('id, data').like('id', 'fincra_va_%'),
          supabase.from('wallet_transactions').select('flw_ref, tx_ref').like('flw_ref', 'REFUND_%')
        ]);
        localProfiles = profsRes.data || [];
        localConfigs = cfgsRes.data || [];
        (refundRes.data || []).forEach((t: any) => {
          if (t.flw_ref) refundedRefs.add(t.flw_ref.replace('REFUND_', ''));
          if (t.tx_ref) refundedRefs.add(t.tx_ref.replace('REFUND_', ''));
        });
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

    const payouts = (Array.isArray(rawPayouts) ? rawPayouts : []).slice(0, 50).map(p => {
      const custRef = p.customerReference || '';
      const fincraRef = p.reference || '';
      const isRefunded = refundedRefs.has(custRef) || refundedRefs.has(fincraRef);

      return {
        id: p.id || p._id,
        amount: Number(p.amountSent || p.amount || 0),
        currency: p.sourceCurrency || p.currency || 'NGN',
        fee: Number(p.fee || 0),
        beneficiaryName: p.beneficiaryName || p.beneficiary?.accountHolderName || 'Beneficiary',
        accountNumber: p.beneficiary?.accountNumber || p.accountNumber || '—',
        bankName: p.beneficiary?.bankCode || p.bankCode || 'NIP Bank',
        status: p.status,
        failedReason: p.failedReason || p.reason || p.errorMessage || null,
        reference: fincraRef,
        customerReference: custRef,
        isRefunded,
        createdAt: p.createdAt
      };
    });

    const collections = rawCollections.slice(0, 50).map(c => {
      const accNum = c.accountNumber || c.destinationAccountNumber || c.virtualAccount?.accountNumber;
      const matchedProf = localProfiles.find(p => p.account_number === accNum);
      const matchedCfg = localConfigs.find(cfg => cfg.data?.accountNumber === accNum || cfg.data?.virtualAccountId === c.virtualAccountId);
      const userEmail = matchedProf?.email || (matchedCfg?.id ? matchedCfg.id.replace('fincra_va_', '') : null);

      return {
        id: c.id || c._id,
        reference: c.reference,
        merchantReference: c.merchantReference,
        amount: Number(c.sourceAmount || c.amount || 0),
        currency: c.sourceCurrency || 'NGN',
        fee: Number(c.vat || 0) + Number(c.electronicMoneyTransferLevy || 0),
        emtl: Number(c.electronicMoneyTransferLevy || 0),
        vat: Number(c.vat || 0),
        payeeName: c.payeeName || 'Inbound Payee',
        paymentMethod: c.paymentMethod || 'bank_transfer',
        status: c.status,
        virtualAccountId: c.virtualAccountId,
        accountNumber: accNum || '—',
        assignedUserEmail: userEmail,
        assignedUserName: matchedProf?.full_name || null,
        createdAt: c.createdAt || c.initiatedAt
      };
    });

    const summary = {
      ngnAvailable: ngnWallet?.availableBalance || 0,
      ngnLedger: ngnWallet?.ledgerBalance || 0,
      usdAvailable: usdWallet?.availableBalance || 0,
      eurAvailable: eurWallet?.availableBalance || 0,
      gbpAvailable: gbpWallet?.availableBalance || 0,
      totalVirtualAccounts: virtualAccounts.length,
      totalPayoutsCount: payouts.length,
      totalCollectionsCount: collections.length,
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
      payouts,
      collections
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

/**
 * 6. Get Fincra Collections (Inbound Bank Deposits & Collections)
 */
export async function getFincraCollections(req: Request, res: Response) {
  try {
    const page = Number(req.query.page || 1);
    const perPage = Number(req.query.perPage || 30);
    const colRes = await FincraService.listCollections({ page, perPage });
    return res.json(colRes);
  } catch (err: any) {
    return res.status(500).json({ status: false, message: err.message });
  }
}

/**
 * 7. Manually Reconcile / Allocate an Inbound Collection to a User
 */
export async function reconcileFincraCollection(req: Request, res: Response) {
  try {
    const { reference, email, narration } = req.body;
    if (!reference || !email) {
      return res.status(400).json({ error: 'reference and email are required' });
    }

    const cleanEmail = email.toLowerCase().trim();
    if (!supabase) return res.status(503).json({ error: 'Database unavailable' });

    // Fetch user profile
    const { data: prof } = await supabase
      .from('profiles')
      .select('id, email, full_name, wallet_balance')
      .eq('email', cleanEmail)
      .maybeSingle();

    if (!prof) {
      return res.status(404).json({ error: `User with email ${cleanEmail} not found` });
    }

    // Verify collection on Fincra
    const colRes = await FincraService.listCollections({ page: 1, perPage: 50 });
    const collections = colRes.data || [];
    const matched = collections.find((c: any) =>
      String(c.reference || '').trim() === reference ||
      String(c.id || '').trim() === reference ||
      String(c.merchantReference || '').trim() === reference
    );

    const amount = Number(matched?.sourceAmount || matched?.amount || req.body.amount || 0);
    if (amount <= 0) {
      return res.status(400).json({ error: 'Could not determine a valid collection amount to credit' });
    }

    const creditNarration = narration || `Manual Fincra Collection Credit (${matched?.payeeName || 'Inbound Transfer'})`;
    const creditRes = await AtomicLedgerService.creditWalletAtomic({
      userId: prof.id,
      email: prof.email,
      amount,
      flwRef: reference,
      txRef: reference,
      narration: creditNarration
    });

    if (creditRes.success) {
      await TransactionStore.addTransaction({
        id: `FINCRA_MANUAL_${reference}`,
        userId: prof.id,
        email: prof.email,
        title: creditNarration,
        type: 'Electronic Bank Inbound Deposit',
        category: 'deposit',
        amount,
        isCredit: true,
        reference,
        sender: matched?.payeeName || 'Fincra Commercial Bank Rail',
        beneficiary: prof.full_name || prof.email,
        recipientBank: 'Wema Bank Commercial Rail',
        status: 'SUCCESSFUL',
        date: new Date().toISOString()
      });

      NotificationDispatcher.dispatch({
        userId: prof.id,
        email: prof.email,
        userName: prof.full_name || 'Valued User',
        category: 'wallet',
        title: `Payment Reconciled: ₦${amount.toLocaleString()} Credited`,
        message: `Your deposit of ₦${amount.toLocaleString()} has been reconciled and credited to your Rentilly Escrow Vault. New Balance: ₦${(creditRes.newBalance ?? 0).toLocaleString()}.`,
        metadata: { amount, reference, date: new Date().toISOString() }
      }).catch(() => {});
    }

    return res.json({
      success: true,
      message: `Successfully credited ₦${amount.toLocaleString()} to ${prof.email}`,
      data: creditRes
    });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
}

/**
 * 8. Generate Fincra Conversion / FX Quote
 */
export async function generateFincraQuote(req: Request, res: Response) {
  try {
    const { sourceCurrency, destinationCurrency, amount, action = 'receive' } = req.body;
    if (!sourceCurrency || !destinationCurrency || !amount) {
      return res.status(400).json({ error: 'sourceCurrency, destinationCurrency, and amount are required' });
    }

    const headers = getHeaders();
    const payload = {
      action,
      transactionType: 'conversion',
      sourceCurrency: sourceCurrency.toUpperCase(),
      destinationCurrency: destinationCurrency.toUpperCase(),
      amount: Number(amount),
      business: FINCRA_BUSINESS_ID
    };

    const resRaw = await fetch(`${FINCRA_BASE_URL}/quotes/generate`, {
      method: 'POST',
      headers,
      body: JSON.stringify(payload)
    });

    const data = await resRaw.json();
    return res.json(data);
  } catch (err: any) {
    return res.status(500).json({ success: false, error: err.message });
  }
}

/**
 * 9. Execute Currency Conversion (Swap Treasury Balances)
 */
export async function executeFincraConversion(req: Request, res: Response) {
  try {
    const { quoteReference } = req.body;
    if (!quoteReference) {
      return res.status(400).json({ error: 'quoteReference is required' });
    }

    const headers = getHeaders();
    const resRaw = await fetch(`${FINCRA_BASE_URL}/conversions`, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        businessId: FINCRA_BUSINESS_ID,
        business: FINCRA_BUSINESS_ID,
        quoteReference
      })
    });

    const data = await resRaw.json();
    return res.json(data);
  } catch (err: any) {
    return res.status(500).json({ success: false, error: err.message });
  }
}

/**
 * 10. Get Beneficiaries Directory
 */
export async function getFincraBeneficiaries(_req: Request, res: Response) {
  try {
    const headers = getHeaders();
    const resRaw = await fetch(`${FINCRA_BASE_URL}/profile/beneficiaries/business/${FINCRA_BUSINESS_ID}?page=1&perPage=50`, { headers });
    const data = await resRaw.json();
    return res.json(data);
  } catch (err: any) {
    return res.status(500).json({ success: false, error: err.message });
  }
}

/**
 * 11. Create a Saved Beneficiary on Fincra
 */
export async function createFincraBeneficiary(req: Request, res: Response) {
  try {
    const { firstName, lastName, accountHolderName, accountNumber, bankCode } = req.body;
    if (!accountNumber || !bankCode) {
      return res.status(400).json({ error: 'accountNumber and bankCode are required' });
    }

    const headers = getHeaders();
    const payload = {
      firstName: firstName || 'Beneficiary',
      lastName: lastName || 'User',
      accountHolderName: accountHolderName || `${firstName || ''} ${lastName || ''}`.trim(),
      accountNumber: accountNumber.toString().trim(),
      bankCode: bankCode.toString().trim(),
      type: 'individual',
      currency: 'NGN'
    };

    const resRaw = await fetch(`${FINCRA_BASE_URL}/profile/beneficiaries/business/${FINCRA_BUSINESS_ID}`, {
      method: 'POST',
      headers,
      body: JSON.stringify(payload)
    });

    const data = await resRaw.json();
    return res.json(data);
  } catch (err: any) {
    return res.status(500).json({ success: false, error: err.message });
  }
}

/**
 * 12. Instant Payout Reversal / Refund Action
 */
export async function refundFincraPayout(req: Request, res: Response) {
  try {
    const { reference, customerReference, failedReason, amount, beneficiaryName, accountNumber } = req.body;
    if (!reference && !customerReference) {
      return res.status(400).json({ error: 'reference or customerReference is required' });
    }

    const result = await PayoutReversalService.handleFailedPayout({
      reference,
      customerReference,
      amount: Number(amount || 0),
      failedReason: failedReason || 'Manual Admin Triggered Reversal',
      beneficiaryName,
      accountNumber
    });

    return res.json(result);
  } catch (err: any) {
    return res.status(500).json({ success: false, error: err.message });
  }
}

/**
 * 13. Resolve Nigerian Bank Account (Real-Time Beneficiary Verification)
 */
export async function resolveFincraAccount(req: Request, res: Response) {
  try {
    const accountNumber = String(req.query.accountNumber || req.body.accountNumber || '').trim();
    const bankCode = String(req.query.bankCode || req.body.bankCode || '').trim();

    if (!accountNumber || !bankCode) {
      return res.status(400).json({ error: 'accountNumber and bankCode are required' });
    }

    // Try Paystack resolver first (highest speed and accuracy across all 650+ Nigerian banks)
    try {
      const pRes = await PaystackService.resolveAccount(accountNumber, bankCode);
      if (pRes.status && (pRes.data as any)?.accountName) {
        return res.json({
          status: true,
          accountName: (pRes.data as any).accountName,
          accountNumber,
          bankCode
        });
      }
    } catch (_) {}

    // Fallback to Fincra core resolver
    try {
      const headers = getHeaders();
      const fRes = await fetch(`${FINCRA_BASE_URL}/core/accounts/resolve`, {
        method: 'POST',
        headers,
        body: JSON.stringify({ accountNumber, bankCode })
      });
      const fData = await fRes.json();
      if (fData.status || fData.success) {
        return res.json({
          status: true,
          accountName: fData.data?.accountName || fData.data?.accountHolderName,
          accountNumber,
          bankCode
        });
      }
    } catch (_) {}

    return res.status(422).json({
      status: false,
      error: 'Could not resolve account name. Please confirm the account number and bank.'
    });
  } catch (err: any) {
    return res.status(500).json({ status: false, error: err.message });
  }
}

/**
 * 14. Get Official 650+ Banks Directory
 */
export async function getFincraBanks(_req: Request, res: Response) {
  try {
    const banks = await FincraService.getBanks('NG', 'NGN');
    return res.json({ status: true, count: banks.length, data: banks });
  } catch (err: any) {
    return res.status(500).json({ status: false, error: err.message });
  }
}
