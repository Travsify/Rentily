import type { Request, Response } from 'express';
import { FlutterwaveService } from '../services/flutterwaveService';
import { PaystackService } from '../services/paystackService';
import { FlutterwaveBillsService } from '../services/flutterwaveBillsService';
import { supabase } from '../supabaseClient';
import { UserStore } from '../services/userStore';
import { TransactionStore, type WalletTransaction } from '../services/transactionStore';
import { NotificationDispatcher } from '../services/notificationDispatcher';

export async function createVirtualAccount(req: Request, res: Response) {
  try {
    const { propertyId, propertyTitle, email, tenantName, phoneNumber, expectedAmount } = req.body;

    if (!propertyId || !expectedAmount) {
      return res.status(400).json({ error: 'Property ID and expected amount are required' });
    }

    const result = await FlutterwaveService.createVirtualAccount({
      propertyId,
      propertyTitle: propertyTitle || 'Property Transaction',
      email: email || 'renter@myrentilly.com',
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

    // Auto-sync real inbound transactions from Flutterwave Cloud API
    await syncFlutterwaveTransactionsForUser(cleanEmail);

    // Check user true net balance from TransactionStore
    const currentBal = TransactionStore.computeNetBalance(cleanEmail);
    const memUser = await UserStore.findByEmail(cleanEmail);
    console.log(`[Withdrawal] Verifying user ${cleanEmail} true balance: ₦${currentBal} vs requested: ₦${numAmount}`);

    if (currentBal < numAmount) {
      return res.status(400).json({
        error: `Insufficient wallet balance. You have ₦${currentBal.toLocaleString()}.`
      });
    }

    // Step A: Create Paystack Transfer Recipient
    const recipientRes = await PaystackService.createTransferRecipient({
      name: accountName || memUser?.fullName || 'Account Holder',
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
        userId: userId || memUser?.id || `usr_${cleanEmail}`,
        email: cleanEmail,
        title: `Bank Transfer Payout to ${accountName || 'Bank Account'}`,
        type: 'Instant Direct Bank Payout',
        category: 'withdrawal',
        amount: numAmount,
        isCredit: false,
        reference: txRef,
        sender: `${memUser?.fullName || memUser?.businessName || 'Rentilly Partner'} (Rentilly Living Escrow)`,
        beneficiary: accountName || 'Bank Account',
        recipientAccount: accountNumber.toString(),
        recipientBank: 'Direct Bank Transfer',
        status: 'SUCCESSFUL',
        date: new Date().toISOString(),
      });

      // Update UserStore and Supabase
      if (memUser) {
        UserStore.upsertUser({
          ...memUser,
          walletBalance: newBal,
          updatedAt: new Date().toISOString()
        });
      }
      if (supabase) {
        try {
          await supabase.from('users').update({ wallet_balance: newBal }).eq('email', cleanEmail);
        } catch (_) {}
      }

      // Dispatch In-App Alert & Resend HTML Email
      NotificationDispatcher.dispatch({
        userId: userId || memUser?.id,
        email: cleanEmail,
        userName: memUser?.fullName || accountName,
        title: `Debit Alert: ₦${numAmount.toLocaleString()} Withdrawn`,
        category: 'wallet',
        message: `A payout of ₦${numAmount.toLocaleString()} has been processed and sent to your bank account (${accountNumber}).`,
        metadata: {
          amount: numAmount,
          reference: txRef,
          bankName: 'NIBSS Instant Transfer',
          accountNumber: accountNumber.toString()
        }
      });

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

    if (result.status) {
      if (supabase && userId) {
        await supabase.from('transactions').insert({
          user_id: userId,
          total_amount: Number(amount),
          escrow_status: 'bill_paid',
          payment_gateway: 'flutterwave_bills',
          payment_reference: result.data?.txRef,
        });
      }

      if (email) {
        NotificationDispatcher.dispatch({
          userId: userId?.toString(),
          email: email.toString(),
          title: `Receipt: ₦${Number(amount).toLocaleString()} Electricity Token Purchased`,
          category: 'utilities',
          message: `Your prepaid electricity token for meter ${meterNumber} has been generated successfully.`,
          metadata: {
            amount: Number(amount),
            token: result.data?.token || 'TOKEN-GENERATED',
            meterNumber: meterNumber.toString(),
            reference: result.data?.txRef || `DISCO-${Date.now()}`
          }
        });
      }
    }

    res.json(result);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

// 4c. Flutterwave Webhook Listener
export async function flutterwaveWebhook(req: Request, res: Response) {
  try {
    // Always respond 200 immediately so Flutterwave doesn't retry
    res.status(200).json({ received: true });

    const payload = req.body;
    const event = payload?.event;
    const data = payload?.data;

    console.log(`[FLW Webhook] Event: ${event}`, JSON.stringify(data || {}, null, 2));

    // Flutterwave virtual account credit events:
    //   event === 'charge.completed'  (virtual account top-up)
    //   event === 'transfer.completed' (transfer received)
    const isCredit = (
      event === 'charge.completed' ||
      event === 'transfer.completed' ||
      event === 'virtualaccount.creditnotification'
    );
    const isSuccess = (
      data?.status === 'successful' ||
      data?.status === 'success' ||
      data?.status === 'SUCCESSFUL'
    );

    if (!isCredit || !isSuccess) {
      console.log(`[FLW Webhook] Ignoring event ${event} / status ${data?.status}`);
      return;
    }

    const amountPaid = Number(
      data.amount ||
      data.charged_amount ||
      data.settlement_amount ||
      0
    );

    if (amountPaid <= 0) {
      console.log('[FLW Webhook] Amount is 0, ignoring.');
      return;
    }

    // --- Resolve which user this payment belongs to ---
    // Priority 1: virtual account number that received the money
    const incomingAccNo: string = (
      data?.meta?.virtualaccountnumber ||
      data?.account_number ||
      data?.destination_account_number ||
      data?.virtual_account_number ||
      ''
    ).toString().replace(/\s/g, '');

    // Priority 2: customer email registered on Flutterwave for this virtual account
    const customerEmail = data?.customer?.email?.toLowerCase?.()?.trim?.() || '';

    // Priority 3: Extract user ID from tx_ref (format: RENTILLY_ACC_<userId>_<suffix>_<timestamp>)
    const txRef = (data?.tx_ref || '').toString();
    const txRefUserIdMatch = txRef.match(/RENTILLY_ACC_(usr_[^_]+)/);
    const txRefUserId = txRefUserIdMatch ? txRefUserIdMatch[1] : '';

    console.log(`[FLW Webhook] amount=₦${amountPaid}, virtualAcc=${incomingAccNo}, email=${customerEmail}, txRefUserId=${txRefUserId}`);

    // Load all in-memory users and find match
    const allUsers = UserStore.getAllUsers();

    let targetUser = allUsers.find(u =>
      incomingAccNo &&
      u.accountNumber?.replace(/\s/g, '') === incomingAccNo
    );

    if (!targetUser && customerEmail) {
      targetUser = allUsers.find(u =>
        u.email.toLowerCase().trim() === customerEmail
      );
    }

    if (!targetUser && txRefUserId) {
      targetUser = allUsers.find(u => u.id === txRefUserId);
    }

    // Supabase fallback: look up by account number, email, or user ID from tx_ref
    if (!targetUser && supabase) {
      let sbQuery = supabase.from('users').select('*');

      if (incomingAccNo) {
        const { data: sbUsers } = await sbQuery.eq('account_number', incomingAccNo).limit(1);
        if (sbUsers && sbUsers.length > 0) {
          const sb = sbUsers[0];
          targetUser = {
            id: sb.id, email: sb.email, fullName: sb.full_name || sb.fullName || '',
            accountNumber: sb.account_number || incomingAccNo,
            bankName: sb.bank_name || 'Flutterwave MFB',
            walletBalance: sb.wallet_balance ?? 0,
            isVerified: sb.is_verified ?? true,
            role: sb.role || 'owner',
          };
        }
      }

      if (!targetUser && customerEmail) {
        const { data: sbUsers } = await supabase.from('users').select('*').eq('email', customerEmail).limit(1);
        if (sbUsers && sbUsers.length > 0) {
          const sb = sbUsers[0];
          targetUser = {
            id: sb.id, email: sb.email, fullName: sb.full_name || sb.fullName || '',
            accountNumber: sb.account_number || incomingAccNo,
            bankName: sb.bank_name || 'Flutterwave MFB',
            walletBalance: sb.wallet_balance ?? 0,
            isVerified: sb.is_verified ?? true,
            role: sb.role || 'owner',
          };
        }
      }

      if (!targetUser && txRefUserId) {
        const { data: sbUsers } = await supabase.from('users').select('*').eq('id', txRefUserId).limit(1);
        if (sbUsers && sbUsers.length > 0) {
          const sb = sbUsers[0];
          targetUser = {
            id: sb.id, email: sb.email, fullName: sb.full_name || sb.fullName || '',
            accountNumber: sb.account_number || incomingAccNo,
            bankName: sb.bank_name || 'Flutterwave MFB',
            walletBalance: sb.wallet_balance ?? 0,
            isVerified: sb.is_verified ?? true,
            role: sb.role || 'owner',
          };
        }
      }
    }

    // Last resort: Patrick Achua's known account 9254090338
    if (!targetUser && (
      incomingAccNo === '9254090338' ||
      customerEmail === 'patrickachua3@gmail.com' ||
      customerEmail === 'travsifyglobalinclusive@gmail.com'
    )) {
      targetUser = await UserStore.findByEmail('patrickachua3@gmail.com') || undefined;
    }

    if (!targetUser) {
      console.warn(`[FLW Webhook] No user found for virtualAcc=${incomingAccNo} / email=${customerEmail} / txRefUserId=${txRefUserId}`);
      return;
    }

    const prevBal = targetUser.walletBalance ?? 0;
    const newBal = prevBal + amountPaid;

    console.log(`[FLW Webhook] Crediting ${targetUser.email}: ₦${prevBal} → ₦${newBal} (+₦${amountPaid})`);

    UserStore.upsertUser({
      ...targetUser,
      walletBalance: newBal,
      updatedAt: new Date().toISOString(),
    });

    // Record the inbound transaction
    const creditRef = data?.flw_ref || data?.tx_ref || `FLW_CREDIT_${Date.now()}`;
    const senderName = data?.meta?.originatorname || data?.narration || 'Bank Transfer';
    await TransactionStore.addTransaction({
      id: `TX_CREDIT_${Date.now()}`,
      userId: targetUser.id,
      email: targetUser.email,
      title: `Wallet Funded — ₦${amountPaid.toLocaleString()}`,
      type: 'Virtual Account Credit',
      category: 'wallet_funding',
      amount: amountPaid,
      isCredit: true,
      reference: creditRef,
      sender: senderName,
      beneficiary: targetUser.accountNumber || '',
      status: 'SUCCESSFUL',
      date: new Date().toISOString(),
    });

    // Dispatch In-App Alert & Resend HTML Email
    NotificationDispatcher.dispatch({
      userId: targetUser.id,
      email: targetUser.email,
      userName: targetUser.fullName,
      title: `Credit Alert: ₦${amountPaid.toLocaleString()} Received in Wallet`,
      category: 'wallet',
      message: `Your dedicated Flutterwave MFB bank account received an inflow of ₦${amountPaid.toLocaleString()} from ${senderName}.`,
      metadata: {
        amount: amountPaid,
        reference: txRef,
        bankName: 'Flutterwave MFB Dedicated Bank Transfer'
      }
    });

    console.log(`[FLW Webhook] ✅ Balance updated to ₦${newBal} for ${targetUser.email}`);
  } catch (err: any) {
    console.error('[FLW Webhook] ERROR:', err.message);
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

    // Auto-sync real inbound transactions from Flutterwave Cloud API
    await syncFlutterwaveTransactionsForUser(cleanEmail);

    // Check user true net balance from TransactionStore
    const currentBal = TransactionStore.computeNetBalance(cleanEmail);
    const memUser = await UserStore.findByEmail(cleanEmail);

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

    const opRaw = (operator || '').toString().trim();
    const opClean = opRaw.toUpperCase().includes('AIRTEL') ? 'Airtel' :
                    opRaw.toUpperCase().includes('GLO') ? 'Glo' :
                    opRaw.toUpperCase().includes('9MOBILE') || opRaw.toUpperCase().includes('ETISALAT') ? '9mobile' :
                    opRaw.toUpperCase().includes('MTN') ? 'MTN' : (opRaw || 'MTN');

    if (category === 'airtime') {
      title = `${opClean} Airtime Top-Up (₦${numAmount.toLocaleString()})`;
      type = `${opClean} Airtime Recharge`;
      serviceResult = await FlutterwaveBillsService.purchaseAirtime({
        phoneNumber: customerNumber,
        amount: numAmount,
        operator: opClean,
        email: cleanEmail,
      });
    } else if (category === 'data') {
      title = `${opClean} Data Bundle (${plan || 'Data'})`;
      type = `${opClean} Mobile Data`;
      serviceResult = await FlutterwaveBillsService.purchaseData({
        phoneNumber: customerNumber,
        amount: numAmount,
        plan: plan || 'Data Bundle',
        operator: opClean,
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
        userId: memUser?.id || (cleanEmail === 'tonerocool1@gmail.com' ? 'c0000000-0000-0000-0000-000000000001' : 'b0000000-0000-0000-0000-000000000001'),
        email: cleanEmail,
        title: title,
        type: type,
        category: 'utility',
        amount: numAmount,
        isCredit: false,
        reference: txRef,
        sender: `${memUser?.businessName || memUser?.fullName || 'Rentilly User'} (Rentilly Wallet)`,
        beneficiary: customerNumber,
        status: 'SUCCESSFUL',
        token: tokenOutput,
        units: unitsOutput,
        date: new Date().toISOString(),
      });

      // Update UserStore and Supabase
      if (memUser) {
        UserStore.upsertUser({
          ...memUser,
          walletBalance: newBal,
          updatedAt: new Date().toISOString()
        });
      }
      if (supabase) {
        try {
          await supabase.from('users').update({ wallet_balance: newBal }).eq('email', cleanEmail);
        } catch (_) {}
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

// Helper: Sync ONLY Rentilly-initiated live Flutterwave deposits AND Paystack withdrawals into ledger
async function syncFlutterwaveTransactionsForUser(cleanEmail: string) {
  try {
    const existing = TransactionStore.getAllTransactions();
    const user = await UserStore.findByEmail(cleanEmail);

    // 1. Sync Inbound Deposits from Flutterwave Cloud API
    const liveFlwTxs = await FlutterwaveService.fetchLiveTransactions(cleanEmail);
    for (const flwTx of liveFlwTxs) {
      if (flwTx.status !== 'successful' && flwTx.status !== 'success') continue;

      const flwEmail = (flwTx.customer?.email || '').toLowerCase().trim();
      const txRef = (flwTx.tx_ref || flwTx.flw_ref || '').toString();
      const virtualAccNo = (flwTx.meta?.virtualaccountnumber || '').toString().replace(/\s/g, '');

      // Match by: exact email OR virtual account number belonging to this user
      const emailMatch = flwEmail === cleanEmail;
      const accMatch = user?.accountNumber && virtualAccNo && user.accountNumber.replace(/\s/g, '') === virtualAccNo;

      if (!emailMatch && !accMatch) {
        continue;
      }

      const exists = existing.some(e =>
        e.reference === flwTx.flw_ref ||
        e.reference === txRef ||
        e.id === `FLW_TX_${flwTx.id}`
      );

      if (!exists) {
        const amount = Number(flwTx.amount || 0);
        if (amount > 0) {
          const effectiveBeneficiary = user?.businessName || user?.fullName || cleanEmail;
          await TransactionStore.addTransaction({
            id: `FLW_TX_${flwTx.id}`,
            userId: user?.id || `usr_${cleanEmail}`,
            email: cleanEmail,
            title: `Direct Inbound Transfer — ₦${amount.toLocaleString()}`,
            type: 'Electronic Bank Inbound Deposit',
            category: 'deposit',
            amount: amount,
            isCredit: true,
            reference: flwTx.flw_ref || txRef,
            sender: flwTx.meta?.originatorname || flwTx.narration || flwTx.customer?.name || 'Inbound Bank Transfer',
            beneficiary: effectiveBeneficiary,
            status: 'SUCCESSFUL',
            date: flwTx.created_at || new Date().toISOString()
          });

          // Also update user wallet balance immediately
          if (user) {
            const currentBal = user.walletBalance ?? 0;
            UserStore.upsertUser({
              ...user,
              walletBalance: currentBal + amount,
              updatedAt: new Date().toISOString()
            });
          }
        }
      }
    }

    // 2. Sync Outbound Withdrawals / Payouts (ONLY exact matches initiated by this user)
    const livePaystackTxs = await PaystackService.fetchLiveTransfers();
    for (const pstTx of livePaystackTxs) {
      const pstStatus = (pstTx.status || '').toUpperCase();
      if (pstStatus !== 'SUCCESS' && pstStatus !== 'SUCCESSFUL' && pstStatus !== 'PENDING' && pstStatus !== 'PROCESSING') continue;

      const txRef = (pstTx.reference || pstTx.transfer_code || '').toString();

      // Must be a transfer tied specifically to this user ID or email in the reference
      const userRefPrefix = `RENTILLY_WD_${user?.id || ''}`;
      if (!txRef.includes(user?.id || 'NO_MATCH_ID') && !txRef.includes(cleanEmail)) {
        continue;
      }

      const exists = existing.some(e =>
        e.reference === txRef ||
        e.id === `PST_TX_${pstTx.id}` ||
        e.id === pstTx.transfer_code
      );

      if (!exists) {
        const amount = Number(pstTx.amount || 0) / 100; // convert Kobo to Naira
        if (amount > 0) {
          const recipientName = pstTx.recipient?.name || pstTx.recipient?.details?.account_name || 'Bank Account';
          const recipientAcc = pstTx.recipient?.details?.account_number || '';
          const recipientBank = pstTx.recipient?.details?.bank_name || 'Direct Bank Payout';
          const status = (pstStatus === 'SUCCESS' || pstStatus === 'SUCCESSFUL') ? 'SUCCESSFUL' : 'PENDING';

          await TransactionStore.addTransaction({
            id: `PST_TX_${pstTx.id}`,
            userId: user?.id || `usr_${cleanEmail}`,
            email: cleanEmail,
            title: `Bank Transfer Payout to ${recipientName}`,
            type: 'Instant Direct Bank Payout',
            category: 'withdrawal',
            amount: amount,
            isCredit: false,
            reference: txRef,
            sender: user?.businessName || user?.fullName || cleanEmail,
            beneficiary: recipientName,
            recipientAccount: recipientAcc,
            recipientBank: recipientBank,
            status: status,
            date: pstTx.createdAt || pstTx.transferred_at || new Date().toISOString()
          });
        }
      }
    }
  } catch (e: any) {
    console.error('Error syncing live transactions:', e.message);
  }
}

// 6. Get User Transaction Ledger (with real-time Flutterwave sync)
export async function getUserTransactions(req: Request, res: Response) {
  try {
    const { email } = req.query;
    const cleanEmail = (email || 'patrickachua3@gmail.com').toString().toLowerCase().trim();

    // Auto-sync from Flutterwave
    await syncFlutterwaveTransactionsForUser(cleanEmail);

    const transactions = await TransactionStore.getTransactionsByEmail(cleanEmail);
    res.json({
      status: true,
      data: transactions
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

// 7. Instant Wallet Balance Sync API (with real-time Flutterwave sync)
export async function getWalletBalance(req: Request, res: Response) {
  try {
    const { userId, email } = req.query;
    const cleanEmail = email?.toString().toLowerCase().trim() || 'patrickachua3@gmail.com';

    // Auto-sync from Flutterwave
    await syncFlutterwaveTransactionsForUser(cleanEmail);

    const netBal = TransactionStore.computeNetBalance(cleanEmail);
    const memUser = await UserStore.findByEmail(cleanEmail);

    let balance = Math.max(
      memUser?.walletBalance ?? 0,
      netBal
    );

    if (memUser && memUser.walletBalance !== balance) {
      UserStore.upsertUser({
        ...memUser,
        walletBalance: balance
      });
    }

    const accountNumber = memUser?.accountNumber || '9254090338';
    const bankName = memUser?.bankName || 'Flutterwave MFB';

    res.json({
      status: true,
      walletBalance: balance,
      user: {
        id: memUser?.id || userId || (cleanEmail === 'tonerocool1@gmail.com' ? 'c0000000-0000-0000-0000-000000000001' : 'b0000000-0000-0000-0000-000000000001'),
        fullName: memUser?.fullName || (cleanEmail === 'tonerocool1@gmail.com' ? 'Eoms Global Partner' : 'Rentilly User'),
        businessName: memUser?.businessName || (cleanEmail === 'tonerocool1@gmail.com' ? 'Eoms Global Inclusive Limited' : null),
        email: cleanEmail,
        accountNumber,
        bankName,
        isVerified: memUser?.isVerified ?? true,
        role: memUser?.role || 'owner',
        walletBalance: balance,
      }
    });
  } catch (err: any) {
    console.error('getWalletBalance error:', err);
    res.status(500).json({ error: err.message });
  }
}
// 8a. Admin Bootstrap User + Immediate Reconcile (for users whose record doesn't exist server-side)
export async function adminRegisterAndCreditUser(req: Request, res: Response) {
  try {
    const { userId, email, fullName, accountNumber, bankName, role } = req.body;
    const cleanEmail = (email || '').toString().toLowerCase().trim();
    const cleanAccNo = (accountNumber || '').toString().replace(/\s/g, '');

    if (!cleanEmail) {
      return res.status(400).json({ error: 'email is required' });
    }

    const resolvedId = (userId || '').toString() || `usr_${Date.now()}`;

    // Upsert user into memory store
    const existingUser = await UserStore.findByEmail(cleanEmail);
    const userRecord = {
      id: resolvedId,
      email: cleanEmail,
      fullName: (fullName || '').toString() || cleanEmail.split('@')[0],
      phoneNumber: '',
      role: (role || 'partner').toString(),
      isVerified: true,
      accountNumber: cleanAccNo || existingUser?.accountNumber || null,
      bankName: (bankName || 'Flutterwave MFB').toString(),
      walletBalance: existingUser?.walletBalance ?? 0,
      businessName: existingUser?.businessName || null,
      createdAt: existingUser?.createdAt || new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    UserStore.upsertUser(userRecord);

    // Also upsert into Supabase for persistence
    if (supabase) {
      await supabase.from('users').upsert({
        id: resolvedId,
        email: cleanEmail,
        full_name: userRecord.fullName,
        role: userRecord.role,
        is_verified: true,
        account_number: cleanAccNo || null,
        bank_name: userRecord.bankName,
        wallet_balance: userRecord.walletBalance,
        updated_at: new Date().toISOString()
      }, { onConflict: 'email' });
    }

    // Now run reconcile using the established FlutterwaveService (uses env key, no date range issues)
    // Fetch by email first (exact match), then merge with all-transactions fetch for acc/txRef matching
    const [byEmail, allTxs] = await Promise.all([
      FlutterwaveService.fetchLiveTransactions(cleanEmail),
      FlutterwaveService.fetchLiveTransactions()   // no filter = all merchant transactions
    ]);
    // Combine and deduplicate
    const seenIds = new Set<number>();
    const combinedTxs: any[] = [];
    for (const tx of [...byEmail, ...allTxs]) {
      if (!seenIds.has(tx.id)) { seenIds.add(tx.id); combinedTxs.push(tx); }
    }

    const existing = TransactionStore.getAllTransactions();
    let credited = 0;
    let totalAmount = 0;

    for (const flwTx of combinedTxs) {
      const virtualAccNo = (flwTx.meta?.virtualaccountnumber || '').toString().replace(/\s/g, '');
      const flwEmail = (flwTx.customer?.email || '').toLowerCase().trim();
      const flwTxRef = (flwTx.tx_ref || '').toString();
      const flwTxRefMatch = flwTxRef.match(/RENTILLY_ACC_(usr_[^_]+)/);
      const flwTxRefUserId = flwTxRefMatch ? flwTxRefMatch[1] : '';

      const matchesEmail   = flwEmail === cleanEmail;
      const matchesAcc     = cleanAccNo && virtualAccNo && virtualAccNo === cleanAccNo;
      const matchesTxRef   = resolvedId && flwTxRefUserId && flwTxRefUserId === resolvedId;

      if (!matchesEmail && !matchesAcc && !matchesTxRef) continue;

      const alreadyCaptured = existing.some(e =>
        e.reference === flwTx.flw_ref ||
        e.reference === flwTx.tx_ref ||
        e.id === `FLW_TX_${flwTx.id}`
      );
      if (alreadyCaptured) continue;

      const amount = Number(flwTx.amount || 0);
      if (amount <= 0) continue;

      await TransactionStore.addTransaction({
        id: `FLW_TX_${flwTx.id}`,
        userId: resolvedId,
        email: cleanEmail,
        title: `Recovered Credit — ₦${amount.toLocaleString()}`,
        type: 'Electronic Bank Inbound Deposit',
        category: 'deposit',
        amount,
        isCredit: true,
        reference: flwTx.flw_ref || flwTx.tx_ref,
        sender: flwTx.meta?.originatorname || flwTx.narration || 'Inbound Transfer',
        beneficiary: userRecord.fullName,
        status: 'SUCCESSFUL',
        date: flwTx.created_at || new Date().toISOString()
      });

      credited++;
      totalAmount += amount;

      // Update wallet balance in memory
      const freshUser = await UserStore.findByEmail(cleanEmail);
      if (freshUser) {
        UserStore.upsertUser({
          ...freshUser,
          walletBalance: (freshUser.walletBalance ?? 0) + amount,
          updatedAt: new Date().toISOString()
        });
      }

      // Update in Supabase
      if (supabase) {
        const { data: sbUser } = await supabase.from('users').select('wallet_balance').eq('email', cleanEmail).single();
        const sbBal = (sbUser as any)?.wallet_balance ?? 0;
        await supabase.from('users').update({ wallet_balance: sbBal + amount }).eq('email', cleanEmail);

        await supabase.from('transactions').upsert({
          id: `FLW_TX_${flwTx.id}`,
          user_id: resolvedId,
          email: cleanEmail,
          title: `Recovered Credit — ₦${amount.toLocaleString()}`,
          type: 'Electronic Bank Inbound Deposit',
          category: 'deposit',
          amount,
          is_credit: true,
          reference: flwTx.flw_ref || flwTx.tx_ref,
          sender: flwTx.meta?.originatorname || flwTx.narration || 'Inbound Transfer',
          status: 'SUCCESSFUL',
          date: flwTx.created_at || new Date().toISOString()
        }, { onConflict: 'id' });
      }
    }

    const finalBal = TransactionStore.computeNetBalance(cleanEmail);
    res.json({
      status: true,
      message: `User registered. ${credited} missed transaction(s) recovered totalling ₦${totalAmount.toLocaleString()}.`,
      userId: resolvedId,
      email: cleanEmail,
      accountNumber: cleanAccNo,
      transactionsCredited: credited,
      totalCredited: totalAmount,
      currentBalance: finalBal
    });
  } catch (err: any) {
    console.error('[adminRegisterAndCreditUser] Error:', err.message);
    res.status(500).json({ error: err.message });
  }
}

// 8b. Admin Manual Balance Reconciliation — force-syncs all FLW inbound credits
export async function adminReconcileBalance(req: Request, res: Response) {
  try {
    const { email, accountNumber } = req.body;
    const cleanEmail = (email || '').toString().toLowerCase().trim();
    const cleanAccNo = (accountNumber || '').toString().replace(/\s/g, '');

    if (!cleanEmail && !cleanAccNo) {
      return res.status(400).json({ error: 'Provide email or accountNumber to reconcile.' });
    }

    // Determine user
    let user = cleanEmail ? await UserStore.findByEmail(cleanEmail) : undefined;

    if (!user && cleanAccNo) {
      const allUsers = UserStore.getAllUsers();
      user = allUsers.find(u => u.accountNumber?.replace(/\s/g, '') === cleanAccNo);
    }

    // Fetch ALL successful FLW transactions (no email filter — for account number matching)
    const FLW_SECRET = process.env.FLUTTERWAVE_SECRET_KEY || FlutterwaveService.getSecretKey();

    const today = new Date().toISOString().slice(0, 10);
    const fromDate = '2026-01-01';
    const flwRes = await fetch(
      `https://api.flutterwave.com/v3/transactions?from=${fromDate}&to=${today}&status=successful`,
      { headers: { Authorization: `Bearer ${FLW_SECRET}`, 'Content-Type': 'application/json' } }
    );
    const flwJson = await flwRes.json() as any;
    const allTxs: any[] = flwJson?.data || [];

    const existing = TransactionStore.getAllTransactions();
    let credited = 0;
    let totalAmount = 0;

    for (const flwTx of allTxs) {
      const virtualAccNo = (flwTx.meta?.virtualaccountnumber || '').toString().replace(/\s/g, '');
      const flwEmail = (flwTx.customer?.email || '').toLowerCase().trim();
      const flwTxRef = (flwTx.tx_ref || '').toString();
      const flwTxRefMatch = flwTxRef.match(/RENTILLY_ACC_(usr_[^_]+)/);
      const flwTxRefUserId = flwTxRefMatch ? flwTxRefMatch[1] : '';

      const matchesEmail = cleanEmail && flwEmail === cleanEmail;
      const matchesAcc   = cleanAccNo && virtualAccNo && virtualAccNo === cleanAccNo;
      const userMatchesAcc = user?.accountNumber && virtualAccNo && user.accountNumber.replace(/\s/g, '') === virtualAccNo;
      const matchesTxRefUser = user?.id && flwTxRefUserId && flwTxRefUserId === user.id;

      if (!matchesEmail && !matchesAcc && !userMatchesAcc && !matchesTxRefUser) continue;

      const alreadyCaptured = existing.some(e =>
        e.reference === flwTx.flw_ref ||
        e.reference === flwTx.tx_ref ||
        e.id === `FLW_TX_${flwTx.id}`
      );
      if (alreadyCaptured) continue;

      const amount = Number(flwTx.amount || 0);
      if (amount <= 0) continue;

      const resolvedEmail = user?.email || cleanEmail || flwEmail;
      const resolvedUserId = user?.id || `usr_${resolvedEmail}`;

      await TransactionStore.addTransaction({
        id: `FLW_TX_${flwTx.id}`,
        userId: resolvedUserId,
        email: resolvedEmail,
        title: `Recovered Credit — ₦${amount.toLocaleString()}`,
        type: 'Electronic Bank Inbound Deposit',
        category: 'deposit',
        amount: amount,
        isCredit: true,
        reference: flwTx.flw_ref || flwTx.tx_ref,
        sender: flwTx.meta?.originatorname || flwTx.narration || 'Inbound Transfer',
        beneficiary: user?.fullName || resolvedEmail,
        status: 'SUCCESSFUL',
        date: flwTx.created_at || new Date().toISOString()
      });

      credited++;
      totalAmount += amount;

      // Update wallet balance
      const freshUser = await UserStore.findByEmail(resolvedEmail);
      if (freshUser) {
        UserStore.upsertUser({
          ...freshUser,
          walletBalance: (freshUser.walletBalance ?? 0) + amount,
          updatedAt: new Date().toISOString()
        });
      }
    }

    const finalBal = TransactionStore.computeNetBalance(user?.email || cleanEmail);
    res.json({
      status: true,
      message: `Reconciliation complete. ${credited} missed transaction(s) recovered totalling ₦${totalAmount.toLocaleString()}.`,
      transactionsCredited: credited,
      totalCredited: totalAmount,
      currentBalance: finalBal
    });
  } catch (err: any) {
    console.error('[adminReconcileBalance] Error:', err.message);
    res.status(500).json({ error: err.message });
  }
}
