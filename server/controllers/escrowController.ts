import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';
import type { Transaction } from '../types';

export async function getTransactions(_req: Request, res: Response) {
  try {
    if (!supabase) return res.json([]);

    const { data, error } = await supabase
      .from('transactions')
      .select('*, properties(*)')
      .order('created_at', { ascending: false });

    if (error) return res.json([]);

    const transactions: Transaction[] = (data || []).map((row: any) => ({
      id: row.id,
      propertyId: row.property_id,
      propertyTitle: row.properties?.title || 'Property Transaction',
      payerId: row.payer_id,
      payerName: row.payer_name || 'Buyer / Renter',
      recipientOwnerId: row.recipient_owner_id,
      recipientOwnerName: row.recipient_owner_name || 'Property Owner',
      transactionType: row.transaction_type,
      totalAmount: Number(row.total_amount || 0),
      basePrice: Number(row.base_price || 0),
      cautionDeposit: Number(row.caution_deposit || 0),
      serviceCharge: Number(row.service_charge || 0),
      rentillyLegalFee: Number(row.rentilly_legal_fee || 0),
      escrowStatus: row.escrow_status,
      paymentGateway: row.payment_gateway,
      paymentReference: row.payment_reference,
      ownerPayoutReference: row.owner_payout_reference,
      payoutReleasedAt: row.payout_released_at,
      createdAt: row.created_at
    }));

    res.json(transactions);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function releaseEscrowPayout(req: Request, res: Response) {
  try {
    const { id } = req.params;
    if (!supabase) return res.status(500).json({ error: 'Database unavailable' });

    const payoutReference = `PAYOUT-RENTILLY-${Date.now()}`;
    const payoutReleasedAt = new Date().toISOString();

    // 1. Release escrow in transactions table
    const { data: txn, error: txnError } = await supabase
      .from('transactions')
      .update({
        escrow_status: 'released_to_owner',
        owner_payout_reference: payoutReference,
        payout_released_at: payoutReleasedAt
      })
      .eq('id', id)
      .select()
      .single();

    if (txnError) throw new Error(txnError.message);

    // 2. Mark property as rented / sold and delist from public discovery
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

    res.json({ transaction: txn, payoutReference, payoutReleasedAt });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}
