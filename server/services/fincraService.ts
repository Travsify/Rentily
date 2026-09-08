import crypto from 'crypto';
import dotenv from 'dotenv';

dotenv.config();

export interface FincraCheckoutCustomer {
  name: string;
  email: string;
  phoneNumber?: string;
}

export interface FincraBeneficiary {
  firstName: string;
  lastName: string;
  accountHolderName: string;
  accountNumber: string;
  bankCode: string;
  type?: 'individual' | 'corporate';
}

export class FincraService {
  private static get BASE_URL(): string {
    return process.env.FINCRA_BASE_URL || 'https://api.fincra.com';
  }
  private static get SECRET_KEY(): string {
    return process.env.FINCRA_SECRET_KEY || 'k7jRtbW31oSn9naZ4ZIQCrLcjqV0o2zv';
  }
  private static get PUBLIC_KEY(): string {
    return process.env.FINCRA_PUBLIC_KEY || 'pk_NjkzYzU1MzM5NTdjOTAwMDEyMDExN2E2OjoyMDgyODA=';
  }
  private static get WEBHOOK_KEY(): string {
    return process.env.FINCRA_WEBHOOK_KEY || '2543fbb973594ace82648bc611dd7e4f';
  }
  private static get BUSINESS_ID(): string {
    return process.env.FINCRA_BUSINESS_ID || '693c5533957c9000120117a6';
  }

  private static getHeaders() {
    return {
      'api-key': this.SECRET_KEY,
      'x-pub-key': this.PUBLIC_KEY,
      'x-business-id': this.BUSINESS_ID,
      'Content-Type': 'application/json'
    };
  }

  /**
   * Check if Fincra credentials are configured
   */
  static isConfigured(): boolean {
    return Boolean(this.SECRET_KEY && this.PUBLIC_KEY && this.BUSINESS_ID);
  }

  /**
   * Initialize a High-Value Fincra Hosted Checkout
   * Supports huge limits for institutional escrow inflows and high-value rent payments.
   */
  static async initializeCheckout(params: {
    reference: string;
    amount: number;
    currency?: string;
    customerEmail: string;
    customerName: string;
    customerPhone?: string;
    redirectUrl?: string;
    description?: string;
    paymentMethods?: string[];
  }): Promise<{
    status: boolean;
    data?: {
      checkoutUrl: string;
      reference: string;
      payCode?: string;
    };
    message?: string;
  }> {
    try {
      const payload = {
        amount: params.amount,
        currency: params.currency || 'NGN',
        redirectUrl: params.redirectUrl || 'https://myrentilly.com/wallet',
        feeBearer: 'business',
        reference: params.reference,
        customer: {
          name: params.customerName,
          email: params.customerEmail,
          phoneNumber: params.customerPhone || '08000000000'
        },
        paymentMethods: params.paymentMethods || ['bank_transfer', 'card']
      };

      const res = await fetch(`${this.BASE_URL}/checkout/payments`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify(payload)
      });

      const resJson: any = await res.json().catch(() => null);

      if (res.ok && resJson && (resJson.status === true || resJson.success === true)) {
        const d = resJson.data;
        return {
          status: true,
          data: {
            checkoutUrl: d.link || d.checkoutUrl,
            reference: d.reference || params.reference,
            payCode: d.payCode
          },
          message: 'Fincra checkout initiated successfully'
        };
      }

      const errMsg = resJson?.error || resJson?.message || 'Failed to initialize Fincra checkout';
      console.error('[FincraService] initializeCheckout error:', res.status, resJson);
      return {
        status: false,
        message: errMsg
      };
    } catch (err: any) {
      console.error('[FincraService] initializeCheckout exception:', err);
      return {
        status: false,
        message: err.message || 'Error connecting to Fincra API'
      };
    }
  }

  /**
   * Verify a Fincra Payment by Merchant Reference
   */
  static async verifyPayment(merchantReference: string): Promise<{
    status: boolean;
    data?: any;
    message?: string;
  }> {
    try {
      const res = await fetch(`${this.BASE_URL}/checkout/payments/merchant-reference/${encodeURIComponent(merchantReference)}`, {
        method: 'GET',
        headers: this.getHeaders()
      });

      const resJson: any = await res.json().catch(() => null);

      if (res.ok && resJson && (resJson.status === true || resJson.success === true)) {
        return {
          status: true,
          data: resJson.data
        };
      }

      return {
        status: false,
        message: resJson?.error || resJson?.message || 'Failed to verify Fincra transaction'
      };
    } catch (err: any) {
      return {
        status: false,
        message: err.message || 'Error connecting to Fincra verification endpoint'
      };
    }
  }

  private static _cachedBanks: any[] = [];
  private static _lastBanksFetch: number = 0;
  private static readonly BANKS_CACHE_TTL = 24 * 60 * 60 * 1000; // 24 hours

  /**
   * Map input bank code (Paystack, Maplerad, CBN, NIBSS, Flutterwave) to Fincra Native Bank Code
   */
  static mapToFincraBankCode(inputCode: string, bankName?: string): string {
    const clean = (inputCode || '').toString().trim();
    if (!clean) return clean;

    const FINCRA_BANK_MAPPING: Record<string, string> = {
      // 1975 -> Fewchore Finance Company Limited (NIBSS / Fincra code: 050002)
      '1975': '050002',
      '050002': '050002',

      // OPay (Paycom): Paystack 999992, Maplerad 710, NIBSS 100004 -> Fincra 305
      '999992': '305',
      '710': '305',
      '100004': '305',
      '305': '305',

      // PalmPay: Paystack 999991, Maplerad 311, NIBSS 100033 -> Fincra 100033
      '999991': '100033',
      '311': '100033',
      '100033': '100033',

      // Moniepoint MFB: Paystack 50515, Maplerad 868, NIBSS 090405 -> Fincra 50515
      '50515': '50515',
      '868': '50515',
      '090405': '50515',

      // Kuda Bank: Paystack 50211, Maplerad 137, NIBSS 090267 -> Fincra 50211
      '50211': '50211',
      '137': '50211',
      '090267': '50211',

      // VFD MFB: Paystack 566, Maplerad 1897, NIBSS 090110 -> Fincra 566
      '566': '566',
      '1897': '566',
      '090110': '566',

      // Carbon: Paystack 100026 / 565 -> Fincra 100026
      '100026': '100026',
      '565': '100026',

      // Fairmoney MFB: 090551 -> Fincra 090551
      '090551': '090551',
      '551': '090551',

      // TAJ Bank: Paystack 302, Maplerad 143, NIBSS 000026 -> Fincra 000026
      '302': '000026',
      '143': '000026',
      '000026': '000026',

      // Jaiz Bank: Paystack 301, Maplerad 132 -> Fincra 301
      '301': '301',
      '132': '301',

      // Providus Bank: Paystack 101, Maplerad 130 -> Fincra 101
      '101': '101',
      '130': '101',

      // GTBank: Paystack 058, Maplerad 120 -> Fincra 058
      '058': '058',
      '120': '058',
      '58': '058',

      // Access Bank: Paystack 044, Maplerad 114 -> Fincra 044
      '044': '044',
      '114': '044',
      '44': '044',

      // Zenith Bank: Paystack 057, Maplerad 107 -> Fincra 057
      '057': '057',
      '107': '057',
      '57': '057',

      // First Bank: Paystack 011, Maplerad 105 -> Fincra 011
      '011': '011',
      '105': '011',
      '11': '011',

      // UBA: Paystack 033, Maplerad 125 -> Fincra 033
      '033': '033',
      '125': '033',
      '33': '033',

      // Wema Bank: Paystack 035, Maplerad 127 -> Fincra 035
      '035': '035',
      '127': '035',
      '35': '035',

      // Fidelity Bank: Paystack 070, Maplerad 119 -> Fincra 070
      '070': '070',
      '119': '070',
      '70': '070',

      // FCMB: Paystack 214, Maplerad 118 -> Fincra 214
      '214': '214',
      '118': '214',

      // Sterling Bank: Paystack 232, Maplerad 124 -> Fincra 232
      '232': '232',
      '124': '232',

      // Stanbic IBTC: Paystack 221, Maplerad 122 -> Fincra 221
      '221': '221',
      '122': '221',

      // Union Bank: Paystack 032, Maplerad 126 -> Fincra 032
      '032': '032',
      '126': '032',
      '32': '032',

      // Ecobank: Paystack 050, Maplerad 116 -> Fincra 050
      '050': '050',
      '116': '050',
      '50': '050',

      // Polaris Bank: Paystack 076, Maplerad 121 -> Fincra 076
      '076': '076',
      '121': '076',
      '76': '076',

      // Keystone Bank: Paystack 082, Maplerad 128 -> Fincra 082
      '082': '082',
      '128': '082',
      '82': '082',

      // Titan Trust / Paystack-Titan: Paystack 102 / 110006 -> Fincra 102
      '102': '102',
      '110006': '102',
    };

    if (FINCRA_BANK_MAPPING[clean]) {
      return FINCRA_BANK_MAPPING[clean];
    }

    // Dynamic search across all 650 cached Fincra NIBSS banks
    if (this._cachedBanks && this._cachedBanks.length > 0) {
      const match = this._cachedBanks.find((b: any) =>
        b.code === clean ||
        b.nibssCode === clean ||
        b.id === clean ||
        (clean.length <= 3 && b.code === clean.padStart(3, '0')) ||
        (clean.length <= 6 && b.nibssCode === clean.padStart(6, '0'))
      );
      if (match && match.code) return match.code;
    }

    // Name-based fallback lookup if bankName was provided
    if (bankName && this._cachedBanks && this._cachedBanks.length > 0) {
      const nameClean = bankName.toLowerCase().replace(/bank|microfinance|mfb|plc|limited|ltd|\(.*?\)/g, '').trim();
      if (nameClean.length >= 3) {
        const nameMatch = this._cachedBanks.find((b: any) => {
          const bName = (b.name || '').toLowerCase();
          return bName.includes(nameClean) || nameClean.includes(bName);
        });
        if (nameMatch && nameMatch.code) return nameMatch.code;
      }
    }

    return clean;
  }

  /**
   * Fetch all 650+ Nigerian Banks directly from Fincra (Cached for 24 hours)
   */
  static async getBanks(country: string = 'NG', currency: string = 'NGN'): Promise<any[]> {
    const now = Date.now();
    if (this._cachedBanks.length > 0 && (now - this._lastBanksFetch) < this.BANKS_CACHE_TTL) {
      return this._cachedBanks;
    }

    try {
      const res = await fetch(`${this.BASE_URL}/core/banks?country=${country}&currency=${currency}`, {
        headers: this.getHeaders()
      });
      const json: any = await res.json().catch(() => null);
      if (json && (json.success || json.status) && Array.isArray(json.data) && json.data.length > 0) {
        this._cachedBanks = json.data;
        this._lastBanksFetch = now;
        console.log(`[FincraService] Hydrated ${this._cachedBanks.length} NIBSS banks from Fincra.`);
        return this._cachedBanks;
      }
    } catch (err: any) {
      console.error('[FincraService] getBanks error:', err.message);
    }

    return this._cachedBanks;
  }

  /**
   * Initiate High-Value Payout / Disbursement to Beneficiary Bank Account
   */
  static async initiatePayout(params: {
    amount: number;
    reference: string;
    description: string;
    beneficiary: FincraBeneficiary;
    currency?: string;
    sender?: {
      name: string;
      email?: string;
    };
  }): Promise<{
    status: boolean;
    data?: any;
    message?: string;
  }> {
    try {
      const fincraBankCode = this.mapToFincraBankCode(params.beneficiary.bankCode);
      const payload: any = {
        business: this.BUSINESS_ID,
        sourceCurrency: params.currency || 'NGN',
        destinationCurrency: params.currency || 'NGN',
        amount: params.amount,
        description: params.description || 'Rentilly Transfer',
        paymentDestination: 'bank_account',
        customerReference: params.reference,
        beneficiary: {
          firstName: params.beneficiary.firstName,
          lastName: params.beneficiary.lastName,
          accountHolderName: params.beneficiary.accountHolderName,
          accountNumber: params.beneficiary.accountNumber,
          bankCode: fincraBankCode,
          type: params.beneficiary.type || 'individual'
        }
      };

      if (params.sender && params.sender.name) {
        payload.sender = {
          name: params.sender.name.trim(),
          email: params.sender.email?.trim() || 'support@myrentilly.com'
        };
      }

      const res = await fetch(`${this.BASE_URL}/disbursements/payouts`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify(payload)
      });

      const resJson: any = await res.json().catch(() => null);

      if (res.ok && resJson && (resJson.status === true || resJson.success === true)) {
        return {
          status: true,
          data: resJson.data,
          message: 'Payout initiated successfully via Fincra'
        };
      }

      return {
        status: false,
        message: resJson?.error || resJson?.message || 'Fincra payout failed'
      };
    } catch (err: any) {
      return {
        status: false,
        message: err.message || 'Error connecting to Fincra Payouts API'
      };
    }
  }

  /**
   * List Merchant Collections (Inbound Bank Transfers into Virtual Accounts)
   * Fetches real-time collections directly from Fincra
   */
  static async listCollections(params?: { page?: number; perPage?: number }): Promise<{
    status: boolean;
    data?: any[];
    total?: number;
    message?: string;
  }> {
    try {
      const page = params?.page || 1;
      const perPage = params?.perPage || 50;
      const url = `${this.BASE_URL}/collections?business=${this.BUSINESS_ID}&page=${page}&perPage=${perPage}`;

      const res = await fetch(url, {
        method: 'GET',
        headers: this.getHeaders()
      });

      const resJson: any = await res.json().catch(() => null);

      if (res.ok && resJson && (resJson.status === true || resJson.success === true || Array.isArray(resJson.data?.results) || Array.isArray(resJson.data))) {
        const results = Array.isArray(resJson.data?.results)
          ? resJson.data.results
          : (Array.isArray(resJson.data) ? resJson.data : []);
        const total = resJson.data?.total || results.length;
        return {
          status: true,
          data: results,
          total,
          message: 'Collections fetched successfully'
        };
      }

      return {
        status: false,
        message: resJson?.error || resJson?.message || 'Failed to fetch collections from Fincra'
      };
    } catch (err: any) {
      return {
        status: false,
        message: err.message || 'Error connecting to Fincra Collections API'
      };
    }
  }

  /**
   * Fetch All Merchant Virtual Accounts from Fincra
   */
  static async getMerchantVirtualAccounts(currency: string = 'NGN'): Promise<{
    status: boolean;
    data?: any[];
    total?: number;
    message?: string;
  }> {
    try {
      const res = await fetch(`${this.BASE_URL}/profile/virtual-accounts?currency=${encodeURIComponent(currency)}`, {
        method: 'GET',
        headers: this.getHeaders()
      });
      const resJson: any = await res.json().catch(() => null);
      if (res.ok && resJson && (resJson.status === true || resJson.success === true)) {
        return {
          status: true,
          data: resJson.data?.results || [],
          total: resJson.data?.total || 0,
          message: 'Virtual accounts fetched successfully'
        };
      }
      return {
        status: false,
        message: resJson?.error || resJson?.message || 'Failed to fetch virtual accounts'
      };
    } catch (err: any) {
      return {
        status: false,
        message: err.message || 'Error connecting to Fincra Virtual Accounts API'
      };
    }
  }

  /**
   * Create / Request Virtual Account on Fincra
   * Primary provider: Wema Bank (035), with zero PSB limits and instant corporate limits
   */
  static async createVirtualAccount(params: {
    currency?: string;
    accountType?: 'individual' | 'corporate';
    channel?: string; // 'wema' | 'globus' | 'sterling'
    KYCInformation: {
      firstName?: string;
      lastName?: string;
      email: string;
      bvn: string;
      businessName?: string;
      bvnName?: string;
    };
  }): Promise<{
    status: boolean;
    data?: any;
    message?: string;
  }> {
    try {
      const payload: any = {
        currency: params.currency || 'NGN',
        accountType: params.accountType || 'individual',
        channel: params.channel || 'wema',
        KYCInformation: {
          email: params.KYCInformation.email,
          bvn: params.KYCInformation.bvn
        }
      };

      if (params.accountType === 'corporate') {
        payload.KYCInformation.businessName = params.KYCInformation.businessName || 'Ehomes Global Inclusive Limited';
        if (params.KYCInformation.bvnName) {
          payload.KYCInformation.bvnName = params.KYCInformation.bvnName;
        }
      } else {
        payload.KYCInformation.firstName = params.KYCInformation.firstName || 'Rentilly';
        payload.KYCInformation.lastName = params.KYCInformation.lastName || 'User';
      }

      const res = await fetch(`${this.BASE_URL}/profile/virtual-accounts/requests`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify(payload)
      });

      const resJson: any = await res.json().catch(() => null);

      if (res.ok && resJson && (resJson.status === true || resJson.success === true)) {
        return {
          status: true,
          data: resJson.data,
          message: resJson.message || 'Virtual account requested successfully'
        };
      }

      const errMsg = resJson?.error || resJson?.message || 'Failed to request virtual account from Fincra';
      console.warn('[FincraService] createVirtualAccount warning:', res.status, resJson);
      return {
        status: false,
        message: errMsg
      };
    } catch (err: any) {
      console.error('[FincraService] createVirtualAccount error:', err.message);
      return {
        status: false,
        message: err.message || 'Error connecting to Fincra Virtual Account creation API'
      };
    }
  }

  /**
   * Get Merchant Wallets & Balances across all currencies
   */
  static async getWallets(): Promise<{
    status: boolean;
    data?: any[];
    message?: string;
  }> {
    try {
      const res = await fetch(`${this.BASE_URL}/wallets?businessID=${this.BUSINESS_ID}`, {
        method: 'GET',
        headers: this.getHeaders()
      });
      const resJson: any = await res.json().catch(() => null);
      if (res.ok && resJson && (resJson.status === true || resJson.success === true)) {
        return {
          status: true,
          data: resJson.data || [],
          message: 'Wallets fetched successfully'
        };
      }
      return {
        status: false,
        message: resJson?.error || resJson?.message || 'Failed to fetch wallets'
      };
    } catch (err: any) {
      return {
        status: false,
        message: err.message || 'Error connecting to Fincra Wallets API'
      };
    }
  }

  /**
   * Verify HMAC-SHA512 Signature from Fincra Webhooks
   */
  static verifyWebhookSignature(payload: any, signature: string | string[] | undefined): boolean {
    if (!signature) return false;
    try {
      const sig = Array.isArray(signature) ? signature[0] : signature;
      const hmac = crypto.createHmac('sha512', this.WEBHOOK_KEY);
      const computed = hmac.update(typeof payload === 'string' ? payload : JSON.stringify(payload)).digest('hex');
      return computed.toLowerCase() === sig.toLowerCase();
    } catch (err) {
      console.error('[FincraService] Webhook signature verification error:', err);
      return false;
    }
  }
}

