import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';

export interface BlacklistEntry {
  id: string;
  fullName: string;
  phoneNumber?: string;
  bvn?: string;
  nin?: string;
  bankAccountNumber?: string;
  bankName?: string;
  flagReason: string;
  severity: 'low' | 'medium' | 'high' | 'critical';
  flaggedBy: string;
  isActive: boolean;
  createdAt: string;
}

let _blacklistCache: BlacklistEntry[] = [];

/**
 * Hydrate blacklist from Supabase on server boot
 */
export async function initBlacklistFromSupabase(): Promise<void> {
  if (!supabase) return;
  try {
    const { data, error } = await supabase
      .from('system_configs')
      .select('data')
      .eq('id', 'fraud_blacklist')
      .single();

    if (!error && data && Array.isArray(data.data)) {
      _blacklistCache = data.data;
      console.log(`[FraudController] Hydrated ${_blacklistCache.length} blacklisted entities from Supabase.`);
    }
  } catch (err: any) {
    console.warn('[FraudController] Notice on blacklist hydration:', err.message);
  }
}

async function saveBlacklist(entries: BlacklistEntry[]): Promise<void> {
  _blacklistCache = entries;
  if (supabase) {
    try {
      await supabase.from('system_configs').upsert({
        id: 'fraud_blacklist',
        data: entries,
        updated_at: new Date().toISOString()
      }, { onConflict: 'id' });
    } catch (e) {
      console.error('[FraudController] Error saving blacklist to Supabase:', e);
    }
  }
}

export async function getBlacklist(_req: Request, res: Response) {
  if (supabase) {
    try {
      const { data } = await supabase.from('system_configs').select('data').eq('id', 'fraud_blacklist').single();
      if (data && Array.isArray(data.data)) {
        _blacklistCache = data.data;
      }
    } catch (_) {}
  }
  res.json({ success: true, count: _blacklistCache.length, blacklist: _blacklistCache });
}

export async function addToBlacklist(req: Request, res: Response) {
  try {
    const { fullName, phoneNumber, bvn, nin, bankAccountNumber, bankName, flagReason, severity = 'high', flaggedBy = 'Rentilly Admin' } = req.body;

    if (!fullName || !flagReason) {
      return res.status(400).json({ error: 'Full name and flag reason are required.' });
    }

    const newEntry: BlacklistEntry = {
      id: `BLK-${Date.now()}`,
      fullName,
      phoneNumber,
      bvn,
      nin,
      bankAccountNumber,
      bankName,
      flagReason,
      severity,
      flaggedBy,
      isActive: true,
      createdAt: new Date().toISOString()
    };

    const current = [..._blacklistCache];
    current.unshift(newEntry);
    await saveBlacklist(current);

    res.json({ success: true, message: `${fullName} has been added to the fraud blacklist in Supabase.`, entry: newEntry });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function checkBlacklist(req: Request, res: Response) {
  try {
    const { phoneNumber, bvn, nin, bankAccountNumber } = req.query;
    const all = _blacklistCache;

    const matched = all.filter(entry => {
      if (!entry.isActive) return false;
      if (phoneNumber && entry.phoneNumber && entry.phoneNumber.includes(phoneNumber.toString())) return true;
      if (bvn && entry.bvn && entry.bvn === bvn.toString()) return true;
      if (nin && entry.nin && entry.nin === nin.toString()) return true;
      if (bankAccountNumber && entry.bankAccountNumber && entry.bankAccountNumber === bankAccountNumber.toString()) return true;
      return false;
    });

    res.json({
      isFlagged: matched.length > 0,
      matchCount: matched.length,
      matches: matched
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}
