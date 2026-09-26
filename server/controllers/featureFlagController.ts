import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';

export interface FeatureFlagsConfig {
  enableVirtualCards: boolean;          // Virtual USD & NGN Visa/Mastercard
  enableMultiCurrencyVault: boolean;    // USD/GBP/EUR Inbound Bank Coordinates
  enableUtilityBills: boolean;          // Electricity Disco & Airtime Desk
  enableStatutoryNotices: boolean;      // Legal Notices & Tenancy Termination
  enableCautionClaims: boolean;         // Security Deposit Claims & Inspections
  maintenanceMode: boolean;             // Emergency System-Wide Maintenance Banner
  requirePhoneVerification: boolean;    // Phone SMS OTP requirement toggle
  enablePhoneOtp: boolean;              // SMS gateway toggle
  latestVersionCode: number;           // Latest mobile build code (e.g. 10)
  latestVersionName: string;           // Latest human release version (e.g. 1.1.0)
  minRequiredVersionCode: number;      // Force-update cutoff code
  apkDownloadUrl: string;              // Direct APK link hosted on VPS
  playStoreUrl: string;                // Google Play Store URL
  updateTitle: string;                 // Notification/prompt header
  updateMessage: string;               // Release summary for installed users
  forceUpdate: boolean;                // Whether users must update to continue
  updatedAt: string;
}

const DEFAULT_FLAGS: FeatureFlagsConfig = {
  enableVirtualCards: true,           // Active across all users
  enableMultiCurrencyVault: false,    // Off by default pending live banking setup
  enableUtilityBills: true,
  enableStatutoryNotices: true,
  enableCautionClaims: true,
  maintenanceMode: false,
  requirePhoneVerification: false,    // Waived pending Termii activation
  enablePhoneOtp: false,              // Waived
  latestVersionCode: 10,
  latestVersionName: '1.1.0',
  minRequiredVersionCode: 8,
  apkDownloadUrl: 'https://api.myrentilly.com/Rentily.apk',
  playStoreUrl: 'https://play.google.com/store/apps/details?id=ng.rentilly.rentilly_mobile',
  updateTitle: '⚡ Rentilly 1.1.0 Update Available',
  updateMessage: 'Upgrade now for 12 new Utility Bills categories (Electricity, Airtime VTU, Cable TV, Water, Tolls, Internet) and 0% caution Co-Living with Split-the-Scroll!',
  forceUpdate: false,
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

export const getFeatureFlags = getStoredFeatureFlags;

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
