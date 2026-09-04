import dotenv from 'dotenv';
import { supabase } from '../supabaseClient';

dotenv.config();

export interface VirtualAccountResult {
  bankName: string;
  accountNumber: string;
  accountName: string;
  currency: string;
  provider: 'MAPLERAD';
  rawId?: string;
}

export interface UsdtTronAddressResult {
  address: string;
  chain: 'TRC20 (TRON)';
  coin: 'USDT';
  active: boolean;
}

export interface BankTransferResult {
  success: boolean;
  reference: string;
  transferId?: string;
  status?: string;
  message?: string;
}

export interface Tier1ProvisionResult {
  success: boolean;
  mapleradCustomerId?: string;
  mapleradTier?: number;
  accountNumber?: string;
  bankName?: string;
  usdtTronAddress?: string;
  message: string;
  errors?: string[];
}

export class MapleradBankingService {
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
   * Normalizes any incoming Date of Birth to strict DD-MM-YYYY format
   */
  static normalizeDob(raw?: string): string {
    if (!raw || !raw.trim()) return '01-01-1990';
    const cleaned = raw.trim().replace(/[\/\.]/g, '-');
    const parts = cleaned.split('-');
    if (parts.length === 3) {
      if (parts[0].length === 4) {
        // YYYY-MM-DD -> DD-MM-YYYY
        return `${parts[2].padStart(2, '0')}-${parts[1].padStart(2, '0')}-${parts[0]}`;
      }
      // DD-MM-YYYY
      return `${parts[0].padStart(2, '0')}-${parts[1].padStart(2, '0')}-${parts[2]}`;
    }
    return cleaned;
  }

  /**
   * 1. Resolves or Enrolls Customer (Tier 1 Eligible)
   */
  static async resolveOrEnrollCustomer(params: {
    email: string;
    fullName: string;
    phoneNumber?: string;
    nin?: string;
  }): Promise<string | null> {
    const cleanEmail = params.email.trim().toLowerCase();
    const nameParts = params.fullName.trim().split(' ');
    const firstName = nameParts[0] || 'Rentilly';
    const lastName = nameParts.slice(1).join(' ') || 'Partner';
    const rawPhone = (params.phoneNumber || '').replace(/\D/g, '');
    const cleanPhone = rawPhone.length === 11 && rawPhone.startsWith('0') ? rawPhone.substring(1) : (rawPhone.length >= 10 ? rawPhone.slice(-10) : '8000000000');

    try {
      // Check existing customer
      const getRes = await fetch(`${this.baseUrl}/customers?page=1&page_size=50`, {
        headers: this.headers
      });
      const getData = await getRes.json().catch(() => ({}));
      if (getData?.status && Array.isArray(getData?.data)) {
        const cust = getData.data.find((c: any) => c.email?.toLowerCase().trim() === cleanEmail);
        if (cust) {
          console.log(`[MapleradBanking] Resolved existing customer ID: ${cust.id} for ${cleanEmail} (Tier: ${cust.tier})`);
          return cust.id;
        }
      }

      // Enroll new Tier 1 customer directly
      console.log(`[MapleradBanking] Enrolling new customer for ${cleanEmail}...`);
      const enrollRes = await fetch(`${this.baseUrl}/customers/enroll`, {
        method: 'POST',
        headers: this.headers,
        body: JSON.stringify({
          first_name: firstName,
          last_name: lastName,
          email: cleanEmail,
          phone: {
            phone_country_code: '+234',
            phone_number: cleanPhone
          },
          dob: params.dob || '01-01-1990',
          identification_number: params.nin || params.bvn || '',
          address: {
            street: 'Admiralty Way, Lekki Phase 1',
            city: 'Lagos',
            state: 'Lagos',
            postal_code: '105102',
            country: 'NG'
          }
        })
      });

      const enrollData = await enrollRes.json().catch(() => ({}));
      if (enrollData?.status && enrollData?.data?.id) {
        console.log(`[MapleradBanking] Enrolled customer ID: ${enrollData.data.id}`);
        return enrollData.data.id;
      }

      // Fallback simple registration
      const simpleRes = await fetch(`${this.baseUrl}/customers`, {
        method: 'POST',
        headers: this.headers,
        body: JSON.stringify({
          first_name: firstName,
          last_name: lastName,
          email: cleanEmail,
          country: 'NG'
        })
      });
      const simpleData = await simpleRes.json().catch(() => ({}));
      return simpleData?.data?.id || null;
    } catch (err: any) {
      console.error('[MapleradBanking] resolveOrEnrollCustomer error:', err.message);
      return null;
    }
  }

  /**
   * 2. Creates a Dedicated NGN Virtual Account (9PSB / WEMA)
   */
  static async createVirtualAccount(params: {
    email: string;
    fullName: string;
    phoneNumber?: string;
  }): Promise<VirtualAccountResult | null> {
    const customerId = await this.resolveOrEnrollCustomer(params);
    if (!customerId) return null;

    try {
      console.log(`[MapleradBanking] Generating NGN Virtual Account for ${params.email}...`);
      const res = await fetch(`${this.baseUrl}/collections/virtual-account`, {
        method: 'POST',
        headers: this.headers,
        body: JSON.stringify({
          customer_id: customerId,
          currency: 'NGN'
        })
      });

      const data = await res.json().catch(() => ({}));
      if (data?.status && data?.data?.account_number) {
        return {
          bankName: data.data.bank_name || '9PSB',
          accountNumber: data.data.account_number,
          accountName: data.data.account_name || params.fullName,
          currency: 'NGN',
          provider: 'MAPLERAD',
          rawId: data.data.id
        };
      }

      console.warn('[MapleradBanking] Virtual account generation returned:', data?.message);
      return null;
    } catch (err: any) {
      console.error('[MapleradBanking] createVirtualAccount error:', err.message);
      return null;
    }
  }

  /**
   * 3. Creates or Retrieves Dedicated USDT Wallet on TRON (TRC20)
   */
  static async getOrCreateUsdtTronAddress(params: {
    email: string;
    fullName: string;
  }): Promise<UsdtTronAddressResult | null> {
    const cleanEmail = params.email.trim().toLowerCase();

    // 1. Check Supabase cache
    if (supabase) {
      try {
        const { data: config } = await supabase
          .from('system_configs')
          .select('data')
          .eq('id', `crypto_tron_${cleanEmail}`)
          .single();

        if (config?.data?.address) {
          return {
            address: config.data.address,
            chain: 'TRC20 (TRON)',
            coin: 'USDT',
            active: true
          };
        }
      } catch (_) {}
    }

    // 2. Generate on Maplerad
    const customerId = await this.resolveOrEnrollCustomer(params);
    if (!customerId) return null;

    try {
      console.log(`[MapleradBanking] Generating USDT TRON address for ${cleanEmail}...`);
      const res = await fetch(`${this.baseUrl}/crypto`, {
        method: 'POST',
        headers: this.headers,
        body: JSON.stringify({
          customer_id: customerId,
          coin: 'USDT',
          chain: 'tron',
          offramp: false
        })
      });

      const data = await res.json().catch(() => ({}));
      if (data?.status && data?.data?.address) {
        const result: UsdtTronAddressResult = {
          address: data.data.address,
          chain: 'TRC20 (TRON)',
          coin: 'USDT',
          active: true
        };

        // Cache in Supabase system_configs
        if (supabase) {
          await supabase.from('system_configs').upsert({
            id: `crypto_tron_${cleanEmail}`,
            data: {
              ...result,
              rawId: data.data.id,
              customerId: customerId,
              email: cleanEmail,
              updatedAt: new Date().toISOString()
            }
          });
        }

        return result;
      }

      console.warn('[MapleradBanking] USDT address creation returned:', data?.message);
      return null;
    } catch (err: any) {
      console.error('[MapleradBanking] getOrCreateUsdtTronAddress error:', err.message);
      return null;
    }
  }

  /**
   * 4. Instant Bank Transfer / Withdrawal Payout
   */
  static async transferToBank(params: {
    accountNumber: string;
    bankCode: string;
    amountNgn: number;
    narration: string;
    reference: string;
  }): Promise<BankTransferResult> {
    try {
      console.log(`[MapleradBanking] Initiating payout: ?${params.amountNgn} to ${params.accountNumber} (${params.bankCode})...`);
      const res = await fetch(`${this.baseUrl}/transfers`, {
        method: 'POST',
        headers: this.headers,
        body: JSON.stringify({
          bank_code: params.bankCode,
          account_number: params.accountNumber,
          amount: Math.round(params.amountNgn * 100), // in kobo
          currency: 'NGN',
          reason: params.narration,
          reference: params.reference
        })
      });

      const data = await res.json().catch(() => ({}));
      if (data?.status && data?.data) {
        return {
          success: true,
          reference: data.data.reference || params.reference,
          transferId: data.data.id,
          status: data.data.status || 'SUCCESSFUL',
          message: data.message || 'Transfer completed successfully'
        };
      }

      return {
        success: false,
        reference: params.reference,
        message: data?.message || 'Maplerad transfer was rejected'
      };
    } catch (err: any) {
      console.error('[MapleradBanking] transferToBank error:', err.message);
      return {
        success: false,
        reference: params.reference,
        message: err.message
      };
    }
  }

  /**
   * 5. Bank Account Name Enquiry / Resolution
   */
  static async resolveBankAccount(params: {
    accountNumber: string;
    bankCode: string;
  }): Promise<{ accountName?: string; success: boolean; message?: string }> {
    try {
      const res = await fetch(`${this.baseUrl}/institutions/resolve`, {
        method: 'POST',
        headers: this.headers,
        body: JSON.stringify({
          account_number: params.accountNumber,
          bank_code: params.bankCode
        })
      });

      const data = await res.json().catch(() => ({}));
      if (data?.status && data?.data?.account_name) {
        return {
          success: true,
          accountName: data.data.account_name
        };
      }

      return {
        success: false,
        message: data?.message || 'Unable to resolve account name'
      };
    } catch (err: any) {
      return { success: false, message: err.message };
    }
  }

  /**
   * 6. List of Nigerian Banks
   */
  static async getInstitutions(): Promise<Array<{ name: string; code: string }>> {
    try {
      const res = await fetch(`${this.baseUrl}/institutions?country=NG`, {
        headers: this.headers
      });
      const data = await res.json().catch(() => ({}));
      if (data?.status && Array.isArray(data?.data)) {
        return data.data.map((b: any) => ({ name: b.name, code: b.code }));
      }
      return [];
    } catch (err: any) {
      console.error('[MapleradBanking] getInstitutions error:', err.message);
      return [];
    }
  }

  /**
   * 7. Direct Crypto / Stablecoin Withdrawal
   */
  static async withdrawCrypto(params: {
    address: string;
    amountUsdt: number;
    reference: string;
    chain?: string;
    reason?: string;
  }): Promise<{ success: boolean; reference: string; message?: string; data?: any }> {
    try {
      console.log(`[MapleradBanking] Initiating crypto withdrawal of ${params.amountUsdt} USDT to ${params.address}...`);
      const res = await fetch(`${this.baseUrl}/crypto/transfer`, {
        method: 'POST',
        headers: this.headers,
        body: JSON.stringify({
          amount: Math.round(params.amountUsdt * 100), // in cents
          reference: params.reference,
          reason: params.reason || 'Rentilly USDT Withdrawal',
          address: params.address,
          chain: params.chain || 'solana',
          coin: 'usdt',
          funding_source: 'USD'
        })
      });

      const data = await res.json().catch(() => ({}));
      if (data?.status && data?.data) {
        return {
          success: true,
          reference: data.data.reference || params.reference,
          data: data.data,
          message: data.message || 'Crypto withdrawal dispatched'
        };
      }

      return {
        success: false,
        reference: params.reference,
        message: data?.message || 'Crypto withdrawal request failed'
      };
    } catch (err: any) {
      console.error('[MapleradBanking] withdrawCrypto error:', err.message);
      return {
        success: false,
        reference: params.reference,
        message: err.message
      };
    }
  }

  /**
   * 7b. FX Currency Exchange (e.g. USDT -> NGN, or USDT -> USD)
   */
  static async exchangeCurrency(params: {
    sourceCurrency: string;
    targetCurrency: string;
    amount: number;
  }): Promise<{ success: boolean; targetAmount?: number; rate?: number; error?: string }> {
    try {
      // 1. Get quote
      const quoteRes = await fetch(`${this.baseUrl}/fx/quote`, {
        method: 'POST',
        headers: this.headers,
        body: JSON.stringify({
          source_currency: params.sourceCurrency.toUpperCase(),
          target_currency: params.targetCurrency.toUpperCase(),
          amount: Math.round(params.amount * 100)
        })
      });
      const quoteData = await quoteRes.json().catch(() => ({}));
      if (!quoteData?.status || !quoteData?.data?.reference) {
        return { success: false, error: quoteData?.message || 'Could not generate FX quote' };
      }

      // 2. Execute swap
      const fxRes = await fetch(`${this.baseUrl}/fx`, {
        method: 'POST',
        headers: this.headers,
        body: JSON.stringify({
          quote_reference: quoteData.data.reference
        })
      });
      const fxData = await fxRes.json().catch(() => ({}));
      if (fxData?.status && fxData?.data) {
        return {
          success: true,
          targetAmount: fxData.data.target?.human_readable_amount,
          rate: fxData.data.rate
        };
      }
      return { success: false, error: fxData?.message || 'FX exchange execution failed' };
    } catch (e: any) {
      return { success: false, error: e.message };
    }
  }

  /**
   * 7c. Fund SPEND Wallet from TREASURY for Card Issuing
   */
  static async fundSpendWallet(currency: string, amount: number): Promise<boolean> {
    try {
      const res = await fetch(`${this.baseUrl}/wallets/fund`, {
        method: 'POST',
        headers: this.headers,
        body: JSON.stringify({
          currency: currency.toUpperCase(),
          source_wallet_type: 'TREASURY',
          destination_wallet_type: 'SPEND',
          amount: Math.round(amount * 100)
        })
      });
      const data = await res.json().catch(() => ({}));
      return data?.status === true;
    } catch (_) {
      return false;
    }
  }

  /**
   * 8. ONE-SHOT KYC TIER 1 PROVISIONER
   * Called after identity verification / when user submits KYC or DOB.
   * Enrolls user at Maplerad Tier 1, provisions their dedicated Maplerad NGN VBA
   * and personal USDT TRC20 address, and persists all data to Supabase while preserving wallet balance.
   */
  static async enrollAndProvisionTier1(params: {
    email: string;
    fullName: string;
    phoneNumber?: string;
    nin?: string;
    bvn?: string;
    dob?: string;
  }): Promise<Tier1ProvisionResult> {
    const cleanEmail = params.email.trim().toLowerCase();
    const errors: string[] = [];
    let mapleradCustomerId: string | undefined;
    let mapleradTier = 0;
    let accountNumber: string | undefined;
    let bankName: string | undefined;
    let usdtTronAddress: string | undefined;

    const nameParts = (params.fullName || 'Rentilly User').trim().split(' ');
    const firstName = nameParts[0] || 'Rentilly';
    const lastName = nameParts.slice(1).join(' ') || 'User';
    const rawPhone = (params.phoneNumber || '').replace(/\D/g, '');
    const cleanPhone = rawPhone.length === 11 && rawPhone.startsWith('0')
      ? rawPhone.substring(1) : (rawPhone.length >= 10 ? rawPhone.slice(-10) : '8000000000');
    const dob = this.normalizeDob(params.dob);

    console.log(`[MapleradTier1] Starting Tier 1 enrollment for ${cleanEmail}...`);

    // Step A: Check if existing profile already has maplerad data
    if (supabase) {
      try {
        const { data: cached } = await supabase
          .from('profiles')
          .select('maplerad_customer_id, maplerad_tier, account_number, bank_name, usdt_tron_address')
          .eq('email', cleanEmail)
          .maybeSingle();

        if (cached?.maplerad_customer_id) {
          mapleradCustomerId = cached.maplerad_customer_id;
          mapleradTier = cached.maplerad_tier || 0;
        }
      } catch (_) {}
    }

    // Step B: Resolve or Enroll Customer on Maplerad
    try {
      if (!mapleradCustomerId) {
        const getRes = await fetch(`${this.baseUrl}/customers?page=1&page_size=50`, {
          headers: this.headers,
          signal: AbortSignal.timeout(8000)
        });
        const getData = await getRes.json().catch(() => ({}));
        if (getData?.status && Array.isArray(getData?.data)) {
          const match = getData.data.find((c: any) => c.email?.toLowerCase().trim() === cleanEmail);
          if (match) {
            mapleradCustomerId = match.id;
            mapleradTier = match.tier ?? 0;
            console.log(`[MapleradTier1] Resolved existing customer ${mapleradCustomerId} for ${cleanEmail} (Tier ${mapleradTier})`);
          }
        }
      }

      // Try NIN first (most reliably validated by Maplerad), then BVN as fallback
      const bvnNumber = (params.bvn && params.bvn.trim().length === 11) ? params.bvn.trim() : '';
      const ninNumber = (params.nin && params.nin.trim().length === 11) ? params.nin.trim() : '';
      // NIN prioritized — Maplerad validates NIN more reliably in production
      const primaryId  = ninNumber || bvnNumber || params.nin || params.bvn || '';
      const fallbackId = bvnNumber && primaryId !== bvnNumber ? bvnNumber : '';

      // Helper: build shared enroll/upgrade payload
      const buildIdPayload = (idNum: string) => ({
        dob,
        identification_number: idNum,
        phone: { phone_country_code: '+234', phone_number: cleanPhone },
        address: {
          street: '14 Admiralty Way, Lekki Phase 1',
          city: 'Lagos',
          state: 'Lagos',
          country: 'NG',
          postal_code: '105102'
        }
      });

      if (mapleradCustomerId) {
        // Step B1: Sync customer name so upgrade doesn't fail on name mismatch
        if (firstName && lastName) {
          try {
            await fetch(`${this.baseUrl}/customers/update`, {
              method: 'PATCH',
              headers: this.headers,
              body: JSON.stringify({ customer_id: mapleradCustomerId, first_name: firstName, last_name: lastName })
            });
          } catch (_) {}
        }

        // Try upgrade with primary ID (NIN), then retry with BVN if it fails
        console.log(`[MapleradTier1] Upgrading existing customer ${mapleradCustomerId} to Tier 1...`);
        const tryUpgrade = async (idNum: string) => {
          const r = await fetch(`${this.baseUrl}/customers/upgrade/tier1`, {
            method: 'PATCH',
            headers: this.headers,
            signal: AbortSignal.timeout(15000),
            body: JSON.stringify({ customer_id: mapleradCustomerId, ...buildIdPayload(idNum) })
          });
          return r.json().catch(() => ({}));
        };

        let upgradeData = await tryUpgrade(primaryId);
        if (!upgradeData?.status && fallbackId) {
          console.warn(`[MapleradTier1] Primary ID upgrade failed (${upgradeData?.message}), retrying with fallback ID...`);
          upgradeData = await tryUpgrade(fallbackId);
        }

        if (upgradeData?.status && upgradeData?.data?.id) {
          mapleradTier = upgradeData.data.tier ?? 1;
          console.log(`[MapleradTier1] ✅ Upgraded customer ${mapleradCustomerId} to Tier ${mapleradTier}`);
        } else {
          console.error(`[MapleradTier1] ❌ Tier 1 upgrade failed:`, upgradeData);
          errors.push(upgradeData?.message || 'Tier 1 upgrade failed');
        }
      } else {
        // Enroll new customer — try primary ID (NIN), then BVN fallback
        const tryEnroll = async (idNum: string) => {
          console.log(`[MapleradTier1] Enrolling new customer for ${cleanEmail} with ID: ${idNum.substring(0,4)}...`);
          const r = await fetch(`${this.baseUrl}/customers/enroll`, {
            method: 'POST',
            headers: this.headers,
            signal: AbortSignal.timeout(15000),
            body: JSON.stringify({
              first_name: firstName,
              last_name: lastName,
              email: cleanEmail,
              country: 'NG',
              ...buildIdPayload(idNum)
            })
          });
          return r.json().catch(() => ({}));
        };

        let enrollData = await tryEnroll(primaryId);

        // If primary fails and we have a fallback, retry with BVN
        if (!enrollData?.status && fallbackId) {
          console.warn(`[MapleradTier1] NIN enroll failed (${enrollData?.message}), retrying with BVN...`);
          enrollData = await tryEnroll(fallbackId);
        }

        if (enrollData?.status && enrollData?.data?.id) {
          mapleradCustomerId = enrollData.data.id;
          mapleradTier = enrollData.data.tier ?? 1;
          console.log(`[MapleradTier1] ✅ Enrolled ${cleanEmail} -> Customer ID: ${mapleradCustomerId} at Tier ${mapleradTier}`);
        } else if (enrollData?.message?.toLowerCase().includes('already exist') ||
                   enrollData?.message?.toLowerCase().includes('email already')) {
          // Customer already exists from a prior attempt — look them up by email and continue
          console.warn(`[MapleradTier1] Customer already exists for ${cleanEmail}, fetching existing record...`);
          const getRes = await fetch(`${this.baseUrl}/customers?page=1&page_size=100`, {
            headers: this.headers, signal: AbortSignal.timeout(8000)
          });
          const getData = await getRes.json().catch(() => ({}));
          const existing = (getData?.data || []).find((c: any) => c.email?.toLowerCase().trim() === cleanEmail);
          if (existing?.id) {
            mapleradCustomerId = existing.id;
            mapleradTier = existing.tier ?? 0;
            console.log(`[MapleradTier1] ✅ Recovered existing customer ${mapleradCustomerId} (Tier ${mapleradTier})`);
          } else {
            errors.push('Customer already exists but could not be recovered. Please contact support.');
          }
        } else {
          console.error(`[MapleradTier1] ❌ Customer enrollment failed:`, enrollData);
          errors.push(enrollData?.message || 'Customer enrollment failed');
        }
      }
    } catch (e: any) {
      errors.push(`Enrollment network error: ${e.message}`);
    }

    if (!mapleradCustomerId) {
      return {
        success: false,
        message: 'Could not obtain Maplerad customer ID',
        errors
      };
    }

    // Step C: Provision Dedicated Maplerad NGN Virtual Account
    try {
      const vbaRes = await fetch(`${this.baseUrl}/collections/virtual-account`, {
        method: 'POST',
        headers: this.headers,
        signal: AbortSignal.timeout(10000),
        body: JSON.stringify({
          customer_id: mapleradCustomerId,
          currency: 'NGN'
        })
      });
      const vbaData = await vbaRes.json().catch(() => ({}));
      if (vbaData?.status && vbaData?.data?.account_number) {
        accountNumber = vbaData.data.account_number;
        bankName = `${vbaData.data.bank_name || '9PSB'} (Rentilly)`;
        console.log(`[MapleradTier1] ✅ Rentilly NGN Virtual Account: ${accountNumber} via ${bankName}`);
      } else {
        errors.push(`Central settlement account notice: ${vbaData?.message || 'Pending identity confirmation'}`);
      }
    } catch (e: any) {
      errors.push(`VBA error: ${e.message}`);
    }

    // Step D: Provision Dedicated Maplerad USDT TRC20 Address
    try {
      const cryptoRes = await fetch(`${this.baseUrl}/crypto`, {
        method: 'POST',
        headers: this.headers,
        signal: AbortSignal.timeout(10000),
        body: JSON.stringify({
          customer_id: mapleradCustomerId,
          coin: 'USDT',
          chain: 'tron',
          offramp: false
        })
      });
      const cryptoData = await cryptoRes.json().catch(() => ({}));
      if (cryptoData?.status && cryptoData?.data?.address) {
        usdtTronAddress = cryptoData.data.address;
        console.log(`[MapleradTier1] ✅ Maplerad Personal USDT TRC20 Address: ${usdtTronAddress}`);

        if (supabase) {
          await supabase.from('system_configs').upsert({
            id: `crypto_tron_${cleanEmail}`,
            data: {
              address: usdtTronAddress,
              chain: 'TRC20 (TRON)',
              coin: 'USDT',
              active: true,
              rawId: cryptoData.data.id,
              customerId: mapleradCustomerId,
              email: cleanEmail,
              isTreasuryFallback: false,
              updatedAt: new Date().toISOString()
            }
          }, { onConflict: 'id' });
        }
      } else {
        errors.push(`USDT wallet notice: ${cryptoData?.message || 'Pending identity confirmation'}`);
      }
    } catch (e: any) {
      errors.push(`USDT address error: ${e.message}`);
    }

    // Step E: Persist to Supabase profiles (preserving wallet balance!)
    if (supabase) {
      try {
        const updateFields: Record<string, any> = {
          maplerad_customer_id: mapleradCustomerId,
          maplerad_tier: mapleradTier || 1,
          is_verified: true,
          rekyc_required: false,
          kyc_enrolled_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        };
        if (params.dob) updateFields.dob = params.dob;
        if (params.nin) updateFields.nin_number = params.nin;
        if (accountNumber) {
          updateFields.account_number = accountNumber;
          updateFields.bank_name = bankName;
        }
        if (usdtTronAddress) {
          updateFields.usdt_tron_address = usdtTronAddress;
        }

        const { error: upErr } = await supabase
          .from('profiles')
          .update(updateFields)
          .eq('email', cleanEmail);

        if (upErr) {
          // If columns don't exist yet in profiles table, update existing known columns
          await supabase
            .from('profiles')
            .update({
              is_verified: true,
              account_number: accountNumber,
              bank_name: bankName,
              updated_at: new Date().toISOString()
            })
            .eq('email', cleanEmail);
        }

        // Also save Maplerad customer linkage in system_configs for resilience
        await supabase.from('system_configs').upsert({
          id: `maplerad_tier1_${cleanEmail}`,
          data: {
            customerId: mapleradCustomerId,
            tier: mapleradTier,
            accountNumber,
            bankName,
            usdtTronAddress,
            dob,
            updatedAt: new Date().toISOString()
          }
        }, { onConflict: 'id' });

        console.log(`[MapleradTier1] ✅ Persisted Maplerad Tier 1 profile for ${cleanEmail}`);
      } catch (e: any) {
        errors.push(`Supabase persist error: ${e.message}`);
      }
    }

    return {
      success: true,
      mapleradCustomerId,
      mapleradTier,
      accountNumber,
      bankName,
      usdtTronAddress,
      message: `Maplerad Tier 1 setup completed for ${cleanEmail}`,
      errors: errors.length > 0 ? errors : undefined
    };
  }
}
