import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';

export interface PlatformFeeConfig {
  withdrawalFee: number;            // ₦ flat fee on bank withdrawals (default 50)
  electricityFee: number;           // ₦ convenience fee on Disco tokens (default 100)
  airtimeDataMarginPct: number;     // % margin on airtime/data (default 2.5)
  rentLegalFeePct: number;          // % on rent leases (default 10)
  saleEscrowFeePct: number;         // % on sales (default 5)
  partnerCommissionRentPct: number; // % partner commission rent (default 2.5)
  partnerCommissionSalePct: number; // % partner commission sale (default 2.0)
  depositStampDuty: number;         // ₦ stamp duty on deposits (default 50)
  minWithdrawal: number;            // ₦ minimum bank withdrawal (default 500)
  maxWithdrawal: number;            // ₦ maximum daily withdrawal (default 5000000)
  updatedAt: string;
}

const DEFAULT_FEES: PlatformFeeConfig = {
  withdrawalFee: 50,
  electricityFee: 100,
  airtimeDataMarginPct: 2.5,
  rentLegalFeePct: 10.0,
  saleEscrowFeePct: 5.0,
  partnerCommissionRentPct: 2.5,
  partnerCommissionSalePct: 2.0,
  depositStampDuty: 50,
  minWithdrawal: 500,
  maxWithdrawal: 5000000,
  updatedAt: new Date().toISOString()
};

let _feeCache: PlatformFeeConfig = { ...DEFAULT_FEES };

/**
 * Hydrates fees from Supabase Cloud on server boot
 */
export async function initFeesFromSupabase(): Promise<void> {
  if (!supabase) return;
  try {
    const { data, error } = await supabase
      .from('system_configs')
      .select('data')
      .eq('id', 'platform_fees')
      .single();

    if (!error && data && data.data) {
      _feeCache = { ...DEFAULT_FEES, ...data.data };
      console.log('[FeeController] Hydrated platform fees from Supabase:', _feeCache);
    }
  } catch (err: any) {
    console.warn('[FeeController] Notice on fee hydration:', err.message);
  }
}

export function getStoredFees(): PlatformFeeConfig {
  return _feeCache;
}

export async function saveStoredFees(fees: PlatformFeeConfig): Promise<void> {
  _feeCache = fees;
  if (supabase) {
    try {
      await supabase.from('system_configs').upsert({
        id: 'platform_fees',
        data: fees,
        updated_at: new Date().toISOString()
      }, { onConflict: 'id' });
      console.log('[FeeController] Saved updated platform fees directly to Supabase.');
    } catch (err) {
      console.error('[FeeController] Failed to save platform fees to Supabase:', err);
    }
  }
}

export async function getFees(_req: Request, res: Response) {
  // Always verify with Supabase on read
  if (supabase) {
    try {
      const { data } = await supabase.from('system_configs').select('data').eq('id', 'platform_fees').single();
      if (data && data.data) {
        _feeCache = { ...DEFAULT_FEES, ...data.data };
      }
    } catch (_) {}
  }
  res.json({ success: true, fees: _feeCache });
}

export async function updateFees(req: Request, res: Response) {
  try {
    const current = getStoredFees();
    const updated: PlatformFeeConfig = {
      ...current,
      ...req.body,
      updatedAt: new Date().toISOString()
    };
    await saveStoredFees(updated);
    res.json({ success: true, message: 'Platform fees updated successfully in Supabase', fees: updated });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}
