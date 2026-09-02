import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';
import type { Transaction } from '../types';
import { TransactionStore } from '../services/transactionStore';
import { AdminDataStore } from '../services/adminDataStore';
import { NotificationDispatcher } from '../services/notificationDispatcher';
import { UserStore } from '../services/userStore';

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

    // Dispatch payout release alert to landlord
    const targetOwnerEmail = txn?.owner_name || `${id}@myrentilly.com`;
    NotificationDispatcher.dispatch({
      userId: txn?.owner_id || id,
      email: targetOwnerEmail.includes('@') ? targetOwnerEmail : 'owner@myrentilly.com',
      userName: txn?.owner_name || 'Property Owner',
      title: `Move-In Escrow Payout Released 💰`,
      category: 'escrow',
      message: `Your property funds have been released from Rentilly escrow to your settlement bank account. Payout Reference: ${payoutReference}.`,
      metadata: {
        payoutReference,
        transactionId: id,
        amount: txn?.total_amount
      }
    });

    // 3. Automated Accredited Partner Commission Payout Credit
    const propertyId = txn?.property_id;
    const property = propertyId ? AdminDataStore.getProperties().find(p => p.id === propertyId) : null;
    let partnerCommissionAmount = 0;
    let creditedPartner: any = null;

    if (property && (property as any).listedByRole === 'verified_partner') {
      const partnerId = (property as any).partnerId || property.ownerId;
      const allUsers = await UserStore.getAllUsers();
      const partnerUser = (await UserStore.findById(partnerId)) || 
        allUsers.find(u => u.id === partnerId || (property.ownerPhone && u.phoneNumber === property.ownerPhone) || u.email === property.ownerEmail);

      if (partnerUser) {
        const isRent = (txn?.transaction_type === 'rent') || (property.purpose === 'rent');
        const rate = isRent ? 0.025 : 0.020;
        const baseAmount = Number(txn?.base_price || txn?.total_amount || property.basePrice || 0);
        partnerCommissionAmount = Math.round(baseAmount * rate);

        if (partnerCommissionAmount > 0) {
          // A. Credit the partner's wallet balance
          const updatedBal = (partnerUser.walletBalance || 0) + partnerCommissionAmount;
          await UserStore.upsertUser({
            ...partnerUser,
            walletBalance: updatedBal,
            updatedAt: payoutReleasedAt
          });

          // B. Record credit transaction in live ledger
          const commTxId = `TX-COMM-${Date.now()}`;
          TransactionStore.recordTransaction({
            id: commTxId,
            userId: partnerUser.id,
            userEmail: partnerUser.email,
            amount: partnerCommissionAmount,
            type: 'credit',
            status: 'SUCCESSFUL',
            category: 'commission',
            title: `Brokerage Commission: ${property.title}`,
            description: `${isRent ? '2.5%' : '2.0%'} mandate commission for ${property.title}. Released from escrow payout ${payoutReference}.`,
            reference: `COMM-${payoutReference}`,
            date: payoutReleasedAt,
            isCredit: true,
            escrowStatus: 'released_to_owner'
          });

          creditedPartner = {
            id: partnerUser.id,
            name: partnerUser.businessName || partnerUser.fullName,
            email: partnerUser.email,
            commissionAmount: partnerCommissionAmount,
            rate: isRent ? '2.5%' : '2.0%'
          };

          // C. Dispatch instant notification alert to Accredited Partner
          NotificationDispatcher.dispatch({
            userId: partnerUser.id,
            email: partnerUser.email,
            userName: partnerUser.businessName || partnerUser.fullName,
            title: `🎉 Brokerage Commission Unlocked: ₦${partnerCommissionAmount.toLocaleString()}`,
            category: 'escrow',
            message: `Your ${isRent ? '2.5%' : '2.0%'} commission for "${property.title}" has been released and credited to your settlement vault. Current Balance: ₦${updatedBal.toLocaleString()}.`,
            metadata: {
              propertyId: property.id,
              propertyTitle: property.title,
              commissionAmount: partnerCommissionAmount,
              payoutReference
            }
          });
        }
      }
    }

    res.json({ 
      success: true, 
      transaction: txn, 
      payoutReference, 
      payoutReleasedAt,
      partnerCommissionCredited: partnerCommissionAmount > 0,
      creditedPartner
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function getPartnerCommissions(req: Request, res: Response) {
  try {
    const { partnerId, email } = req.query;
    const cleanEmail = email ? String(email).toLowerCase().trim() : '';
    const cleanId = partnerId ? String(partnerId).trim() : '';

    // 1. Get properties listed by this partner from AdminDataStore
    const allProperties = AdminDataStore.getProperties();
    const partnerProps = allProperties.filter(p => 
      (cleanId && ((p as any).partnerId === cleanId || (p as any).ownerId === cleanId)) ||
      (cleanEmail && ((p as any).ownerEmail && (p as any).ownerEmail.toLowerCase() === cleanEmail))
    );
    const partnerPropIds = new Set(partnerProps.map(p => p.id));

    // 2. Get direct commission credits in wallet
    const walletTxs = cleanEmail ? await TransactionStore.getTransactionsByEmail(cleanEmail) : [];
    const directCommissions = walletTxs.filter(t => 
      t.isCredit && (t.category === 'commission' || (t.title && t.title.toLowerCase().includes('commission')))
    );

    // 3. Get all platform escrow transactions
    const allEscrowTxs = AdminDataStore.buildEscrowTransactions(TransactionStore.getAllTransactions());
    const propertyTxns = allEscrowTxs.filter(t => partnerPropIds.has(t.propertyId));

    let escrowBalance = 0;
    let settledCommissions = 0;
    const formattedTxns: any[] = [];

    // Include direct credited commissions
    for (const d of directCommissions) {
      settledCommissions += d.amount;
      formattedTxns.push({
        id: d.id,
        propertyTitle: d.title || 'Corporate Brokerage Commission',
        commissionAmount: d.amount,
        commissionRate: '2.5%',
        escrowStatus: 'released_to_owner',
        createdAt: d.date
      });
    }

    // Include property transactions on partner's mandates
    for (const pt of propertyTxns) {
      const isRent = pt.transactionType === 'rent';
      const rate = isRent ? 0.025 : 0.020;
      const commAmount = Math.round(pt.baseAmount * rate);

      if (pt.escrowStatus === 'held_in_escrow') {
        escrowBalance += commAmount;
      } else {
        settledCommissions += commAmount;
      }

      formattedTxns.push({
        id: pt.id,
        propertyTitle: pt.propertyTitle || 'Mandate Listing',
        commissionAmount: commAmount,
        commissionRate: isRent ? '2.5%' : '2.0%',
        escrowStatus: pt.escrowStatus,
        createdAt: pt.createdAt
      });
    }

    return res.json({
      status: true,
      escrowBalance,
      settledCommissions,
      transactions: formattedTxns
    });
  } catch (err: any) {
    return res.json({ status: true, escrowBalance: 0, settledCommissions: 0, transactions: [] });
  }
}
