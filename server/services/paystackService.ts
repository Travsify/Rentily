import dotenv from 'dotenv';

dotenv.config();

const PAYSTACK_BASE_URL = process.env.PAYSTACK_BASE_URL || 'https://api.paystack.co';

export class PaystackService {
  private static getSecretKey(): string {
    return process.env.PAYSTACK_SECRET_KEY || '';
  }

  private static getHeaders() {
    return {
      'Authorization': `Bearer ${this.getSecretKey()}`,
      'Content-Type': 'application/json'
    };
  }

  // 1. Fetch Nigerian Banks List
  static async getBanks(): Promise<{ status: boolean; data?: any[]; message?: string }> {
    try {
      const response = await fetch(`${PAYSTACK_BASE_URL}/bank?country=nigeria`, {
        headers: this.getHeaders()
      });
      const resJson: any = await response.json();
      if (response.ok && resJson.status) {
        return { status: true, data: resJson.data };
      }
      return { status: false, message: resJson.message || 'Failed to fetch banks' };
    } catch (err: any) {
      return { status: false, message: err.message };
    }
  }

  // 2. Resolve NUBAN Bank Account (Fetch real account owner name)
  static async resolveAccount(accountNumber: string, bankCode: string): Promise<{
    status: boolean;
    data?: { accountNumber: string; accountName: string; bankId: number };
    message?: string;
  }> {
    try {
      const response = await fetch(
        `${PAYSTACK_BASE_URL}/bank/resolve?account_number=${accountNumber}&bank_code=${bankCode}`,
        { headers: this.getHeaders() }
      );
      const resJson: any = await response.json();
      if (response.ok && resJson.status && resJson.data) {
        return {
          status: true,
          data: {
            accountNumber: resJson.data.account_number,
            accountName: resJson.data.account_name,
            bankId: resJson.data.bank_id
          }
        };
      }
      return { status: false, message: resJson.message || 'Could not resolve account details' };
    } catch (err: any) {
      return { status: false, message: err.message };
    }
  }

  // 3. Create Transfer Recipient
  static async createTransferRecipient(params: {
    name: string;
    accountNumber: string;
    bankCode: string;
    description?: string;
  }): Promise<{ status: boolean; recipientCode?: string; message?: string }> {
    try {
      const response = await fetch(`${PAYSTACK_BASE_URL}/transferrecipient`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify({
          type: 'nuban',
          name: params.name,
          account_number: params.accountNumber,
          bank_code: params.bankCode,
          currency: 'NGN',
          description: params.description || 'Rentilly Escrow Withdrawal'
        })
      });
      const resJson: any = await response.json();
      if (response.ok && resJson.status && resJson.data) {
        return { status: true, recipientCode: resJson.data.recipient_code };
      }
      return { status: false, message: resJson.message || 'Failed to create transfer recipient' };
    } catch (err: any) {
      return { status: false, message: err.message };
    }
  }

  // 4. Initiate Paystack Payout / Withdrawal Transfer
  static async initiateTransfer(params: {
    recipientCode: string;
    amount: number; // in Naira
    reason?: string;
    reference?: string;
  }): Promise<{
    status: boolean;
    data?: {
      transferCode: string;
      reference: string;
      amount: number;
      status: string;
    };
    message?: string;
  }> {
    try {
      const transferRef = params.reference || `RENTILLY_WD_${Date.now()}`;
      const response = await fetch(`${PAYSTACK_BASE_URL}/transfer`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify({
          source: 'balance',
          amount: Math.round(params.amount * 100), // Paystack expects Kobo
          recipient: params.recipientCode,
          reason: params.reason || 'Rentilly Escrow Payout',
          reference: transferRef
        })
      });

      const resJson: any = await response.json();
      if (response.ok && resJson.status && resJson.data) {
        return {
          status: true,
          data: {
            transferCode: resJson.data.transfer_code,
            reference: resJson.data.reference || transferRef,
            amount: params.amount,
            status: resJson.data.status
          }
        };
      }
      return { status: false, message: resJson.message || 'Transfer failed' };
    } catch (err: any) {
      return { status: false, message: err.message };
    }
  }

  // 5. Fetch Live Outbound Transfers Ledger from Paystack Cloud API
  static async fetchLiveTransfers(): Promise<any[]> {
    try {
      const response = await fetch(`${PAYSTACK_BASE_URL}/transfer?perPage=50`, {
        headers: this.getHeaders()
      });
      const resJson: any = await response.json();
      if (response.ok && resJson.status && Array.isArray(resJson.data)) {
        return resJson.data;
      }
      return [];
    } catch (err: any) {
      console.error('Failed to fetch live Paystack transfers:', err.message);
      return [];
    }
  }
}
