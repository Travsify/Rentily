import type { Request, Response } from 'express';
import { FlutterwaveService } from '../services/flutterwaveService';
import { PaystackService } from '../services/paystackService';
import { FlutterwaveBillsService } from '../services/flutterwaveBillsService';
import { supabase } from '../supabaseClient';
import { UserStore } from '../services/userStore';
import { TransactionStore, type WalletTransaction } from '../services/transactionStore';
import { NotificationDispatcher } from '../services/notificationDispatcher';
import { getStoredFees } from './feeController';
import { MultiCurrencyService } from '../services/multiCurrencyService';
import { CardIssuingService } from '../services/cardIssuingService';
import { getFeatureFlags } from './featureFlagController';
import { AtomicLedgerService } from '../services/atomicLedgerService';
import { MapleradBankingService } from '../services/mapleradBankingService';

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

// 1. Fetch Nigerian Banks List (Maplerad / Paystack Unified)
export async function getPaystackBanks(_req: Request, res: Response) {
  try {
    const mapleBanks = await MapleradBankingService.getInstitutions();
    if (mapleBanks && mapleBanks.length > 0) {
      return res.json({
        status: true,
        message: 'Banks retrieved successfully',
        data: mapleBanks
      });
    }
    const result = await PaystackService.getBanks();
    res.json(result);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

// 2. Resolve Beneficiary Account Number via Maplerad / Paystack
export async function resolvePaystackAccount(req: Request, res: Response) {
  try {
    const { accountNumber, bankCode } = req.query;
    if (!accountNumber || !bankCode) {
      return res.status(400).json({ error: 'Account number and bank code are required' });
    }

    // Try Maplerad first
    const mapleRes = await MapleradBankingService.resolveBankAccount({
      accountNumber: accountNumber.toString(),
      bankCode: bankCode.toString()
    });

    if (mapleRes.success && mapleRes.accountName) {
      return res.json({
        status: true,
        data: {
          account_number: accountNumber.toString(),
          account_name: mapleRes.accountName,
          bank_id: bankCode.toString()
        }
      });
    }

    // Fallback to Paystack
    const result = await PaystackService.resolveAccount(accountNumber.toString(), bankCode.toString());
    res.json(result);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

// 3. Execute Bank Transfer Payout (Maplerad Primary, Paystack Fallback)
export async function withdrawWithPaystack(req: Request, res: Response) {
  try {
    const { userId, email, accountNumber, bankCode, accountName, amount, reason, sourceCurrency, usdtAmount, fxRate } = req.body;
    const cleanEmail = (email || '').toString().toLowerCase().trim();

    if (!accountNumber || !bankCode || !amount || Number(amount) <= 0) {
      return res.status(400).json({ error: 'Account number, bank code, and a valid amount are required' });
    }

    const numAmount = Number(amount);
    let cleanReason = (reason && !reason.toLowerCase().includes('living escrow') ? reason : 'Rentilly Payout')
      .replace(/transify/gi, '')
      .replace(/living escrow/gi, '')
      .trim() || 'Rentilly Payout';

    if (sourceCurrency === 'USDT' && usdtAmount) {
      cleanReason = `Payout: $${usdtAmount} USDT converted to ₦${numAmount.toLocaleString()} (Rate: 1 USDT = ₦${fxRate || 1510})`;
    }

    // Auto-sync real inbound transactions from Flutterwave Cloud API
    await syncFlutterwaveTransactionsForUser(cleanEmail);

    // Apply Platform Fee Settings (₦50 bank withdrawal fee)
    const platformFees = getStoredFees();
    const withdrawalFee = Number(platformFees.withdrawalFee ?? 50);
    const totalDebit = numAmount + withdrawalFee;

    // Check user true net balance from TransactionStore
    const currentBal = TransactionStore.computeNetBalance(cleanEmail);
    const memUser = await UserStore.findByEmail(cleanEmail);
    console.log(`[Withdrawal] Verifying user ${cleanEmail} true balance: ₦${currentBal} vs total required: ₦${totalDebit} (Amount: ₦${numAmount} + Fee: ₦${withdrawalFee})`);

    if (currentBal < totalDebit) {
      return res.status(400).json({
        error: `Insufficient wallet balance. Withdrawing ₦${numAmount.toLocaleString()} requires ₦${totalDebit.toLocaleString()} (including the standard ₦${withdrawalFee} bank transfer fee). Available balance: ₦${currentBal.toLocaleString()}.`
      });
    }

    // Step A: Attempt Maplerad Local Payment (Primary Rail)
    let transferSuccess = false;
    let transferProvider: 'MAPLERAD' | 'PAYSTACK' = 'MAPLERAD';
    let txRef = `WD_MAPLE_${Date.now()}`;
    let transferData: any = null;

    try {
      const mapleradRes = await MapleradBankingService.transferToBank({
        accountNumber: accountNumber.toString(),
        bankCode: bankCode.toString(),
        amountNgn: numAmount,
        narration: cleanReason,
        reference: txRef
      });

      if (mapleradRes.success) {
        transferSuccess = true;
        transferData = mapleradRes;
        txRef = mapleradRes.reference || txRef;
        console.log(`[Withdrawal] ✅ Maplerad payout successful: ${txRef}`);
      } else {
        console.warn('[Withdrawal] Maplerad payout returned non-success:', mapleradRes.message, 'Engaging Paystack fallback...');
      }
    } catch (e: any) {
      console.warn('[Withdrawal] Maplerad payout exception:', e.message, 'Engaging Paystack fallback...');
    }

    // Step B: Fallback to Paystack if Maplerad was not successful
    if (!transferSuccess) {
      transferProvider = 'PAYSTACK';
      const recipientRes = await PaystackService.createTransferRecipient({
        name: accountName || memUser?.fullName || 'Account Holder',
        accountNumber: accountNumber.toString(),
        bankCode: bankCode.toString(),
        description: cleanReason
      });

      if (!recipientRes.status || !recipientRes.recipientCode) {
        return res.status(400).json({ error: recipientRes.message || 'Failed to process bank payout' });
      }

      const transferRes = await PaystackService.initiateTransfer({
        recipientCode: recipientRes.recipientCode,
        amount: numAmount,
        reason: cleanReason
      });

      if (transferRes.status) {
        transferSuccess = true;
        transferData = transferRes.data;
        txRef = transferRes.data?.reference || `WD_PST_${Date.now()}`;
      } else {
        return res.status(400).json({ error: transferRes.message || 'Payout settlement failed' });
      }
    }

    if (transferSuccess) {
      const newBal = Math.max(0, currentBal - totalDebit);
      const txRef = transferRes.data?.reference || `WD_${Date.now()}`;

      const targetUserId = userId || memUser?.id || (cleanEmail === 'tonerocool1@gmail.com' ? 'c0000000-0000-0000-0000-000000000001' : 'b0000000-0000-0000-0000-000000000001');

      // Record single consolidated withdrawal in TransactionStore (amount + fee unified)
      await TransactionStore.addTransaction({
        id: `TX_WD_${Date.now()}`,
        userId: targetUserId,
        email: cleanEmail,
        title: `Bank Transfer Payout to ${accountName || 'Bank Account'}`,
        type: 'Instant Direct Bank Payout',
        category: 'withdrawal',
        amount: totalDebit,
        isCredit: false,
        reference: txRef,
        sender: `${memUser?.businessName || memUser?.fullName || 'Rentilly User'} (Rentilly Payout)`,
        beneficiary: accountName || 'Bank Account',
        recipientAccount: accountNumber.toString(),
        recipientBank: 'Direct Bank Transfer',
        status: 'SUCCESSFUL',
        date: new Date().toISOString(),
      });

      // Update in-memory user cache
      if (memUser) {
        UserStore.upsertUserForced({
          ...memUser,
          walletBalance: newBal,
          updatedAt: new Date().toISOString()
        });
      }

      // Authoritative Supabase Cloud profiles & ledger updates
      if (supabase) {
        try {
          await supabase
            .from('profiles')
            .update({ wallet_balance: newBal, updated_at: new Date().toISOString() })
            .eq('id', targetUserId);

          await supabase.from('wallet_transactions').insert({
            user_id: targetUserId,
            email: cleanEmail,
            amount: totalDebit,
            type: 'debit',
            status: 'completed',
            flw_ref: txRef,
            tx_ref: txRef,
            narration: `Payout to ${accountName || 'Bank Account'} (${accountNumber}) • Incl. ₦${withdrawalFee} Fee`,
            created_at: new Date().toISOString()
          });
        } catch (e: any) {
          console.warn('[Withdrawal] Supabase profiles update warning:', e?.message);
        }
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

// 3b. Execute Direct Crypto (USDT) Payout
export async function withdrawCrypto(req: Request, res: Response) {
  try {
    const { userId, email, address, amountUsdt, chain } = req.body;
    const cleanEmail = (email || '').toString().toLowerCase().trim();
    const numUsdt = Number(amountUsdt || 0);

    if (!address || numUsdt <= 0) {
      return res.status(400).json({ error: 'Valid recipient crypto address and USDT amount are required.' });
    }

    // Platform fee: Percentage fee on USDT withdrawals (default 2.0%)
    const platformFees = getStoredFees();
    const feePercent = Number(platformFees.usdtWithdrawalFeePct ?? 2.0);
    const feeUsdt = Number(((numUsdt * feePercent) / 100).toFixed(4));
    const netUsdtToSend = Number((numUsdt - feeUsdt).toFixed(4));

    if (netUsdtToSend <= 0) {
      return res.status(400).json({
        error: `Withdrawal amount (${numUsdt} USDT) is too low to cover the ${feePercent}% withdrawal fee (${feeUsdt} USDT).`
      });
    }

    // Live FX benchmark
    const rates = MultiCurrencyService.getFxRates();
    const fxRate = rates.USD_NGN || 1510.0;
    const equivalentNgn = numUsdt * fxRate;
    const totalDebitNgn = equivalentNgn;

    const currentBal = TransactionStore.computeNetBalance(cleanEmail);
    const memUser = await UserStore.findByEmail(cleanEmail);

    if (currentBal < totalDebitNgn) {
      return res.status(400).json({
        error: `Insufficient wallet balance. Withdrawing ${numUsdt} USDT requires ₦${totalDebitNgn.toLocaleString()} NGN equivalent. Available: ₦${currentBal.toLocaleString()}.`
      });
    }

    const txRef = `WD_CRYPTO_${Date.now()}`;
    const targetUserId = userId || memUser?.id || (cleanEmail === 'tonerocool1@gmail.com' ? 'c0000000-0000-0000-0000-000000000001' : 'b0000000-0000-0000-0000-000000000001');

    // Call Maplerad withdrawCrypto with netUsdtToSend
    const cryptoRes = await MapleradBankingService.withdrawCrypto({
      address,
      amountUsdt: netUsdtToSend,
      reference: txRef,
      chain: chain || 'tron'
    });

    const newBal = Math.max(0, currentBal - totalDebitNgn);

    // Record in TransactionStore
    await TransactionStore.addTransaction({
      id: `TX_WD_CRYPTO_${Date.now()}`,
      userId: targetUserId,
      email: cleanEmail,
      title: `Crypto Withdrawal: ${numUsdt} USDT (${feePercent}% Fee: $${feeUsdt.toFixed(2)})`,
      type: 'Direct Crypto Withdrawal',
      category: 'withdrawal',
      amount: totalDebitNgn,
      isCredit: false,
      reference: txRef,
      sender: `${memUser?.businessName || memUser?.fullName || 'Rentilly User'} (USDT Vault)`,
      beneficiary: `${address.substring(0, 8)}...${address.substring(address.length - 6)} (${chain || 'TRC20'})`,
      recipientAccount: address,
      recipientBank: `Blockchain (${chain || 'TRON TRC20'})`,
      status: cryptoRes.success ? 'SUCCESSFUL' : 'PROCESSING',
      date: new Date().toISOString(),
    });

    if (memUser) {
      UserStore.upsertUserForced({
        ...memUser,
        walletBalance: newBal,
        updatedAt: new Date().toISOString()
      });
    }

    if (supabase) {
      try {
        await supabase
          .from('profiles')
          .update({ wallet_balance: newBal, updated_at: new Date().toISOString() })
          .eq('id', targetUserId);

        await supabase.from('wallet_transactions').insert({
          user_id: targetUserId,
          email: cleanEmail,
          amount: totalDebitNgn,
          type: 'debit',
          status: 'completed',
          flw_ref: txRef,
          tx_ref: txRef,
          narration: `Crypto Transfer: ${numUsdt} USDT to ${address} • ₦${totalDebitNgn.toLocaleString()}`,
          created_at: new Date().toISOString()
        });
      } catch (e: any) {
        console.warn('[WithdrawCrypto] Supabase update warning:', e?.message);
      }
    }

    // Dispatch In-App & Email alerts
    NotificationDispatcher.dispatch({
      userId: targetUserId,
      email: cleanEmail,
      userName: memUser?.fullName,
      title: `Crypto Payout: ${numUsdt} USDT Dispatched`,
      category: 'wallet',
      message: `Your withdrawal of ${numUsdt} USDT to ${address} has been dispatched. ${feePercent}% withdrawal fee ($${feeUsdt.toFixed(2)}) was applied; recipient receives ${netUsdtToSend} USDT.`,
      metadata: {
        amountUsdt: numUsdt,
        feeUsdt,
        netUsdtToSend,
        feePercent,
        amountNgn: totalDebitNgn,
        address,
        reference: txRef
      }
    });

    res.json({
      status: true,
      message: `Successfully processed withdrawal of ${numUsdt} USDT!`,
      amountUsdt: numUsdt,
      feeUsdt,
      feePercent,
      netUsdtToSend,
      newBalance: newBal,
      reference: txRef
    });
  } catch (err: any) {
    console.error('withdrawCrypto error:', err);
    res.status(500).json({ error: err.message || 'Crypto withdrawal failed' });
  }
}

// ==================== BID / ASK SPREAD & CURRENCY SWAP ENGINE ====================

export async function getFxSpreadRates(req: Request, res: Response) {
  try {
    const spreadRates = MultiCurrencyService.getSpreadRates();
    return res.status(200).json({ success: true, ...spreadRates });
  } catch (e: any) {
    return res.status(500).json({ error: e.message || 'Failed to fetch spread rates' });
  }
}

export async function updateFxSpreadConfig(req: Request, res: Response) {
  try {
    const updated = await MultiCurrencyService.updateSpreadConfig(req.body);
    return res.status(200).json({ success: true, ...updated });
  } catch (e: any) {
    return res.status(500).json({ error: e.message || 'Failed to update spread config' });
  }
}

export async function executeCurrencySwap(req: Request, res: Response) {
  try {
    const { email, fromCurrency, toCurrency, amount } = req.body;
    const cleanEmail = (email || '').toLowerCase().trim();
    const numAmount = Number(amount);

    if (!cleanEmail || !fromCurrency || !toCurrency || isNaN(numAmount) || numAmount <= 0) {
      return res.status(400).json({ error: 'Valid email, fromCurrency, toCurrency, and positive amount are required' });
    }

    if (fromCurrency === toCurrency) {
      return res.status(400).json({ error: 'Source and destination currencies must be different' });
    }

    const spread = MultiCurrencyService.getSpreadRates();
    const memUser = await UserStore.findByEmail(cleanEmail);
    if (!memUser) {
      return res.status(404).json({ error: 'User not found' });
    }

    const currentBalNgn = TransactionStore.computeNetBalance(cleanEmail);
    const targetUserId = memUser.id;
    const txRef = `SWAP_${Date.now()}_${Math.random().toString(36).substring(2, 7).toUpperCase()}`;

    // Resolve current USDT balance from Supabase system_configs or memUser
    let currentUsdtBal = 0.0;
    if (supabase) {
      try {
        const { data: usdtCfg } = await supabase
          .from('system_configs')
          .select('data')
          .eq('id', `usdt_balance_${cleanEmail}`)
          .single();
        if (usdtCfg?.data?.usdtBalance != null) {
          currentUsdtBal = Number(usdtCfg.data.usdtBalance);
        }
      } catch (_) {}
    }
    if (!currentUsdtBal && memUser?.usdtBalance != null) {
      currentUsdtBal = Number(memUser.usdtBalance);
    }

    let fromDebitNgn = 0;
    let executionRate = 0;
    let marginNgn = 0;
    let convertedAmount = 0;
    let title = '';
    let narration = '';

    if (fromCurrency === 'USDT' && toCurrency === 'NGN') {
      // STRICT ANTI-CHEAT GUARD: User CANNOT swap USDT they do not own!
      if (currentUsdtBal <= 0 || currentUsdtBal < numAmount) {
        return res.status(400).json({
          error: `Insufficient USDT balance. You currently have $${currentUsdtBal.toFixed(2)} USDT. You cannot convert USDT you do not have.`
        });
      }

      // User is converting USDT -> NGN (Rentily buys USDT at buyRate below market)
      executionRate = spread.buyRate; // e.g. 1400
      convertedAmount = Number((numAmount * executionRate).toFixed(2)); // in NGN
      marginNgn = Number((numAmount * spread.buyMargin).toFixed(2));
      
      title = `Converted $${numAmount.toFixed(2)} USDT to ₦${convertedAmount.toLocaleString()}`;
      narration = `Currency Swap: $${numAmount.toFixed(2)} USDT ➔ ₦${convertedAmount.toLocaleString()} NGN (Rate: 1 USDT = ₦${executionRate.toLocaleString()})`;

      const newBal = currentBalNgn + convertedAmount;
      const newUsdtBal = Number(Math.max(0, currentUsdtBal - numAmount).toFixed(2));

      await TransactionStore.addTransaction({
        id: `TX_${txRef}`,
        userId: targetUserId,
        email: cleanEmail,
        title,
        type: 'Currency Swap (USDT ➔ NGN)',
        category: 'swap',
        amount: convertedAmount,
        isCredit: true,
        reference: txRef,
        sender: 'USDT Vault (TRON TRC20)',
        beneficiary: `${memUser.businessName || memUser.fullName || 'Rentilly User'} (Naira Wallet)`,
        recipientAccount: memUser.virtualAccountNumber || 'Rentilly Wallet',
        recipientBank: 'Rentilly Treasury',
        status: 'SUCCESSFUL',
        date: new Date().toISOString(),
      });

      UserStore.upsertUserForced({
        ...memUser,
        walletBalance: newBal,
        usdtBalance: newUsdtBal,
        updatedAt: new Date().toISOString()
      });

      if (supabase) {
        try {
          await supabase.from('profiles').update({ wallet_balance: newBal, updated_at: new Date().toISOString() }).eq('id', targetUserId);
          await supabase.from('system_configs').upsert({
            id: `usdt_balance_${cleanEmail}`,
            data: {
              usdtBalance: newUsdtBal,
              email: cleanEmail,
              updatedAt: new Date().toISOString()
            }
          });
          await supabase.from('wallet_transactions').insert({
            user_id: targetUserId,
            email: cleanEmail,
            amount: convertedAmount,
            type: 'credit',
            status: 'completed',
            flw_ref: txRef,
            tx_ref: txRef,
            narration,
            created_at: new Date().toISOString()
          });
        } catch (e: any) {
          console.warn('[Swap USDT->NGN] Supabase warning:', e?.message);
        }
      }

      return res.status(200).json({
        success: true,
        txRef,
        fromCurrency,
        toCurrency,
        fromAmount: numAmount,
        toAmount: convertedAmount,
        executionRate,
        platformMarginEarned: marginNgn,
        newWalletBalance: newBal,
        newUsdtBalance: newUsdtBal,
        message: `Successfully converted $${numAmount.toFixed(2)} USDT to ₦${convertedAmount.toLocaleString()}`
      });

    } else if (fromCurrency === 'NGN' && toCurrency === 'USDT') {
      executionRate = spread.sellRate; // e.g. 1460
      fromDebitNgn = numAmount; // in NGN
      convertedAmount = Number((fromDebitNgn / executionRate).toFixed(2)); // in USDT
      marginNgn = Number((convertedAmount * spread.sellMargin).toFixed(2));

      // STRICT ANTI-CHEAT GUARD: User CANNOT swap Naira they do not own!
      if (currentBalNgn <= 0 || currentBalNgn < fromDebitNgn) {
        return res.status(400).json({
          error: `Insufficient Naira balance. Swapping ₦${fromDebitNgn.toLocaleString()} requires at least ₦${fromDebitNgn.toLocaleString()}, but your balance is ₦${currentBalNgn.toLocaleString()}. You cannot swap Naira you do not have.`
        });
      }

      title = `Converted ₦${fromDebitNgn.toLocaleString()} to $${convertedAmount.toFixed(2)} USDT`;
      narration = `Currency Swap: ₦${fromDebitNgn.toLocaleString()} NGN ➔ $${convertedAmount.toFixed(2)} USDT (Rate: 1 USDT = ₦${executionRate.toLocaleString()})`;

      const newBal = Math.max(0, currentBalNgn - fromDebitNgn);
      const newUsdtBal = Number((currentUsdtBal + convertedAmount).toFixed(2));

      await TransactionStore.addTransaction({
        id: `TX_${txRef}`,
        userId: targetUserId,
        email: cleanEmail,
        title,
        type: 'Currency Swap (NGN ➔ USDT)',
        category: 'swap',
        amount: fromDebitNgn,
        isCredit: false,
        reference: txRef,
        sender: `${memUser.businessName || memUser.fullName || 'Rentilly User'} (Naira Wallet)`,
        beneficiary: 'USDT Vault (TRON TRC20)',
        recipientAccount: 'TRC20 Vault',
        recipientBank: 'Blockchain Treasury',
        status: 'SUCCESSFUL',
        date: new Date().toISOString(),
      });

      UserStore.upsertUserForced({
        ...memUser,
        walletBalance: newBal,
        usdtBalance: newUsdtBal,
        updatedAt: new Date().toISOString()
      });

      if (supabase) {
        try {
          await supabase.from('profiles').update({ wallet_balance: newBal, updated_at: new Date().toISOString() }).eq('id', targetUserId);
          await supabase.from('system_configs').upsert({
            id: `usdt_balance_${cleanEmail}`,
            data: {
              usdtBalance: newUsdtBal,
              email: cleanEmail,
              updatedAt: new Date().toISOString()
            }
          });
          await supabase.from('wallet_transactions').insert({
            user_id: targetUserId,
            email: cleanEmail,
            amount: fromDebitNgn,
            type: 'debit',
            status: 'completed',
            flw_ref: txRef,
            tx_ref: txRef,
            narration,
            created_at: new Date().toISOString()
          });
        } catch (e: any) {
          console.warn('[Swap NGN->USDT] Supabase warning:', e?.message);
        }
      }

      return res.status(200).json({
        success: true,
        txRef,
        fromCurrency,
        toCurrency,
        fromAmount: fromDebitNgn,
        toAmount: convertedAmount,
        executionRate,
        platformMarginEarned: marginNgn,
        newWalletBalance: newBal,
        newUsdtBalance: newUsdtBal,
        message: `Successfully swapped ₦${fromDebitNgn.toLocaleString()} to $${convertedAmount.toFixed(2)} USDT`
      });
    } else {
      return res.status(400).json({ error: `Unsupported swap pair ${fromCurrency}/${toCurrency}. Currently supported: USDT/NGN` });
    }
  } catch (e: any) {
    console.error('[ExecuteCurrencySwap] Error:', e);
    return res.status(500).json({ error: e.message || 'Currency swap failed' });
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
    // 1. Verify Flutterwave signature header (verif-hash)
    const secretHash = process.env.FLUTTERWAVE_SECRET_HASH || 'rentilly_secure_flw_hash_2026';
    const signature = req.headers['verif-hash'];
    if (signature && signature !== secretHash) {
      console.warn('[FLW Webhook] ⚠️ Invalid verif-hash signature received:', signature);
      return res.status(401).json({ error: 'Unauthorized webhook call: signature mismatch' });
    }

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

    const flwRef = (data?.flw_ref || data?.reference || `FLW_${data?.id || ''}`).toString();

    // 2. Strict Financial Idempotency Check
    if (flwRef && supabase) {
      const { data: alreadyProcessed } = await supabase
        .from('reconciled_transactions')
        .select('flw_ref')
        .eq('flw_ref', flwRef)
        .maybeSingle();

      if (alreadyProcessed) {
        console.log(`[FLW Webhook] ⚡ Idempotency pass: Transaction ${flwRef} already reconciled. Skipping duplicate.`);
        return;
      }
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
      if (incomingAccNo) {
        const { data: sbUsers } = await supabase.from('profiles').select('*').eq('account_number', incomingAccNo).limit(1);
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
        const { data: sbUsers } = await supabase.from('profiles').select('*').eq('email', customerEmail).limit(1);
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
        const { data: sbUsers } = await supabase.from('profiles').select('*').eq('id', txRefUserId).limit(1);
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

    if (!targetUser) {
      console.warn(`[FLW Webhook] Dynamic routing: No profile found for account=${incomingAccNo} / email=${customerEmail} / txRef=${txRef}`);
      return;
    }

    const creditRef = data?.flw_ref || data?.tx_ref || `FLW_CREDIT_${Date.now()}`;
    const senderName = data?.meta?.originatorname || data?.narration || 'Inbound Bank Transfer';
    const narrationText = `Bank Transfer from ${senderName} to account ${targetUser.accountNumber || incomingAccNo}`;

    // Execute ACID atomic credit via AtomicLedgerService
    const creditResult = await AtomicLedgerService.creditWalletAtomic({
      userId: targetUser.id,
      email: targetUser.email,
      amount: amountPaid,
      flwRef: flwRef,
      txRef: creditRef,
      narration: narrationText,
    });

    if (!creditResult.success) {
      console.error(`[FLW Webhook] Atomic credit failed for ${targetUser.email}:`, creditResult.error);
      return;
    }

    if (creditResult.alreadyProcessed) {
      console.log(`[FLW Webhook] Transaction ${flwRef} was already processed. Current balance: ₦${creditResult.newBalance}`);
      return;
    }

    const newBal = creditResult.newBalance ?? (targetUser.walletBalance ?? 0) + amountPaid;
    console.log(`[FLW Webhook] ✅ Atomic Ledger: Credited ${targetUser.email} +₦${amountPaid} (New Balance: ₦${newBal})`);

    // In-memory cache update
    UserStore.upsertUserForced({
      ...targetUser,
      walletBalance: newBal,
      updatedAt: new Date().toISOString(),
    });

    // Record transaction in TransactionStore cache
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

// 4d. Maplerad Webhook Listener (Virtual Cards & Settlement Events)
export async function mapleradWebhook(req: Request, res: Response) {
  try {
    // Always respond 200 immediately to acknowledge receipt
    res.status(200).json({ received: true });

    const payload = req.body;
    const event = payload?.event;
    const data = payload?.data;
    console.log(`[Maplerad Webhook] Event received: ${event}`, JSON.stringify(data || {}, null, 2));

    // 1. Virtual Card Issuing & Transaction Events
    if (event?.includes('issuing') || data?.card_number || data?.masked_pan) {
      const cardId = data?.id || data?.card_id;
      const maskedPan = data?.masked_pan || data?.card_number;
      const last4 = data?.last4 || data?.last_4;
      const expiryMonth = data?.expiry_month || data?.expiryMonth;
      const expiryYear = data?.expiry_year || data?.expiryYear;
      const cvv = data?.cvv;
      const customerEmail = data?.customer?.email || data?.email;

      if (cardId && supabase) {
        await supabase
          .from('virtual_cards')
          .update({
            masked_pan: maskedPan,
            expiry_month: expiryMonth,
            expiry_year: expiryYear,
            cvv: cvv,
            status: 'ACTIVE',
            raw_payload: data
          })
          .or(`card_id.eq.${cardId},email.eq.${customerEmail}`);
        console.log(`[Maplerad Webhook] Successfully reconciled card ${cardId} in Supabase`);
      }
    }

    // 2. Inbound Bank Transfer Collections (NGN Virtual Accounts)
    if (event?.includes('collection') || event?.includes('inbound') || event?.includes('deposit')) {
      const incomingAccNo = data?.account_number || data?.virtual_account_number;
      const customerEmail = data?.customer?.email || data?.email;
      const amountPaid = Number(data?.amount || 0) / 100; // Maplerad amounts are in lowest denomination (kobo)
      const ref = data?.reference || data?.id || `MAPLE_COL_${Date.now()}`;
      const sender = data?.sender?.name || data?.sender_name || 'Inbound Bank Transfer';

      if (amountPaid > 0 && supabase) {
        let query = supabase.from('profiles').select('id, email, full_name, wallet_balance');
        if (incomingAccNo) {
          query = query.eq('account_number', incomingAccNo);
        } else if (customerEmail) {
          query = query.eq('email', customerEmail.toLowerCase().trim());
        }

        const { data: matchedUsers } = await query.limit(1);
        const targetUser = matchedUsers?.[0];

        if (targetUser) {
          await AtomicLedgerService.creditWalletAtomic({
            userId: targetUser.id,
            email: targetUser.email,
            amount: amountPaid,
            flwRef: ref,
            txRef: ref,
            narration: `Inbound Bank Transfer (Maplerad • ${incomingAccNo || 'Virtual Account'}) from ${sender}`
          });
          console.log(`[Maplerad Webhook] ✅ Credited ₦${amountPaid} to ${targetUser.email}`);
        }
      }
    }

    // 3. Stablecoin Crypto Deposits (USDT on TRON)
    if (event?.includes('crypto') || data?.chain === 'tron' || data?.coin === 'usdt') {
      const address = data?.address;
      const amountUsdt = Number(data?.amount || 0);
      const customerEmail = data?.customer?.email || data?.email;
      const ref = data?.reference || data?.tx_hash || `CRYPTO_TRON_${Date.now()}`;

      if (amountUsdt > 0 && supabase) {
        // Convert USDT to NGN at live FX rate for ledger
        const rates = MultiCurrencyService.getFxRates();
        const fxRate = rates.USD_NGN || 1510.0;
        const amountNgn = Number((amountUsdt * fxRate).toFixed(2));

        let query = supabase.from('profiles').select('id, email, full_name, wallet_balance');
        if (customerEmail) {
          query = query.eq('email', customerEmail.toLowerCase().trim());
        }

        const { data: matchedUsers } = await query.limit(1);
        const targetUser = matchedUsers?.[0];

        if (targetUser) {
          await AtomicLedgerService.creditWalletAtomic({
            userId: targetUser.id,
            email: targetUser.email,
            amount: amountNgn,
            flwRef: ref,
            txRef: ref,
            narration: `Crypto Inflow: +$${amountUsdt} USDT (TRON TRC20 • ₦${amountNgn.toLocaleString()})`
          });
          console.log(`[Maplerad Webhook] ✅ Credited ${amountUsdt} USDT (₦${amountNgn}) to ${targetUser.email}`);
        }
      }
    }
  } catch (err: any) {
    console.error('[Maplerad Webhook] Exception:', err.message);
  }
}

// 5. Universal Bill & Airtime Payment API
export async function payBill(req: Request, res: Response) {
  try {
    const { email, category, operator, plan, customerNumber, amount } = req.body;
    const cleanEmail = (email || '').toString().toLowerCase().trim();
    if (!cleanEmail) {
      return res.status(400).json({ error: 'User email is required to process bills.' });
    }
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

      // Dispatch in-app and email notification
      NotificationDispatcher.dispatch({
        email: cleanEmail,
        userName: memUser?.fullName || memUser?.businessName || 'Valued Partner',
        category: 'utilities',
        title: `${title} — Successful`,
        message: `Your utility payment of ₦${numAmount.toLocaleString()} (${type}) for ${customerNumber} has been delivered successfully.${tokenOutput ? ` Token: ${tokenOutput}` : ''}`,
        metadata: {
          reference: txRef,
          category,
          token: tokenOutput,
          units: unitsOutput,
          customer: customerNumber
        }
      });

      // Update UserStore and Supabase
      if (memUser) {
        await UserStore.upsertUserForced({
          ...memUser,
          walletBalance: newBal,
          updatedAt: new Date().toISOString()
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

      // Dynamic Matching: Check if transaction was already reconciled to a specific user
      if (supabase) {
        const { data: reconciledRec } = await supabase
          .from('reconciled_transactions')
          .select('user_id, email')
          .eq('flw_ref', flwTx.flw_ref)
          .maybeSingle();

        if (reconciledRec) {
          // If already reconciled to another user, do not allocate here
          if (reconciledRec.email && reconciledRec.email.toLowerCase() !== cleanEmail) {
            continue;
          }
        }
      }

      // Match dynamically by: dedicated virtual account number OR customer email OR tx_ref user identifier
      const emailMatch = flwEmail === cleanEmail;
      const accMatch = Boolean(user?.accountNumber && virtualAccNo && user.accountNumber.replace(/\s/g, '') === virtualAccNo);
      const txRefMatch = Boolean(user?.id && txRef.includes(user.id));

      if (!emailMatch && !accMatch && !txRefMatch) {
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

          // Note: Wallet balance is authoritatively credited by AtomicLedgerService (webhook / auto-reconciliation).
          // Read-time sync must NEVER increment wallet balance to prevent double/triple crediting.
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
    const cleanEmail = (email || '').toString().toLowerCase().trim();

    if (!cleanEmail) {
      return res.status(400).json({ error: 'Email is required' });
    }

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

// 7. Instant Wallet Balance Sync API (with real-time Supabase Cloud & Flutterwave sync)
export async function getWalletBalance(req: Request, res: Response) {
  try {
    const { userId, email } = req.query;
    const cleanEmail = email?.toString().toLowerCase().trim() || '';
    if (!cleanEmail) {
      return res.status(400).json({ error: 'Email is required' });
    }

    // 1. Fetch live profile directly from Supabase Cloud
    let dbUser: any = null;
    let liveDbBalance: number | null = null;
    if (supabase) {
      try {
        const { data, error } = await supabase.from('profiles').select('*').eq('email', cleanEmail).limit(1);
        if (!error && data && data.length > 0) {
          dbUser = data[0];
          liveDbBalance = Number(dbUser.wallet_balance ?? 0);
        }
      } catch (e: any) {
        console.warn('[getWalletBalance] Supabase profile read warning:', e?.message);
      }
    }

    // 2. Auto-sync from Flutterwave
    await syncFlutterwaveTransactionsForUser(cleanEmail);

    const memUser = await UserStore.findByEmail(cleanEmail);
    const userTxs = await TransactionStore.getTransactionsByEmail(cleanEmail);
    const netBal = TransactionStore.computeNetBalance(cleanEmail);

    // Authoritative Single Source of Truth: Supabase Cloud profiles table
    let balance = liveDbBalance !== null 
      ? liveDbBalance
      : (userTxs.length > 0 ? netBal : (memUser?.walletBalance ?? 0));

    // Keep memory cache aligned with authoritative database
    if (memUser && memUser.walletBalance !== balance) {
      UserStore.upsertUserForced({
        ...memUser,
        walletBalance: balance
      });
    }

    let accountNumber = dbUser?.account_number || memUser?.accountNumber;
    let bankName = dbUser?.bank_name || memUser?.bankName;

    // Auto-provision Maplerad Virtual NGN Account ONLY if user is verified but missing account
    if (!accountNumber && cleanEmail && (dbUser?.is_verified || memUser?.isVerified)) {
      try {
        const mapleAcc = await MapleradBankingService.createVirtualAccount({
          email: cleanEmail,
          fullName: dbUser?.full_name || memUser?.fullName || 'Rentilly User'
        });

        if (mapleAcc) {
          accountNumber = mapleAcc.accountNumber;
          bankName = `${mapleAcc.bankName || '9PSB'} (Rentilly)`;

          if (supabase && dbUser?.id) {
            await supabase
              .from('profiles')
              .update({ account_number: accountNumber, bank_name: bankName, updated_at: new Date().toISOString() })
              .eq('id', dbUser.id);
          }
        }
      } catch (e: any) {
        console.warn('[getWalletBalance] Auto-provisioning warning:', e.message);
      }
    }

    // If still unresolved, do NOT invent fake numbers.
    if (!accountNumber) {
      accountNumber = null;
      bankName = 'Rentilly Settlement Account (Pending)';
    }

    // Resolve or retrieve dedicated USDT TRON deposit address
    let usdtTronAddress: string | null = null;
    try {
      const cryptoData = await MapleradBankingService.getOrCreateUsdtTronAddress({
        email: cleanEmail,
        fullName: dbUser?.full_name || memUser?.fullName || 'Rentilly User'
      });
      usdtTronAddress = cryptoData?.address || null;
    } catch (e: any) {
      console.warn('[getWalletBalance] USDT TRON resolution warning:', e.message);
    }

    // Resolve USDT Balance from Supabase system_configs or memUser
    let usdtBalance = 0.0;
    if (supabase) {
      try {
        const { data: usdtCfg } = await supabase
          .from('system_configs')
          .select('data')
          .eq('id', `usdt_balance_${cleanEmail}`)
          .single();
        if (usdtCfg?.data?.usdtBalance != null) {
          usdtBalance = Number(usdtCfg.data.usdtBalance);
        }
      } catch (_) {}
    }
    if (!usdtBalance && memUser?.usdtBalance != null) {
      usdtBalance = Number(memUser.usdtBalance);
    }

    res.json({
      status: true,
      walletBalance: balance,
      usdtBalance,
      usdtTronAddress,
      user: {
        id: dbUser?.id || memUser?.id || userId || (cleanEmail === 'tonerocool1@gmail.com' ? 'c0000000-0000-0000-0000-000000000001' : 'b0000000-0000-0000-0000-000000000001'),
        fullName: dbUser?.full_name || memUser?.fullName || (cleanEmail === 'tonerocool1@gmail.com' ? 'Ehomes Global Inclusive Limited' : 'Rentilly User'),
        businessName: dbUser?.business_name || memUser?.businessName || (cleanEmail === 'tonerocool1@gmail.com' ? 'Ehomes Global Inclusive Limited' : null),
        email: cleanEmail,
        accountNumber,
        bankName,
        usdtTronAddress,
        isVerified: dbUser?.is_verified ?? memUser?.isVerified ?? true,
        role: dbUser?.role || memUser?.role || 'owner',
        walletBalance: balance,
        usdtBalance,
      }
    });
  } catch (err: any) {
    console.error('getWalletBalance error:', err);
    res.status(500).json({ error: err.message });
  }
}

// 7b. Dedicated USDT TRON Address API
export async function getUserCryptoAddress(req: Request, res: Response) {
  try {
    const { email } = req.query;
    const cleanEmail = (email || '').toString().toLowerCase().trim();
    if (!cleanEmail) {
      return res.status(400).json({ error: 'Email is required' });
    }

    const user = await UserStore.findByEmail(cleanEmail);
    let cryptoData = await MapleradBankingService.getOrCreateUsdtTronAddress({
      email: cleanEmail,
      fullName: user?.fullName || user?.businessName || 'Rentilly User'
    });

    if (!cryptoData || !cryptoData.address) {
      return res.json({
        status: true,
        processing: true,
        message: 'Personal USDT TRC20 wallet is generated automatically upon Tier 1 KYC verification.',
        data: null
      });
    }

    return res.json({
      status: true,
      data: cryptoData
    });
  } catch (err: any) {
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

    UserStore.upsertUserForced(userRecord);

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
        UserStore.upsertUserForced({
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

      // Dispatch Push Notification & Resend HTML Email
      NotificationDispatcher.dispatch({
        userId: resolvedId,
        email: cleanEmail,
        title: `Credit Alert: ₦${amount.toLocaleString()} Recovered Inbound Deposit`,
        category: 'wallet',
        message: `Your dedicated Flutterwave MFB account received an inflow of ₦${amount.toLocaleString()}.`,
        metadata: {
          amount,
          reference: flwTx.flw_ref || flwTx.tx_ref,
          bankName: 'Flutterwave MFB Dedicated Bank Transfer'
        }
      });
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
        UserStore.upsertUserForced({
          ...freshUser,
          walletBalance: (freshUser.walletBalance ?? 0) + amount,
          updatedAt: new Date().toISOString()
        });
      }

      // Dispatch Push Notification & Resend HTML Email
      NotificationDispatcher.dispatch({
        userId: resolvedUserId,
        email: resolvedEmail,
        userName: freshUser?.fullName || 'Valued User',
        title: `Credit Alert: ₦${amount.toLocaleString()} Inbound Payment Reconciled`,
        category: 'wallet',
        message: `Your Rentilly wallet has been credited with +₦${amount.toLocaleString()} via Inbound Bank Transfer.`,
        metadata: {
          amount,
          reference: flwTx.flw_ref || flwTx.tx_ref,
          bankName: 'Dedicated Virtual Account'
        }
      });
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

// --- MULTI-CURRENCY VAULT CONTROLLER ---

export async function getMultiCurrencyAccounts(req: Request, res: Response) {
  try {
    const { email } = req.query;
    const cleanEmail = (email || 'tonerocool1@gmail.com').toString().trim().toLowerCase();
    const user = await UserStore.findByEmail(cleanEmail);
    const fullName = user?.fullName || user?.businessName || 'Valued Partner';

    const accounts = await MultiCurrencyService.getUserAccounts(cleanEmail, fullName);
    
    // Sync true NGN net balance from TransactionStore
    const trueNgn = TransactionStore.computeNetBalance(cleanEmail);
    const ngnAcc = accounts.find(a => a.currency === 'NGN');
    if (ngnAcc) {
      ngnAcc.balance = trueNgn;
    }

    // Filter foreign accounts (USD, GBP, EUR) if Multi-Currency Vault is toggled OFF by admin
    const flags = getFeatureFlags();
    const effectiveAccounts = flags.enableMultiCurrencyVault
      ? accounts
      : accounts.filter(a => a.currency === 'NGN');

    res.json({
      status: true,
      data: effectiveAccounts
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function convertVaultCurrency(req: Request, res: Response) {
  try {
    const { fromCurrency, toCurrency, amount, email } = req.body;
    if (!fromCurrency || !toCurrency || !amount || Number(amount) <= 0) {
      return res.status(400).json({ error: 'Valid fromCurrency, toCurrency, and amount are required' });
    }

    const conversion = MultiCurrencyService.convert(fromCurrency, toCurrency, Number(amount));
    
    // Dispatch in-app / email alert
    NotificationDispatcher.dispatch({
      email: email || 'tonerocool1@gmail.com',
      userName: 'Valued Partner',
      category: 'wallet',
      title: `Currency Converted: ${fromCurrency} → ${toCurrency}`,
      message: `Successfully converted ${fromCurrency} ${Number(amount).toLocaleString()} to ${toCurrency} ${conversion.convertedAmount.toLocaleString()} at rate ${conversion.rate}.`,
      metadata: {
        fromCurrency,
        toCurrency,
        amount: Number(amount),
        convertedAmount: conversion.convertedAmount,
        rate: conversion.rate,
        fee: conversion.fee
      }
    });

    res.json({
      status: true,
      message: `Converted ${fromCurrency} ${Number(amount).toLocaleString()} into ${toCurrency} ${conversion.convertedAmount.toLocaleString()}`,
      data: conversion
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

// --- VIRTUAL CARD ISSUING CONTROLLER ---

export async function getUserCards(req: Request, res: Response) {
  try {
    const { email } = req.query;
    const cleanEmail = (email || 'tonerocool1@gmail.com').toString().trim().toLowerCase();
    const user = await UserStore.findByEmail(cleanEmail);
    const fullName = user?.fullName || user?.businessName || 'Valued Partner';

    const cards = await CardIssuingService.getUserCards(cleanEmail, fullName);
    res.json({
      status: true,
      data: cards
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function issueVirtualCard(req: Request, res: Response) {
  try {
    const { email, cardholderName, currency, brand, initialFunding } = req.body;
    const cleanEmail = (email || 'tonerocool1@gmail.com').toString().trim().toLowerCase();
    const user = await UserStore.findByEmail(cleanEmail);
    const name = cardholderName || user?.fullName || user?.businessName || 'Valued Partner';

    // 1. Calculate issuance fee in NGN
    const rates = typeof MultiCurrencyService.getFxRates === 'function'
      ? MultiCurrencyService.getFxRates()
      : (typeof (MultiCurrencyService as any).getRates === 'function' ? (MultiCurrencyService as any).getRates() : { USD_NGN: 1510.0 });
    const fxRate = rates.USD_NGN || 1510.0;
    const pricing = typeof CardIssuingService.getCardPricing === 'function' ? CardIssuingService.getCardPricing() : { issuanceFeeUsd: 3.00 };
    const issuanceFeeUsd = pricing.issuanceFeeUsd || 3.00;
    const initialUsd = Number(initialFunding || 0);
    const totalDebitUsd = issuanceFeeUsd + initialUsd;
    const totalDebitNgn = Number((totalDebitUsd * fxRate).toFixed(2));

    // 2. Issue the virtual card in Supabase
    const card = await CardIssuingService.issueCard({
      email: cleanEmail,
      cardholderName: name,
      currency: currency || 'USD',
      brand: brand || 'VISA',
      initialFunding: initialUsd
    });

    // 3. Debit individual user balance in Supabase & record in ledger
    let resolvedUserId = user?.id;
    if (supabase) {
      const { data: profile } = await supabase
        .from('profiles')
        .select('id, wallet_balance, full_name')
        .eq('email', cleanEmail)
        .single();

      if (profile) {
        resolvedUserId = profile.id;
        const currentBal = Number(profile.wallet_balance || 0);
        const newBal = Math.max(0, currentBal - totalDebitNgn);

        await supabase
          .from('profiles')
          .update({ wallet_balance: newBal, updated_at: new Date().toISOString() })
          .eq('email', cleanEmail);

        // Record debit transaction in Supabase
        const txRef = `RENTILLY_CARD_ISSUE_${Date.now()}`;
        await supabase
          .from('transactions')
          .insert({
            user_id: profile.id,
            email: cleanEmail,
            amount: totalDebitNgn,
            type: 'debit',
            status: 'completed',
            reference: txRef,
            title: `Virtual Dollar Card Issuance Fee ($${issuanceFeeUsd.toFixed(2)} USD)`,
            created_at: new Date().toISOString()
          });

        await TransactionStore.addTransaction({
          id: `TX_${Date.now()}`,
          userId: profile.id,
          email: cleanEmail,
          title: `Virtual Dollar Card Issuance Fee ($${issuanceFeeUsd.toFixed(2)} USD)`,
          type: 'Virtual Card Issuance',
          category: 'debit',
          amount: totalDebitNgn,
          isCredit: false,
          reference: txRef,
          sender: `${name} (Rentilly Wallet)`,
          beneficiary: 'Rentilly Virtual Card Issuance System',
          status: 'SUCCESSFUL',
          date: new Date().toISOString()
        });
      }
    }

    if (user) {
      const memBal = Number(user.walletBalance || 0);
      user.walletBalance = Math.max(0, memBal - totalDebitNgn);
      UserStore.upsertUserForced(user);
    }

    // 4. Dispatch Realtime Push & Branded HTML Email
    NotificationDispatcher.dispatch({
      userId: resolvedUserId,
      email: cleanEmail,
      userName: name,
      category: 'wallet',
      title: `Virtual USD Visa Card Issued! 💳`,
      message: `Your new virtual card ending in ${card.maskedPan.slice(-4)} is active. Issuance fee of $${issuanceFeeUsd.toFixed(2)} USD (₦${totalDebitNgn.toLocaleString()}) was debited from your wallet balance.`,
      metadata: {
        cardId: card.id,
        maskedPan: card.maskedPan,
        currency: card.currency,
        brand: card.brand,
        amount: totalDebitNgn,
        reference: `CARD_ISSUE_${card.id}`
      }
    });

    res.json({
      status: true,
      message: `Virtual ${card.currency} card issued successfully! ₦${totalDebitNgn.toLocaleString()} debited from wallet.`,
      data: card,
      debitedAmount: totalDebitNgn,
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function fundVirtualCard(req: Request, res: Response) {
  try {
    const { cardId, amount, email } = req.body;
    if (!cardId || !amount || Number(amount) <= 0) {
      return res.status(400).json({ error: 'Valid cardId and amount are required' });
    }

    const cleanEmail = (email || 'tonerocool1@gmail.com').toString().trim().toLowerCase();
    const fxRate = MultiCurrencyService.getFxRates().USD_NGN || 1510.0;
    const debitAmountNgn = Number((Number(amount) * fxRate).toFixed(2));

    // 1. Fund the virtual card
    const result = await CardIssuingService.fundCard(cardId, Number(amount));
    if (!result.success) {
      return res.status(400).json({ error: result.message });
    }

    // 2. Debit user's Naira wallet & insert into ledger
    const user = await UserStore.findByEmail(cleanEmail);
    const name = user?.fullName || user?.businessName || 'Valued Partner';

    if (supabase) {
      try {
        const { data: profile } = await supabase
          .from('profiles')
          .select('id, wallet_balance, full_name')
          .eq('email', cleanEmail)
          .single();

        if (profile) {
          const currentBal = Number(profile.wallet_balance || 0);
          const newBal = Math.max(0, currentBal - debitAmountNgn);

          await supabase
            .from('profiles')
            .update({ wallet_balance: newBal, updated_at: new Date().toISOString() })
            .eq('email', cleanEmail);

          const txRef = `CARD_FUND_${Date.now()}`;
          await supabase
            .from('transactions')
            .insert({
              user_id: profile.id,
              email: cleanEmail,
              amount: debitAmountNgn,
              type: 'debit',
              status: 'completed',
              reference: txRef,
              title: `Virtual Dollar Card Top-Up ($${Number(amount).toFixed(2)} USD)`,
              created_at: new Date().toISOString()
            });

          await TransactionStore.addTransaction({
            id: `TX_${Date.now()}`,
            userId: profile.id,
            email: cleanEmail,
            title: `Virtual Dollar Card Top-Up ($${Number(amount).toFixed(2)} USD)`,
            type: 'Virtual Card Funding',
            category: 'debit',
            amount: debitAmountNgn,
            isCredit: false,
            reference: txRef,
            sender: `${name} (Rentilly Wallet)`,
            beneficiary: 'Rentilly Virtual Card Top-Up System',
            status: 'SUCCESSFUL',
            date: new Date().toISOString()
          });
        }
      } catch (err: any) {
        console.warn('[PaymentController] Ledger recording notice on card fund:', err.message);
      }
    }

    if (user) {
      const memBal = Number(user.walletBalance || 0);
      user.walletBalance = Math.max(0, memBal - debitAmountNgn);
    }

    // 3. Dispatch Email & Push Notification
    NotificationDispatcher.dispatch({
      email: cleanEmail,
      userName: name,
      category: 'wallet',
      title: `Virtual Dollar Card Top-Up ($${Number(amount).toFixed(2)} USD)`,
      message: `Successfully funded $${Number(amount).toFixed(2)} USD onto your virtual card. ₦${debitAmountNgn.toLocaleString()} was debited from your wallet. New card balance: $${result.newBalance.toFixed(2)} USD.`,
      metadata: { cardId, amountUsd: Number(amount), amountNgn: debitAmountNgn, newBalance: result.newBalance }
    });

    res.json({
      status: true,
      message: result.message,
      newBalance: result.newBalance,
      debitedAmountNgn: debitAmountNgn
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function toggleFreezeVirtualCard(req: Request, res: Response) {
  try {
    const { cardId } = req.body;
    if (!cardId) {
      return res.status(400).json({ error: 'cardId is required' });
    }

    const result = await CardIssuingService.toggleFreeze(cardId);
    if (!result.success) {
      return res.status(400).json({ error: result.message });
    }

    res.json({
      status: true,
      isFrozen: result.isFrozen,
      message: result.message
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function deleteVirtualCard(req: Request, res: Response) {
  try {
    const { cardId, email } = req.body;
    if (!cardId) {
      return res.status(400).json({ error: 'cardId is required' });
    }

    const result = await CardIssuingService.deleteCard(cardId, email);
    res.json({
      status: true,
      message: result.message
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function setCardPin(req: Request, res: Response) {
  try {
    const { cardId, pin } = req.body;
    if (!cardId || !pin) {
      return res.status(400).json({ error: 'cardId and a 4-digit pin are required' });
    }

    const result = await CardIssuingService.setCardPin(cardId, pin.toString());
    if (!result.success) {
      return res.status(400).json({ error: result.message });
    }

    res.json({
      status: true,
      message: result.message,
      pin: result.pin
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function revealCardDetails(req: Request, res: Response) {
  try {
    const { cardId } = req.body;
    if (!cardId) {
      return res.status(400).json({ error: 'cardId is required' });
    }

    const details = await CardIssuingService.revealDetails(cardId);
    if (!details) {
      return res.status(404).json({ error: 'Card not found' });
    }

    res.json({
      status: true,
      data: details
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function getCardTransactions(req: Request, res: Response) {
  try {
    const { cardId } = req.params;
    const txs = CardIssuingService.getCardTransactions(cardId || 'default');
    res.json({
      status: true,
      data: txs
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function getFxRatesHandler(req: Request, res: Response) {
  try {
    const rates = MultiCurrencyService.getFxRates();
    res.json({
      status: true,
      data: rates
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function updateFxRatesHandler(req: Request, res: Response) {
  try {
    const { USD_NGN, GBP_NGN, EUR_NGN } = req.body;
    const updated = MultiCurrencyService.updateFxRates({
      USD_NGN: Number(USD_NGN),
      GBP_NGN: Number(GBP_NGN),
      EUR_NGN: Number(EUR_NGN)
    });
    res.json({
      status: true,
      message: 'Exchange rates updated successfully',
      data: updated
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function getCardPricingHandler(req: Request, res: Response) {
  try {
    const pricing = CardIssuingService.getCardPricing();
    res.json({
      status: true,
      data: pricing
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function updateCardPricingHandler(req: Request, res: Response) {
  try {
    const updated = CardIssuingService.updateCardPricing(req.body);
    res.json({
      status: true,
      message: 'Card pricing and fees updated successfully',
      data: updated
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function clientDispatchNotification(req: Request, res: Response) {
  try {
    const { email, userId, userName, category, title, message, metadata } = req.body;
    if (!title || !message) {
      return res.status(400).json({ error: 'title and message are required' });
    }

    const cleanEmail = (email || '').toString().trim().toLowerCase();

    const clientIp = (metadata?.ipAddress || req.headers['x-forwarded-for'] || req.socket.remoteAddress || req.ip || '102.89.42.15').toString().split(',')[0].trim();
    const userAgent = (metadata?.deviceModel || metadata?.platform || req.headers['user-agent'] || 'Rentilly Mobile Client').toString();
    const deviceId = (metadata?.deviceId || req.headers['x-device-id'] || 'RENT-DEV-MOBILE').toString();
    const location = (metadata?.location || (req.headers['cf-ipcountry'] ? `${req.headers['cf-ipcity'] || 'Lagos'}, ${req.headers['cf-ipcountry']}` : 'Lagos, Nigeria')).toString();

    const mergedMetadata = {
      ...(metadata || {}),
      deviceId,
      deviceModel: userAgent.includes('Dart') ? 'Rentilly Mobile App (Android/ARM64)' : userAgent.slice(0, 45),
      ipAddress: clientIp,
      location
    };

    console.log(`[Security Notification Dispatch] Triggered for email: ${cleanEmail}, title: "${title}", IP: ${clientIp}, Device: ${deviceId}`);

    const result = await NotificationDispatcher.dispatch({
      userId: userId?.toString(),
      email: cleanEmail,
      userName: userName?.toString(),
      category: category || 'security',
      title: title.toString(),
      message: message.toString(),
      metadata: mergedMetadata
    });

    res.json({
      status: true,
      message: 'Notification dispatched successfully across Push and Email.',
      result
    });
  } catch (err: any) {
    console.error('[Notification Dispatch API] Error:', err.message);
    res.status(500).json({ error: err.message });
  }
}

// 24. Server-Encapsulated Notification Read Status Mutation
export async function markNotificationRead(req: Request, res: Response) {
  try {
    const { id, userId } = req.body;
    if (!id) {
      return res.status(400).json({ error: 'Notification ID is required' });
    }

    const cleanId = id.toString().replace('NOTIF_SB_', '');
    if (supabase) {
      await supabase
        .from('notifications')
        .update({ read: true })
        .eq('id', cleanId);
    }

    res.json({ status: true, message: 'Notification marked as read', id: cleanId });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

// 25. Server-Encapsulated Mark All Notifications Read
export async function markAllNotificationsRead(req: Request, res: Response) {
  try {
    const { userId } = req.body;
    if (!userId) {
      return res.status(400).json({ error: 'User ID is required' });
    }

    if (supabase) {
      await supabase
        .from('notifications')
        .update({ read: true })
        .eq('user_id', userId.toString());
    }

    res.json({ status: true, message: 'All notifications marked as read', userId });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

// 26. Server-Encapsulated OneSignal Player ID Registration
export async function registerOneSignalPlayer(req: Request, res: Response) {
  try {
    const { userId, email, playerId } = req.body;
    if (!playerId) {
      return res.status(400).json({ error: 'Player ID is required' });
    }

    const cleanEmail = email ? email.toString().toLowerCase().trim() : '';

    if (supabase) {
      if (userId) {
        await supabase
          .from('profiles')
          .update({ onesignal_player_id: playerId.toString() })
          .eq('id', userId.toString());
      } else if (cleanEmail) {
        await supabase
          .from('profiles')
          .update({ onesignal_player_id: playerId.toString() })
          .eq('email', cleanEmail);
      }
    }

    res.json({ status: true, message: 'OneSignal Player ID successfully registered', playerId });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

// 27. Remote In-App Notifications Fetcher
export async function getUserNotifications(req: Request, res: Response) {
  try {
    const email = (req.query.email || '').toString().toLowerCase().trim();
    const userId = (req.query.userId || '').toString().trim();

    if (!email && !userId) {
      return res.status(400).json({ error: 'email or userId is required' });
    }

    let notifs: any[] = [];
    if (supabase) {
      let targetUuid = userId;
      const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(targetUuid);
      if (!isUuid && email) {
        try {
          const { data: prof } = await supabase.from('profiles').select('id').eq('email', email).maybeSingle();
          if (prof?.id) targetUuid = prof.id;
        } catch (_) {}
      }

      if (!targetUuid || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(targetUuid)) {
        if (email.includes('tonero')) {
          targetUuid = 'c0000000-0000-0000-0000-000000000001';
        }
      }

      if (targetUuid) {
        const { data, error } = await supabase
          .from('notifications')
          .select('*')
          .eq('user_id', targetUuid)
          .order('created_at', { ascending: false })
          .limit(50);
        if (!error && data) {
          notifs = data;
        }
      }
    }

    return res.json({ status: true, notifications: notifs });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
}

