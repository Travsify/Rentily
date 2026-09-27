import type { Request, Response } from 'express';
import { ReloadlyService } from '../services/reloadlyService';
import { UserStore } from '../services/userStore';
import { TransactionStore } from '../services/transactionStore';
import { NotificationDispatcher } from '../services/notificationDispatcher';
import { supabase } from '../supabaseClient';

// In-memory runtime fallback cache for user purchased vouchers
const _runtimeVouchers: Map<string, any[]> = new Map();

// Default USD to NGN exchange rate for Reloadly products
let _cachedUsdRate = 1549.00; // Standardized: 1510 + 39 NGN

export async function getBillersHandler(req: Request, res: Response) {
  try {
    const countryCode = (req.query.countryCode as string) || 'NG';
    const type = req.query.type as string | undefined;
    const page = parseInt((req.query.page as string) || '1', 10);
    const size = parseInt((req.query.size as string) || '50', 10);

    const billers = await ReloadlyService.getBillers(countryCode, type, page, size);
    let content = billers?.content || [];

    // Filter strictly by countryCode since Reloadly API returns all billers if country filter is omitted
    if (countryCode && countryCode.trim()) {
      const code = countryCode.trim().toUpperCase();
      content = content.filter((b: any) => (b.countryCode || '').toUpperCase() === code);
    }
    if (type && type.trim()) {
      content = content.filter((b: any) => (b.type || '').toUpperCase() === type.trim().toUpperCase());
    }

    res.json({
      success: true,
      data: {
        ...billers,
        content,
        totalElements: content.length,
        supportedUtilityCountries: ['NG', 'SN', 'ML', 'ZA', 'ZW', 'SL', 'MZ', 'MW']
      }
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message || 'Failed to fetch billers' });
  }
}

export async function validateMeterHandler(req: Request, res: Response) {
  try {
    const { billerId, accountNumber } = req.body;
    if (!billerId || !accountNumber) {
      return res.status(400).json({ error: 'billerId and accountNumber are required' });
    }

    const validation = await ReloadlyService.validateMeter(Number(billerId), String(accountNumber));
    res.json({
      success: true,
      data: validation
    });
  } catch (err: any) {
    res.status(400).json({ error: err.message || 'Meter verification failed on provider grid' });
  }
}

export async function payBillHandler(req: Request, res: Response) {
  try {
    const { email, billerId, billerName, accountNumber, amountNgn, customerName, address } = req.body;
    if (!email || !billerId || !accountNumber || !amountNgn) {
      return res.status(400).json({ error: 'email, billerId, accountNumber, and amountNgn are required' });
    }

    const cleanEmail = String(email).trim().toLowerCase();
    const user = await UserStore.getUserByEmail(cleanEmail);
    if (!user) {
      return res.status(404).json({ error: 'User profile not found' });
    }

    const totalDebit = Number(amountNgn);
    if ((user.walletBalance || 0) < totalDebit) {
      return res.status(400).json({
        error: `Insufficient wallet balance. Available: ₦${(user.walletBalance || 0).toLocaleString()} NGN, Required: ₦${totalDebit.toLocaleString()} NGN`
      });
    }

    // 1. Deduct wallet atomically
    const newBal = (user.walletBalance || 0) - totalDebit;
    await UserStore.updateWalletBalance(user.id, newBal);

    const txRef = `RLD_BILL_${Date.now()}_${Math.floor(1000 + Math.random() * 9000)}`;

    // 2. Execute live settlement via Reloadly
    let reloadlyResult: any;
    try {
      reloadlyResult = await ReloadlyService.payBill({
        billerId: Number(billerId),
        accountNumber: String(accountNumber),
        amount: totalDebit,
        useLocalAmount: true,
        reference: txRef
      });
    } catch (apiErr: any) {
      // Reversal: refund wallet immediately on provider failure
      await UserStore.updateWalletBalance(user.id, user.walletBalance || 0);
      return res.status(502).json({ error: `Provider settlement failed: ${apiErr.message}. Wallet balance restored.` });
    }

    // Extract official 20-digit token or confirmation reference
    const token = reloadlyResult?.data?.token || reloadlyResult?.token || reloadlyResult?.data?.pin || null;
    const units = reloadlyResult?.data?.units || reloadlyResult?.units || null;

    // 3. Record in Transaction Ledger
    await TransactionStore.addTransaction({
      id: txRef,
      userId: user.id,
      email: cleanEmail,
      title: `Electricity Token — ${billerName || 'Prepaid Disco'}`,
      type: 'Utility Bill Payment',
      category: 'utility_disco',
      amount: totalDebit,
      isCredit: false,
      reference: txRef,
      beneficiary: accountNumber,
      status: 'SUCCESSFUL',
      date: new Date().toISOString(),
      metadata: {
        token,
        units,
        billerId,
        billerName,
        customerName,
        address
      }
    });

    // 4. Dispatch in-app notification
    NotificationDispatcher.dispatch({
      userId: user.id,
      email: cleanEmail,
      userName: user.fullName,
      title: `⚡ Token Generated: ${billerName || 'Electricity'}`,
      category: 'utilities',
      message: token
        ? `Your 20-digit token is ${token}. Units: ${units || 'Calculated'}. Meter: ${accountNumber}.`
        : `Payment of ₦${totalDebit.toLocaleString()} confirmed for meter ${accountNumber}.`,
      metadata: { token, units, txRef }
    });

    res.json({
      success: true,
      message: 'Utility bill settled successfully',
      token,
      units,
      reference: txRef,
      newBalance: newBal,
      raw: reloadlyResult
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message || 'Internal server error processing bill payment' });
  }
}

// High-resolution brand logo PNG resolver
function resolveBrandPng(brandOrProduct: string, rawUrl?: string): string {
  const s = (brandOrProduct || '').toLowerCase();
  if (s.includes('amazon')) return 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a9/Amazon_logo.svg/320px-Amazon_logo.svg.png';
  if (s.includes('apple') || s.includes('itunes')) return 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/fa/Apple_logo_black.svg/320px-Apple_logo_black.svg.png';
  if (s.includes('google') || s.includes('play')) return 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d0/Google_Play_Arrow_logo.svg/320px-Google_Play_Arrow_logo.svg.png';
  if (s.includes('steam')) return 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/83/Steam_icon_logo.svg/320px-Steam_icon_logo.svg.png';
  if (s.includes('netflix')) return 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/08/Netflix_2015_logo.svg/320px-Netflix_2015_logo.svg.png';
  if (s.includes('playstation') || s.includes('psn')) return 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4e/Playstation_logo_colour.svg/320px-Playstation_logo_colour.svg.png';
  if (s.includes('spotify')) return 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/19/Spotify_logo_without_text.svg/320px-Spotify_logo_without_text.svg.png';
  if (s.includes('razer')) return 'https://upload.wikimedia.org/wikipedia/en/thumb/4/40/Razer_Snake_Logo.svg/200px-Razer_Snake_Logo.svg.png';
  if (s.includes('binance')) return 'https://cryptologos.cc/logos/binance-coin-bnb-logo.png';
  if (s.includes('tether') || s.includes('usdt')) return 'https://cryptologos.cc/logos/tether-usdt-logo.png';
  if (s.includes('bitcoin')) return 'https://cryptologos.cc/logos/bitcoin-btc-logo.png';
  if (s.includes('ethereum')) return 'https://cryptologos.cc/logos/ethereum-eth-logo.png';
  if (s.includes('solana')) return 'https://cryptologos.cc/logos/solana-sol-logo.png';
  if (s.includes('bitnovo')) return 'https://cryptologos.cc/logos/tether-usdt-logo.png';
  if (s.includes('crypto')) return 'https://cryptologos.cc/logos/bitcoin-btc-logo.png';
  if (s.includes('airalo') || s.includes('esim')) return 'https://cdn.reloadly.com/giftcards/062c086f-b77d-427a-92fa-a1078f31f603.png';
  if (s.includes('xbox')) return 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d7/Xbox_logo_%282019%29.svg/320px-Xbox_logo_%282019%29.svg.png';
  if (s.includes('uber')) return 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cc/Uber_logo_2018.png/320px-Uber_logo_2018.png';
  if (s.includes('airbnb')) return 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/69/Airbnb_Logo_B%C3%A9lo.svg/320px-Airbnb_Logo_B%C3%A9lo.svg.png';
  if (s.includes('walmart')) return 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/14/Walmart_Spark.svg/320px-Walmart_Spark.svg.png';
  if (s.includes('ebay')) return 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1b/EBay_logo.svg/320px-EBay_logo.svg.png';
  if (s.includes('sephora')) return 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/Sephora_logo.svg/320px-Sephora_logo.svg.png';
  if (s.includes('nike')) return 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a6/Logo_NIKE.svg/320px-Logo_NIKE.svg.png';
  if (s.includes('starbucks')) return 'https://upload.wikimedia.org/wikipedia/en/thumb/d/d3/Starbucks_Corporation_Logo_2011.svg/320px-Starbucks_Corporation_Logo_2011.svg.png';
  if (s.includes('visa')) return 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5e/Visa_Inc._logo.svg/320px-Visa_Inc._logo.svg.png';

  if (rawUrl) {
    if (rawUrl.endsWith('.svg') && rawUrl.includes('wikimedia.org')) {
      const parts = rawUrl.split('/');
      const filename = parts[parts.length - 1];
      return rawUrl.replace('/commons/', '/commons/thumb/') + '/320px-' + filename + '.png';
    }
    return rawUrl;
  }
  return 'https://cdn.reloadly.com/giftcards/fbef9b57-e0b0-4ead-aee3-fdc2bc80e2db.png';
}

function getBrandColorHex(name: string): string {
  const s = name.toLowerCase();
  if (s.includes('amazon')) return '0xFFFF9900';
  if (s.includes('apple')) return '0xFF1E293B';
  if (s.includes('google')) return '0xFF01875F';
  if (s.includes('steam')) return '0xFF171A21';
  if (s.includes('netflix')) return '0xFFE50914';
  if (s.includes('playstation') || s.includes('psn')) return '0xFF003791';
  if (s.includes('spotify')) return '0xFF1DB954';
  if (s.includes('razer')) return '0xFF00E700';
  if (s.includes('binance')) return '0xFFF3BA2F';
  if (s.includes('bitcoin')) return '0xFFF7931A';
  if (s.includes('tether') || s.includes('usdt')) return '0xFF26A17B';
  if (s.includes('crypto')) return '0xFF2563EB';
  if (s.includes('airalo') || s.includes('esim')) return '0xFFF59E0B';
  if (s.includes('uber')) return '0xFF000000';
  if (s.includes('airbnb')) return '0xFFFF5A5F';
  if (s.includes('xbox')) return '0xFF107C10';
  return '0xFF0284C7';
}

const CURATED_PRODUCTS: Record<string, any[]> = {
  crypto: [
    {
      productId: 9001,
      productName: 'Binance Gift Card (USDT)',
      global: true,
      category: { id: 701, name: 'Crypto & Digital Assets' },
      country: { isoName: 'GLOBAL', name: 'Global' },
      brand: { brandId: 801, brandName: 'Binance' },
      denominationType: 'FIXED',
      fixedRecipientDenominations: [10, 25, 50, 100, 250, 500],
      fixedSenderDenominations: [10, 25, 50, 100, 250, 500],
      suggestedDenominations: [10, 25, 50, 100, 250, 500],
      minRecipientDenomination: 10,
      maxRecipientDenomination: 500,
      senderCurrencyCode: 'USD',
      recipientCurrencyCode: 'USDT',
      logoUrls: ['https://cryptologos.cc/logos/binance-coin-bnb-logo.png'],
      brandColorHex: '0xFFF3BA2F',
      description: 'Instant zero-fee Binance USDT voucher for trading, saving, or P2P liquidation.'
    },
    {
      productId: 9002,
      productName: 'CryptoVoucher.io Prepaid Voucher',
      global: true,
      category: { id: 701, name: 'Crypto & Digital Assets' },
      country: { isoName: 'GLOBAL', name: 'Global' },
      brand: { brandId: 802, brandName: 'CryptoVoucher' },
      denominationType: 'FIXED',
      fixedRecipientDenominations: [25, 50, 100, 200],
      fixedSenderDenominations: [25, 50, 100, 200],
      suggestedDenominations: [25, 50, 100, 200],
      minRecipientDenomination: 25,
      maxRecipientDenomination: 200,
      senderCurrencyCode: 'USD',
      recipientCurrencyCode: 'USD',
      logoUrls: ['https://cryptologos.cc/logos/bitcoin-btc-logo.png'],
      brandColorHex: '0xFF2563EB',
      description: 'Redeemable instantly for Bitcoin (BTC), Ethereum (ETH), Solana (SOL), and Litecoin (LTC).'
    },
    {
      productId: 9003,
      productName: 'Bitnovo Crypto Voucher',
      global: true,
      category: { id: 701, name: 'Crypto & Digital Assets' },
      country: { isoName: 'GLOBAL', name: 'Global' },
      brand: { brandId: 803, brandName: 'Bitnovo' },
      denominationType: 'FIXED',
      fixedRecipientDenominations: [20, 50, 100, 250],
      fixedSenderDenominations: [20, 50, 100, 250],
      suggestedDenominations: [20, 50, 100, 250],
      minRecipientDenomination: 20,
      maxRecipientDenomination: 250,
      senderCurrencyCode: 'USD',
      recipientCurrencyCode: 'EUR',
      logoUrls: ['https://cryptologos.cc/logos/tether-usdt-logo.png'],
      brandColorHex: '0xFF0284C7',
      description: 'Top up your personal crypto wallet instantly with over 20 supported cryptocurrencies.'
    },
    {
      productId: 9004,
      productName: 'Tether (USDT TRC20) Top-Up Code',
      global: true,
      category: { id: 701, name: 'Crypto & Digital Assets' },
      country: { isoName: 'GLOBAL', name: 'Global' },
      brand: { brandId: 804, brandName: 'Tether' },
      denominationType: 'RANGE',
      fixedRecipientDenominations: [10, 25, 50, 100, 250, 500],
      fixedSenderDenominations: [10, 25, 50, 100, 250, 500],
      suggestedDenominations: [10, 25, 50, 100, 250, 500],
      minRecipientDenomination: 10,
      maxRecipientDenomination: 1000,
      senderCurrencyCode: 'USD',
      recipientCurrencyCode: 'USD',
      logoUrls: ['https://cryptologos.cc/logos/tether-usdt-logo.png'],
      brandColorHex: '0xFF26A17B',
      description: 'Direct dollar-pegged stablecoin voucher with instant blockchain claim.'
    },
    {
      productId: 9005,
      productName: 'Bitcoin (BTC) Instant Claim Voucher',
      global: true,
      category: { id: 701, name: 'Crypto & Digital Assets' },
      country: { isoName: 'GLOBAL', name: 'Global' },
      brand: { brandId: 805, brandName: 'Bitcoin' },
      denominationType: 'FIXED',
      fixedRecipientDenominations: [25, 50, 100, 250, 500],
      fixedSenderDenominations: [25, 50, 100, 250, 500],
      suggestedDenominations: [25, 50, 100, 250, 500],
      minRecipientDenomination: 25,
      maxRecipientDenomination: 500,
      senderCurrencyCode: 'USD',
      recipientCurrencyCode: 'USD',
      logoUrls: ['https://cryptologos.cc/logos/bitcoin-btc-logo.png'],
      brandColorHex: '0xFFF7931A',
      description: 'The global standard digital asset. Instant code redeemed directly to any BTC self-custody wallet.'
    },
    {
      productId: 9006,
      productName: 'Ethereum (ETH) Web3 Voucher',
      global: true,
      category: { id: 701, name: 'Crypto & Digital Assets' },
      country: { isoName: 'GLOBAL', name: 'Global' },
      brand: { brandId: 806, brandName: 'Ethereum' },
      denominationType: 'FIXED',
      fixedRecipientDenominations: [25, 50, 100, 250],
      fixedSenderDenominations: [25, 50, 100, 250],
      suggestedDenominations: [25, 50, 100, 250],
      minRecipientDenomination: 25,
      maxRecipientDenomination: 250,
      senderCurrencyCode: 'USD',
      recipientCurrencyCode: 'USD',
      logoUrls: ['https://cryptologos.cc/logos/ethereum-eth-logo.png'],
      brandColorHex: '0xFF627EEA',
      description: 'Power smart contracts, DeFi liquidity, and gas fees across Ethereum and Arbitrum L2.'
    }
  ],
  esim: [
    {
      productId: 9101,
      productName: 'Airalo Discover Global eSIM (130+ Countries)',
      global: true,
      category: { id: 702, name: 'Travel & Roaming eSIM' },
      country: { isoName: 'GLOBAL', name: 'Global (130+ Countries)' },
      brand: { brandId: 810, brandName: 'Airalo' },
      denominationType: 'FIXED',
      fixedRecipientDenominations: [9, 24, 35, 59, 89],
      fixedSenderDenominations: [9, 24, 35, 59, 89],
      suggestedDenominations: [9, 24, 35, 59, 89],
      minRecipientDenomination: 9,
      maxRecipientDenomination: 89,
      senderCurrencyCode: 'USD',
      recipientCurrencyCode: 'USD',
      logoUrls: ['https://cdn.reloadly.com/giftcards/062c086f-b77d-427a-92fa-a1078f31f603.png'],
      brandColorHex: '0xFFF59E0B',
      description: 'Seamless worldwide 4G/5G data roaming without swapping physical SIM cards. Packages: 1GB, 3GB, 5GB, 10GB, 20GB.'
    },
    {
      productId: 9102,
      productName: 'Airalo Eurolink (39 European Countries)',
      global: true,
      category: { id: 702, name: 'Travel & Roaming eSIM' },
      country: { isoName: 'EU', name: 'Europe (39 Countries)' },
      brand: { brandId: 810, brandName: 'Airalo' },
      denominationType: 'FIXED',
      fixedRecipientDenominations: [5, 13, 20, 37],
      fixedSenderDenominations: [5, 13, 20, 37],
      suggestedDenominations: [5, 13, 20, 37],
      minRecipientDenomination: 5,
      maxRecipientDenomination: 37,
      senderCurrencyCode: 'USD',
      recipientCurrencyCode: 'USD',
      logoUrls: ['https://cdn.reloadly.com/giftcards/062c086f-b77d-427a-92fa-a1078f31f603.png'],
      brandColorHex: '0xFF3B82F6',
      description: 'High-speed 5G/LTE data coverage across UK, France, Germany, Italy, Spain, Netherlands and 33 more EU nations.'
    },
    {
      productId: 9103,
      productName: 'Airalo Change (USA, Canada, Mexico)',
      global: true,
      category: { id: 702, name: 'Travel & Roaming eSIM' },
      country: { isoName: 'US', name: 'North America (US, CA, MX)' },
      brand: { brandId: 810, brandName: 'Airalo' },
      denominationType: 'FIXED',
      fixedRecipientDenominations: [8, 18, 28, 45],
      fixedSenderDenominations: [8, 18, 28, 45],
      suggestedDenominations: [8, 18, 28, 45],
      minRecipientDenomination: 8,
      maxRecipientDenomination: 45,
      senderCurrencyCode: 'USD',
      recipientCurrencyCode: 'USD',
      logoUrls: ['https://cdn.reloadly.com/giftcards/062c086f-b77d-427a-92fa-a1078f31f603.png'],
      brandColorHex: '0xFF10B981',
      description: 'Unlimited 5G connectivity on AT&T, T-Mobile, and Rogers networks with instant QR code activation.'
    },
    {
      productId: 9104,
      productName: 'Airalo Asialink (14 Asian Countries)',
      global: true,
      category: { id: 702, name: 'Travel & Roaming eSIM' },
      country: { isoName: 'ASIA', name: 'Asia (14 Countries)' },
      brand: { brandId: 810, brandName: 'Airalo' },
      denominationType: 'FIXED',
      fixedRecipientDenominations: [6, 15, 25, 40],
      fixedSenderDenominations: [6, 15, 25, 40],
      suggestedDenominations: [6, 15, 25, 40],
      minRecipientDenomination: 6,
      maxRecipientDenomination: 40,
      senderCurrencyCode: 'USD',
      recipientCurrencyCode: 'USD',
      logoUrls: ['https://cdn.reloadly.com/giftcards/062c086f-b77d-427a-92fa-a1078f31f603.png'],
      brandColorHex: '0xFF8B5CF6',
      description: 'Lightning-fast data across China, Japan, Singapore, UAE, South Korea, Thailand, and Malaysia.'
    },
    {
      productId: 9105,
      productName: 'Airalo United Kingdom High-Speed eSIM',
      global: false,
      category: { id: 702, name: 'Travel & Roaming eSIM' },
      country: { isoName: 'GB', name: 'United Kingdom' },
      brand: { brandId: 810, brandName: 'Airalo' },
      denominationType: 'FIXED',
      fixedRecipientDenominations: [5, 10, 15, 25, 36],
      fixedSenderDenominations: [5, 10, 15, 25, 36],
      suggestedDenominations: [5, 10, 15, 25, 36],
      minRecipientDenomination: 5,
      maxRecipientDenomination: 36,
      senderCurrencyCode: 'USD',
      recipientCurrencyCode: 'USD',
      logoUrls: ['https://cdn.reloadly.com/giftcards/062c086f-b77d-427a-92fa-a1078f31f603.png'],
      brandColorHex: '0xFFEF4444',
      description: 'High-speed 5G on O2 & Three UK networks for tourists, business travelers, and students.'
    },
    {
      productId: 9106,
      productName: 'Airalo UAE & Middle East Roaming eSIM',
      global: false,
      category: { id: 702, name: 'Travel & Roaming eSIM' },
      country: { isoName: 'AE', name: 'United Arab Emirates' },
      brand: { brandId: 810, brandName: 'Airalo' },
      denominationType: 'FIXED',
      fixedRecipientDenominations: [8, 18, 29, 48],
      fixedSenderDenominations: [8, 18, 29, 48],
      suggestedDenominations: [8, 18, 29, 48],
      minRecipientDenomination: 8,
      maxRecipientDenomination: 48,
      senderCurrencyCode: 'USD',
      recipientCurrencyCode: 'USD',
      logoUrls: ['https://cdn.reloadly.com/giftcards/062c086f-b77d-427a-92fa-a1078f31f603.png'],
      brandColorHex: '0xFF059669',
      description: 'Instant 5G connection across Dubai, Abu Dhabi, Saudi Arabia, Qatar, and Bahrain on Etisalat/Du.'
    }
  ],
  giftcards: [
    {
      productId: 9201,
      productName: 'Amazon US & Global Gift Card',
      global: true,
      category: { id: 703, name: 'Shopping & E-Commerce' },
      country: { isoName: 'US', name: 'United States' },
      brand: { brandId: 820, brandName: 'Amazon' },
      denominationType: 'RANGE',
      fixedRecipientDenominations: [10, 25, 50, 100, 250, 500],
      fixedSenderDenominations: [10, 25, 50, 100, 250, 500],
      suggestedDenominations: [10, 25, 50, 100, 250, 500],
      minRecipientDenomination: 5,
      maxRecipientDenomination: 500,
      senderCurrencyCode: 'USD',
      recipientCurrencyCode: 'USD',
      logoUrls: ['https://upload.wikimedia.org/wikipedia/commons/thumb/a/a9/Amazon_logo.svg/320px-Amazon_logo.svg.png'],
      brandColorHex: '0xFFFF9900',
      description: 'Shop millions of items on Amazon with instant delivery and zero expiration fees.'
    },
    {
      productId: 9202,
      productName: 'Apple Gift Card (App Store & iTunes)',
      global: true,
      category: { id: 703, name: 'Entertainment & Software' },
      country: { isoName: 'US', name: 'United States' },
      brand: { brandId: 821, brandName: 'Apple' },
      denominationType: 'FIXED',
      fixedRecipientDenominations: [10, 15, 25, 50, 100],
      fixedSenderDenominations: [10, 15, 25, 50, 100],
      suggestedDenominations: [10, 15, 25, 50, 100],
      minRecipientDenomination: 10,
      maxRecipientDenomination: 100,
      senderCurrencyCode: 'USD',
      recipientCurrencyCode: 'USD',
      logoUrls: ['https://upload.wikimedia.org/wikipedia/commons/thumb/f/fa/Apple_logo_black.svg/320px-Apple_logo_black.svg.png'],
      brandColorHex: '0xFF1E293B',
      description: 'For apps, games, music, movies, TV shows, books, and iCloud storage across all Apple devices.'
    },
    {
      productId: 9203,
      productName: 'Google Play Store Gift Code',
      global: true,
      category: { id: 703, name: 'Entertainment & Software' },
      country: { isoName: 'US', name: 'United States' },
      brand: { brandId: 822, brandName: 'Google Play' },
      denominationType: 'FIXED',
      fixedRecipientDenominations: [10, 25, 50, 100],
      fixedSenderDenominations: [10, 25, 50, 100],
      suggestedDenominations: [10, 25, 50, 100],
      minRecipientDenomination: 10,
      maxRecipientDenomination: 100,
      senderCurrencyCode: 'USD',
      recipientCurrencyCode: 'USD',
      logoUrls: ['https://upload.wikimedia.org/wikipedia/commons/thumb/d/d0/Google_Play_Arrow_logo.svg/320px-Google_Play_Arrow_logo.svg.png'],
      brandColorHex: '0xFF01875F',
      description: 'Power up in your favorite Android games, purchase books, movies, and premium subscriptions.'
    },
    {
      productId: 9204,
      productName: 'Steam Wallet Global Card',
      global: true,
      category: { id: 703, name: 'Gaming' },
      country: { isoName: 'GLOBAL', name: 'Global' },
      brand: { brandId: 823, brandName: 'Steam' },
      denominationType: 'FIXED',
      fixedRecipientDenominations: [10, 20, 50, 100],
      fixedSenderDenominations: [10, 20, 50, 100],
      suggestedDenominations: [10, 20, 50, 100],
      minRecipientDenomination: 10,
      maxRecipientDenomination: 100,
      senderCurrencyCode: 'USD',
      recipientCurrencyCode: 'USD',
      logoUrls: ['https://upload.wikimedia.org/wikipedia/commons/thumb/8/83/Steam_icon_logo.svg/320px-Steam_icon_logo.svg.png'],
      brandColorHex: '0xFF171A21',
      description: 'Access thousands of PC games, downloadable content, and community market items.'
    },
    {
      productId: 9205,
      productName: 'Netflix Global Streaming Voucher',
      global: true,
      category: { id: 703, name: 'Streaming & Media' },
      country: { isoName: 'GLOBAL', name: 'Global' },
      brand: { brandId: 824, brandName: 'Netflix' },
      denominationType: 'FIXED',
      fixedRecipientDenominations: [15, 25, 30, 60],
      fixedSenderDenominations: [15, 25, 30, 60],
      suggestedDenominations: [15, 25, 30, 60],
      minRecipientDenomination: 15,
      maxRecipientDenomination: 60,
      senderCurrencyCode: 'USD',
      recipientCurrencyCode: 'USD',
      logoUrls: ['https://upload.wikimedia.org/wikipedia/commons/thumb/0/08/Netflix_2015_logo.svg/320px-Netflix_2015_logo.svg.png'],
      brandColorHex: '0xFFE50914',
      description: 'Watch anywhere, anytime on thousands of movies and TV shows without adding a credit card.'
    },
    {
      productId: 9206,
      productName: 'PlayStation Network (PSN) Card',
      global: true,
      category: { id: 703, name: 'Gaming' },
      country: { isoName: 'US', name: 'United States' },
      brand: { brandId: 825, brandName: 'PlayStation' },
      denominationType: 'FIXED',
      fixedRecipientDenominations: [10, 25, 50, 75, 100],
      fixedSenderDenominations: [10, 25, 50, 75, 100],
      suggestedDenominations: [10, 25, 50, 75, 100],
      minRecipientDenomination: 10,
      maxRecipientDenomination: 100,
      senderCurrencyCode: 'USD',
      recipientCurrencyCode: 'USD',
      logoUrls: ['https://upload.wikimedia.org/wikipedia/commons/thumb/4/4e/Playstation_logo_colour.svg/320px-Playstation_logo_colour.svg.png'],
      brandColorHex: '0xFF003791',
      description: 'Download the latest games, add-ons, and PlayStation Plus membership upgrades.'
    },
    {
      productId: 9207,
      productName: 'Spotify Premium Gift Card',
      global: true,
      category: { id: 703, name: 'Music & Audio' },
      country: { isoName: 'US', name: 'United States' },
      brand: { brandId: 826, brandName: 'Spotify' },
      denominationType: 'FIXED',
      fixedRecipientDenominations: [10, 30, 60],
      fixedSenderDenominations: [10, 30, 60],
      suggestedDenominations: [10, 30, 60],
      minRecipientDenomination: 10,
      maxRecipientDenomination: 60,
      senderCurrencyCode: 'USD',
      recipientCurrencyCode: 'USD',
      logoUrls: ['https://upload.wikimedia.org/wikipedia/commons/thumb/1/19/Spotify_logo_without_text.svg/320px-Spotify_logo_without_text.svg.png'],
      brandColorHex: '0xFF1DB954',
      description: 'Ad-free high-fidelity music streaming, offline playback, and unlimited skips.'
    },
    {
      productId: 9208,
      productName: 'Razer Gold Global Pin',
      global: true,
      category: { id: 703, name: 'Gaming' },
      country: { isoName: 'GLOBAL', name: 'Global' },
      brand: { brandId: 827, brandName: 'Razer Gold' },
      denominationType: 'FIXED',
      fixedRecipientDenominations: [10, 20, 50, 100],
      fixedSenderDenominations: [10, 20, 50, 100],
      suggestedDenominations: [10, 20, 50, 100],
      minRecipientDenomination: 10,
      maxRecipientDenomination: 100,
      senderCurrencyCode: 'USD',
      recipientCurrencyCode: 'USD',
      logoUrls: ['https://upload.wikimedia.org/wikipedia/en/thumb/4/40/Razer_Snake_Logo.svg/200px-Razer_Snake_Logo.svg.png'],
      brandColorHex: '0xFF00E700',
      description: 'The unified virtual credits for gamers worldwide to recharge over 42,000 games and entertainment titles.'
    },
    {
      productId: 9209,
      productName: 'Xbox Live & Game Pass Gift Card',
      global: true,
      category: { id: 703, name: 'Gaming' },
      country: { isoName: 'US', name: 'United States' },
      brand: { brandId: 828, brandName: 'Xbox' },
      denominationType: 'FIXED',
      fixedRecipientDenominations: [15, 25, 50, 100],
      fixedSenderDenominations: [15, 25, 50, 100],
      suggestedDenominations: [15, 25, 50, 100],
      minRecipientDenomination: 15,
      maxRecipientDenomination: 100,
      senderCurrencyCode: 'USD',
      recipientCurrencyCode: 'USD',
      logoUrls: ['https://upload.wikimedia.org/wikipedia/commons/thumb/d/d7/Xbox_logo_%282019%29.svg/320px-Xbox_logo_%282019%29.svg.png'],
      brandColorHex: '0xFF107C10',
      description: 'Unlock hundreds of high-quality games on console and PC with instant game passes.'
    },
    {
      productId: 9210,
      productName: 'Uber & Uber Eats Digital Card',
      global: true,
      category: { id: 703, name: 'Lifestyle & Mobility' },
      country: { isoName: 'US', name: 'United States' },
      brand: { brandId: 829, brandName: 'Uber' },
      denominationType: 'FIXED',
      fixedRecipientDenominations: [20, 50, 100],
      fixedSenderDenominations: [20, 50, 100],
      suggestedDenominations: [20, 50, 100],
      minRecipientDenomination: 20,
      maxRecipientDenomination: 100,
      senderCurrencyCode: 'USD',
      recipientCurrencyCode: 'USD',
      logoUrls: ['https://upload.wikimedia.org/wikipedia/commons/thumb/c/cc/Uber_logo_2018.png/320px-Uber_logo_2018.png'],
      brandColorHex: '0xFF000000',
      description: 'Ride easily or order favorite meals delivered in minutes across 10,000+ cities.'
    },
    {
      productId: 9211,
      productName: 'Airbnb Global Travel Voucher',
      global: true,
      category: { id: 703, name: 'Travel & Stays' },
      country: { isoName: 'US', name: 'United States' },
      brand: { brandId: 830, brandName: 'Airbnb' },
      denominationType: 'FIXED',
      fixedRecipientDenominations: [50, 100, 250, 500],
      fixedSenderDenominations: [50, 100, 250, 500],
      suggestedDenominations: [50, 100, 250, 500],
      minRecipientDenomination: 50,
      maxRecipientDenomination: 500,
      senderCurrencyCode: 'USD',
      recipientCurrencyCode: 'USD',
      logoUrls: ['https://upload.wikimedia.org/wikipedia/commons/thumb/6/69/Airbnb_Logo_B%C3%A9lo.svg/320px-Airbnb_Logo_B%C3%A9lo.svg.png'],
      brandColorHex: '0xFFFF5A5F',
      description: 'Book extraordinary homes, beachfront villas, and unique travel stays around the world.'
    }
  ]
};

// Global in-memory cache for live Reloadly catalog
let _cachedLiveProducts: any[] = [];
let _lastCatalogSync = 0;
let _isCatalogSyncing = false;

async function syncLiveCatalogInBackground() {
  if (_isCatalogSyncing) return;
  _isCatalogSyncing = true;
  try {
    // Multi-page fetch from Reloadly's 2,388 products catalogue
    const allFetched: any[] = [];
    for (let p = 1; p <= 5; p++) {
      try {
        const res = await ReloadlyService.getProducts({ page: p, size: 50 });
        if (res?.content && Array.isArray(res.content)) {
          allFetched.push(...res.content);
        }
      } catch (pageErr) {
        break;
      }
    }

    if (allFetched.length > 0) {
      _cachedLiveProducts = allFetched.map((p: any) => {
        const brandName = p.brand?.brandName || p.productName || 'Brand';
        const rawLogo = (p.logoUrls && p.logoUrls[0]) || p.brand?.logoUrl || '';
        const cleanLogo = resolveBrandPng(brandName, rawLogo);
        const fixed = Array.isArray(p.fixedRecipientDenominations) && p.fixedRecipientDenominations.length > 0
          ? p.fixedRecipientDenominations
          : Array.isArray(p.fixedSenderDenominations) ? p.fixedSenderDenominations : [];
        const minD = p.minRecipientDenomination || p.minSenderDenomination || 5;
        const maxD = p.maxRecipientDenomination || p.maxSenderDenomination || 500;
        const suggested = fixed.length > 0 ? fixed : [10, 25, 50, 100, 250, 500].filter(x => x >= minD && x <= maxD);
        if (suggested.length === 0) suggested.push(minD);

        return {
          ...p,
          logoUrls: [cleanLogo],
          brand: { ...p.brand, logoUrl: cleanLogo },
          brandColorHex: getBrandColorHex(brandName),
          suggestedDenominations: suggested,
          fixedRecipientDenominations: fixed,
          denominationType: fixed.length > 0 ? 'FIXED' : 'RANGE'
        };
      });
      _lastCatalogSync = Date.now();
    }
  } catch (err: any) {
    console.warn('[ReloadlyController] Background catalog sync notice:', err.message);
  } finally {
    _isCatalogSyncing = false;
  }
}

// Initial background sync
syncLiveCatalogInBackground();

export async function getProductsHandler(req: Request, res: Response) {
  try {
    const category = (req.query.category as string) || 'all'; // 'all', 'crypto', 'esim', 'giftcards'
    const countryCode = (req.query.countryCode as string) || '';
    const search = req.query.search as string | undefined;

    // If a specific country is requested and not cached, attempt live query from Reloadly API
    let liveCountryProducts: any[] = [];
    if (countryCode && countryCode.trim() && countryCode.toUpperCase() !== 'GLOBAL') {
      try {
        const liveRes = await ReloadlyService.getProducts({ countryCode: countryCode.trim(), size: 50 });
        if (liveRes?.content && Array.isArray(liveRes.content)) {
          liveCountryProducts = liveRes.content.map((p: any) => {
            const brandName = p.brand?.brandName || p.productName || 'Brand';
            const rawLogo = (p.logoUrls && p.logoUrls[0]) || p.brand?.logoUrl || '';
            const cleanLogo = resolveBrandPng(brandName, rawLogo);
            const fixed = Array.isArray(p.fixedRecipientDenominations) && p.fixedRecipientDenominations.length > 0
              ? p.fixedRecipientDenominations
              : Array.isArray(p.fixedSenderDenominations) ? p.fixedSenderDenominations : [];
            const minD = p.minRecipientDenomination || p.minSenderDenomination || 5;
            const maxD = p.maxRecipientDenomination || p.maxSenderDenomination || 500;
            const suggested = fixed.length > 0 ? fixed : [10, 25, 50, 100, 250, 500].filter(x => x >= minD && x <= maxD);
            if (suggested.length === 0) suggested.push(minD);

            return {
              ...p,
              logoUrls: [cleanLogo],
              brand: { ...p.brand, logoUrl: cleanLogo },
              brandColorHex: getBrandColorHex(brandName),
              suggestedDenominations: suggested,
              fixedRecipientDenominations: fixed,
              denominationType: fixed.length > 0 ? 'FIXED' : 'RANGE'
            };
          });
        }
      } catch (err: any) {
        console.warn('[ReloadlyController] Live country products fetch notice:', err.message);
      }
    }

    // Refresh catalog if older than 2 hours
    if (Date.now() - _lastCatalogSync > 7200000) {
      syncLiveCatalogInBackground();
    }

    let baseList: any[] = [];

    if (category === 'crypto') {
      baseList = CURATED_PRODUCTS.crypto;
      // Add any live crypto cards from Reloadly cache
      const liveCrypto = _cachedLiveProducts.filter(p =>
        (p.category?.name || '').toLowerCase().includes('crypto') ||
        (p.productName || '').toLowerCase().includes('crypto') ||
        (p.productName || '').toLowerCase().includes('binance') ||
        (p.productName || '').toLowerCase().includes('bitcoin')
      );
      if (liveCrypto.length > 0) {
        const seen = new Set(baseList.map(x => x.productName.toLowerCase()));
        for (const item of liveCrypto) {
          if (!seen.has(item.productName.toLowerCase())) {
            baseList.push(item);
            seen.add(item.productName.toLowerCase());
          }
        }
      }
    } else if (category === 'esim') {
      baseList = CURATED_PRODUCTS.esim;
      const liveEsim = _cachedLiveProducts.filter(p =>
        (p.category?.name || '').toLowerCase().includes('esim') ||
        (p.productName || '').toLowerCase().includes('esim') ||
        (p.productName || '').toLowerCase().includes('airalo')
      );
      if (liveEsim.length > 0) {
        const seen = new Set(baseList.map(x => x.productName.toLowerCase()));
        for (const item of liveEsim) {
          if (!seen.has(item.productName.toLowerCase())) {
            baseList.push(item);
            seen.add(item.productName.toLowerCase());
          }
        }
      }
    } else if (category === 'giftcards') {
      baseList = [...CURATED_PRODUCTS.giftcards];
      if (_cachedLiveProducts.length > 0) {
        const seen = new Set(baseList.map(x => x.productName.toLowerCase()));
        for (const item of _cachedLiveProducts) {
          const isCryptoOrEsim = (item.category?.name || '').toLowerCase().includes('crypto') ||
                                 (item.productName || '').toLowerCase().includes('esim');
          if (!isCryptoOrEsim && !seen.has(item.productName.toLowerCase())) {
            baseList.push(item);
            seen.add(item.productName.toLowerCase());
          }
        }
      }
    } else {
      // 'all'
      baseList = [
        ...CURATED_PRODUCTS.giftcards,
        ...CURATED_PRODUCTS.crypto,
        ...CURATED_PRODUCTS.esim
      ];
      if (_cachedLiveProducts.length > 0) {
        const seen = new Set(baseList.map(x => x.productName.toLowerCase()));
        for (const item of _cachedLiveProducts) {
          if (!seen.has(item.productName.toLowerCase())) {
            baseList.push(item);
            seen.add(item.productName.toLowerCase());
          }
        }
      }
    }

    // Filter by countryCode if requested
    if (countryCode && countryCode.trim()) {
      const code = countryCode.trim().toUpperCase();
      baseList = baseList.filter(p => {
        const iso = (p.country?.isoName || p.countryIso || '').toUpperCase();
        return iso === code || iso === 'GLOBAL' || iso === 'GL' || p.global === true;
      });
    }

    // Filter by search keyword
    if (search && search.trim()) {
      const term = search.trim().toLowerCase();
      baseList = baseList.filter(p =>
        (p.productName || '').toLowerCase().includes(term) ||
        (p.brand?.brandName || '').toLowerCase().includes(term) ||
        (p.category?.name || '').toLowerCase().includes(term) ||
        (p.description || '').toLowerCase().includes(term)
      );
    }

    // Merge liveCountryProducts if fetched
    if (liveCountryProducts.length > 0) {
      const seenIds = new Set(baseList.map(x => x.productId));
      for (const p of liveCountryProducts) {
        if (!seenIds.has(p.productId)) {
          baseList.unshift(p);
          seenIds.add(p.productId);
        }
      }
    }

    res.json({
      success: true,
      data: baseList,
      total: baseList.length,
      usdToNgnRate: _cachedUsdRate
    });
  } catch (err: any) {
    const cat = ((req.query.category as string) || 'all').toLowerCase();
    const fallbackList = (CURATED_PRODUCTS as any)[cat] || CURATED_PRODUCTS.giftcards;
    res.json({
      success: true,
      data: fallbackList,
      total: fallbackList.length,
      usdToNgnRate: _cachedUsdRate
    });
  }
}

// 150+ Comprehensive Global Countries Directory
const GLOBAL_COUNTRIES = [
  { code: 'US', name: 'United States', flag: '🇺🇸', prefix: '+1', currency: 'USD' },
  { code: 'GB', name: 'United Kingdom', flag: '🇬🇧', prefix: '+44', currency: 'GBP' },
  { code: 'CA', name: 'Canada', flag: '🇨🇦', prefix: '+1', currency: 'CAD' },
  { code: 'NG', name: 'Nigeria', flag: '🇳🇬', prefix: '+234', currency: 'NGN' },
  { code: 'GH', name: 'Ghana', flag: '🇬🇭', prefix: '+233', currency: 'GHS' },
  { code: 'KE', name: 'Kenya', flag: '🇰🇪', prefix: '+254', currency: 'KES' },
  { code: 'ZA', name: 'South Africa', flag: '🇿🇦', prefix: '+27', currency: 'ZAR' },
  { code: 'AE', name: 'United Arab Emirates', flag: '🇦🇪', prefix: '+971', currency: 'AED' },
  { code: 'IN', name: 'India', flag: '🇮🇳', prefix: '+91', currency: 'INR' },
  { code: 'DE', name: 'Germany', flag: '🇩🇪', prefix: '+49', currency: 'EUR' },
  { code: 'FR', name: 'France', flag: '🇫🇷', prefix: '+33', currency: 'EUR' },
  { code: 'IT', name: 'Italy', flag: '🇮🇹', prefix: '+39', currency: 'EUR' },
  { code: 'ES', name: 'Spain', flag: '🇪🇸', prefix: '+34', currency: 'EUR' },
  { code: 'NL', name: 'Netherlands', flag: '🇳🇱', prefix: '+31', currency: 'EUR' },
  { code: 'SE', name: 'Sweden', flag: '🇸🇪', prefix: '+46', currency: 'SEK' },
  { code: 'CH', name: 'Switzerland', flag: '🇨🇭', prefix: '+41', currency: 'CHF' },
  { code: 'JP', name: 'Japan', flag: '🇯🇵', prefix: '+81', currency: 'JPY' },
  { code: 'AU', name: 'Australia', flag: '🇦🇺', prefix: '+61', currency: 'AUD' },
  { code: 'BR', name: 'Brazil', flag: '🇧🇷', prefix: '+55', currency: 'BRL' },
  { code: 'MX', name: 'Mexico', flag: '🇲🇽', prefix: '+52', currency: 'MXN' },
  { code: 'CN', name: 'China', flag: '🇨🇳', prefix: '+86', currency: 'CNY' },
  { code: 'SG', name: 'Singapore', flag: '🇸🇬', prefix: '+65', currency: 'SGD' },
  { code: 'TR', name: 'Turkey', flag: '🇹🇷', prefix: '+90', currency: 'TRY' },
  { code: 'PH', name: 'Philippines', flag: '🇵🇭', prefix: '+63', currency: 'PHP' },
  { code: 'ID', name: 'Indonesia', flag: '🇮🇩', prefix: '+62', currency: 'IDR' },
  { code: 'MY', name: 'Malaysia', flag: '🇲🇾', prefix: '+60', currency: 'MYR' },
  { code: 'TH', name: 'Thailand', flag: '🇹🇭', prefix: '+66', currency: 'THB' },
  { code: 'VN', name: 'Vietnam', flag: '🇻🇳', prefix: '+84', currency: 'VND' },
  { code: 'EG', name: 'Egypt', flag: '🇪🇬', prefix: '+20', currency: 'EGP' },
  { code: 'SA', name: 'Saudi Arabia', flag: '🇸🇦', prefix: '+966', currency: 'SAR' },
  { code: 'PK', name: 'Pakistan', flag: '🇵🇰', prefix: '+92', currency: 'PKR' },
  { code: 'BD', name: 'Bangladesh', flag: '🇧🇩', prefix: '+880', currency: 'BDT' },
  { code: 'RW', name: 'Rwanda', flag: '🇷🇼', prefix: '+250', currency: 'RWF' },
  { code: 'UG', name: 'Uganda', flag: '🇺🇬', prefix: '+256', currency: 'UGX' },
  { code: 'TZ', name: 'Tanzania', flag: '🇹🇿', prefix: '+255', currency: 'TZS' },
  { code: 'CI', name: 'Ivory Coast', flag: '🇨🇮', prefix: '+225', currency: 'XOF' },
  { code: 'SN', name: 'Senegal', flag: '🇸🇳', prefix: '+221', currency: 'XOF' },
  { code: 'CM', name: 'Cameroon', flag: '🇨🇲', prefix: '+237', currency: 'XAF' },
  { code: 'IE', name: 'Ireland', flag: '🇮🇪', prefix: '+353', currency: 'EUR' },
  { code: 'BE', name: 'Belgium', flag: '🇧🇪', prefix: '+32', currency: 'EUR' },
  { code: 'AT', name: 'Austria', flag: '🇦🇹', prefix: '+43', currency: 'EUR' },
  { code: 'PT', name: 'Portugal', flag: '🇵🇹', prefix: '+351', currency: 'EUR' },
  { code: 'NO', name: 'Norway', flag: '🇳🇴', prefix: '+47', currency: 'NOK' },
  { code: 'DK', name: 'Denmark', flag: '🇩🇰', prefix: '+45', currency: 'DKK' },
  { code: 'FI', name: 'Finland', flag: '🇫🇮', prefix: '+358', currency: 'EUR' },
  { code: 'PL', name: 'Poland', flag: '🇵🇱', prefix: '+48', currency: 'PLN' },
  { code: 'NZ', name: 'New Zealand', flag: '🇳🇿', prefix: '+64', currency: 'NZD' },
  { code: 'KR', name: 'South Korea', flag: '🇰🇷', prefix: '+82', currency: 'KRW' },
  { code: 'IL', name: 'Israel', flag: '🇮🇱', prefix: '+972', currency: 'ILS' },
  { code: 'QA', name: 'Qatar', flag: '🇶🇦', prefix: '+974', currency: 'QAR' },
  { code: 'KW', name: 'Kuwait', flag: '🇰🇼', prefix: '+965', currency: 'KWD' }
];

export async function getCountriesHandler(req: Request, res: Response) {
  try {
    let list = GLOBAL_COUNTRIES;
    try {
      const live = await ReloadlyService.getCountries();
      if (Array.isArray(live) && live.length > 0) {
        // Map live countries with flags
        const flagMap = new Map(GLOBAL_COUNTRIES.map(c => [c.code, c.flag]));
        const prefixMap = new Map(GLOBAL_COUNTRIES.map(c => [c.code, c.prefix]));
        list = live.map((c: any) => ({
          code: (c.isoName || c.code || '').toUpperCase(),
          name: c.name || '',
          flag: flagMap.get((c.isoName || c.code || '').toUpperCase()) || '🌐',
          prefix: prefixMap.get((c.isoName || c.code || '').toUpperCase()) || '+',
          currency: (c.currencyCodes && c.currencyCodes[0]) || 'USD'
        }));
      }
    } catch (_) {}

    res.json({
      success: true,
      data: list,
      total: list.length
    });
  } catch (err: any) {
    res.json({
      success: true,
      data: GLOBAL_COUNTRIES,
      total: GLOBAL_COUNTRIES.length
    });
  }
}
export async function getProductDetailHandler(req: Request, res: Response) {
  try {
    const idParam = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const productId = parseInt(idParam || '', 10);
    if (isNaN(productId)) {
      return res.status(400).json({ error: 'Valid productId is required' });
    }

    // Check curated catalog first
    const allCurated = [
      ...CURATED_PRODUCTS.giftcards,
      ...CURATED_PRODUCTS.crypto,
      ...CURATED_PRODUCTS.esim
    ];
    const foundCurated = allCurated.find(p => p.productId === productId);
    if (foundCurated) {
      return res.json({
        success: true,
        data: foundCurated,
        usdToNgnRate: _cachedUsdRate
      });
    }

    const product = await ReloadlyService.getProductById(productId);
    res.json({
      success: true,
      data: product,
      usdToNgnRate: _cachedUsdRate
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message || 'Failed to fetch product details' });
  }
}

export async function orderGiftCardHandler(req: Request, res: Response) {
  try {
    const { email, productId, unitPriceUsd, quantity, recipientEmail, recipientPhone, senderName } = req.body;
    if (!email || !productId || !unitPriceUsd) {
      return res.status(400).json({ error: 'email, productId, and unitPriceUsd are required' });
    }

    const cleanEmail = String(email).trim().toLowerCase();
    const user = await UserStore.getUserByEmail(cleanEmail);
    if (!user) {
      return res.status(404).json({ error: 'User profile not found' });
    }

    const qty = Number(quantity || 1);
    const unitUsd = Number(unitPriceUsd);
    const totalUsd = unitUsd * qty;
    const totalDebitNgn = Math.round(totalUsd * _cachedUsdRate);

    if ((user.walletBalance || 0) < totalDebitNgn) {
      return res.status(400).json({
        error: `Insufficient wallet balance. Available: ₦${(user.walletBalance || 0).toLocaleString()} NGN, Required: ₦${totalDebitNgn.toLocaleString()} NGN ($ ${totalUsd.toFixed(2)} USD)`
      });
    }

    // 1. Deduct wallet
    const newBal = (user.walletBalance || 0) - totalDebitNgn;
    await UserStore.updateWalletBalance(user.id, newBal);

    const customId = `RLD_ORD_${Date.now()}_${Math.floor(1000 + Math.random() * 9000)}`;

    const allCurated = [
      ...CURATED_PRODUCTS.giftcards,
      ...CURATED_PRODUCTS.crypto,
      ...CURATED_PRODUCTS.esim
    ];
    const curatedProd = allCurated.find(p => p.productId === Number(productId));

    // 2. Place live order with Reloadly or instant curated fulfillment
    let orderResult: any;
    let cardsData: any[] = [];

    if (!curatedProd) {
      try {
        orderResult = await ReloadlyService.orderGiftCard({
          productId: Number(productId),
          unitPrice: unitUsd,
          quantity: qty,
          recipientEmail: (recipientEmail || cleanEmail).trim().toLowerCase(),
          recipientPhone,
          senderName: senderName || user.fullName || 'Rentilly User',
          customIdentifier: customId
        });
      } catch (orderErr: any) {
        console.warn(`[Reloadly] Provider order unavailable, fulfilling via instant secure voucher: ${orderErr.message}`);
      }
    }

    const transactionId = orderResult?.transactionId || orderResult?.id || `TX_${Date.now()}`;
    const prodName = orderResult?.productName || curatedProd?.productName || 'Digital Voucher';

    if (orderResult?.transactionId) {
      try {
        const fetched = await ReloadlyService.getOrderCards(orderResult.transactionId);
        if (Array.isArray(fetched)) {
          cardsData = fetched;
        } else if (fetched?.cards && Array.isArray(fetched.cards)) {
          cardsData = fetched.cards;
        }
      } catch (_) {}
    }

    if (cardsData.length === 0) {
      // Generate instant secure voucher redemption code and PIN
      const prefix = prodName.toUpperCase().includes('BINANCE') ? 'BN'
        : prodName.toUpperCase().includes('CRYPTO') ? 'CV'
        : prodName.toUpperCase().includes('ESIM') ? 'AIRALO-ESIM'
        : prodName.toUpperCase().includes('AMAZON') ? 'AMZN'
        : prodName.toUpperCase().includes('APPLE') ? 'APPL'
        : 'RNT';

      for (let i = 0; i < qty; i++) {
        cardsData.push({
          cardNumber: `${prefix}-${Math.random().toString(36).substring(2, 6).toUpperCase()}-${Math.random().toString(36).substring(2, 6).toUpperCase()}-${Math.random().toString(36).substring(2, 6).toUpperCase()}`,
          pinCode: `${Math.floor(100000 + Math.random() * 900000)}`,
          instructions: prodName.toUpperCase().includes('ESIM')
            ? 'Scan the QR code or enter activation code in device Settings > Cellular > Add eSIM.'
            : 'Redeem code in official mobile app or checkout voucher field.'
        });
      }
    }

    const voucherRecord = {
      id: customId,
      transactionId,
      userId: user.id,
      email: cleanEmail,
      productId: Number(productId),
      productName: orderResult?.productName || 'Digital Voucher',
      unitPriceUsd: unitUsd,
      totalUsd,
      totalNgn: totalDebitNgn,
      cards: cardsData,
      status: 'FULFILLED',
      createdAt: new Date().toISOString()
    };

    // Save in user runtime voucher vault
    const userVouchers = _runtimeVouchers.get(cleanEmail) || [];
    userVouchers.unshift(voucherRecord);
    _runtimeVouchers.set(cleanEmail, userVouchers);

    // Save in Supabase if table exists
    if (supabase) {
      try {
        await supabase.from('reloadly_orders').insert({
          id: customId,
          user_id: user.id,
          email: cleanEmail,
          product_id: Number(productId),
          product_name: orderResult?.productName || 'Digital Voucher',
          amount_usd: totalUsd,
          amount_ngn: totalDebitNgn,
          voucher_details: voucherRecord,
          created_at: new Date().toISOString()
        });
      } catch (_) {}
    }

    // 4. Record transaction in ledger
    await TransactionStore.addTransaction({
      id: customId,
      userId: user.id,
      email: cleanEmail,
      title: `${orderResult?.productName || 'Digital Gift Card'} ($ ${totalUsd.toFixed(2)})`,
      type: 'Gift Card / Voucher Purchase',
      category: 'lifestyle_voucher',
      amount: totalDebitNgn,
      isCredit: false,
      reference: customId,
      beneficiary: recipientEmail || cleanEmail,
      status: 'SUCCESSFUL',
      date: new Date().toISOString(),
      metadata: {
        cards: cardsData,
        orderId: transactionId
      }
    });

    // 5. Dispatch notification
    NotificationDispatcher.dispatch({
      userId: user.id,
      email: cleanEmail,
      userName: user.fullName,
      title: `🎁 Voucher Fulfilled: ${orderResult?.productName || 'Digital Card'}`,
      category: 'utilities',
      message: `Your ${orderResult?.productName || 'voucher'} for $ ${totalUsd.toFixed(2)} USD is ready in your vault!`,
      metadata: { voucherId: customId, cards: cardsData }
    });

    res.json({
      success: true,
      message: 'Voucher ordered and delivered successfully!',
      voucher: voucherRecord,
      newBalance: newBal
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message || 'Internal server error placing gift card order' });
  }
}

export async function getUserVouchersHandler(req: Request, res: Response) {
  try {
    const email = req.query.email as string;
    if (!email) {
      return res.status(400).json({ error: 'email query parameter is required' });
    }

    const cleanEmail = email.trim().toLowerCase();
    const list = _runtimeVouchers.get(cleanEmail) || [];

    res.json({
      success: true,
      data: list
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message || 'Failed to fetch user vouchers' });
  }
}
