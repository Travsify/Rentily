import dotenv from 'dotenv';

dotenv.config();

const FLW_BASE_URL = 'https://api.flutterwave.com/v3';

export class FlutterwaveService {
  private static getSecretKey(): string {
    return process.env.FLUTTERWAVE_SECRET_KEY || 'FLWSECK-2a833d7d7454e38e1215b225916053aa-193498877521-X';
  }

  private static getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${this.getSecretKey()}`
    };
  }

  static isConfigured(): boolean {
    const key = this.getSecretKey();
    return Boolean(key && key.length > 5);
  }

  // 1. Dynamic Virtual Account for Rent Escrow Collection
  static async createVirtualAccount(params: {
    email: string;
    amount: number;
    propertyId: string;
    propertyTitle: string;
    tenantName: string;
  }): Promise<{
    status: boolean;
    data?: {
      accountNumber: string;
      bankName: string;
      orderRef: string;
      flwRef: string;
      expiryDate: string;
    };
    message?: string;
  }> {
    const txRef = `RENTILLY_PROP_${params.propertyId}_${Date.now()}`;
    const nameParts = (params.tenantName || 'Rentilly Tenant').trim().split(' ');
    const firstName = nameParts[0] || 'Rentilly';
    const lastName = nameParts.slice(1).join(' ') || 'Tenant';

    try {
      const response = await fetch(`${FLW_BASE_URL}/virtual-account-numbers`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify({
          email: params.email,
          is_permanent: false,
          bvn: '22194820183',
          tx_ref: txRef,
          phonenumber: '08120000000',
          firstname: firstName,
          lastname: lastName,
          narration: `Rentilly Escrow - ${params.propertyTitle}`,
          amount: params.amount
        })
      });

      const resJson: any = await response.json();

      if (response.ok && resJson.status === 'success' && resJson.data) {
        return {
          status: true,
          data: {
            accountNumber: resJson.data.account_number,
            bankName: resJson.data.bank_name || 'Flutterwave MFB',
            orderRef: resJson.data.order_ref || txRef,
            flwRef: resJson.data.flw_ref || txRef,
            expiryDate: resJson.data.expiry_date || new Date(Date.now() + 86400000 * 3).toISOString()
          }
        };
      }

      return {
        status: false,
        message: resJson.message || 'Failed to create dynamic virtual account'
      };
    } catch (error: any) {
      console.error('[Flutterwave] Virtual account creation error:', error);
      return {
        status: false,
        message: error.message || 'Network error communicating with Flutterwave'
      };
    }
  }

  // 1b. Generate Dedicated Permanent Virtual Bank Account for Verified User / Partner
  static async createPermanentUserVirtualAccount(params: {
    userId: string;
    email: string;
    fullName: string;
    businessName?: string;
    role?: string;
    bvn?: string;
    phoneNumber?: string;
  }): Promise<{
    status: boolean;
    data?: {
      accountNumber: string;
      bankName: string;
      orderRef: string;
      accountReference: string;
    };
    message?: string;
  }> {
    const txRef = `RENTILLY_ACC_${params.userId}_${Date.now()}`;
    const isPartner = params.role === 'partner' || (params.businessName && params.businessName.trim().length > 0);
    
    let firstName: string;
    let lastName: string;
    let narration: string;

    if (isPartner) {
      const bizName = (params.businessName || params.fullName).trim();
      firstName = bizName;
      lastName = 'Rentilly Partner';
      narration = `Rentilly Partner - ${bizName}`;
    } else {
      const resolvedName = params.fullName.trim();
      const nameParts = resolvedName.split(' ');
      firstName = nameParts[0] || 'Property';
      lastName = nameParts.slice(1).join(' ') || 'Owner';
      narration = `Rentilly Living - ${resolvedName}`;
    }

    const bvnToUse = params.bvn && params.bvn.length === 11 ? params.bvn : '22194820183';

    try {
      console.log(`[Flutterwave] Calling /virtual-account-numbers for ${params.email}, name: ${firstName} ${lastName}, bvn: ${bvnToUse}`);
      const response = await fetch(`${FLW_BASE_URL}/virtual-account-numbers`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify({
          email: params.email,
          is_permanent: true,
          bvn: bvnToUse,
          tx_ref: txRef,
          phonenumber: params.phoneNumber || '08120000000',
          firstname: firstName,
          lastname: lastName,
          narration: narration
        })
      });

      const resJson: any = await response.json();
      console.log('[Flutterwave] API Response:', JSON.stringify(resJson));

      if (response.ok && resJson.status === 'success' && resJson.data) {
        const d = resJson.data;
        return {
          status: true,
          data: {
            accountNumber: d.account_number,
            bankName: d.bank_name || 'Flutterwave MFB',
            orderRef: d.order_ref || txRef,
            accountReference: d.flw_ref || txRef
          }
        };
      }

      console.error('[Flutterwave] Virtual account creation error:', resJson);
      return {
        status: false,
        message: resJson.message || 'Flutterwave virtual account creation failed'
      };
    } catch (error: any) {
      console.error('[Flutterwave] Dedicated virtual account error:', error);
      return {
        status: false,
        message: error.message || 'Network error communicating with Flutterwave'
      };
    }
  }

  // 2. Transfer Funds to Landlord / Partner Bank Account
  static async transferToLandlord(params: {
    accountBank: string;
    accountNumber: string;
    amount: number;
    narration: string;
    currency?: string;
    reference?: string;
  }): Promise<{
    status: boolean;
    message: string;
    data?: any;
  }> {
    try {
      const response = await fetch(`${FLW_BASE_URL}/transfers`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify({
          account_bank: params.accountBank,
          account_number: params.accountNumber,
          amount: params.amount,
          narration: params.narration,
          currency: params.currency || 'NGN',
          reference: params.reference || `RENTILLY_TRF_${Date.now()}`,
          callback_url: 'https://rentilly.ng/api/payments/webhook'
        })
      });

      const resJson: any = await response.json();

      if (response.ok && resJson.status === 'success') {
        return {
          status: true,
          message: 'Transfer queued successfully',
          data: resJson.data
        };
      }

      return {
        status: false,
        message: resJson.message || 'Failed to initiate transfer'
      };
    } catch (error: any) {
      console.error('[Flutterwave] Transfer error:', error);
      return {
        status: false,
        message: error.message || 'Network error initiating transfer'
      };
    }
  }

  // 3. Fetch list of supported Nigerian banks
  static async getNigerianBanks(): Promise<Array<{ code: string; name: string }>> {
    try {
      const response = await fetch(`${FLW_BASE_URL}/banks/NG`, {
        headers: this.getHeaders()
      });

      const resJson: any = await response.json();
      if (response.ok && resJson.status === 'success') {
        return resJson.data.map((bank: any) => ({
          code: bank.code,
          name: bank.name
        }));
      }
      return [];
    } catch (error) {
      console.error('[Flutterwave] Failed to fetch bank list:', error);
      return [];
    }
  }

  // 4. Fetch Live Transactions from Flutterwave
  static async fetchLiveTransactions(email?: string): Promise<any[]> {
    try {
      const query = email ? `?customer_email=${encodeURIComponent(email)}` : '';
      const response = await fetch(`${FLW_BASE_URL}/transactions${query}`, {
        headers: this.getHeaders()
      });

      const resJson: any = await response.json();
      if (response.ok && resJson.status === 'success' && Array.isArray(resJson.data)) {
        return resJson.data;
      }
      return [];
    } catch (error) {
      console.error('[Flutterwave] Failed to fetch transactions:', error);
      return [];
    }
  }
}
