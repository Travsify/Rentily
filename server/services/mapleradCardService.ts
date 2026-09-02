import dotenv from 'dotenv';
import { supabase } from '../supabaseClient';
import type { VirtualCard } from './cardIssuingService';

dotenv.config();

export class MapleradCardService {
  private static get apiKey(): string {
    return process.env.MAPLERAD_SECRET_KEY || 'mpr_sk_ad35decc-eb6c-466b-9850-15ce57c9e392';
  }

  private static get baseUrl(): string {
    return process.env.MAPLERAD_BASE_URL || 'https://api.maplerad.com/v1';
  }

  private static get headers(): Record<string, string> {
    return {
      'Authorization': `Bearer ${this.apiKey}`,
      'Content-Type': 'application/json'
    };
  }

  /**
   * Issues a live Virtual Card via Maplerad Issuing API
   */
  static async issueCard(params: {
    email: string;
    cardholderName: string;
    currency: 'USD' | 'NGN';
    brand: 'VISA' | 'MASTERCARD';
    initialFunding?: number;
  }): Promise<{ success: boolean; data?: any; error?: string }> {
    const cleanEmail = params.email.trim().toLowerCase();
    const nameParts = params.cardholderName.trim().split(' ');
    const firstName = nameParts[0] || 'Rentilly';
    const lastName = nameParts.slice(1).join(' ') || 'User';

    try {
      // 1. Create or retrieve customer on Maplerad
      console.log(`[Maplerad] Creating customer for ${cleanEmail}...`);
      const custRes = await fetch(`${this.baseUrl}/customers`, {
        method: 'POST',
        headers: this.headers,
        signal: AbortSignal.timeout(6000),
        body: JSON.stringify({
          first_name: firstName,
          last_name: lastName,
          email: cleanEmail,
          country: 'NG'
        })
      });

      const custData = await custRes.json().catch(() => ({}));
      console.log('[Maplerad] Customer response:', JSON.stringify(custData));

      const customerId = custData?.data?.id || custData?.id;
      if (!customerId) {
        return {
          success: false,
          error: custData?.message || 'Failed to register customer on Maplerad (Access Denied or Inactive Permissions).'
        };
      }

      // 2. Issue Virtual Card
      console.log(`[Maplerad] Issuing card for customer ${customerId}...`);
      const cardRes = await fetch(`${this.baseUrl}/issuing/cards`, {
        method: 'POST',
        headers: this.headers,
        signal: AbortSignal.timeout(6000),
        body: JSON.stringify({
          customer_id: customerId,
          currency: params.currency || 'USD',
          type: 'VIRTUAL',
          brand: params.brand || 'VISA',
          amount: Math.max(0, Math.round((params.initialFunding || 0) * 100)) // in cents
        })
      });

      const cardData = await cardRes.json().catch(() => ({}));
      console.log('[Maplerad] Card issuance response:', JSON.stringify(cardData));

      if (cardData?.status && cardData?.data) {
        return { success: true, data: cardData.data };
      }

      return {
        success: false,
        error: cardData?.message || 'Maplerad card issuance rejected.'
      };
    } catch (err: any) {
      console.error('[Maplerad] Issuing exception:', err.message);
      return { success: false, error: err.message };
    }
  }
}
