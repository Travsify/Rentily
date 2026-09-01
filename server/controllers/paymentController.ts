import type { Request, Response } from 'express';
import { FlutterwaveService } from '../services/flutterwaveService';
import { PaystackService } from '../services/paystackService';
import { FlutterwaveBillsService } from '../services/flutterwaveBillsService';
import { supabase } from '../supabaseClient';
import { UserStore } from '../services/userStore';
import { TransactionStore, type WalletTransaction } from '../services/transactionStore';

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
    const { userId, email, accountNumber, bankCode, accountName, amount, reason } = req.body;
    const cleanEmail = (email || '').toString().toLowerCase().trim();

    if (!accountNumber || !bankCode || !amount || Number(amount) <= 0) {
      return res.status(400).json({ error: 'Account number, bank code, and a valid amount are required' });
    }

    const numAmount = Number(amount);
    const cleanReason = (reason || 'Rentilly Living Escrow Payout').replace(/transify/gi, '').trim();

    // Check user net balance from TransactionStore & UserStore
    const userNetBal = TransactionStore.computeNetBalance(cleanEmail);
    const memUser = await UserStore.findByEmail(cleanEmail);
    const currentBal = Math.max(userNetBal, memUser?.walletBalance || 0);

    console.log(`[Withdrawal] Verifying user ${cleanEmail} balance: ₦${currentBal} vs requested: ₦${numAmount}`);

    if (currentBal < numAmount) {
      return res.status(400).json({
        error: `Insufficient wallet balance. You have ₦${currentBal.toLocaleString()}.`
      });
    }

    // Step A: Create Paystack Transfer Recipient
    const recipientRes = await PaystackService.createTransferRecipient({
      name: accountName || 'Patrick Achua',
      accountNumber: accountNumber.toString(),
      bankCode: bankCode.toString(),
      description: cleanReason
    });

    if (!recipientRes.status || !recipientRes.recipientCode) {
      return res.status(400).json({ error: recipientRes.message || 'Failed to register transfer recipient with Paystack' });
    }

    // Step B: Initiate Transfer Payout
    const transferRes = await PaystackService.initiateTransfer({
      recipientCode: recipientRes.recipientCode,
      amount: numAmount,
      reason: cleanReason
    });

    if (transferRes.status) {
      const newBal = Math.max(0, currentBal - numAmount);
      const txRef = transferRes.data?.reference || `WD_${Date.now()}`;

      // Record in TransactionStore
      await TransactionStore.addTransaction({
        id: `TX_WD_${Date.now()}`,
        userId: userId || memUser?.id || 'usr_patrick_achua_live',
        email: cleanEmail,
        title: `Bank Transfer Payout to ${accountName || 'Bank Account'}`,
        type: 'Instant Direct Bank Payout',
        category: 'withdrawal',
        amount: numAmount,
        isCredit: false,
        reference: txRef,
        sender: `${memUser?.fullName || 'Patrick Achua'} (Rentilly Living Escrow)`,
        beneficiary: accountName || 'Patrick Achua',
        recipientAccount: accountNumber.toString(),
        recipientBank: 'Direct Bank Transfer',
        status: 'SUCCESSFUL',
        date: new Date().toISOString(),
      });

      // Update UserStore
      if (memUser) {
        UserStore.upsertUser({
          ...memUser,
          walletBalance: newBal
        });
      }

      return res.json({
        status: true,
        message: 'Withdrawal processed successfully via Paystack!',
        newBalance: newBal,
        data: transferRes.data
      });
    } else {
      return res.status(400).json({ error: transferRes.message || 'Paystack payout settlement failed' });
    }
  } catch (err: any) {
    console.error('Withdrawal error:', err);
    res.status(500).json({ error: err.message || 'Payout settlement failed' });
  }
}

// ==================== LIVE UTILITY BILLS & AIRTIME ====================

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

// 4b. Vend Electricity Prepaid Token Direct Endpoint
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
      email,
    });

    if (result.status && supabase && userId) {
      await supabase.from('transactions').insert({
        user_id: userId,
        total_amount: Number(amount),
        escrow_status: 'bill_paid',
        payment_gateway: 'flutterwave_bills',
        payment_reference: result.data?.txRef,
      });
    }

    res.json(result);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

// 4c. Flutterwave Webhook Listener
export async function flutterwaveWebhook(req: Request, res: Response) {
  try {
    const payload = req.body;
    const event = payload?.event;
    const data = payload?.data;

    if ((event === 'charge.completed' || event === 'transfer.completed') && (data?.status === 'successful' || data?.status === 'success')) {
      const amountPaid = Number(data.amount || data.charged_amount || 0);
      const email = data.customer?.email?.toLowerCase();

      if (amountPaid > 0 && email) {
        const memUser = await UserStore.findByEmail(email);
        if (memUser) {
          const newBal = (memUser.walletBalance || 0) + amountPaid;
          UserStore.upsertUser({
            ...memUser,
            walletBalance: newBal,
          });
        }
      }
    }

    res.status(200).json({ received: true });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

// 5. Universal Bill & Airtime Payment API
export async function payBill(req: Request, res: Response) {
  try {
    const { email, category, operator, plan, customerNumber, amount } = req.body;
    const cleanEmail = (email || 'patrickachua3@gmail.com').toString().toLowerCase().trim();
    const numAmount = Number(amount || 0);

    if (numAmount <= 0) {
      return res.status(400).json({ error: 'Please specify a valid payment amount.' });
    }

    // Check user balance
    const userNetBal = TransactionStore.computeNetBalance(cleanEmail);
    const memUser = await UserStore.findByEmail(cleanEmail);
    const currentBal = Math.max(userNetBal, memUser?.walletBalance || 0);

    if (currentBal < numAmount) {
      return res.status(400).json({
        error: `Insufficient wallet balance. You have ₦${currentBal.toLocaleString()}, but ₦${numAmount.toLocaleString()} is required.`
      });
    }

    let serviceResult: any = null;
    let title = 'Utility Bill Payment';
    let type = 'Utility Payment';
    let tokenOutput: string | undefined;
    let unitsOutput: string | undefined;

    if (category === 'airtime') {
      title = `${operator || 'MTN'} Airtime Top-Up (₦${numAmount.toLocaleString()})`;
      type = 'Airtime VTU Recharge';
      serviceResult = await FlutterwaveBillsService.purchaseAirtime({
        phoneNumber: customerNumber,
        amount: numAmount,
        operator: operator || 'MTN',
        email: cleanEmail,
      });
    } else if (category === 'data') {
      title = `${operator || 'MTN'} Data Bundle (${plan || 'Data'})`;
      type = 'Mobile Data Bundle';
      serviceResult = await FlutterwaveBillsService.purchaseData({
        phoneNumber: customerNumber,
        amount: numAmount,
        plan: plan || 'Data Bundle',
        operator: operator || 'MTN',
        email: cleanEmail,
      });
    } else if (category === 'electricity') {
      title = `${operator || 'EKEDC'} Prepaid Electricity Token`;
      type = 'Prepaid Electricity Token';
      serviceResult = await FlutterwaveBillsService.purchaseElectricity({
        disco: operator || 'EKEDC',
        meterNumber: customerNumber,
        amount: numAmount,
        email: cleanEmail,
      });
      tokenOutput = serviceResult.data?.token;
      unitsOutput = serviceResult.data?.units;
    } else if (category === 'cable') {
      title = `${operator || 'DSTV'} Cable TV Subscription`;
      type = 'Cable TV Renewal';
      serviceResult = await FlutterwaveBillsService.purchaseCable({
        smartcardNumber: customerNumber,
        bouquet: plan || 'Bouquet',
        amount: numAmount,
        provider: operator || 'DSTV',
      });
    } else {
      title = `${operator || 'Utility'} Payment`;
      type = 'Direct Utility Settlement';
      serviceResult = {
        status: true,
        data: {
          txRef: `RENTILLY_UTIL_${Date.now()}`,
          amount: numAmount,
          customer: customerNumber,
          status: 'SUCCESSFUL',
        }
      };
    }

    if (serviceResult.status) {
      const newBal = Math.max(0, currentBal - numAmount);
      const txRef = serviceResult.data?.txRef || `UTIL_${Date.now()}`;

      // Record in TransactionStore
      const newTx = await TransactionStore.addTransaction({
        id: `TX_${Date.now()}`,
        userId: memUser?.id || 'usr_patrick_achua_live',
        email: cleanEmail,
        title: title,
        type: type,
        category: 'utility',
        amount: numAmount,
        isCredit: false,
        reference: txRef,
        sender: `${memUser?.fullName || 'Patrick Achua'} (Rentilly Living Escrow)`,
        beneficiary: customerNumber,
        status: 'SUCCESSFUL',
        token: tokenOutput,
        units: unitsOutput,
        date: new Date().toISOString(),
      });

      // Update UserStore
      if (memUser) {
        UserStore.upsertUser({
          ...memUser,
          walletBalance: newBal
        });
      }

      return res.json({
        status: true,
        message: serviceResult.message || 'Service payment processed successfully!',
        newBalance: newBal,
        transaction: newTx,
        token: tokenOutput,
        units: unitsOutput,
        data: serviceResult.data,
      });
    } else {
      return res.status(400).json({ error: serviceResult.message || 'Service bill fulfillment failed.' });
    }
  } catch (err: any) {
    console.error('payBill error:', err);
    res.status(500).json({ error: err.message || 'Bill payment failed' });
  }
}

// 6. Get User Transaction Ledger
export async function getUserTransactions(req: Request, res: Response) {
  try {
    const { email } = req.query;
    const cleanEmail = (email || 'patrickachua3@gmail.com').toString().toLowerCase().trim();
    const transactions = await TransactionStore.getTransactionsByEmail(cleanEmail);
    res.json({
      status: true,
      data: transactions
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

// 7. Instant Wallet Balance Sync API
export async function getWalletBalance(req: Request, res: Response) {
  try {
    const { userId, email } = req.query;
    const cleanEmail = email?.toString().toLowerCase().trim() || 'patrickachua3@gmail.com';

    const netBal = TransactionStore.computeNetBalance(cleanEmail);
    const memUser = await UserStore.findByEmail(cleanEmail);
    const balance = memUser?.walletBalance !== undefined ? memUser.walletBalance : netBal;

    res.json({
      status: true,
      walletBalance: balance,
      user: {
        id: memUser?.id || userId || 'usr_patrick_achua_live',
        fullName: memUser?.fullName || 'Patrick Achua',
        email: cleanEmail,
        accountNumber: memUser?.accountNumber || '9955394366',
        bankName: memUser?.bankName || 'Flutterwave MFB',
        isVerified: true,
        walletBalance: balance,
      }
    });
  } catch (err: any) {
    console.error('getWalletBalance error:', err);
    res.status(500).json({ error: err.message });
  }
}
