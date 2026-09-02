import dotenv from 'dotenv';
import { KorapayService } from './korapayService';
import { supabase } from '../supabaseClient';

dotenv.config();

export interface VirtualBankAccount {
  currency: 'NGN' | 'USD' | 'GBP' | 'EUR';
  currencySymbol: string;
  currencyName: string;
  flagEmoji: string;
  balance: number;
  bankName: string;
  accountNumber: string;
  accountName: string;
  routingNumber?: string; // ACH / ABA for USD
  sortCode?: string;      // UK Sort code for GBP
  iban?: string;          // IBAN for EUR
  swiftBic?: string;      // SWIFT/BIC
  status: 'ACTIVE' | 'PENDING' | 'MAINTENANCE';
  railType: string;
}

export class MultiCurrencyService {
  // Exchange Rates relative to NGN
  private static fxRates: Record<string, number> = {
    'USD_NGN': 1510.00,
    'GBP_NGN': 1980.00,
    'EUR_NGN': 1660.00,
    'NGN_USD': 1 / 1510.00,
    'NGN_GBP': 1 / 1980.00,
    'NGN_EUR': 1 / 1660.00,
  };

  /**
   * Hydrates live FX rates from Supabase Cloud on server boot
   */
  static async initFromSupabase(): Promise<void> {
    if (!supabase) return;
    try {
      const { data, error } = await supabase
        .from('system_configs')
        .select('data')
        .eq('id', 'system_fx_rates')
        .single();

      if (!error && data && data.data) {
        this.fxRates = { ...this.fxRates, ...data.data };
        console.log('[MultiCurrencyService] Hydrated live FX rates from Supabase:', this.fxRates);
      }
    } catch (e: any) {
      console.warn('[MultiCurrencyService] Notice on FX hydration:', e.message);
    }
  }

  static getFxRates(): Record<string, number> {
    return { ...this.fxRates };
  }

  static async updateFxRates(newRates: { USD_NGN?: number; GBP_NGN?: number; EUR_NGN?: number }): Promise<Record<string, number>> {
    if (newRates.USD_NGN && newRates.USD_NGN > 0) {
      this.fxRates['USD_NGN'] = newRates.USD_NGN;
      this.fxRates['NGN_USD'] = 1 / newRates.USD_NGN;
    }
    if (newRates.GBP_NGN && newRates.GBP_NGN > 0) {
      this.fxRates['GBP_NGN'] = newRates.GBP_NGN;
      this.fxRates['NGN_GBP'] = 1 / newRates.GBP_NGN;
    }
    if (newRates.EUR_NGN && newRates.EUR_NGN > 0) {
      this.fxRates['EUR_NGN'] = newRates.EUR_NGN;
      this.fxRates['NGN_EUR'] = 1 / newRates.EUR_NGN;
    }

    if (supabase) {
      await supabase.from('system_configs').upsert({
        id: 'system_fx_rates',
        data: this.fxRates,
        updated_at: new Date().toISOString()
      }, { onConflict: 'id' });
      console.log('[MultiCurrencyService] Saved updated FX rates directly to Supabase.');
    }

    return { ...this.fxRates };
  }

  /**
   * Generates or retrieves institutional multi-currency virtual accounts for a user via Korapay & Supabase
   */
  static async getUserMultiCurrencyAccounts(email: string, fullName: string): Promise<VirtualBankAccount[]> {
    const cleanEmail = (email || '').trim().toLowerCase();
    const cleanName = (fullName || 'Valued User').trim();

    // 1. Query Supabase virtual_bank_accounts first
    if (supabase && cleanEmail) {
      try {
        const { data: dbAccounts } = await supabase
          .from('virtual_bank_accounts')
          .select('*')
          .eq('email', cleanEmail);

        if (dbAccounts && dbAccounts.length > 0) {
          const result: VirtualBankAccount[] = dbAccounts.map((acc: any) => ({
            currency: acc.currency,
            currencySymbol: acc.currency === 'USD' ? '$' : acc.currency === 'GBP' ? '£' : acc.currency === 'EUR' ? '€' : '₦',
            currencyName: acc.currency === 'USD' ? 'US Dollars' : acc.currency === 'GBP' ? 'British Pounds' : acc.currency === 'EUR' ? 'Euros' : 'Nigerian Naira',
            flagEmoji: acc.currency === 'USD' ? '🇺🇸' : acc.currency === 'GBP' ? '🇬🇧' : acc.currency === 'EUR' ? '🇪🇺' : '🇳🇬',
            balance: 0.00,
            bankName: acc.bank_name || 'Standard Chartered (Intl)',
            accountNumber: acc.account_number || '',
            accountName: acc.account_name || cleanName,
            routingNumber: acc.routing_number,
            sortCode: acc.sort_code,
            iban: acc.iban,
            swiftBic: acc.swift_bic,
            status: (acc.status || 'ACTIVE') as 'ACTIVE' | 'PENDING' | 'MAINTENANCE',
            railType: acc.rail_type || 'Direct Inbound Rail'
          }));
          return result;
        }
      } catch (_) {}
    }

    return [];
  }
}
