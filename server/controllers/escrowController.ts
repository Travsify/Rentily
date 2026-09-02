import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';
import type { Transaction } from '../types';
import { TransactionStore } from '../services/transactionStore';
import { AdminDataStore } from '../services/adminDataStore';

export async function getTransactions(_req: Request, res: Response) {
  try {
    // Primary source: live wallet ledger (TransactionStore)
    const walletTxs = TransactionStore.getAllTransactions();
    const escrowFromWallet = AdminDataStore.buildEscrowTransactions(walletTxs);

    // Secondary source: Supabase (if connected and has data)
    let supabaseTxns: Transaction[] = [];
    if (supabase) {
      try {
        const { data, error } = await supabase
          .from('transactions')
          .select('*, properties(*)')
          .order('created_at', { ascending: false });

        if (!error && data && data.length > 0) {
          supabaseTxns = data.map((row: any) => ({
            id: row.id,
            propertyId: row.property_id || 'wallet_inbound',
            propertyTitle: row.properties?.title || 'Property Transaction',
            payerId: row.payer_id || row.user_id,
            payerName: row.payer_name || 'Buyer / Renter',
            ownerId: row.recipient_owner_id || row.user_id,
            ownerName: row.recipient_owner_name || 'Property Owner',
            transactionType: row.transaction_type || 'rent',
            paymentReference: row.payment_reference,
            paymentGateway: row.payment_gateway || 'flutterwave',
            baseAmount: Number(row.base_price || row.total_amount || 0),
            rentillyLegalFee: Number(row.rentilly_legal_fee || 0),
            cautionFee: Number(row.caution_deposit || 0),
            serviceCharge: Number(row.service_charge || 0),
            totalAmount: Number(row.total_amount || 0),
            escrowStatus: row.escrow_status || 'held_in_escrow',
            ownerPayoutReference: row.owner_payout_reference,
            payoutReleasedAt: row.payout_released_at,
            createdAt: row.created_at
          }));
        }
      } catch (_) {}
    }

    // Merge: prefer Supabase records for IDs that overlap, then wallet-sourced
    const supabaseIds = new Set(supabaseTxns.map(t => t.id));
    const dedupedWallet = escrowFromWallet.filter(t => !supabaseIds.has(t.id));
    const allTxns = [...supabaseTxns, ...dedupedWallet].sort(
      (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    );

    res.json(allTxns);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function releaseEscrowPayout(req: Request, res: Response) {
  try {
    const { id } = req.params;
    const payoutReference = `PAYOUT-RENTILLY-${Date.now()}`;
    const payoutReleasedAt = new Date().toISOString();

    // 1. Always update in local/in-memory TransactionStore
    TransactionStore.updateTransactionStatus(id, 'released_to_owner', payoutReference);

    // 2. Also update Supabase if available
    let txn: any = null;
    if (supabase) {
      try {
        const { data } = await supabase
          .from('transactions')
          .update({
            escrow_status: 'released_to_owner',
            owner_payout_reference: payoutReference,
            payout_released_at: payoutReleasedAt
          })
          .eq('id', id)
          .select()
          .maybeSingle();

        txn = data;

        if (txn && txn.property_id) {
          await supabase
            .from('properties')
            .update({
              status: txn.transaction_type === 'rent' ? 'rented' : 'sold',
              delisted_at: payoutReleasedAt,
              updated_at: payoutReleasedAt
            })
            .eq('id', txn.property_id);
        }
      } catch (_) {}
    }

    res.json({ success: true, transaction: txn, payoutReference, payoutReleasedAt });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function getPartnerCommissions(req: Request, res: Response) {
  try {
    const { partnerId, email } = req.query;

    if (email) {
      const partnerEmail = String(email).toLowerCase().trim();
      const walletTxs = await TransactionStore.getTransactionsByEmail(partnerEmail);
      const creditTxs = walletTxs.filter(t => t.isCredit && t.status === 'SUCCESSFUL');
      const settledTxs = walletTxs.filter(t => !t.isCredit && t.status === 'SUCCESSFUL');

      const escrowBalance = creditTxs.reduce((sum, t) => sum + Math.round(t.amount * 0.025), 0);
      const settledCommissions = settledTxs.reduce((sum, t) => sum + Math.round(t.amount * 0.025), 0);

      return res.json({
        status: true,
        escrowBalance,
        settledCommissions,
        transactions: creditTxs.map(t => ({
          id: t.id,
          propertyTitle: t.title || 'Partner Commission',
          commissionAmount: Math.round(t.amount * 0.025),
          commissionRate: '2.5%',
          escrowStatus: t.escrowStatus || 'held_in_escrow',
          createdAt: t.date
        }))
      });
    }

    if (!supabase) {
      return res.json({ status: true, escrowBalance: 0, settledCommissions: 0, transactions: [] });
    }

    const { data: txns, error } = await supabase
      .from('transactions')
      .select('*, properties(*)')
      .or(`recipient_owner_id.eq.${partnerId},payer_id.eq.${partnerId}`)
      .order('created_at', { ascending: false });

    if (error || !txns) {
      return res.json({ status: true, escrowBalance: 0, settledCommissions: 0, transactions: [] });
    }

    let escrowBalance = 0;
    let settledCommissions = 0;

    const formattedTxns = txns.map((t: any) => {
      const base = Number(t.base_price || t.total_amount || 0);
      const isRent = t.transaction_type === 'rent_deposit' || t.transaction_type === 'rent_renewal';
      const commissionRate = isRent ? 0.025 : 0.020;
      const commissionAmount = Math.round(base * commissionRate);

      if (t.escrow_status === 'held_in_escrow') {
        escrowBalance += commissionAmount;
      } else if (t.escrow_status === 'released_to_owner' || t.escrow_status === 'settled') {
        settledCommissions += commissionAmount;
      }

      return {
        id: t.id,
        propertyTitle: t.properties?.title || 'Mandate Listing',
        commissionAmount,
        commissionRate: isRent ? '2.5%' : '2.0%',
        escrowStatus: t.escrow_status,
        createdAt: t.created_at
      };
    });

    return res.json({ status: true, escrowBalance, settledCommissions, transactions: formattedTxns });
  } catch (err: any) {
    return res.json({ status: true, escrowBalance: 0, settledCommissions: 0, transactions: [] });
  }
}
