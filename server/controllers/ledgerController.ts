import type { Request, Response } from 'express';
import { TransactionStore, WalletTransaction } from '../services/transactionStore';
import { getStoredFees } from './feeController';
import { supabase } from '../supabaseClient';

export async function getMasterLedger(req: Request, res: Response) {
  try {
    const { category, search, limit = '100', offset = '0' } = req.query;
    let transactions = TransactionStore.getAllTransactions();

    // Also pull transactions from Supabase if available
    if (supabase) {
      try {
        const { data } = await supabase
          .from('transactions')
          .select('*')
          .order('created_at', { ascending: false })
          .limit(100);

        if (data && data.length > 0) {
          const mapped: WalletTransaction[] = data.map((d: any) => ({
            id: d.id,
            userId: d.user_id || d.payer_id,
            email: d.payer_name || 'user@rentilly.ng',
            title: d.property_title || `Transaction #${d.id.slice(0, 8)}`,
            type: d.transaction_type || 'escrow',
            category: (d.category as any) || 'escrow',
            amount: Number(d.total_amount || d.amount || 0),
            isCredit: false,
            reference: d.reference || d.id,
            status: (d.escrow_status === 'released_to_owner' || d.status === 'SUCCESSFUL') ? 'SUCCESSFUL' : 'PENDING',
            escrowStatus: d.escrow_status,
            date: d.created_at
          }));

          // Merge without duplicates
          const seen = new Set(transactions.map(t => t.id));
          for (const m of mapped) {
            if (!seen.has(m.id)) {
              transactions.push(m);
              seen.add(m.id);
            }
          }
        }
      } catch (_) {}
    }

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
        t.title.toLowerCase().includes(q) ||
        t.reference.toLowerCase().includes(q) ||
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

      if (tx.category === 'withdrawal') {
        totalWithdrawals += amt;
        totalFeesCollected += fees.withdrawalFee;
      } else if (tx.category === 'deposit' || tx.category === 'wallet_funding') {
        totalDeposits += amt;
        if (amt >= 10000) totalFeesCollected += fees.depositStampDuty;
      } else if (tx.category === 'utility') {
        totalUtilityVolume += amt;
        totalFeesCollected += fees.electricityFee;
      } else if (tx.category === 'rent') {
        totalFeesCollected += Math.round(amt * (fees.rentLegalFeePct / 100));
      } else if (tx.category === 'escrow') {
        totalFeesCollected += Math.round(amt * (fees.saleEscrowFeePct / 100));
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
    const all = TransactionStore.getAllTransactions();
    const utilities = all.filter(t => t.category === 'utility' || t.title.toLowerCase().includes('electricity') || t.title.toLowerCase().includes('airtime') || t.title.toLowerCase().includes('data'));

    res.json({
      success: true,
      count: utilities.length,
      utilities
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}
