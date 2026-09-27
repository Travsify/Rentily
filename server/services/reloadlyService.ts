import https from 'https';
import dotenv from 'dotenv';
dotenv.config();

const RELOADLY_CLIENT_ID = process.env.RELOADLY_CLIENT_ID || '4WTPjBlGxafzyAmxVosEA8dvphoYZ3Lq';
const RELOADLY_CLIENT_SECRET = process.env.RELOADLY_CLIENT_SECRET || 'wzq0JXdPwO-atq9tXdAFI0Xi1HsobE-8IgO6n7ltvCqNpjIOScIUaJoWYfRyN26';

interface TokenCache {
  token: string;
  expiresAt: number; // epoch ms
}

const _tokenCaches: Map<string, TokenCache> = new Map();

/**
 * Low-level HTTPS JSON request helper
 */
function httpsRequest(options: https.RequestOptions, postData?: string): Promise<{ statusCode: number; data: any }> {
  return new Promise((resolve, reject) => {
    const req = https.request({ ...options, timeout: 4000 }, (res) => {
      let raw = '';
      res.on('data', chunk => raw += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(raw);
          resolve({ statusCode: res.statusCode || 200, data: parsed });
        } catch (e) {
          resolve({ statusCode: res.statusCode || 200, data: raw });
        }
      });
    });

    req.on('timeout', () => {
      req.destroy(new Error('Request timed out'));
    });

    req.on('error', err => reject(err));

    if (postData) {
      req.write(postData);
    }
    req.end();
  });
}

export class ReloadlyService {
  /**
   * Acquire or return cached OAuth 2.0 access token for a specific Reloadly audience
   */
  public static async getAccessToken(audience: string): Promise<string> {
    const now = Date.now();
    const cached = _tokenCaches.get(audience);
    if (cached && cached.expiresAt > now + 60000) {
      return cached.token;
    }

    const payload = JSON.stringify({
      client_id: RELOADLY_CLIENT_ID,
      client_secret: RELOADLY_CLIENT_SECRET,
      grant_type: 'client_credentials',
      audience: audience
    });

    const res = await httpsRequest({
      hostname: 'auth.reloadly.com',
      path: '/oauth/token',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload)
      }
    }, payload);

    if (res.statusCode !== 200 || !res.data || !res.data.access_token) {
      throw new Error(`[ReloadlyService] OAuth token acquisition failed (${res.statusCode}): ${JSON.stringify(res.data)}`);
    }

    const token = res.data.access_token as string;
    const expiresIn = (res.data.expires_in || 3600) as number;
    _tokenCaches.set(audience, {
      token,
      expiresAt: now + (expiresIn * 1000)
    });

    return token;
  }

  // =========================================================================
  // 1. UTILITIES API (Electricity Discos, Water, TV, Internet)
  // =========================================================================

  /**
   * Fetch active utilities balance (USD)
   */
  public static async getUtilitiesBalance(): Promise<any> {
    const token = await this.getAccessToken('https://utilities.reloadly.com');
    const res = await httpsRequest({
      hostname: 'utilities.reloadly.com',
      path: '/accounts/balance',
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Accept': 'application/com.reloadly.utilities-v1+json'
      }
    });
    return res.data;
  }

  /**
   * Get billers list with optional country and serviceType filters
   */
  public static async getBillers(countryCode = 'NG', type?: string, page = 1, size = 50): Promise<any> {
    const token = await this.getAccessToken('https://utilities.reloadly.com');
    let path = `/billers?page=${page}&size=${size}`;
    if (countryCode) path += `&countryCode=${encodeURIComponent(countryCode.toUpperCase())}`;
    if (type) path += `&type=${encodeURIComponent(type)}`;

    const res = await httpsRequest({
      hostname: 'utilities.reloadly.com',
      path,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Accept': 'application/com.reloadly.utilities-v1+json'
      }
    });
    return res.data;
  }

  /**
   * Real-time pre-validation of a meter or customer account number
   */
  public static async validateMeter(billerId: number, accountNumber: string): Promise<any> {
    const token = await this.getAccessToken('https://utilities.reloadly.com');
    const path = `/billers/${billerId}/validate?accountNumber=${encodeURIComponent(accountNumber.trim())}`;

    const res = await httpsRequest({
      hostname: 'utilities.reloadly.com',
      path,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Accept': 'application/com.reloadly.utilities-v1+json'
      }
    });

    if (res.statusCode >= 400) {
      throw new Error(res.data?.message || 'Meter validation failed on provider grid.');
    }

    return res.data;
  }

  /**
   * Live payment execution on Reloadly Utility API.
   * For prepaid electricity, returns the official 20-digit STS token.
   */
  public static async payBill(params: {
    billerId: number;
    accountNumber: string;
    amount: number;
    useLocalAmount?: boolean;
    reference?: string;
    additionalInfo?: Record<string, any>;
  }): Promise<any> {
    const token = await this.getAccessToken('https://utilities.reloadly.com');
    const payload = JSON.stringify({
      subscriberAccountNumber: params.accountNumber.trim(),
      amount: Number(params.amount),
      billerId: Number(params.billerId),
      useLocalAmount: params.useLocalAmount ?? true,
      referenceId: params.reference || `RLD_BILL_${Date.now()}`,
      additionalInfo: params.additionalInfo || {}
    });

    const res = await httpsRequest({
      hostname: 'utilities.reloadly.com',
      path: '/pay',
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Accept': 'application/com.reloadly.utilities-v1+json',
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload)
      }
    }, payload);

    if (res.statusCode >= 400) {
      throw new Error(res.data?.message || 'Bill payment settlement failed on provider grid.');
    }

    return res.data;
  }

  // =========================================================================
  // 2. DIGITAL GIFT CARDS, CRYPTO VOUCHERS & AIRALO eSIM
  // =========================================================================

  /**
   * Fetch active gift cards balance (USD)
   */
  public static async getGiftCardsBalance(): Promise<any> {
    const token = await this.getAccessToken('https://giftcards.reloadly.com');
    const res = await httpsRequest({
      hostname: 'giftcards.reloadly.com',
      path: '/accounts/balance',
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Accept': 'application/com.reloadly.giftcards-v1+json'
      }
    });
    return res.data;
  }

  /**
   * Fetch gift card product catalogue (Global, Nigeria, Crypto, Travel)
   */
  public static async getProducts(params?: {
    countryCode?: string;
    categoryId?: number;
    page?: number;
    size?: number;
    search?: string;
  }): Promise<any> {
    const token = await this.getAccessToken('https://giftcards.reloadly.com');
    const page = params?.page || 1;
    const size = params?.size || 50;

    let path = `/products?page=${page}&size=${size}`;
    if (params?.countryCode) path += `&countryCode=${encodeURIComponent(params.countryCode.toUpperCase())}`;
    if (params?.categoryId) path += `&categoryId=${params.categoryId}`;
    if (params?.search) path += `&productName=${encodeURIComponent(params.search)}`;

    const res = await httpsRequest({
      hostname: 'giftcards.reloadly.com',
      path,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Accept': 'application/com.reloadly.giftcards-v1+json'
      }
    });
    return res.data;
  }

  /**
   * Get single product details including live denominations, fee structure, and redeem instructions
   */
  public static async getProductById(productId: number): Promise<any> {
    const token = await this.getAccessToken('https://giftcards.reloadly.com');
    const res = await httpsRequest({
      hostname: 'giftcards.reloadly.com',
      path: `/products/${productId}`,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Accept': 'application/com.reloadly.giftcards-v1+json'
      }
    });

    if (res.statusCode >= 400) {
      throw new Error(res.data?.message || `Failed to load product details for ID ${productId}`);
    }

    return res.data;
  }

  /**
   * Order a digital gift card, crypto voucher, or travel eSIM.
   */
  public static async orderGiftCard(params: {
    productId: number;
    unitPrice: number;
    quantity: number;
    recipientEmail: string;
    recipientPhone?: string;
    senderName?: string;
    customIdentifier?: string;
  }): Promise<any> {
    const token = await this.getAccessToken('https://giftcards.reloadly.com');
    const payload = JSON.stringify({
      productId: Number(params.productId),
      unitPrice: Number(params.unitPrice),
      quantity: Number(params.quantity || 1),
      recipientEmail: params.recipientEmail.trim().toLowerCase(),
      recipientPhoneDetails: params.recipientPhone ? {
        countryCode: 'NG',
        phoneNumber: params.recipientPhone.replace(/[^0-9]/g, '')
      } : undefined,
      senderName: params.senderName || 'Rentilly Digital Vault',
      customIdentifier: params.customIdentifier || `RLD_GC_${Date.now()}`
    });

    const res = await httpsRequest({
      hostname: 'giftcards.reloadly.com',
      path: '/orders',
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Accept': 'application/com.reloadly.giftcards-v1+json',
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload)
      }
    }, payload);

    if (res.statusCode >= 400) {
      throw new Error(res.data?.message || 'Gift card purchase order failed with provider.');
    }

    return res.data;
  }

  /**
   * Retrieve the generated card codes, PINs, and redemption URLs for a fulfilled order
   */
  public static async getOrderCards(orderId: number): Promise<any> {
    const token = await this.getAccessToken('https://giftcards.reloadly.com');
    const res = await httpsRequest({
      hostname: 'giftcards.reloadly.com',
      path: `/orders/transactions/${orderId}/cards`,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Accept': 'application/com.reloadly.giftcards-v1+json'
      }
    });

    return res.data;
  }

  /**
   * Fetch all supported countries for gift cards and international services
   */
  public static async getCountries(): Promise<any> {
    const token = await this.getAccessToken('https://giftcards.reloadly.com');
    const res = await httpsRequest({
      hostname: 'giftcards.reloadly.com',
      path: '/countries',
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Accept': 'application/com.reloadly.giftcards-v1+json'
      }
    });
    return res.data;
  }
}
