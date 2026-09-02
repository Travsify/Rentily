import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';
import { TransactionStore } from '../services/transactionStore';
import { AdminDataStore } from '../services/adminDataStore';
import { UserStore } from '../services/userStore';

export async function getMetrics(_req: Request, res: Response) {
  try {
    // === Live wallet data from TransactionStore ===
    const allWalletTxs = TransactionStore.getAllTransactions();
    const successfulCredits = allWalletTxs.filter(t => t.isCredit && t.status === 'SUCCESSFUL');
    const totalGMV = successfulCredits.reduce((sum, t) => sum + t.amount, 0);
    const totalRentillyCommission = Math.round(totalGMV * 0.10);
    const activeEscrowHeld = successfulCredits
      .filter(t => t.category === 'deposit' || t.category === 'escrow' || t.category === 'rent')
      .reduce((sum, t) => sum + t.amount, 0);

    // === Properties from AdminDataStore (seeded + Supabase fallback) ===
    const properties = AdminDataStore.getProperties();
    let supabaseProps: any[] = [];
    if (supabase) {
      try {
        const { data } = await supabase.from('properties').select('id, status');
        supabaseProps = data || [];
      } catch (_) {}
    }
    const allPropsForCount = supabaseProps.length > 0 ? supabaseProps : properties;
    const verifiedProperties = allPropsForCount.filter((p: any) => p.status === 'verified').length;
    const totalProperties = allPropsForCount.length;

    // === KYP from AdminDataStore ===
    const kyps = AdminDataStore.getKYP();
    let supabaseKyps: any[] = [];
    if (supabase) {
      try {
        const { data } = await supabase.from('kyp_verifications').select('id, status');
        supabaseKyps = data || [];
      } catch (_) {}
    }
    const allKyps = supabaseKyps.length > 0 ? supabaseKyps : kyps;
    const pendingKYP = allKyps.filter((k: any) => k.status === 'pending').length;

    // === Inspections from AdminDataStore ===
    const inspections = AdminDataStore.getInspections();
    let supabaseInsps: any[] = [];
    if (supabase) {
      try {
        const { data } = await supabase.from('inspections').select('id, status');
        supabaseInsps = data || [];
      } catch (_) {}
    }
    const allInsps = supabaseInsps.length > 0 ? supabaseInsps : inspections;
    const activeInspections = allInsps.filter((i: any) => i.status === 'confirmed' || i.status === 'pending_owner').length;

    // === Total Users from UserStore ===
    const allUsers = UserStore.getAllUsers();
    let totalUsers = allUsers.length;
    if (supabase) {
      try {
        const { count } = await supabase.from('profiles').select('id', { count: 'exact', head: true });
        if (count && count > totalUsers) totalUsers = count;
      } catch (_) {}
    }

    res.json({
      totalGMV,
      totalRentillyCommission,
      activeEscrowHeld,
      verifiedProperties,
      pendingKYP,
      activeInspections,
      totalProperties,
      totalUsers,
      liveTransactionsCount: allWalletTxs.length,
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}
