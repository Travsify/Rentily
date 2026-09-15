import { supabase } from '../supabaseClient';

export interface UtilityBeneficiary {
  id: string;
  category: 'electricity' | 'airtime' | 'data' | 'cable' | 'internet' | 'water' | 'toll' | 'waste' | string;
  operator: string;             // e.g. 'EKEDC', 'IKEDC', 'MTN', 'Airtel', 'Glo', 'DSTV', 'GOTV'
  customerNumber: string;       // Meter number, Phone number, Smartcard / IUC number
  beneficiaryName: string;      // Customer name from DisCo/Cable verification or user label
  address?: string;             // DisCo service address (if available)
  meterType?: 'prepaid' | 'postpaid';
  lastAmount?: number;
  lastPlan?: string;            // Data plan or cable bouquet
  createdAt: string;
  updatedAt: string;
}

export class UtilityBeneficiaryService {
  private static memCache: Map<string, UtilityBeneficiary[]> = new Map();

  /**
   * Normalize email for key consistency
   */
  private static getKey(email: string): string {
    return `util_beneficiaries_${email.toLowerCase().trim()}`;
  }

  /**
   * Normalize account / customer number for matching (strips spaces and hyphens)
   */
  private static cleanNumber(num: string): string {
    return (num || '').replace(/[\s\-_]/g, '').trim();
  }

  /**
   * Fetch all saved utility beneficiaries for a user
   */
  static async getBeneficiaries(email: string, category?: string): Promise<UtilityBeneficiary[]> {
    const cleanEmail = email.toLowerCase().trim();
    if (!cleanEmail) return [];

    let list: UtilityBeneficiary[] = [];

    // 1. Check in-memory cache first
    if (this.memCache.has(cleanEmail)) {
      list = this.memCache.get(cleanEmail)!;
    } else if (supabase) {
      // 2. Fetch from Supabase system_configs
      try {
        const { data, error } = await supabase
          .from('system_configs')
          .select('data')
          .eq('id', this.getKey(cleanEmail))
          .maybeSingle();

        if (!error && data?.data) {
          list = Array.isArray(data.data) ? data.data : (data.data.beneficiaries || []);
          this.memCache.set(cleanEmail, list);
        }
      } catch (err: any) {
        console.warn('[UtilityBeneficiaryService] Fetch warning:', err.message);
      }
    }

    // 3. Filter by category if specified
    if (category) {
      const catClean = category.toLowerCase().trim();
      list = list.filter(b => b.category.toLowerCase().trim() === catClean);
    }

    // Sort by most recently updated
    return list.sort((a, b) => new Date(b.updatedAt || 0).getTime() - new Date(a.updatedAt || 0).getTime());
  }

  /**
   * Auto-save or update a utility beneficiary
   */
  static async saveBeneficiary(
    email: string,
    params: {
      category: string;
      operator: string;
      customerNumber: string;
      beneficiaryName?: string;
      address?: string;
      meterType?: 'prepaid' | 'postpaid';
      lastAmount?: number;
      lastPlan?: string;
    }
  ): Promise<UtilityBeneficiary | null> {
    const cleanEmail = email.toLowerCase().trim();
    const rawNumber = (params.customerNumber || '').trim();
    const targetNumber = this.cleanNumber(rawNumber);

    if (!cleanEmail || !targetNumber) return null;

    const cat = params.category.toLowerCase().trim();
    const now = new Date().toISOString();

    // Default friendly beneficiary name if none provided
    let bName = (params.beneficiaryName || '').trim();
    if (!bName || bName === rawNumber || bName === targetNumber) {
      if (cat === 'airtime' || cat === 'data') {
        bName = `${params.operator || 'Mobile'} (${rawNumber})`;
      } else if (cat === 'electricity') {
        bName = `${params.operator || 'DisCo'} Meter`;
      } else if (cat === 'cable') {
        bName = `${params.operator || 'Cable'} Decoder`;
      } else {
        bName = `${params.operator || 'Utility'} Beneficiary`;
      }
    }

    // Load current list
    let all = await this.getBeneficiaries(cleanEmail);

    // Look for existing beneficiary with same customer number and category
    const existingIndex = all.findIndex(b =>
      this.cleanNumber(b.customerNumber) === targetNumber &&
      b.category.toLowerCase().trim() === cat
    );

    let savedItem: UtilityBeneficiary;

    if (existingIndex >= 0) {
      const existing = all[existingIndex];
      savedItem = {
        ...existing,
        operator: params.operator || existing.operator,
        customerNumber: rawNumber,
        beneficiaryName: (params.beneficiaryName && params.beneficiaryName !== rawNumber)
          ? params.beneficiaryName
          : existing.beneficiaryName,
        address: params.address || existing.address,
        meterType: params.meterType || existing.meterType,
        lastAmount: params.lastAmount ?? existing.lastAmount,
        lastPlan: params.lastPlan ?? existing.lastPlan,
        updatedAt: now,
      };
      all[existingIndex] = savedItem;
    } else {
      savedItem = {
        id: `ub_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
        category: cat,
        operator: params.operator || 'Utility',
        customerNumber: rawNumber,
        beneficiaryName: bName,
        address: params.address,
        meterType: params.meterType,
        lastAmount: params.lastAmount,
        lastPlan: params.lastPlan,
        createdAt: now,
        updatedAt: now,
      };
      all.unshift(savedItem);
    }

    // Keep top 60 most recent beneficiaries per user
    if (all.length > 60) {
      all = all.slice(0, 60);
    }

    // Update memory cache
    this.memCache.set(cleanEmail, all);

    // Persist in Supabase system_configs
    if (supabase) {
      try {
        await supabase.from('system_configs').upsert({
          id: this.getKey(cleanEmail),
          data: all,
          updated_at: now
        }, { onConflict: 'id' });
        console.log(`[UtilityBeneficiaryService] ✅ Saved ${cat} beneficiary for ${cleanEmail}: ${bName} (${rawNumber})`);
      } catch (err: any) {
        console.warn('[UtilityBeneficiaryService] Upsert notice:', err.message);
      }
    }

    return savedItem;
  }

  /**
   * Delete a saved utility beneficiary
   */
  static async deleteBeneficiary(email: string, id: string): Promise<boolean> {
    const cleanEmail = email.toLowerCase().trim();
    if (!cleanEmail || !id) return false;

    let all = await this.getBeneficiaries(cleanEmail);
    const filtered = all.filter(b => b.id !== id);

    this.memCache.set(cleanEmail, filtered);

    if (supabase) {
      try {
        await supabase.from('system_configs').upsert({
          id: this.getKey(cleanEmail),
          data: filtered,
          updated_at: new Date().toISOString()
        }, { onConflict: 'id' });
        return true;
      } catch (err: any) {
        console.warn('[UtilityBeneficiaryService] Delete warning:', err.message);
      }
    }
    return true;
  }
}
