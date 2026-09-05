import dotenv from 'dotenv';

dotenv.config();

export interface KorapayVirtualAccount {
  accountName: string;
  accountNumber: string;
  bankName: string;
  bankCode: string;
  accountReference: string;
  uniqueId: string;
  currency: string;
  status: string;
}

export class KorapayService {
  private static get BASE_URL(): string {
    return process.env.KORAPAY_BASE_URL || 'https://api.korapay.com/merchant/api/v1';
  }
  private static get SECRET_KEY(): string {
    return process.env.KORAPAY_SECRET_KEY || '';
  }
  private static get PUBLIC_KEY(): string {
    return process.env.KORAPAY_PUBLIC_KEY || '';
  }

  private static getHeaders() {
    return {
      'Authorization': `Bearer ${this.SECRET_KEY}`,
      'Content-Type': 'application/json'
    };
  }

  /**
   * Check if Korapay is configured
   */
  static isConfigured(): boolean {
    return Boolean(this.SECRET_KEY && this.SECRET_KEY.startsWith('sk_'));
  }

  /**
   * Fetch Live Multi-Currency Balances from Korapay
   */
  static async getBalances(): Promise<{
    status: boolean;
    data?: Record<string, { available_balance: number; pending_balance: number }>;
    message?: string;
  }> {
    try {
      const res = await fetch(`${this.BASE_URL}/balances`, {
        method: 'GET',
        headers: this.getHeaders()
      });

      const resJson: any = await res.json();
      if (res.ok && resJson.status && resJson.data) {
        return {
          status: true,
          data: resJson.data
        };
      }

      return {
        status: false,
        message: resJson.message || 'Failed to fetch Korapay balances'
      };
    } catch (err: any) {
      return {
        status: false,
        message: err.message || 'Error connecting to Korapay API'
      };
    }
  }

  /**
   * Create a Permanent Multi-Currency Virtual Account on Korapay
   */
  static async createVirtualAccount(params: {
    name: string;
    email: string;
    bvn?: string;
    reference?: string;
    currency?: string;
  }): Promise<{ status: boolean; data?: KorapayVirtualAccount; message?: string }> {
    const ref = params.reference || `RNT_KORA_${Date.now()}`;
    const cleanEmail = params.email.trim().toLowerCase();
    const cleanName = params.name.trim();
    const cleanBvn = (params.bvn || '22222222222').replace(/[^0-9]/g, '');

    try {
      const payload = {
        account_name: cleanName,
        account_reference: ref,
        permanent: true,
        bank_code: '000',
        customer: {
          name: cleanName,
          email: cleanEmail
        },
        kyc: {
          bvn: cleanBvn
        }
      };

      const res = await fetch(`${this.BASE_URL}/virtual-bank-account`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify(payload)
      });

      const resJson: any = await res.json();

      if (res.ok && resJson.status && resJson.data) {
        const d = resJson.data;
        return {
          status: true,
          data: {
            accountName: d.account_name || cleanName,
            accountNumber: d.account_number,
            bankName: d.bank_name || 'Korapay Settlement Bank',
            bankCode: d.bank_code || '000',
            accountReference: d.account_reference || ref,
            uniqueId: d.unique_id || `KPY_${Date.now()}`,
            currency: d.currency || params.currency || 'NGN',
            status: d.account_status || 'active'
          },
          message: 'Virtual bank account created successfully'
        };
      }

      return {
        status: false,
        message: resJson.message || 'Failed to create virtual bank account'
      };
    } catch (err: any) {
      return {
        status: false,
        message: err.message || 'Error connecting to Korapay Virtual Account API'
      };
    }
  }

  /**
   * Initialize a High-Value Checkout or Inflow on Korapay
   */
  static async initializeCheckout(params: {
    reference: string;
    amount: number;
    currency?: string;
    customerEmail: string;
    customerName: string;
    redirectUrl?: string;
    description?: string;
  }): Promise<{ status: boolean; data?: { checkoutUrl: string; reference: string }; message?: string }> {
    try {
      const res = await fetch(`${this.BASE_URL}/charges/initialize`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify({
          reference: params.reference,
          amount: params.amount,
          currency: params.currency || 'NGN',
          customer: {
            name: params.customerName,
            email: params.customerEmail
          },
          information: params.description || 'Rentilly High-Value Escrow Funding',
          redirect_url: params.redirectUrl || 'https://myrentilly.com/wallet',
          channels: ['bank_transfer', 'card']
        })
      });

      const resJson: any = await res.json();
      if (res.ok && resJson.status && resJson.data) {
        return {
          status: true,
          data: {
            checkoutUrl: resJson.data.checkout_url,
            reference: resJson.data.reference
          }
        };
      }

      return {
        status: false,
        message: resJson.message || 'Failed to initialize Korapay checkout'
      };
    } catch (err: any) {
      return {
        status: false,
        message: err.message || 'Error connecting to Korapay Checkout API'
      };
    }
  }

  /**
   * Verify a transaction on Korapay
   */
  static async verifyTransaction(reference: string): Promise<{
    status: boolean;
    data?: any;
    message?: string;
  }> {
    try {
      const res = await fetch(`${this.BASE_URL}/charges/${reference}`, {
        method: 'GET',
        headers: this.getHeaders()
      });

      const resJson: any = await res.json();
      if (res.ok && resJson.status && resJson.data) {
        return {
          status: true,
          data: resJson.data
        };
      }

      return {
        status: false,
        message: resJson.message || 'Verification failed'
      };
    } catch (err: any) {
      return {
        status: false,
        message: err.message || 'Error connecting to Korapay charges API'
      };
    }
  }
}
