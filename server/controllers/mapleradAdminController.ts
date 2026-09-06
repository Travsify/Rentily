import type { Request, Response } from 'express';
import dotenv from 'dotenv';

dotenv.config();

const MAPLERAD_SECRET_KEY = process.env.MAPLERAD_SECRET_KEY || 'mpr_sk_35d197e6-3f6b-437c-995b-a0dff522b3dc';
const MAPLERAD_BASE_URL = process.env.MAPLERAD_BASE_URL || 'https://api.maplerad.com/v1';

const headers = {
  'Authorization': `Bearer ${MAPLERAD_SECRET_KEY}`,
  'Accept': 'application/json',
  'Content-Type': 'application/json',
  'User-Agent': 'Rentilly/2.0 Admin Desk'
};

export interface NormalizedMapleradTx {
  id: string;
  category: 'usdt' | 'conversion' | 'card' | 'transfer' | 'general';
  type: string;
  entry: 'CREDIT' | 'DEBIT';
  amount: number; // in human readable
  amountMinor: number; // in minor units
  currency: string;
  status: string;
  summary: string;
  reference?: string;
  customer?: {
    name?: string;
    email?: string;
    phone?: string;
  } | null;
  sourceOrCounterparty?: string;
  createdAt: string;
  raw?: any;
}

/**
 * 1. Get All Maplerad Balances (Treasury & Spend across all currencies)
 */
export async function getMapleradWallets(_req: Request, res: Response) {
  try {
    const [treasuryRes, spendRes] = await Promise.all([
      fetch(`${MAPLERAD_BASE_URL}/wallets`, { headers }),
      fetch(`${MAPLERAD_BASE_URL}/wallets?wallet_type=SPEND`, { headers })
    ]);

    const treasuryData = await treasuryRes.json().catch(() => ({ status: false, data: [] }));
    const spendData = await spendRes.json().catch(() => ({ status: false, data: [] }));

    const treasuryList: any[] = treasuryData?.data || [];
    const spendList: any[] = spendData?.data || [];

    // Map currencies
    const currencyMap: Record<string, {
      currency: string;
      treasuryBalance: number;
      spendBalance: number;
      treasuryBalanceMinor: number;
      spendBalanceMinor: number;
      totalBalance: number;
    }> = {};

    // Helper to format minor to decimal
    const toDecimal = (minor: number) => Number((minor / 100).toFixed(2));

    treasuryList.forEach((w) => {
      const c = w.currency;
      if (!currencyMap[c]) {
        currencyMap[c] = {
          currency: c,
          treasuryBalance: 0,
          spendBalance: 0,
          treasuryBalanceMinor: 0,
          spendBalanceMinor: 0,
          totalBalance: 0
        };
      }
      currencyMap[c].treasuryBalanceMinor = w.available_balance || 0;
      currencyMap[c].treasuryBalance = toDecimal(w.available_balance || 0);
      currencyMap[c].totalBalance = Number((currencyMap[c].treasuryBalance + currencyMap[c].spendBalance).toFixed(2));
    });

    spendList.forEach((w) => {
      const c = w.currency;
      if (!currencyMap[c]) {
        currencyMap[c] = {
          currency: c,
          treasuryBalance: 0,
          spendBalance: 0,
          treasuryBalanceMinor: 0,
          spendBalanceMinor: 0,
          totalBalance: 0
        };
      }
      currencyMap[c].spendBalanceMinor = w.available_balance || 0;
      currencyMap[c].spendBalance = toDecimal(w.available_balance || 0);
      currencyMap[c].totalBalance = Number((currencyMap[c].treasuryBalance + currencyMap[c].spendBalance).toFixed(2));
    });

    return res.json({
      success: true,
      timestamp: new Date().toISOString(),
      currencies: Object.values(currencyMap),
      treasuryWallets: treasuryList.map(w => ({
        ...w,
        available_balance_formatted: toDecimal(w.available_balance || 0)
      })),
      spendWallets: spendList.map(w => ({
        ...w,
        available_balance_formatted: toDecimal(w.available_balance || 0)
      })),
      summary: {
        ngnTreasury: currencyMap['NGN']?.treasuryBalance || 0,
        usdTreasury: currencyMap['USD']?.treasuryBalance || 0,
        usdSpend: currencyMap['USD']?.spendBalance || 0,
        usdTotal: currencyMap['USD']?.totalBalance || 0,
        usdtTreasury: currencyMap['USDT']?.treasuryBalance || 0,
        usdtSpend: currencyMap['USDT']?.spendBalance || 0,
        usdtTotal: currencyMap['USDT']?.totalBalance || 0,
      }
    });
  } catch (err: any) {
    console.error('[MapleradAdmin] Error fetching wallets:', err);
    return res.status(500).json({ error: err.message });
  }
}

/**
 * 2. Get Live Maplerad Transactions (USDT, Conversions, Cards, Transfers)
 */
export async function getMapleradTransactions(req: Request, res: Response) {
  try {
    const { category, search, page = '1', pageSize = '50' } = req.query;

    // Fetch in parallel: /transactions, /fx (exchanges), /transfers, /issuing (cards)
    const [txRes, fxRes, transfersRes, cardsRes] = await Promise.all([
      fetch(`${MAPLERAD_BASE_URL}/transactions?page=1&page_size=100`, { headers }).catch(() => null),
      fetch(`${MAPLERAD_BASE_URL}/fx`, { headers }).catch(() => null),
      fetch(`${MAPLERAD_BASE_URL}/transfers?page=1&page_size=100`, { headers }).catch(() => null),
      fetch(`${MAPLERAD_BASE_URL}/issuing`, { headers }).catch(() => null)
    ]);

    const txData = txRes ? await txRes.json().catch(() => ({})) : {};
    const fxData = fxRes ? await fxRes.json().catch(() => ({})) : {};
    const transfersData = transfersRes ? await transfersRes.json().catch(() => ({})) : {};
    const cardsData = cardsRes ? await cardsRes.json().catch(() => ({})) : {};

    const rawTxs: any[] = txData?.data || [];
    const rawFx: any[] = fxData?.data || [];
    const rawTransfers: any[] = transfersData?.data || [];
    const rawCards: any[] = cardsData?.data || [];

    // Fetch card authorizations for active cards
    const cardAuthorizations: any[] = [];
    if (rawCards.length > 0) {
      await Promise.all(
        rawCards.slice(0, 3).map(async (card: any) => {
          try {
            const cardTxRes = await fetch(`${MAPLERAD_BASE_URL}/issuing/${card.id}/transactions`, { headers });
            const ctd = await cardTxRes.json().catch(() => ({}));
            if (ctd?.data && Array.isArray(ctd.data)) {
              ctd.data.forEach((ctx: any) => {
                cardAuthorizations.push({
                  ...ctx,
                  cardName: card.name,
                  cardMaskedPan: card.masked_pan
                });
              });
            }
          } catch (_) {}
        })
      );
    }

    const normalizedList: NormalizedMapleradTx[] = [];
    const seenIds = new Set<string>();

    // Helper for minor to decimal
    const toDecimal = (minor: number) => Number((minor / 100).toFixed(2));

    // A. Main /transactions
    for (const t of rawTxs) {
      if (seenIds.has(t.id)) continue;
      seenIds.add(t.id);

      const summary = t.summary || t.reason || '';
      const isUsdt = t.currency === 'USDT' || t.channel === 'CRYPTO' || summary.toLowerCase().includes('usdt') || summary.toLowerCase().includes('tron');
      const isCard = t.type === 'CARD' || t.channel === 'CARD' || summary.toLowerCase().includes('virtual card');
      const isConversion = summary.toLowerCase().includes('exchange') || summary.toLowerCase().includes('convert') || t.type === 'FX';
      const isTransfer = t.type === 'TRANSFER' || summary.toLowerCase().includes('transfer');

      let detectedCat: NormalizedMapleradTx['category'] = 'general';
      if (isUsdt) detectedCat = 'usdt';
      else if (isConversion) detectedCat = 'conversion';
      else if (isCard) detectedCat = 'card';
      else if (isTransfer) detectedCat = 'transfer';

      let sourceOrCounterparty = '';
      if (t.source?.account_number) {
        sourceOrCounterparty = `${t.source.bank_name || ''} ${t.source.account_number} (${t.source.account_name || ''})`.trim();
      } else if (t.source?.bank_name === 'TRON') {
        sourceOrCounterparty = `TRON (${t.source.account_number})`;
      }

      normalizedList.push({
        id: t.id,
        category: detectedCat,
        type: t.type || 'TRANSACTION',
        entry: t.entry || (t.type === 'COLLECTION' ? 'CREDIT' : 'DEBIT'),
        amount: toDecimal(t.amount || 0),
        amountMinor: t.amount || 0,
        currency: t.currency || 'USD',
        status: t.status || 'SUCCESS',
        summary: summary || `${t.entry} ${t.currency}`,
        reference: t.reference || t.id,
        customer: t.customer ? {
          name: t.customer.name,
          email: t.customer.email,
          phone: t.customer.phone_number
        } : null,
        sourceOrCounterparty,
        createdAt: t.created_at || new Date().toISOString(),
        raw: t
      });
    }

    // B. FX History
    for (const f of rawFx) {
      const fxId = `fx_${f.created_at}_${f.source?.currency}_${f.target?.currency}`;
      if (seenIds.has(fxId)) continue;
      seenIds.add(fxId);

      normalizedList.push({
        id: fxId,
        category: 'conversion',
        type: 'FX_EXCHANGE',
        entry: 'DEBIT',
        amount: f.source?.human_readable_amount ?? toDecimal(f.source?.amount || 0),
        amountMinor: f.source?.amount || 0,
        currency: f.source?.currency || 'USDT',
        status: 'SUCCESS',
        summary: `Exchange ${f.source?.currency} to ${f.target?.currency} (Rate: ${f.rate}) -> Recv: ${f.target?.human_readable_amount} ${f.target?.currency}`,
        reference: fxId,
        customer: null,
        sourceOrCounterparty: `${f.source?.currency} ➔ ${f.target?.currency}`,
        createdAt: f.created_at || new Date().toISOString(),
        raw: f
      });
    }

    // C. Transfers (if not already in transactions)
    for (const tf of rawTransfers) {
      if (seenIds.has(tf.id)) continue;
      seenIds.add(tf.id);

      const summary = tf.summary || tf.reason || 'Transfer';
      const isSpendTransfer = summary.includes('TREASURY to SPEND');

      normalizedList.push({
        id: tf.id,
        category: isSpendTransfer ? 'conversion' : 'transfer',
        type: 'TRANSFER',
        entry: tf.entry || 'DEBIT',
        amount: toDecimal(tf.amount || 0),
        amountMinor: tf.amount || 0,
        currency: tf.currency || 'USD',
        status: tf.status || 'SUCCESS',
        summary,
        reference: tf.reference || tf.id,
        customer: null,
        sourceOrCounterparty: tf.counterparty?.account_number
          ? `${tf.counterparty.bank_name || ''} ${tf.counterparty.account_number} (${tf.counterparty.account_name || ''})`.trim()
          : (isSpendTransfer ? 'Treasury ➔ Spend Wallet' : ''),
        createdAt: tf.created_at || new Date().toISOString(),
        raw: tf
      });
    }

    // D. Card Authorizations / POS Transactions
    for (const ca of cardAuthorizations) {
      const caId = `card_auth_${ca.id}`;
      if (seenIds.has(caId)) continue;
      seenIds.add(caId);

      normalizedList.push({
        id: caId,
        category: 'card',
        type: ca.type || 'CARD_AUTH',
        entry: ca.entry || 'DEBIT',
        amount: toDecimal(ca.amount || 0),
        amountMinor: ca.amount || 0,
        currency: ca.currency || 'USD',
        status: ca.status || 'SUCCESS',
        summary: `${ca.description || 'Card Transaction'} | ${ca.merchant?.name || ''} | Card: ${ca.cardMaskedPan || ''}`.trim(),
        reference: ca.id,
        customer: ca.cardName ? { name: ca.cardName } : null,
        sourceOrCounterparty: ca.merchant?.name ? `${ca.merchant.name} (${ca.merchant.country || ''})` : ca.cardMaskedPan,
        createdAt: ca.created_at || new Date().toISOString(),
        raw: ca
      });
    }

    // Sort descending by date
    normalizedList.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

    // Apply category filter if given
    let filtered = normalizedList;
    if (category && category !== 'all') {
      filtered = filtered.filter(item => item.category === category);
    }

    // Apply search filter if given
    if (search) {
      const q = String(search).toLowerCase();
      filtered = filtered.filter(item =>
        item.summary?.toLowerCase().includes(q) ||
        item.reference?.toLowerCase().includes(q) ||
        item.currency?.toLowerCase().includes(q) ||
        item.customer?.name?.toLowerCase().includes(q) ||
        item.customer?.email?.toLowerCase().includes(q) ||
        item.sourceOrCounterparty?.toLowerCase().includes(q)
      );
    }

    const total = filtered.length;
    const p = parseInt(String(page)) || 1;
    const size = parseInt(String(pageSize)) || 50;
    const paginated = filtered.slice((p - 1) * size, p * size);

    // Group counts
    const counts = {
      all: normalizedList.length,
      usdt: normalizedList.filter(i => i.category === 'usdt').length,
      conversion: normalizedList.filter(i => i.category === 'conversion').length,
      card: normalizedList.filter(i => i.category === 'card').length,
      transfer: normalizedList.filter(i => i.category === 'transfer').length,
    };

    return res.json({
      success: true,
      total,
      page: p,
      pageSize: size,
      counts,
      transactions: paginated
    });
  } catch (err: any) {
    console.error('[MapleradAdmin] Error fetching transactions:', err);
    return res.status(500).json({ error: err.message });
  }
}

/**
 * 3. Convert Funds: Transfer Treasury to Spend Wallet (or vice-versa)
 */
export async function transferTreasuryToSpend(req: Request, res: Response) {
  try {
    const {
      currency = 'USD',
      source_wallet_type = 'TREASURY',
      destination_wallet_type = 'SPEND',
      amount // in human readable format (e.g. 10 for $10)
    } = req.body;

    if (!amount || Number(amount) <= 0) {
      return res.status(400).json({ error: 'Valid amount is required.' });
    }

    // Convert to minor units (cents / kobo: multiply by 100)
    const amountMinor = Math.round(Number(amount) * 100);

    console.log(`[MapleradAdmin] Transferring ${amount} ${currency} (${amountMinor} minor) from ${source_wallet_type} to ${destination_wallet_type}...`);

    const resp = await fetch(`${MAPLERAD_BASE_URL}/wallets/fund`, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        currency: currency.toUpperCase(),
        source_wallet_type,
        destination_wallet_type,
        amount: amountMinor
      })
    });

    const data = await resp.json().catch(() => ({}));

    if (!resp.ok || !data.status) {
      return res.status(resp.status || 400).json({
        success: false,
        error: data.message || 'Transfer between wallets failed'
      });
    }

    return res.json({
      success: true,
      message: `Successfully transferred ${amount} ${currency} to ${destination_wallet_type} wallet.`,
      data: data.data
    });
  } catch (err: any) {
    console.error('[MapleradAdmin] Transfer error:', err);
    return res.status(500).json({ error: err.message });
  }
}

/**
 * 4. Get FX Quote (e.g. USDT -> USD or USD -> NGN)
 */
export async function getFxQuote(req: Request, res: Response) {
  try {
    const { source_currency = 'USDT', target_currency = 'USD', amount } = req.body;

    if (!amount || Number(amount) <= 0) {
      return res.status(400).json({ error: 'Valid amount is required' });
    }

    const amountMinor = Math.round(Number(amount) * 100);

    const resp = await fetch(`${MAPLERAD_BASE_URL}/fx/quote`, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        source_currency: source_currency.toUpperCase(),
        target_currency: target_currency.toUpperCase(),
        amount: amountMinor
      })
    });

    const data = await resp.json().catch(() => ({}));

    if (!resp.ok || !data.status) {
      return res.status(resp.status || 400).json({
        success: false,
        error: data.message || 'Failed to generate quote'
      });
    }

    return res.json({
      success: true,
      quote: data.data
    });
  } catch (err: any) {
    console.error('[MapleradAdmin] FX Quote error:', err);
    return res.status(500).json({ error: err.message });
  }
}

/**
 * 5. Execute FX Conversion (Execute Quote)
 */
export async function executeFxExchange(req: Request, res: Response) {
  try {
    const { quote_reference } = req.body;

    if (!quote_reference) {
      return res.status(400).json({ error: 'Quote reference is required' });
    }

    const resp = await fetch(`${MAPLERAD_BASE_URL}/fx`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ quote_reference })
    });

    const data = await resp.json().catch(() => ({}));

    if (!resp.ok || !data.status) {
      return res.status(resp.status || 400).json({
        success: false,
        error: data.message || 'FX Exchange failed'
      });
    }

    return res.json({
      success: true,
      message: 'Currency exchange executed successfully!',
      data: data.data
    });
  } catch (err: any) {
    console.error('[MapleradAdmin] FX Execute error:', err);
    return res.status(500).json({ error: err.message });
  }
}
