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
          const seenIds = new Set(transactions.map(t => t.id));
          const seenRefs = new Set(transactions.map(t => t.reference).filter(Boolean));

          for (const d of data) {
            const txRef = d.payment_reference || d.reference || d.id;
            // Skip if this transaction was already loaded via TransactionStore or Maplerad
            if (seenIds.has(d.id) || seenRefs.has(txRef) || (d.payment_reference && seenRefs.has(d.payment_reference))) {
              continue;
            }

            const isWithdrawal = d.transaction_type === 'withdrawal' || 
              (typeof txRef === 'string' && (txRef.startsWith('WD_') || txRef.startsWith('RENTILLY_WD_')));

            transactions.push({
              id: d.id,
              userId: d.user_id || d.payer_id,
              email: d.payer_name || 'user@rentilly.ng',
              title: d.owner_payout_reference || d.property_title || `Transaction #${d.id.slice(0, 8)}`,
              type: isWithdrawal ? 'withdrawal' : (d.transaction_type || 'escrow'),
              category: isWithdrawal ? 'withdrawal' : ((d.category as any) || 'escrow'),
              amount: Number(d.total_amount || d.amount || 0),
              isCredit: isWithdrawal ? false : (d.escrow_status === 'released_to_owner'),
              reference: txRef,
              status: (d.escrow_status === 'released_to_owner' || d.status === 'SUCCESSFUL' || isWithdrawal) ? 'SUCCESSFUL' : 'PENDING',
              escrowStatus: d.escrow_status,
              date: d.created_at
            });

            seenIds.add(d.id);
            if (txRef) seenRefs.add(txRef);
          }
        }
      } catch (_) {}
    }

    // Live sync all Maplerad transactions for Admin Master Ledger
    const mapleKey = process.env.MAPLERAD_SECRET_KEY;
    if (mapleKey) {
      try {
        const mapleRes = await fetch('https://api.maplerad.com/v1/transactions?page=1&page_size=50', {
          headers: { 'Authorization': `Bearer ${mapleKey}`, 'Accept': 'application/json' }
        });
        if (mapleRes.ok) {
          const mapleData = await mapleRes.json();
          if (mapleData?.status && Array.isArray(mapleData.data)) {
            const seen = new Set(transactions.map(t => t.id));
            for (const mTx of mapleData.data) {
              const txId = `MAPLERAD_${mTx.id}`;
              if (seen.has(txId)) continue;
              const isCredit = (mTx.entry || '').toUpperCase() === 'CREDIT';
              const amt = Number(mTx.amount || 0) / 100;
              const customerEmail = mTx.customer?.email || 'admin@myrentilly.com';
              const narration = mTx.summary || mTx.reason || `Maplerad ${mTx.type || 'Transaction'}`;

              transactions.push({
                id: txId,
                userId: mTx.customer?.id || 'admin_treasury',
                email: customerEmail,
                title: narration,
                type: mTx.type || (isCredit ? 'credit' : 'debit'),
                category: (mTx.type === 'CARD' ? 'wallet_funding' : (isCredit ? 'deposit' : 'withdrawal')),
                amount: amt,
                currency: mTx.currency || 'NGN',
                isCredit,
                reference: mTx.reference || mTx.id,
                status: (mTx.status || '').toUpperCase() === 'SUCCESS' ? 'SUCCESSFUL' : 'PENDING',
                beneficiary: mTx.destination?.address || mTx.destination?.account_number || undefined,
                date: mTx.created_at || new Date().toISOString()
              });
              seen.add(txId);
            }
          }
        }
      } catch (err: any) {
        console.warn('[getMasterLedger] Maplerad live sync notice:', err?.message || err);
      }
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
