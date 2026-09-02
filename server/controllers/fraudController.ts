import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';
import fs from 'fs';
import path from 'path';

function getDataDir(): string {
  const candidates = [
    path.join(process.cwd(), 'server', 'data'),
    path.join('/opt/render/project/src', 'server', 'data'),
    path.join('/tmp', 'rentilly-data'),
  ];
  for (const dir of candidates) {
    try {
      if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
      return dir;
    } catch { continue; }
  }
  return '/tmp';
}

interface BlacklistEntry {
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

let _blacklistCache: BlacklistEntry[] | null = null;

function getBlacklistFile(): string {
  return path.join(getDataDir(), 'admin_blacklist.json');
}

function readBlacklist(): BlacklistEntry[] {
  if (_blacklistCache !== null) {
    return _blacklistCache;
  }
  try {
    const file = getBlacklistFile();
    if (fs.existsSync(file)) {
      const content = fs.readFileSync(file, 'utf-8');
      const parsed = JSON.parse(content || '[]');
      if (Array.isArray(parsed)) {
        _blacklistCache = parsed;
        return _blacklistCache;
      }
    }
  } catch {}
  _blacklistCache = [];
  return _blacklistCache;
}

function writeBlacklist(data: BlacklistEntry[]): void {
  _blacklistCache = data;
  try {
    const file = getBlacklistFile();
    fs.writeFileSync(file, JSON.stringify(data, null, 2), 'utf-8');
  } catch {}
}

export async function getBlacklist(_req: Request, res: Response) {
  try {
    // Primary: local store
    const local = readBlacklist();

    // Secondary: Supabase
    if (supabase) {
      try {
        const { data, error } = await supabase
          .from('fraud_blacklist')
          .select('*')
          .order('created_at', { ascending: false });

        if (!error && data && data.length > 0) {
          const supabaseMapped = data.map((row: any) => ({
            id: row.id,
            fullName: row.full_name,
            phoneNumber: row.phone_number,
            bvn: row.bvn,
            nin: row.nin,
            bankAccountNumber: row.bank_account_number,
            bankName: row.bank_name,
            flagReason: row.flag_reason,
            severity: row.severity,
            flaggedBy: row.flagged_by,
            isActive: row.is_active,
            createdAt: row.created_at
          }));
          const localIds = new Set(local.map(e => e.id));
          const missing = supabaseMapped.filter(e => !localIds.has(e.id));
          return res.json([...local, ...missing]);
        }
      } catch (_) {}
    }

    res.json(local);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function addToBlacklist(req: Request, res: Response) {
  try {
    const { fullName, phoneNumber, bvn, nin, bankAccountNumber, bankName, flagReason, severity } = req.body;

    if (!fullName || !flagReason) {
      return res.status(400).json({ error: 'Full name and flag reason are required.' });
    }

    const newEntry: BlacklistEntry = {
      id: `bl_${Date.now()}`,
      fullName: String(fullName).toUpperCase(),
      phoneNumber,
      bvn,
      nin,
      bankAccountNumber,
      bankName,
      flagReason,
      severity: severity || 'high',
      flaggedBy: 'Rentilly Anti-Fraud Desk (Admin)',
      isActive: true,
      createdAt: new Date().toISOString(),
    };

    // Save locally
    const all = readBlacklist();
    all.unshift(newEntry);
    writeBlacklist(all);

    // Save to Supabase if available
    if (supabase) {
      try {
        await supabase
          .from('fraud_blacklist')
          .insert({
            id: newEntry.id,
            full_name: newEntry.fullName,
            phone_number: newEntry.phoneNumber || null,
            bvn: newEntry.bvn || null,
            nin: newEntry.nin || null,
            bank_account_number: newEntry.bankAccountNumber || null,
            bank_name: newEntry.bankName || null,
            flag_reason: newEntry.flagReason,
            severity: newEntry.severity,
            flagged_by: newEntry.flaggedBy,
          });
      } catch (_) {}
    }

    res.status(201).json(newEntry);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function deleteFromBlacklist(req: Request, res: Response) {
  try {
    const { id } = req.params;

    const all = readBlacklist().filter(e => e.id !== id);
    writeBlacklist(all);

    if (supabase) {
      try {
        await supabase.from('fraud_blacklist').delete().eq('id', id);
      } catch (_) {}
    }

    res.json({ success: true, message: 'Entity removed from blacklist.' });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function checkBlacklist(req: Request, res: Response) {
  try {
    const { phone, bvn, nin } = req.body;
    const all = readBlacklist();

    let match: BlacklistEntry | undefined;
    if (phone) match = all.find(e => e.phoneNumber === phone && e.isActive);
    if (!match && bvn) match = all.find(e => e.bvn === bvn && e.isActive);
    if (!match && nin) match = all.find(e => e.nin === nin && e.isActive);

    if (match) {
      return res.json({ isBlacklisted: true, record: match });
    }

    if (supabase) {
      try {
        let query = supabase.from('fraud_blacklist').select('*').eq('is_active', true);
        if (phone) query = query.eq('phone_number', phone);
        else if (bvn) query = query.eq('bvn', bvn);
        else if (nin) query = query.eq('nin', nin);

        const { data } = await query;
        if (data && data.length > 0) {
          return res.json({ isBlacklisted: true, record: data[0] });
        }
      } catch (_) {}
    }

    res.json({ isBlacklisted: false });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}
