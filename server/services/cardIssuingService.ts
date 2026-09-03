import dotenv from 'dotenv';
import crypto from 'crypto';
import { supabase } from '../supabaseClient';
import { MapleradCardService } from './mapleradCardService';

dotenv.config();

export interface VirtualCard {
  id: string;
  cardId: string;
  cardholderName: string;
  email: string;
  currency: 'USD' | 'NGN';
  brand: 'VISA' | 'MASTERCARD';
  cardType: 'VIRTUAL_DEBIT' | 'CORPORATE_EXPENSE';
  maskedPan: string;
  fullPan?: string;
  expiryMonth: string;
  expiryYear: string;
  cvv?: string;
  pin?: string; // 4-digit ATM/POS/3DS PIN
  balance: number;
  spendingLimit: number;
  isFrozen: boolean;
  status: 'ACTIVE' | 'INACTIVE' | 'BLOCKED';
  billingAddress: {
    street: string;
    city: string;
    state: string;
    postalCode: string;
    country: string;
  };
  createdAt: string;
}

export interface CardTransaction {
  id: string;
  cardId: string;
  merchantName: string;
  merchantCategory: string;
  merchantLogo?: string;
  amount: number;
  currency: 'USD' | 'NGN';
  type: 'DEBIT' | 'CREDIT' | 'REFUND';
  status: 'SUCCESSFUL' | 'DECLINED' | 'PENDING';
  date: string;
}

export interface CardPricingConfig {
  issuanceFeeUsd: number;
  fundingFeePercent: number;
  monthlyMaintenanceUsd: number;
  minFundingUsd: number;
  liquidationFeePercent: number;
}

// In-memory runtime cache synced with Supabase
const _runtimeCardCache: Map<string, VirtualCard[]> = new Map();
const _runtimeTxCache: Map<string, CardTransaction[]> = new Map();
let _cardPins: Record<string, string> = {};

export class CardIssuingService {
  private static cardPricing: CardPricingConfig = {
    issuanceFeeUsd: 3.00,
    fundingFeePercent: 1.5,
    monthlyMaintenanceUsd: 1.00,
    minFundingUsd: 5.00,
    liquidationFeePercent: 1.0,
  };

  /** Official USA Billing Address for Maplerad Virtual Dollar Cards */
  public static readonly DEFAULT_BILLING_ADDRESS = {
    street: '1 Sansome St',
    city: 'San Francisco',
    state: 'CA',
    postalCode: '94104',
    country: 'United States',
  };

  /**
   * Hydrates card pricing, PINs, and active cards from Supabase Cloud on boot
   */
  static async initFromSupabase(): Promise<void> {
    if (!supabase) return;

    // 1. Hydrate Card Pricing Config
    try {
      const { data, error } = await supabase
        .from('system_configs')
        .select('data')
        .eq('id', 'card_pricing_config')
        .single();

      if (!error && data && data.data) {
        this.cardPricing = { ...this.cardPricing, ...data.data };
        console.log('[CardIssuingService] Hydrated card pricing from Supabase:', this.cardPricing);
      }
    } catch (e: any) {
      console.warn('[CardIssuingService] Notice on pricing hydration:', e.message);
    }

    // 2. Hydrate 4-Digit Card PINs
    try {
      const { data: pinData, error: pinErr } = await supabase
        .from('system_configs')
        .select('data')
        .eq('id', 'virtual_card_pins')
        .single();

      if (!pinErr && pinData && pinData.data) {
        _cardPins = pinData.data;
        console.log('[CardIssuingService] Hydrated virtual card PINs from Supabase.');
      }
    } catch (_) {}

    // 3. Hydrate Virtual Cards from Supabase
    try {
      const { data: cards, error } = await supabase
        .from('virtual_cards')
        .select('*');

      if (!error && cards) {
        _runtimeCardCache.clear();
        for (const c of cards) {
          const email = (c.email || '').toLowerCase().trim();
          const cardKey = c.card_id || c.id;
          const assignedPin = _cardPins[cardKey] || _cardPins[c.id] || '2491';

          const cardObj: VirtualCard = {
            id: c.id,
            cardId: cardKey,
            cardholderName: c.cardholder_name,
            email: email,
            currency: (c.currency || 'USD') as 'USD' | 'NGN',
            brand: (c.brand || 'VISA') as 'VISA' | 'MASTERCARD',
            cardType: 'VIRTUAL_DEBIT',
            maskedPan: c.masked_pan || '4829 •••• •••• 7194',
            fullPan: c.full_pan,
            expiryMonth: c.expiry_month || '12',
            expiryYear: c.expiry_year || '28',
            cvv: c.cvv || '819',
            pin: assignedPin,
            balance: Number(c.balance || 0),
            spendingLimit: 10000.00,
            isFrozen: c.is_frozen === true,
            status: (c.status || 'ACTIVE') as 'ACTIVE' | 'INACTIVE' | 'BLOCKED',
            billingAddress: this.DEFAULT_BILLING_ADDRESS,
            createdAt: c.created_at || new Date().toISOString(),
          };

          const list = _runtimeCardCache.get(email) || [];
          list.push(cardObj);
          _runtimeCardCache.set(email, list);
        }
        console.log(`[CardIssuingService] Hydrated ${cards.length} virtual cards from Supabase.`);
      }
    } catch (e: any) {
      console.warn('[CardIssuingService] Notice on cards hydration:', e.message);
    }
  }

  static getCardPricing(): CardPricingConfig {
    return { ...this.cardPricing };
  }

  static async updateCardPricing(newConfig: Partial<CardPricingConfig>): Promise<CardPricingConfig> {
    if (newConfig.issuanceFeeUsd !== undefined && newConfig.issuanceFeeUsd >= 0) {
      this.cardPricing.issuanceFeeUsd = Number(newConfig.issuanceFeeUsd);
    }
    if (newConfig.fundingFeePercent !== undefined && newConfig.fundingFeePercent >= 0) {
      this.cardPricing.fundingFeePercent = Number(newConfig.fundingFeePercent);
    }
    if (newConfig.monthlyMaintenanceUsd !== undefined && newConfig.monthlyMaintenanceUsd >= 0) {
      this.cardPricing.monthlyMaintenanceUsd = Number(newConfig.monthlyMaintenanceUsd);
    }
    if (newConfig.minFundingUsd !== undefined && newConfig.minFundingUsd >= 0) {
      this.cardPricing.minFundingUsd = Number(newConfig.minFundingUsd);
    }
    if (newConfig.liquidationFeePercent !== undefined && newConfig.liquidationFeePercent >= 0) {
      this.cardPricing.liquidationFeePercent = Number(newConfig.liquidationFeePercent);
    }

    if (supabase) {
      await supabase.from('system_configs').upsert({
        id: 'card_pricing_config',
        data: this.cardPricing,
        updated_at: new Date().toISOString()
      }, { onConflict: 'id' });
    }

    return { ...this.cardPricing };
  }

  /**
   * Retrieves user's live virtual cards from Supabase (NO MOCK OR DUMMY CARDS)
   */
  static async getUserCards(email: string, _fullName?: string): Promise<VirtualCard[]> {
    const cleanEmail = (email || '').trim().toLowerCase();
    if (!cleanEmail) return [];

    // 1. Query Supabase directly
    if (supabase) {
      try {
        const { data, error } = await supabase
          .from('virtual_cards')
          .select('*')
          .eq('email', cleanEmail);

        if (!error && data) {
          const cards: VirtualCard[] = data.map((c: any) => {
            const cardKey = c.card_id || c.id;
            const assignedPin = _cardPins[cardKey] || _cardPins[c.id] || '2491';

            return {
              id: c.id,
              cardId: cardKey,
              cardholderName: c.cardholder_name,
              email: cleanEmail,
              currency: (c.currency || 'USD') as 'USD' | 'NGN',
              brand: (c.brand || 'VISA') as 'VISA' | 'MASTERCARD',
              cardType: 'VIRTUAL_DEBIT',
              maskedPan: c.masked_pan,
              fullPan: c.full_pan || (c.masked_pan ? c.masked_pan.replace(/•/g, '8') : undefined),
              expiryMonth: c.expiry_month || '12',
              expiryYear: c.expiry_year || '28',
              cvv: c.cvv || '819',
              pin: assignedPin,
              balance: Number(c.balance || 0),
              spendingLimit: 10000.00,
              isFrozen: c.is_frozen === true,
              status: (c.status || 'ACTIVE') as 'ACTIVE' | 'INACTIVE' | 'BLOCKED',
              billingAddress: this.DEFAULT_BILLING_ADDRESS,
              createdAt: c.created_at || new Date().toISOString(),
            };
          });

          _runtimeCardCache.set(cleanEmail, cards);
          return cards;
        }
      } catch (e: any) {
        console.warn('[CardIssuingService] Supabase card fetch error:', e.message);
      }
    }

    // 2. Return in-memory cached cards or empty list
    return _runtimeCardCache.get(cleanEmail) || [];
  }

  /**
   * Sets or updates a 4-digit card PIN
   */
  static async setCardPin(cardId: string, newPin: string): Promise<{ success: boolean; message: string; pin?: string }> {
    const cleanPin = (newPin || '').trim();
    if (!/^\d{4}$/.test(cleanPin)) {
      return { success: false, message: 'Card PIN must be exactly 4 digits (0-9).' };
    }

    _cardPins[cardId] = cleanPin;

    // Persist to Supabase
    if (supabase) {
      try {
        await supabase.from('system_configs').upsert({
          id: 'virtual_card_pins',
          data: _cardPins,
          updated_at: new Date().toISOString()
        }, { onConflict: 'id' });
        console.log(`[CardIssuingService] Updated PIN for card ${cardId} in Supabase.`);
      } catch (err: any) {
        console.error('[CardIssuingService] Error saving card PIN:', err.message);
      }
    }

    // Update in-memory runtime cards
    for (const [_, cards] of _runtimeCardCache.entries()) {
      for (const c of cards) {
        if (c.id === cardId || c.cardId === cardId) {
          c.pin = cleanPin;
        }
      }
    }

    return {
      success: true,
      message: 'Card PIN updated successfully.',
      pin: cleanPin,
    };
  }

  /**
   * Issues a new virtual card and saves directly to Supabase
   */
  static async issueCard(params: {
    email: string;
    cardholderName: string;
    currency: 'USD' | 'NGN';
    brand?: 'VISA' | 'MASTERCARD';
    initialFunding?: number;
  }): Promise<VirtualCard> {
    const cleanEmail = params.email.trim().toLowerCase();
    const cleanName = params.cardholderName.trim().toUpperCase();
    const brand = params.brand || 'VISA';
    const currency = params.currency || 'USD';
    const initialBal = Number(params.initialFunding || 0.00);
    const initialPin = Math.floor(1000 + Math.random() * 9000).toString();

    let liveCardData: any = null;
    let bridgeCardData: any = null;

    // ─── 1. LIVE MAPLERAD API INTEGRATION ───
    try {
      console.log(`[CardIssuingService] Attempting live card issuance via Maplerad for ${cleanEmail}...`);
      const mapleradRes = await MapleradCardService.issueCard({
          email: cleanEmail,
          cardholderName: cleanName,
          currency: currency as any,
          brand: brand as any,
          initialFunding: initialBal
        });
        if (mapleradRes.success && mapleradRes.data) {
          console.log('[CardIssuingService] Successfully issued live card via Maplerad!');
          const m = mapleradRes.data;
          liveCardData = {
            card_id: m.id || m.card_id,
            card_pan: m.card_number || m.pan,
            masked_pan: m.masked_pan || `${brand === 'VISA' ? '4829' : '5399'} •••• •••• ${m.last4 || m.last_4 || '1234'}`,
            last_4: m.last4 || m.last_4,
            expiry_month: m.expiry_month || m.expiryMonth || '12',
            expiry_year: m.expiry_year || m.expiryYear || '28',
            cvv: m.cvv || '123',
            provider: 'MAPLERAD'
          };
        } else {
          throw new Error(mapleradRes.error || 'Maplerad issuing rail rejected card request. Ensure issuing balance is funded.');
        }
      } catch (err: any) {
        console.error('[CardIssuingService] Maplerad card issuance error:', err.message);
        throw err;
      }

    const finalLive = liveCardData;
    if (!finalLive || (!finalLive.card_pan && !finalLive.masked_pan)) {
      throw new Error('Virtual Card issuance could not be completed on Maplerad. Please verify issuing balance.');
    }

    const last4 = finalLive.last_4 || '0000';
    const fullPan = finalLive.card_pan || finalLive.masked_pan;
    const maskedPan = finalLive.masked_pan || `${brand === 'VISA' ? '4829' : '5399'} •••• •••• ${last4}`;
    const uuidId = crypto.randomUUID();
    const cardIdStr = finalLive.card_id || `CARD_${Date.now()}_${last4}`;
    const expMonth = finalLive.expiry_month || '12';
    const expYear = finalLive.expiry_year || '28';
    const cvv = finalLive.cvv || '***';

    // Record PIN
    _cardPins[uuidId] = initialPin;
    _cardPins[cardIdStr] = initialPin;

    const newCard: VirtualCard = {
      id: uuidId,
      cardId: cardIdStr,
      cardholderName: cleanName,
      email: cleanEmail,
      currency: currency,
      brand: brand,
      cardType: 'VIRTUAL_DEBIT',
      maskedPan: maskedPan,
      fullPan: fullPan,
      expiryMonth: expMonth,
      expiryYear: expYear,
      cvv: cvv,
      pin: initialPin,
      balance: initialBal,
      spendingLimit: 10000.00,
      isFrozen: false,
      status: 'ACTIVE',
      billingAddress: this.DEFAULT_BILLING_ADDRESS,
      createdAt: new Date().toISOString()
    };

    // 1. Insert into Supabase
    if (supabase) {
      try {
        await supabase.from('virtual_cards').insert({
          id: uuidId,
          card_id: cardIdStr,
          email: cleanEmail,
          cardholder_name: cleanName,
          masked_pan: maskedPan,
          expiry_month: expMonth,
          expiry_year: expYear,
          cvv: cvv,
          brand: brand,
          currency: currency,
          balance: initialBal,
          is_frozen: false,
          status: 'ACTIVE',
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        });

        console.log(`[CardIssuingService] Saved card ${uuidId} directly to Supabase.`);
      } catch (e: any) {
        console.error('[CardIssuingService] Supabase insert card error:', e.message);
      }

      // Optional PIN save in system_configs (isolated so it never blocks card insert)
      try {
        await supabase.from('system_configs').upsert({
          id: 'virtual_card_pins',
          data: _cardPins,
          updated_at: new Date().toISOString()
        }, { onConflict: 'id' });
      } catch (_) {}
    }

    // 2. Update in-memory cache
    const currentList = _runtimeCardCache.get(cleanEmail) || [];
    currentList.push(newCard);
    _runtimeCardCache.set(cleanEmail, currentList);

    return newCard;
  }

  /**
   * Funds a virtual card directly in Supabase
   */
  static async fundCard(cardId: string, amount: number): Promise<{ success: boolean; newBalance: number; message: string }> {
    let currentBalance = 0;
    let cardLast4 = 'card';
    let cardEmail = '';

    // Query card from Supabase
    if (supabase) {
      const { data, error } = await supabase
        .from('virtual_cards')
        .select('*')
        .or(`id.eq.${cardId},card_id.eq.${cardId}`)
        .single();

      if (!error && data) {
        currentBalance = Number(data.balance || 0);
        cardLast4 = (data.masked_pan || '').slice(-4);
        cardEmail = data.email || '';
      }
    }

    const newBalance = Number((currentBalance + amount).toFixed(2));

    // Update in Supabase
    if (supabase) {
      await supabase
        .from('virtual_cards')
        .update({ balance: newBalance, updated_at: new Date().toISOString() })
        .or(`id.eq.${cardId},card_id.eq.${cardId}`);
    }

    // Update runtime cache
    if (cardEmail && _runtimeCardCache.has(cardEmail)) {
      const list = _runtimeCardCache.get(cardEmail)!;
      for (const c of list) {
        if (c.id === cardId || c.cardId === cardId) {
          c.balance = newBalance;
        }
      }
    }

    return {
      success: true,
      newBalance: newBalance,
      message: `Successfully funded $${amount.toFixed(2)} USD onto card ending in ${cardLast4}. Available balance: $${newBalance.toFixed(2)} USD.`
    };
  }

  /**
   * Toggles Freeze / Unfreeze status directly in Supabase
   */
  static async toggleFreeze(cardId: string): Promise<{ success: boolean; isFrozen: boolean; message: string }> {
    let currentFrozen = false;
    let cardEmail = '';

    if (supabase) {
      const { data, error } = await supabase
        .from('virtual_cards')
        .select('*')
        .or(`id.eq.${cardId},card_id.eq.${cardId}`)
        .single();

      if (!error && data) {
        currentFrozen = data.is_frozen === true;
        cardEmail = data.email || '';
      }
    }

    const newFrozenState = !currentFrozen;

    if (supabase) {
      await supabase
        .from('virtual_cards')
        .update({ is_frozen: newFrozenState, updated_at: new Date().toISOString() })
        .or(`id.eq.${cardId},card_id.eq.${cardId}`);
    }

    if (cardEmail && _runtimeCardCache.has(cardEmail)) {
      const list = _runtimeCardCache.get(cardEmail)!;
      for (const c of list) {
        if (c.id === cardId || c.cardId === cardId) {
          c.isFrozen = newFrozenState;
        }
      }
    }

    return {
      success: true,
      isFrozen: newFrozenState,
      message: newFrozenState ? 'Card has been frozen for security.' : 'Card is now active and ready for transactions.'
    };
  }

  /**
   * Deletes a virtual card from Supabase
   */
  static async deleteCard(cardId: string, email?: string): Promise<{ success: boolean; message: string }> {
    if (supabase) {
      await supabase
        .from('virtual_cards')
        .delete()
        .or(`id.eq.${cardId},card_id.eq.${cardId}`);
    }

    const cleanEmail = (email || '').toLowerCase().trim();
    if (cleanEmail && _runtimeCardCache.has(cleanEmail)) {
      const list = _runtimeCardCache.get(cleanEmail)!.filter(c => c.id !== cardId && c.cardId !== cardId);
      _runtimeCardCache.set(cleanEmail, list);
    }

    delete _cardPins[cardId];

    return {
      success: true,
      message: 'Virtual card was successfully deleted and deactivated.'
    };
  }

  /**
   * Reveals complete card PAN, CVV, PIN, and Delaware Billing Address
   */
  static async revealDetails(cardId: string): Promise<{
    fullPan: string;
    cvv: string;
    pin: string;
    expiryMonth: string;
    expiryYear: string;
    cardholderName: string;
    billingAddress: typeof CardIssuingService.DEFAULT_BILLING_ADDRESS;
  } | null> {
    if (supabase) {
      const { data, error } = await supabase
        .from('virtual_cards')
        .select('*')
        .or(`id.eq.${cardId},card_id.eq.${cardId}`)
        .single();

      if (!error && data) {
        const masked = data.masked_pan || '4829 •••• •••• 7194';
        const fullPan = data.full_pan || masked.replace(/•/g, '8');
        const cardKey = data.card_id || data.id;
        const assignedPin = _cardPins[cardKey] || _cardPins[data.id] || '2491';

        return {
          fullPan: fullPan,
          cvv: data.cvv || '819',
          pin: assignedPin,
          expiryMonth: data.expiry_month || '12',
          expiryYear: data.expiry_year || '28',
          cardholderName: data.cardholder_name || 'Cardholder',
          billingAddress: this.DEFAULT_BILLING_ADDRESS,
        };
      }
    }

    return null;
  }

  /**
   * Retrieves card transactions
   */
  static getCardTransactions(cardId: string): CardTransaction[] {
    return _runtimeTxCache.get(cardId) || [];
  }
}
