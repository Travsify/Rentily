import type { Request, Response } from 'express';
import { FlutterwaveService } from '../services/flutterwaveService';
import { supabase } from '../supabaseClient';

export async function createVirtualAccount(req: Request, res: Response) {
  try {
    const { propertyId, propertyTitle, email, tenantName, phoneNumber, expectedAmount } = req.body;

    if (!propertyId || !expectedAmount) {
      return res.status(400).json({ error: 'Property ID and expected amount are required' });
    }

    const result = await FlutterwaveService.createVirtualAccount({
      propertyId,
      propertyTitle: propertyTitle || 'Property Transaction',
      email: email || 'renter@rentilly.ng',
      tenantName: tenantName || 'Prospective Tenant',
      phoneNumber,
      expectedAmount: Number(expectedAmount)
    });

    if (result.status && result.data && supabase) {
      // Save virtual bank account to Supabase
      await supabase.from('virtual_bank_accounts').insert({
        property_id: propertyId,
        bank_name: result.data.bankName,
        account_number: result.data.accountNumber,
        account_reference: result.data.accountReference,
        flw_order_ref: result.data.orderRef,
        expected_amount: expectedAmount,
        status: 'active'
      });
    }

    res.json(result);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function transferToLandlord(req: Request, res: Response) {
  try {
    const { accountBankCode, accountNumber, amount, landlordName, propertyTitle, transactionId } = req.body;

    if (!accountBankCode || !accountNumber || !amount || !transactionId) {
      return res.status(400).json({ error: 'Bank details, amount, and transaction ID are required.' });
    }

    const result = await FlutterwaveService.transferToLandlord({
      accountBankCode,
      accountNumber,
      amount: Number(amount),
      landlordName: landlordName || 'Landlord',
      propertyTitle: propertyTitle || 'Rent Payment',
      transactionId
    });

    res.json(result);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function getBanks(_req: Request, res: Response) {
  try {
    const banks = await FlutterwaveService.getNigerianBanks();
    res.json(banks);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

// Flutterwave Webhook Listener
export async function flutterwaveWebhook(req: Request, res: Response) {
  try {
    const secretHash = process.env.FLUTTERWAVE_WEBHOOK_SECRET;
    const signature = req.headers['verif-hash'];

    if (secretHash && signature && signature !== secretHash) {
      return res.status(401).end();
    }

    const payload = req.body;
    const event = payload?.event;
    const data = payload?.data;

    console.log(`🔔 Received Flutterwave Webhook Event: ${event}`, data?.tx_ref);

    if (event === 'charge.completed' && data?.status === 'successful') {
      const txRef = data.tx_ref;
      const amountPaid = data.amount;

      if (supabase && txRef) {
        // 1. Mark virtual account as paid
        await supabase
          .from('virtual_bank_accounts')
          .update({
            status: 'paid',
            amount_paid: amountPaid
          })
          .eq('account_reference', txRef);

        // 2. Create or update escrow transaction
        await supabase.from('transactions').insert({
          total_amount: amountPaid,
          escrow_status: 'held_in_escrow',
          payment_gateway: 'flutterwave',
          payment_reference: data.flw_ref || txRef
        });
      }
    }

    res.status(200).json({ received: true });
  } catch (err: any) {
    console.error('Webhook error:', err);
    res.status(500).json({ error: err.message });
  }
}
