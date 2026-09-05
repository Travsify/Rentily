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

  /**
   * Initiate High-Value Payout / Disbursement to Beneficiary Bank Account
   */
  static async initiatePayout(params: {
    amount: number;
    reference: string;
    description: string;
    beneficiary: FincraBeneficiary;
    currency?: string;
  }): Promise<{
    status: boolean;
    data?: any;
    message?: string;
  }> {
    try {
      const payload = {
        business: this.BUSINESS_ID,
        sourceCurrency: params.currency || 'NGN',
        destinationCurrency: params.currency || 'NGN',
        amount: params.amount,
        description: params.description || 'Rentilly Escrow Disbursement',
        paymentDestination: 'bank_account',
        customerReference: params.reference,
        beneficiary: {
          firstName: params.beneficiary.firstName,
          lastName: params.beneficiary.lastName,
          accountHolderName: params.beneficiary.accountHolderName,
          accountNumber: params.beneficiary.accountNumber,
          bankCode: params.beneficiary.bankCode,
          type: params.beneficiary.type || 'individual'
        }
      };

      const res = await fetch(`${this.BASE_URL}/disbursements/payouts`, {
        method: 'POST',
        headers: {
          'api-key': this.SECRET_KEY,
          'Content-Type': 'application/json'
        },
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
