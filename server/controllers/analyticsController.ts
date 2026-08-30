import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';

export async function getMetrics(_req: Request, res: Response) {
  try {
    if (!supabase) {
      return res.json({
        totalGMV: 0,
        totalRentillyCommission: 0,
        activeEscrowHeld: 0,
        verifiedProperties: 0,
        pendingKYP: 0,
        activeInspections: 0,
        totalProperties: 0,
        totalUsers: 0
      });
    }

    // Run parallel live queries
    const [txnsRes, propsRes, kypRes, inspsRes, usersRes] = await Promise.all([
      supabase.from('transactions').select('total_amount, rentilly_legal_fee, escrow_status'),
      supabase.from('properties').select('id, status'),
      supabase.from('kyp_verifications').select('id, status'),
      supabase.from('inspections').select('id, status'),
      supabase.from('profiles').select('id', { count: 'exact' })
    ]);

    const txns = txnsRes.data || [];
    const props = propsRes.data || [];
    const kyps = kypRes.data || [];
    const insps = inspsRes.data || [];

    const totalGMV = txns.reduce((sum, t) => sum + Number(t.total_amount || 0), 0);
    const totalRentillyCommission = txns.reduce((sum, t) => sum + Number(t.rentilly_legal_fee || 0), 0);
    const activeEscrowHeld = txns
      .filter(t => t.escrow_status === 'held_in_escrow')
      .reduce((sum, t) => sum + Number(t.total_amount || 0), 0);

    const verifiedProperties = props.filter(p => p.status === 'verified').length;
    const pendingKYP = kyps.filter(k => k.status === 'pending').length;
    const activeInspections = insps.filter(i => i.status === 'confirmed').length;

    res.json({
      totalGMV,
      totalRentillyCommission,
      activeEscrowHeld,
      verifiedProperties,
      pendingKYP,
      activeInspections,
      totalProperties: props.length,
      totalUsers: usersRes.count || 0
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}
