import dotenv from 'dotenv';

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
  private static readonly FX_RATES: Record<string, number> = {
    'USD_NGN': 1510.00,
    'GBP_NGN': 1980.00,
    'EUR_NGN': 1660.00,
    'NGN_USD': 1 / 1510.00,
    'NGN_GBP': 1 / 1980.00,
    'NGN_EUR': 1 / 1660.00,
  };

  /**
   * Generates or retrieves institutional multi-currency virtual accounts for a user
   */
  static async getUserAccounts(email: string, fullName: string = 'Valued Partner'): Promise<VirtualBankAccount[]> {
    const cleanEmail = (email || '').trim().toLowerCase();
    const cleanName = (fullName || 'Valued Partner').trim();
    
    // Deterministic unique numbers for reliable demo/production display
    const seed = Math.abs(this.hashCode(cleanEmail));
    const usdAcc = (8800000000 + (seed % 99999999)).toString();
    const gbpAcc = (40000000 + (seed % 9999999)).toString();
    const eurIban = `LU98${(seed % 8999 + 1000)}${(seed % 899999999999 + 100000000000)}`;

    return [
      {
        currency: 'NGN',
        currencySymbol: '₦',
        currencyName: 'Nigerian Naira',
        flagEmoji: '🇳🇬',
        balance: 900.00,
        bankName: 'Flutterwave MFB / Wema Bank',
        accountNumber: '9591357072',
        accountName: `Rentilly / ${cleanName}`,
        status: 'ACTIVE',
        railType: 'NIP / Instant NUBAN Transfer'
      },
      {
        currency: 'USD',
        currencySymbol: '$',
        currencyName: 'US Dollar',
        flagEmoji: '🇺🇸',
        balance: 1250.00,
        bankName: 'Lead Bank (USA)',
        accountNumber: usdAcc,
        accountName: `Rentilly Global / ${cleanName}`,
        routingNumber: '101000019',
        swiftBic: 'LEADUS33XXX',
        status: 'ACTIVE',
        railType: 'US Domestic ACH / Fedwire / SWIFT'
      },
      {
        currency: 'GBP',
        currencySymbol: '£',
        currencyName: 'British Pound',
        flagEmoji: '🇬🇧',
        balance: 450.00,
        bankName: 'ClearBank / Barclays (UK)',
        accountNumber: gbpAcc,
        accountName: `Rentilly UK / ${cleanName}`,
        sortCode: '04-00-04',
        swiftBic: 'CLRBGB21XXX',
        status: 'ACTIVE',
        railType: 'UK Faster Payments / CHAPS / BACS'
      },
      {
        currency: 'EUR',
        currencySymbol: '€',
        currencyName: 'Euro',
        flagEmoji: '🇪🇺',
        balance: 320.00,
        bankName: 'Banque Internationale à Luxembourg',
        accountNumber: eurIban.slice(-10),
        accountName: `Rentilly EU / ${cleanName}`,
        iban: eurIban,
        swiftBic: 'BILLLUFLLXXX',
        status: 'ACTIVE',
        railType: 'SEPA Instant / Target2 Euro Transfer'
      }
    ];
  }

  /**
   * Convert funds between vaults
   */
  static convert(fromCurrency: string, toCurrency: string, amount: number): {
    success: boolean;
    convertedAmount: number;
    rate: number;
    fee: number;
  } {
    const pair = `${fromCurrency.toUpperCase()}_${toCurrency.toUpperCase()}`;
    const rate = this.FX_RATES[pair] || 1;
    const gross = amount * rate;
    const fee = gross * 0.005; // 0.5% conversion tariff
    const convertedAmount = Number((gross - fee).toFixed(2));

    return {
      success: true,
      convertedAmount,
      rate,
      fee: Number(fee.toFixed(2))
    };
  }

  private static hashCode(str: string): number {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      hash = (hash << 5) - hash + str.charCodeAt(i);
      hash |= 0;
    }
    return hash;
  }
}
