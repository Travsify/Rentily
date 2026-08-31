import type { Request, Response } from 'express';
import { FlutterwaveService } from '../services/flutterwaveService';
import { PaystackService } from '../services/paystackService';
import { FlutterwaveBillsService } from '../services/flutterwaveBillsService';
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

// ==================== PAYSTACK WITHDRAWAL & PAYOUTS ====================

// 1. Fetch Nigerian Banks List from Paystack
export async function getPaystackBanks(_req: Request, res: Response) {
  try {
    const result = await PaystackService.getBanks();
    res.json(result);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

// 2. Resolve Beneficiary Account Number via Paystack NIBSS
export async function resolvePaystackAccount(req: Request, res: Response) {
  try {
    const { accountNumber, bankCode } = req.query;
    if (!accountNumber || !bankCode) {
      return res.status(400).json({ error: 'Account number and bank code are required' });
    }

    const result = await PaystackService.resolveAccount(accountNumber.toString(), bankCode.toString());
    res.json(result);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

// 3. Execute Paystack Transfer Payout
export async function withdrawWithPaystack(req: Request, res: Response) {
  try {
    const { userId, accountNumber, bankCode, accountName, amount, reason } = req.body;

    if (!accountNumber || !bankCode || !amount || Number(amount) <= 0) {
      return res.status(400).json({ error: 'Account number, bank code, and a valid amount are required' });
    }

    const numAmount = Number(amount);

    // Verify user has sufficient wallet balance in Supabase
    if (supabase && userId) {
      const { data: user } = await supabase.from('users').select('wallet_balance').eq('id', userId).single();
      const currentBal = Number(user?.wallet_balance || 0);
      if (currentBal < numAmount) {
        return res.status(400).json({ error: `Insufficient wallet balance. You have ₦${currentBal.toLocaleString()}.` });
      }
    }

    // Step A: Create Paystack Transfer Recipient
    const recipientRes = await PaystackService.createTransferRecipient({
      name: accountName || 'Rentilly User',
      accountNumber: accountNumber.toString(),
      bankCode: bankCode.toString(),
      description: reason || 'Rentilly Escrow Withdrawal'
    });

    if (!recipientRes.status || !recipientRes.recipientCode) {
      return res.status(400).json({ error: recipientRes.message || 'Failed to register transfer recipient with Paystack' });
    }

    // Step B: Initiate Transfer Payout
    const transferRes = await PaystackService.initiateTransfer({
      recipientCode: recipientRes.recipientCode,
      amount: numAmount,
      reason: reason || 'Rentilly Escrow Withdrawal'
    });

    if (transferRes.status) {
      // Step C: Debit User Balance & Log Transaction in Supabase
      if (supabase && userId) {
        await supabase.rpc('decrement_wallet_balance', {
          user_id: userId,
          amount_to_deduct: numAmount
        }).catch(async () => {
          // Fallback direct update
          const { data: u } = await supabase.from('users').select('wallet_balance').eq('id', userId).single();
          const newBal = Math.max(0, Number(u?.wallet_balance || 0) - numAmount);
          await supabase.from('users').update({ wallet_balance: newBal }).eq('id', userId);
        });

        await supabase.from('transactions').insert({
          user_id: userId,
          total_amount: numAmount,
          escrow_status: 'payout_completed',
          payment_gateway: 'paystack',
          payment_reference: transferRes.data?.reference || `WD_${Date.now()}`
        });
      }

      return res.json({
        status: true,
        message: 'Withdrawal processed successfully via Paystack!',
        data: transferRes.data
      });
    } else {
      return res.status(400).json({ error: transferRes.message || 'Paystack transfer failed' });
    }
  } catch (err: any) {
    console.error('Withdrawal error:', err);
    res.status(500).json({ error: err.message || 'Payout settlement failed' });
  }
}

// ==================== FLUTTERWAVE UTILITY BILLS ====================

// 4. Validate Prepaid Electricity Meter Number
export async function validateDiscoMeter(req: Request, res: Response) {
  try {
    const { itemCode, billerCode, customerNumber } = req.body;
    if (!customerNumber) {
      return res.status(400).json({ error: 'Meter number is required' });
    }

    const result = await FlutterwaveBillsService.validateMeter({
      itemCode: itemCode || 'UB159',
      billerCode: billerCode || 'BIL112',
      customerNumber: customerNumber.toString()
    });

    res.json(result);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

// 5. Vend Electricity Prepaid Token
export async function purchaseElectricityToken(req: Request, res: Response) {
  try {
    const { disco, meterNumber, amount, phoneNumber, email, userId } = req.body;

    if (!meterNumber || !amount || Number(amount) <= 0) {
      return res.status(400).json({ error: 'Meter number and amount are required' });
    }

    const result = await FlutterwaveBillsService.purchaseElectricity({
      disco: disco || 'EKEDC',
      meterNumber: meterNumber.toString(),
      amount: Number(amount),
      phoneNumber,
      email
    });

    if (result.status && supabase && userId) {
      await supabase.from('transactions').insert({
        user_id: userId,
        total_amount: Number(amount),
        escrow_status: 'bill_paid',
        payment_gateway: 'flutterwave_bills',
        payment_reference: result.data?.txRef
      });
    }

    res.json(result);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

// 6. Flutterwave Webhook Listener
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
        await supabase
          .from('virtual_bank_accounts')
          .update({
            status: 'paid',
            amount_paid: amountPaid
          })
          .eq('account_reference', txRef);

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
