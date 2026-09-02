import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';
import fs from 'fs';
import path from 'path';

const DATA_DIR = path.join(process.cwd(), 'server', 'data');
const BLACKLIST_FILE = path.join(DATA_DIR, 'admin_blacklist.json');

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

function seedBlacklist(): BlacklistEntry[] {
  return [
    {
      id: 'bl_001',
      fullName: 'JOHN DOTUN ADESANYA',
      phoneNumber: '+2348012345678',
      nin: '98765432100',
      bankAccountNumber: '0123456789',
      bankName: 'Access Bank',
      flagReason: 'Serial rental fraud — posed as landlord, collected deposits on properties not owned. 3 verified complaints.',
      severity: 'critical',
      flaggedBy: 'Rentilly Anti-Fraud Desk (Admin)',
      isActive: true,
      createdAt: new Date().toISOString(),
    },
    {
      id: 'bl_002',
      fullName: 'GRACE OBIAGELI NWACHUKWU',
      phoneNumber: '+2348087654321',
      bvn: '22109876543',
      flagReason: 'Forged utility bills and land documents submitted for KYP verification. Case filed at EFCC.',
      severity: 'high',
      flaggedBy: 'Rentilly KYP Legal Officer',
      isActive: true,
      createdAt: new Date().toISOString(),
    },
  ];
}

function readBlacklist(): BlacklistEntry[] {
  if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
  if (!fs.existsSync(BLACKLIST_FILE)) {
    const seed = seedBlacklist();
    fs.writeFileSync(BLACKLIST_FILE, JSON.stringify(seed, null, 2), 'utf-8');
    return seed;
  }
  try {
    const content = fs.readFileSync(BLACKLIST_FILE, 'utf-8');
    const parsed = JSON.parse(content || '[]');
    if (!Array.isArray(parsed) || parsed.length === 0) {
      const seed = seedBlacklist();
      fs.writeFileSync(BLACKLIST_FILE, JSON.stringify(seed, null, 2), 'utf-8');
      return seed;
    }
    return parsed;
  } catch {
    return seedBlacklist();
  }
}

function writeBlacklist(data: BlacklistEntry[]): void {
  if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
  fs.writeFileSync(BLACKLIST_FILE, JSON.stringify(data, null, 2), 'utf-8');
}

export async function getBlacklist(_req: Request, res: Response) {
  try {
    // Try Supabase first
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
          // Merge with local seed
          const local = readBlacklist();
          const supabaseIds = new Set(supabaseMapped.map((e: any) => e.id));
          const extra = local.filter(e => !supabaseIds.has(e.id));
          return res.json([...supabaseMapped, ...extra]);
        }
      } catch (_) {}
    }

    // Fallback: local file store
    res.json(readBlacklist());
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

    // Try Supabase
    if (supabase) {
      try {
        const { data, error } = await supabase
          .from('fraud_blacklist')
          .insert({
            full_name: newEntry.fullName,
            phone_number: newEntry.phoneNumber || null,
            bvn: newEntry.bvn || null,
            nin: newEntry.nin || null,
            bank_account_number: newEntry.bankAccountNumber || null,
            bank_name: newEntry.bankName || null,
            flag_reason: newEntry.flagReason,
            severity: newEntry.severity,
            flagged_by: newEntry.flaggedBy,
          })
          .select()
          .single();

        if (!error && data) {
          // Also save to local store
          const all = readBlacklist();
          all.unshift({ ...newEntry, id: data.id });
          writeBlacklist(all);
          return res.status(201).json(data);
        }
      } catch (_) {}
    }

    // Fallback: local only
    const all = readBlacklist();
    all.unshift(newEntry);
    writeBlacklist(all);
    res.status(201).json(newEntry);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function deleteFromBlacklist(req: Request, res: Response) {
  try {
    const { id } = req.params;

    if (supabase) {
      try {
        await supabase.from('fraud_blacklist').delete().eq('id', id);
      } catch (_) {}
    }

    // Always update local store
    const all = readBlacklist().filter(e => e.id !== id);
    writeBlacklist(all);

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

    // Also check Supabase if connected
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
