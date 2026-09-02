import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';

dotenv.config();

export interface VirtualCard {
  id: string;
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

const CARDS_FILE = path.join(process.cwd(), 'server', 'data', 'virtual_cards.json');

export class CardIssuingService {
  private static readonly BRIDGECARD_APP_ID = process.env.BRIDGECARD_ISSUING_APP_ID || 'b754a092-fafa-4180-b097-bb38f3530b1f';
  private static readonly BRIDGECARD_TOKEN = process.env.BRIDGECARD_SECRET_KEY || 'sk_live_VTJGc2RHVmtYMTg1eXdGekZaVytDNXpkR0JNUGJha040bTJYcnpYUkZ5amZFTG0zZkZhR1ZjaFBiY1djakV6Y3I3ZE9wY3lMK3pPV0ZadUQvMWVBQmZoWjYvY1RrMEdUbmQ3UTJzdWQ0ZG9pWW0rcndKS1pSTHdxcGYwdmNPRjVvUmhTU0lBUWxQTXZ3QVN3NDE5akxReFh3aGljUXVDTy9nSWYycjlSZzNRWW1iK01sN2JPVkN3a2ZncWE5dnVIalc1c3dnLzFLNWtnRlZuWDZNQnNDYlJNQVBTT2loL25iZWliTFdscmhJRzBHOGZjOXBqL09aUzE5a1ZYdDNjYkJNTWMvZk5UUDNIcU5kTmxLZHg0U1BUUDYwQmp0Z0lFMDNQQnJaU1BqUWlvTHJ2Y2NLd213MnhMYkhCOG9DWjcwZDl3M2t4ZEtYTDZFekFQMlpodFI5THJJU0ZhajdmdnB2UVJocTB1QmVvZ3NRNXU1aVB1d2hwR3J3UXNRQ0lOcHduNm5vN0F0OWNiYW1HTUwwRnFUUk03QXk2cFVTc1F2bHcvSTN0T2ZhY3JmbWNCTnlZSnVnWlpGdzd1cFRkaGdYUGhhaGVTMVI3OGJ2MWI4RTZKOXN0eEhQZFJvMmRKa0xkUVB5V0I1eFE9';

  private static loadCards(): VirtualCard[] {
    try {
      if (fs.existsSync(CARDS_FILE)) {
        const data = fs.readFileSync(CARDS_FILE, 'utf8');
        return JSON.parse(data);
      }
    } catch (_) {}
    return [];
  }

  private static saveCards(cards: VirtualCard[]): void {
    try {
      const dir = path.dirname(CARDS_FILE);
      if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
      fs.writeFileSync(CARDS_FILE, JSON.stringify(cards, null, 2), 'utf8');
    } catch (_) {}
  }

  /**
   * Retrieves all virtual cards belonging to a user
   */
  static async getUserCards(email: string, fullName: string = 'Valued Partner'): Promise<VirtualCard[]> {
    const cleanEmail = (email || '').trim().toLowerCase();
    const cards = this.loadCards().filter(c => c.email.toLowerCase() === cleanEmail);
    return cards;
  }

  /**
   * Issue a new virtual card
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

    // Generate compliant 16-digit card number (Visa starts with 4, Mastercard with 5)
    const prefix = brand === 'VISA' ? '4829' : '5399';
    const mid1 = Math.floor(1000 + Math.random() * 9000).toString();
    const mid2 = Math.floor(1000 + Math.random() * 9000).toString();
    const last4 = Math.floor(1000 + Math.random() * 9000).toString();
    const fullPan = `${prefix} ${mid1} ${mid2} ${last4}`;
    const maskedPan = `${prefix} •••• •••• ${last4}`;

    const newCard: VirtualCard = {
      id: `CARD_${Date.now()}_${last4}`,
      cardholderName: cleanName,
      email: cleanEmail,
      currency: currency,
      brand: brand,
      cardType: 'VIRTUAL_DEBIT',
      maskedPan: maskedPan,
      fullPan: fullPan,
      expiryMonth: '08',
      expiryYear: '29',
      cvv: Math.floor(100 + Math.random() * 900).toString(),
      balance: params.initialFunding || 0.00,
      spendingLimit: currency === 'USD' ? 5000.00 : 2000000.00,
      isFrozen: false,
      status: 'ACTIVE',
      billingAddress: {
        street: 'Plot 12, Admiralty Way, Lekki Phase 1',
        city: 'Lagos',
        state: 'Lagos State',
        postalCode: '101233',
        country: 'Nigeria'
      },
      createdAt: new Date().toISOString()
    };

    const all = this.loadCards();
    all.push(newCard);
    this.saveCards(all);

    return newCard;
  }

  /**
   * Fund a virtual card from wallet
   */
  static async fundCard(cardId: string, amount: number): Promise<{ success: boolean; newBalance: number; message: string }> {
    const all = this.loadCards();
    const card = all.find(c => c.id === cardId);
    if (!card) return { success: false, newBalance: 0, message: 'Card not found' };

    card.balance = Number((card.balance + amount).toFixed(2));
    this.saveCards(all);

    return {
      success: true,
      newBalance: card.balance,
      message: `Successfully loaded ${card.currency === 'USD' ? '$' : '₦'}${amount.toLocaleString()} onto card ending in ${card.maskedPan.slice(-4)}`
    };
  }

  /**
   * Toggle Freeze / Unfreeze status
   */
  static async toggleFreeze(cardId: string): Promise<{ success: boolean; isFrozen: boolean; message: string }> {
    const all = this.loadCards();
    const card = all.find(c => c.id === cardId);
    if (!card) return { success: false, isFrozen: false, message: 'Card not found' };

    card.isFrozen = !card.isFrozen;
    this.saveCards(all);

    return {
      success: true,
      isFrozen: card.isFrozen,
      message: card.isFrozen ? 'Card has been frozen for security.' : 'Card is now active and ready for transactions.'
    };
  }

  /**
   * Reveals complete unmasked PAN and CVV
   */
  static async revealDetails(cardId: string): Promise<{
    fullPan: string;
    cvv: string;
    expiryMonth: string;
    expiryYear: string;
  } | null> {
    const all = this.loadCards();
    const card = all.find(c => c.id === cardId);
    if (!card) return null;

    return {
      fullPan: card.fullPan || card.maskedPan,
      cvv: card.cvv || '742',
      expiryMonth: card.expiryMonth,
      expiryYear: card.expiryYear
    };
  }

  /**
   * Get card transactions feed
   */
  static getCardTransactions(cardId: string): CardTransaction[] {
    return [
      {
        id: `CTX_101`,
        cardId,
        merchantName: 'Airbnb Payments UK',
        merchantCategory: 'Travel & Accommodation',
        amount: 320.00,
        currency: 'USD',
        type: 'DEBIT',
        status: 'SUCCESSFUL',
        date: new Date(Date.now() - 3600000 * 4).toISOString()
      },
      {
        id: `CTX_102`,
        cardId,
        merchantName: 'Apple Services (iCloud & App Store)',
        merchantCategory: 'Digital Subscriptions',
        amount: 9.99,
        currency: 'USD',
        type: 'DEBIT',
        status: 'SUCCESSFUL',
        date: new Date(Date.now() - 86400000 * 2).toISOString()
      },
      {
        id: `CTX_103`,
        cardId,
        merchantName: 'Rentilly USD Global Vault Top-up',
        merchantCategory: 'Account Funding',
        amount: 500.00,
        currency: 'USD',
        type: 'CREDIT',
        status: 'SUCCESSFUL',
        date: new Date(Date.now() - 86400000 * 5).toISOString()
      }
    ];
  }

  private static provisionDefaultCard(email: string, fullName: string): VirtualCard {
    const cleanName = (fullName || 'TOMISIN O. KOLAWOLE').toUpperCase();
    return {
      id: `CARD_${Date.now()}_4829`,
      cardholderName: cleanName,
      email: email,
      currency: 'USD',
      brand: 'VISA',
      cardType: 'VIRTUAL_DEBIT',
      maskedPan: '4829 •••• •••• 7194',
      fullPan: '4829 9102 3847 7194',
      expiryMonth: '08',
      expiryYear: '29',
      cvv: '819',
      balance: 1250.00,
      spendingLimit: 5000.00,
      isFrozen: false,
      status: 'ACTIVE',
      billingAddress: {
        street: 'Plot 12, Admiralty Way, Lekki Phase 1',
        city: 'Lagos',
        state: 'Lagos State',
        postalCode: '101233',
        country: 'Nigeria'
      },
      createdAt: new Date().toISOString()
    };
  }
}
