import dotenv from 'dotenv';
import { supabase } from '../supabaseClient';
import type { VirtualCard } from './cardIssuingService';

dotenv.config();

export class MapleradCardService {
  private static get apiKey(): string {
    return process.env.MAPLERAD_SECRET_KEY || 'mpr_sk_35d197e6-3f6b-437c-995b-a0dff522b3dc';
  }

  private static get baseUrl(): string {
    return process.env.MAPLERAD_BASE_URL || 'https://api.maplerad.com/v1';
  }

  private static get headers(): Record<string, string> {
    return {
      'Authorization': `Bearer ${this.apiKey}`,
      'Accept': 'application/json',
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
      // 1. Check if customer already exists in Supabase or on Maplerad
      console.log(`[Maplerad] Resolving Tier 1 customer for ${cleanEmail}...`);
      let customerId: string | null = null;

      if (supabase) {
        try {
          const { data: prof } = await supabase
            .from('profiles')
            .select('maplerad_customer_id, maplerad_tier, phone_number, nin_number, dob')
            .eq('email', cleanEmail)
            .maybeSingle();
          if (prof?.maplerad_customer_id) {
            customerId = prof.maplerad_customer_id;
            console.log(`[Maplerad] Using cached customerId from profile: ${customerId}`);
          }
        } catch (_) {}
      }

      if (!customerId) {
        try {
          const getRes = await fetch(`${this.baseUrl}/customers?email=${encodeURIComponent(cleanEmail)}`, {
            method: 'GET',
            headers: this.headers,
            signal: AbortSignal.timeout(6000)
          });
          const getData = await getRes.json().catch(() => ({}));
          if (getData?.status && Array.isArray(getData?.data) && getData.data.length > 0) {
            customerId = getData.data[0].id;
            console.log(`[Maplerad] Found existing Maplerad customer: ${customerId}`);
          }
        } catch (err: any) {
          console.warn('[Maplerad] Customer lookup failed:', err.message);
        }
      }

      // 2. If still not found, enroll as Tier 1 customer with KYC data
      if (!customerId) {
        console.log(`[Maplerad] Enrolling customer for ${cleanEmail}...`);
        const { MapleradBankingService } = await import('./mapleradBankingService');
        customerId = await MapleradBankingService.resolveOrEnrollCustomer({
          email: cleanEmail,
          fullName: params.cardholderName
        });
      }

      if (!customerId) {
        return {
          success: false,
          error: 'Failed to resolve or register cardholder profile on Maplerad.'
        };
      }

      // 3. Issue Virtual Card via POST /v1/issuing
      console.log(`[Maplerad] Calling POST /v1/issuing for customer ${customerId}...`);
      const cardRes = await fetch(`${this.baseUrl}/issuing`, {
        method: 'POST',
        headers: this.headers,
        signal: AbortSignal.timeout(8000),
        body: JSON.stringify({
          customer_id: customerId,
          currency: 'USD',
          type: 'VIRTUAL',
          auto_approve: true,
          brand: params.brand || 'VISA',
          amount: Math.max(0, Math.round((params.initialFunding || 0) * 100))
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

  /**
   * Unloads/withdraws funds from a live Maplerad Virtual Card
   */
  static async withdrawCard(cardId: string, amountCents: number): Promise<{ success: boolean; data?: any; error?: string }> {
    try {
      console.log(`[Maplerad] Withdrawing ${amountCents} cents from card ${cardId}...`);
      const res = await fetch(`${this.baseUrl}/issuing/${cardId}/withdraw`, {
        method: 'POST',
        headers: this.headers,
        signal: AbortSignal.timeout(10000),
        body: JSON.stringify({ amount: Math.round(amountCents) })
      });
      const data = await res.json().catch(() => ({}));
      console.log(`[Maplerad] Card withdraw response for ${cardId}:`, JSON.stringify(data));
      if (data?.status) {
        return { success: true, data: data.data };
      }
      return { success: false, error: data?.message || 'Card withdrawal failed on issuing rail' };
    } catch (err: any) {
      console.error('[Maplerad] Card withdraw exception:', err.message);
      return { success: false, error: err.message };
    }
  }
}
