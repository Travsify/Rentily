import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';

export async function getBlacklist(_req: Request, res: Response) {
  try {
    if (!supabase) return res.json([]);

    const { data, error } = await supabase
      .from('fraud_blacklist')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) return res.json([]);

    const mapped = (data || []).map((row: any) => ({
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

    res.json(mapped);
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

    if (!supabase) return res.status(500).json({ error: 'Database unavailable' });

    const { data, error } = await supabase
      .from('fraud_blacklist')
      .insert({
        full_name: fullName,
        phone_number: phoneNumber || null,
        bvn: bvn || null,
        nin: nin || null,
        bank_account_number: bankAccountNumber || null,
        bank_name: bankName || null,
        flag_reason: flagReason,
        severity: severity || 'high',
        flagged_by: 'Rentilly Anti-Fraud Desk (Admin)'
      })
      .select()
      .single();

    if (error) throw new Error(error.message);
    res.status(201).json(data);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function deleteFromBlacklist(req: Request, res: Response) {
  try {
    const { id } = req.params;
    if (!supabase) return res.status(500).json({ error: 'Database unavailable' });

    const { error } = await supabase
      .from('fraud_blacklist')
      .delete()
      .eq('id', id);

    if (error) throw new Error(error.message);
    res.json({ success: true, message: 'Entity removed from blacklist.' });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function checkBlacklist(req: Request, res: Response) {
  try {
    const { phone, bvn, nin } = req.body;
    if (!supabase) return res.json({ isBlacklisted: false });

    let query = supabase.from('fraud_blacklist').select('*').eq('is_active', true);
    
    if (phone) query = query.eq('phone_number', phone);
    else if (bvn) query = query.eq('bvn', bvn);
    else if (nin) query = query.eq('nin', nin);

    const { data } = await query;

    if (data && data.length > 0) {
      return res.json({
        isBlacklisted: true,
        record: data[0]
      });
    }

    res.json({ isBlacklisted: false });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}
