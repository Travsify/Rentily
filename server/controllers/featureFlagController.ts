import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';

export interface FeatureFlagsConfig {
  enableVirtualCards: boolean;          // Virtual USD & NGN Visa/Mastercard
  enableMultiCurrencyVault: boolean;    // USD/GBP/EUR Inbound Bank Coordinates
  enableUtilityBills: boolean;          // Electricity Disco & Airtime Desk
  enableStatutoryNotices: boolean;      // Legal Notices & Tenancy Termination
  enableCautionClaims: boolean;         // Security Deposit Claims & Inspections
  maintenanceMode: boolean;             // Emergency System-Wide Maintenance Banner
  updatedAt: string;
}

const DEFAULT_FLAGS: FeatureFlagsConfig = {
  enableVirtualCards: false,          // Off by default pending live provider activation
  enableMultiCurrencyVault: false,    // Off by default pending live banking setup
  enableUtilityBills: true,
  enableStatutoryNotices: true,
  enableCautionClaims: true,
  maintenanceMode: false,
  updatedAt: new Date().toISOString()
};

let _flagCache: FeatureFlagsConfig = { ...DEFAULT_FLAGS };

/**
 * Hydrates live feature flags from Supabase Cloud on server boot
 */
export async function initFeatureFlagsFromSupabase(): Promise<void> {
  if (!supabase) return;
  try {
    const { data, error } = await supabase
      .from('system_configs')
      .select('data')
      .eq('id', 'app_feature_flags')
      .single();

    if (!error && data && data.data) {
      _flagCache = { ...DEFAULT_FLAGS, ...data.data };
      console.log('[FeatureFlags] Hydrated feature flags from Supabase:', _flagCache);
    }
  } catch (err: any) {
    console.warn('[FeatureFlags] Notice on flags hydration:', err.message);
  }
}

export function getStoredFeatureFlags(): FeatureFlagsConfig {
  return _flagCache;
}

export async function saveFeatureFlags(flags: Partial<FeatureFlagsConfig>): Promise<FeatureFlagsConfig> {
  _flagCache = {
    ..._flagCache,
    ...flags,
    updatedAt: new Date().toISOString()
  };

  if (supabase) {
    try {
      await supabase.from('system_configs').upsert({
        id: 'app_feature_flags',
        data: _flagCache,
        updated_at: new Date().toISOString()
      }, { onConflict: 'id' });
      console.log('[FeatureFlags] Saved updated feature flags directly to Supabase.');
    } catch (err: any) {
      console.warn('[FeatureFlags] Supabase save notice:', err.message);
    }
  }

  return _flagCache;
}

export async function getFeatureFlagsHandler(_req: Request, res: Response) {
  if (supabase) {
    try {
      const { data } = await supabase.from('system_configs').select('data').eq('id', 'app_feature_flags').single();
      if (data && data.data) {
        _flagCache = { ...DEFAULT_FLAGS, ...data.data };
      }
    } catch (_) {}
  }

  res.json({
    success: true,
    flags: _flagCache
  });
}

export async function updateFeatureFlagsHandler(req: Request, res: Response) {
  try {
    const updated = await saveFeatureFlags(req.body);
    res.json({
      success: true,
      message: 'Feature flags updated successfully. Changes are now live across mobile and web.',
      flags: updated
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}
