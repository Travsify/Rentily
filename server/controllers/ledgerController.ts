import type { Request, Response } from 'express';
import { TransactionStore, WalletTransaction } from '../services/transactionStore';
import { getStoredFees } from './feeController';
import { supabase } from '../supabaseClient';

export async function getMasterLedger(req: Request, res: Response) {
  try {
    const { category, search, limit = '100', offset = '0' } = req.query;
    // Always ensure fresh canonical state synced from Supabase
    await TransactionStore.syncFromSupabase();
    let transactions = [...TransactionStore.getAllTransactions()];

    // Sort descending by date
    transactions.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());

    // Filter by category
    if (category && category !== 'all') {
      transactions = transactions.filter(t => t.category === category || t.type === category);
    }

    // Search query
    if (search) {
      const q = String(search).toLowerCase();
      transactions = transactions.filter(t => 
        t.title?.toLowerCase().includes(q) ||
        t.reference?.toLowerCase().includes(q) ||
        (t.email && t.email.toLowerCase().includes(q)) ||
        (t.beneficiary && t.beneficiary.toLowerCase().includes(q)) ||
        (t.recipientAccount && t.recipientAccount.includes(q))
      );
    }

    const total = transactions.length;
    const paginated = transactions.slice(Number(offset), Number(offset) + Number(limit));

    res.json({
      success: true,
      total,
      transactions: paginated
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function getLedgerStats(_req: Request, res: Response) {
  try {
    await TransactionStore.syncFromSupabase();
    const transactions = TransactionStore.getAllTransactions();
    const fees = getStoredFees();

    let totalVolume = 0;
    let totalDeposits = 0;
    let totalWithdrawals = 0;
    let totalUtilityVolume = 0;
    let totalFeesCollected = 0;

    for (const tx of transactions) {
      const amt = Number(tx.amount || 0);
      totalVolume += amt;

      if (tx.category === 'withdrawal' || (!tx.isCredit && tx.category !== 'wallet_funding')) {
        totalWithdrawals += amt;
        totalFeesCollected += (fees.withdrawalFee || 65);
      } else if (tx.category === 'deposit' || tx.category === 'wallet_funding' || tx.isCredit) {
        totalDeposits += amt;
        if (amt >= 10000) totalFeesCollected += (fees.depositStampDuty || 50);
      } else if (tx.category === 'utility') {
        totalUtilityVolume += amt;
        totalFeesCollected += (fees.electricityFee || 100);
      } else if (tx.category === 'rent') {
        totalFeesCollected += Math.round(amt * ((fees.rentLegalFeePct || 5) / 100));
      } else if (tx.category === 'escrow') {
        totalFeesCollected += Math.round(amt * ((fees.saleEscrowFeePct || 2) / 100));
      }
    }

    res.json({
      success: true,
      stats: {
        totalVolume,
        totalDeposits,
        totalWithdrawals,
        totalUtilityVolume,
        totalFeesCollected,
        transactionCount: transactions.length,
        feeConfig: fees
      }
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function getUtilityTransactions(_req: Request, res: Response) {
  try {
    await TransactionStore.syncFromSupabase();
    const all = TransactionStore.getAllTransactions();
    const utilities = all.filter(t => 
      t.category === 'utility' || 
      t.type?.toLowerCase().includes('utility') ||
      t.type?.toLowerCase().includes('airtime') ||
      t.type?.toLowerCase().includes('data') ||
      t.type?.toLowerCase().includes('electricity') ||
      t.type?.toLowerCase().includes('cable') ||
      t.title?.toLowerCase().includes('electricity') || 
      t.title?.toLowerCase().includes('airtime') || 
      t.title?.toLowerCase().includes('data') ||
      t.title?.toLowerCase().includes('cable') ||
      t.title?.toLowerCase().includes('token')
    );

    res.json({
      success: true,
      count: utilities.length,
      utilities
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}
