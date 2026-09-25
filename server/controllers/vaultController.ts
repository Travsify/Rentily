import { Request, Response } from 'express';
import fs from 'fs';
import path from 'path';
import { UserStore } from '../services/userStore';
import { TransactionStore, WalletTransaction } from '../services/transactionStore';
import { CreditEngineService } from '../services/creditEngineService';
import { NotificationDispatcher } from '../services/notificationDispatcher';

export interface LivingVault {
  id: string;
  userId: string;
  userEmail: string;
  title: string;
  category: string;
  targetAmount: number;
  savedAmount: number;
  yieldRate: string;
  yieldNote: string;
  durationMonths?: number;
  durationLabel?: string;
  maturityDate?: string;
  createdAt: string;
  updatedAt: string;
}

function getDataDir(): string {
  const candidates = [
    path.join(process.cwd(), 'server', 'data'),
    path.join('/opt/render/project/src', 'server', 'data'),
    path.join('/tmp', 'rentilly-data'),
  ];
  for (const dir of candidates) {
    try {
      if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
      fs.writeFileSync(path.join(dir, '.write_test_v'), 'ok', 'utf-8');
      fs.unlinkSync(path.join(dir, '.write_test_v'));
      return dir;
    } catch { continue; }
  }
  return '/tmp';
}

let _DATA_DIR: string | null = null;
function getStoragePath(): string {
  if (!_DATA_DIR) _DATA_DIR = getDataDir();
  return path.join(_DATA_DIR, 'living_vaults.json');
}

let _vaultsCache: LivingVault[] | null = null;

function loadAllVaults(): LivingVault[] {
  if (_vaultsCache !== null) return _vaultsCache;
  try {
    const file = getStoragePath();
    if (fs.existsSync(file)) {
      const data = fs.readFileSync(file, 'utf-8');
      const parsed = JSON.parse(data || '[]');
      if (Array.isArray(parsed)) {
        _vaultsCache = parsed;
        return _vaultsCache;
      }
    }
  } catch (err: any) {
    console.warn('[VaultController] Error reading living_vaults.json:', err.message);
  }
  _vaultsCache = [];
  return _vaultsCache;
}

function saveAllVaults(vaults: LivingVault[]): void {
  _vaultsCache = vaults;
  try {
    const file = getStoragePath();
    fs.writeFileSync(file, JSON.stringify(vaults, null, 2), 'utf-8');
  } catch (err: any) {
    console.error('[VaultController] Error saving living_vaults.json:', err.message);
  }
}

// User-level concurrency lock for atomic operations
const _userLocks = new Map<string, Promise<void>>();
async function withUserLock<T>(userId: string, fn: () => Promise<T>): Promise<T> {
  while (_userLocks.has(userId)) {
    await _userLocks.get(userId);
  }
  let resolveLock!: () => void;
  const lockPromise = new Promise<void>((resolve) => { resolveLock = resolve; });
  _userLocks.set(userId, lockPromise);
  try {
    return await fn();
  } finally {
    _userLocks.delete(userId);
    resolveLock();
  }
}


// Helper to compute daily accrual (Actual/365 at 5% p.a.) and early break economics
function enrichVaultData(v: LivingVault) {
  const now = Date.now();
  const created = new Date(v.createdAt).getTime();
  const maturity = v.maturityDate 
    ? new Date(v.maturityDate).getTime() 
    : created + 365 * 24 * 60 * 60 * 1000;
  
  const daysPassed = Math.max(0, (now - created) / (24 * 60 * 60 * 1000));
  const daysRemaining = Math.max(0, Math.ceil((maturity - now) / (24 * 60 * 60 * 1000)));
  const isMatured = now >= maturity;

  const saved = v.savedAmount || 0;
  const effectiveDays = Math.min(365, daysPassed);
  
  // Daily Accrual formula: (Principal * 0.05 / 365) * daysActive
  const accruedYield = Math.round(saved * 0.05 * (effectiveDays / 365));
  
  // Early break fee: exactly 1% of running funds
  const earlyBreakFee = Math.round(saved * 0.01);
  const netPayoutIfBrokenEarly = Math.max(0, saved - earlyBreakFee);

  return {
    ...v,
    durationMonths: v.durationMonths || 12,
    durationLabel: v.durationLabel || '1 Year (365 Days)',
    maturityDate: new Date(maturity).toISOString(),
    daysPassed: Math.floor(daysPassed),
    daysRemaining,
    isMatured,
    accruedYield,
    earlyBreakFee,
    netPayoutIfBrokenEarly,
  };
}

export class VaultController {
  // 1. GET /api/vaults
  static async getUserVaults(req: Request, res: Response): Promise<void> {
    try {
      const email = ((req.query.email as string) || '').toLowerCase().trim();
      const userId = (req.query.userId as string) || '';

      if (!email && !userId) {
        res.status(400).json({ success: false, error: 'User email or ID is required.' });
        return;
      }

      const all = loadAllVaults();
      const userVaults = all
        .filter(v => 
          (email && v.userEmail.toLowerCase() === email) || 
          (userId && v.userId === userId)
        )
        .map(enrichVaultData);

      const totalAccruedYield = userVaults.reduce((sum, v) => sum + (v.accruedYield || 0), 0);

      res.json({
        success: true,
        vaults: userVaults,
        totalSaved: userVaults.reduce((sum, v) => sum + (v.savedAmount || 0), 0),
        totalAccruedYield,
      });
    } catch (err: any) {
      console.error('[VaultController.getUserVaults] Error:', err.message);
      res.status(500).json({ success: false, error: err.message });
    }
  }

  // 2. POST /api/vaults/create
  static async createVault(req: Request, res: Response): Promise<void> {
    try {
      const { email, userId, title, category, targetAmount, initialDeposit } = req.body;
      const cleanEmail = (email || '').toLowerCase().trim();

      if (!cleanEmail && !userId) {
        res.status(400).json({ success: false, error: 'User email or ID is required.' });
        return;
      }

      if (!title || !title.trim()) {
        res.status(400).json({ success: false, error: 'Vault title is required.' });
        return;
      }

      const target = Number(targetAmount);
      if (isNaN(target) || target <= 0) {
        res.status(400).json({ success: false, error: 'Target amount must be a positive number.' });
        return;
      }

      const initial = Number(initialDeposit || 0);

      const user = cleanEmail ? UserStore.getUserByEmail(cleanEmail) : UserStore.getUserById(userId);
      if (!user) {
        res.status(404).json({ success: false, error: 'User account not found.' });
        return;
      }

      const effectiveUserId = user.id;
      const effectiveEmail = user.email;

      await withUserLock(effectiveUserId, async () => {
        let initialSaved = 0;

        if (initial > 0) {
          const currentWallet = user.walletBalance || 0;
          if (currentWallet < initial) {
            res.status(400).json({
              success: false,
              error: `Insufficient wallet balance for initial deposit of ₦${initial.toLocaleString()}. Current balance: ₦${currentWallet.toLocaleString()}.`,
            });
            return;
          }

          // Debit wallet
          await UserStore.updateUser(user.email, {
            walletBalance: currentWallet - initial,
          });
          initialSaved = initial;

          // Record transaction
          const txRef = `VAULT-INIT-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
          TransactionStore.addTransaction({
            id: txRef,
            userId: effectiveUserId,
            email: effectiveEmail,
            title: `Living Vault Initial Deposit (${title.trim()})`,
            type: 'VAULT_DEPOSIT',
            category: 'deposit',
            amount: initial,
            isCredit: false,
            reference: txRef,
            status: 'SUCCESSFUL',
            description: `Initial funding of ₦${initial.toLocaleString()} into living vault "${title.trim()}".`,
            createdAt: new Date().toISOString(),
          });
        }

        const yieldRate = '5% p.a.';
        const yieldNote = '5% Annual Yield';
        const now = new Date();
        const maturity = new Date(now.getTime() + 365 * 24 * 60 * 60 * 1000); // 1 Year fixed tenure

        const newVault: LivingVault = {
          id: `vault_${Date.now()}_${Math.floor(Math.random() * 10000)}`,
          userId: effectiveUserId,
          userEmail: effectiveEmail,
          title: title.trim(),
          category: (category && category.trim()) ? category.trim() : 'Custom Living Goal',
          targetAmount: target,
          savedAmount: initialSaved,
          yieldRate,
          yieldNote,
          durationMonths: 12,
          durationLabel: '1 Year (365 Days)',
          maturityDate: maturity.toISOString(),
          createdAt: now.toISOString(),
          updatedAt: now.toISOString(),
        };

        const all = loadAllVaults();
        all.push(newVault);
        saveAllVaults(all);

        NotificationDispatcher.dispatchNotification({
          userId: effectiveUserId,
          userEmail: effectiveEmail,
          title: `Living Vault Created: ${newVault.title} 🎯`,
          message: `Target goal of ₦${target.toLocaleString()} configured for ${newVault.category} (${yieldNote}).`,
          category: 'vault',
          metadata: {
            vaultId: newVault.id,
            title: newVault.title,
            targetAmount: target,
            savedAmount: initialSaved,
          },
        }).catch(() => {});

        res.json({
          success: true,
          message: `Living vault "${newVault.title}" created successfully!`,
          vault: newVault,
          walletBalance: user.walletBalance,
        });
      });
    } catch (err: any) {
      console.error('[VaultController.createVault] Error:', err.message);
      res.status(500).json({ success: false, error: err.message });
    }
  }

  // 3. POST /api/vaults/deposit (Manual Deposit / Save to Vault)
  static async depositToVault(req: Request, res: Response): Promise<void> {
    try {
      const { email, userId, vaultId, amount } = req.body;
      const cleanEmail = (email || '').toLowerCase().trim();

      const numAmount = Number(amount);
      if (isNaN(numAmount) || numAmount <= 0) {
        res.status(400).json({ success: false, error: 'Deposit amount must be a positive number greater than ₦0.' });
        return;
      }

      const user = cleanEmail ? UserStore.getUserByEmail(cleanEmail) : UserStore.getUserById(userId);
      if (!user) {
        res.status(404).json({ success: false, error: 'User account not found.' });
        return;
      }

      await withUserLock(user.id, async () => {
        const all = loadAllVaults();
        const vaultIndex = all.findIndex(v => 
          v.id === vaultId && (v.userId === user.id || v.userEmail.toLowerCase() === user.email.toLowerCase())
        );

        if (vaultIndex === -1) {
          res.status(404).json({ success: false, error: 'Living vault not found.' });
          return;
        }

        const currentWallet = user.walletBalance || 0;
        if (currentWallet < numAmount) {
          res.status(400).json({
            success: false,
            error: `Insufficient wallet balance. You need ₦${numAmount.toLocaleString()}, but your wallet balance is ₦${currentWallet.toLocaleString()}.`,
            shortfall: numAmount - currentWallet,
            virtualAccount: {
              bankName: user.bankName || 'Wema Bank (Fincra Escrow)',
              accountNumber: user.virtualAccountNumber || user.accountNumber || '0123456789',
              accountName: `${user.fullName} / Rentilly Escrow`,
            },
          });
          return;
        }

        // 1. Debit User Wallet
        const newWalletBal = currentWallet - numAmount;
        await UserStore.updateUser(user.email, {
          walletBalance: newWalletBal,
        });

        // 2. Credit Living Vault
        const vault = all[vaultIndex];
        const oldSaved = vault.savedAmount || 0;
        vault.savedAmount = oldSaved + numAmount;
        vault.updatedAt = new Date().toISOString();
        saveAllVaults(all);

        // 3. Record Transaction in Ledger
        const txRef = `VAULT-DEP-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
        TransactionStore.addTransaction({
          id: txRef,
          userId: user.id,
          email: user.email,
          title: `Living Vault Deposit (${vault.title})`,
          type: 'VAULT_DEPOSIT',
          category: 'deposit',
          amount: numAmount,
          isCredit: false,
          reference: txRef,
          status: 'SUCCESSFUL',
          description: `Saved ₦${numAmount.toLocaleString()} to living vault "${vault.title}". Target: ₦${vault.targetAmount.toLocaleString()}.`,
          createdAt: new Date().toISOString(),
          metadata: {
            vaultId: vault.id,
            vaultTitle: vault.title,
            newSavedAmount: vault.savedAmount,
          },
        });

        // 4. Dispatch Alert
        NotificationDispatcher.dispatchNotification({
          userId: user.id,
          userEmail: user.email,
          title: `₦${numAmount.toLocaleString()} Saved to ${vault.title} 💰`,
          message: `Your deposit of ₦${numAmount.toLocaleString()} has been added to "${vault.title}". Total Saved: ₦${vault.savedAmount.toLocaleString()} of ₦${vault.targetAmount.toLocaleString()} target.`,
          category: 'vault',
          metadata: {
            vaultId: vault.id,
            amount: numAmount,
            savedAmount: vault.savedAmount,
            walletBalance: newWalletBal,
          },
        }).catch(() => {});

        res.json({
          success: true,
          message: `Successfully saved ₦${numAmount.toLocaleString()} to "${vault.title}"!`,
          vault,
          walletBalance: newWalletBal,
          transactionReference: txRef,
        });
      });
    } catch (err: any) {
      console.error('[VaultController.depositToVault] Error:', err.message);
      res.status(500).json({ success: false, error: err.message });
    }
  }

  // 4. POST /api/vaults/withdraw (Withdraw from Vault back to Wallet)
  static async withdrawFromVault(req: Request, res: Response): Promise<void> {
    try {
      const { email, userId, vaultId, amount } = req.body;
      const cleanEmail = (email || '').toLowerCase().trim();

      const numAmount = Number(amount);
      if (isNaN(numAmount) || numAmount <= 0) {
        res.status(400).json({ success: false, error: 'Withdrawal amount must be a positive number.' });
        return;
      }

      const user = cleanEmail ? UserStore.getUserByEmail(cleanEmail) : UserStore.getUserById(userId);
      if (!user) {
        res.status(404).json({ success: false, error: 'User account not found.' });
        return;
      }

      await withUserLock(user.id, async () => {
        const all = loadAllVaults();
        const vaultIndex = all.findIndex(v => 
          v.id === vaultId && (v.userId === user.id || v.userEmail.toLowerCase() === user.email.toLowerCase())
        );

        if (vaultIndex === -1) {
          res.status(404).json({ success: false, error: 'Living vault not found.' });
          return;
        }

        const vault = all[vaultIndex];
        const currentSaved = vault.savedAmount || 0;

        if (currentSaved < numAmount) {
          res.status(400).json({
            success: false,
            error: `Insufficient funds in vault "${vault.title}". Available: ₦${currentSaved.toLocaleString()}, Requested: ₦${numAmount.toLocaleString()}.`,
          });
          return;
        }

        // Check if collateral is locked across all user vaults by an active credit loan
        const userLoans = CreditEngineService.getUserLoans(user.id);
        const activeLoan = userLoans.find(l => l.status === 'active' || l.status === 'overdue');
        if (activeLoan && activeLoan.collateralLocked > 0) {
          const totalUserSavings = all
            .filter(v => v.userId === user.id || v.userEmail.toLowerCase() === user.email.toLowerCase())
            .reduce((sum, v) => sum + (v.savedAmount || 0), 0);
          
          const freeSavings = totalUserSavings - activeLoan.collateralLocked;
          if (numAmount > freeSavings) {
            res.status(400).json({
              success: false,
              error: `Cannot withdraw ₦${numAmount.toLocaleString()}. ₦${activeLoan.collateralLocked.toLocaleString()} of your total savings is ring-fenced as collateral for your active Credit Advance #${activeLoan.id}. Free withdrawable amount: ₦${Math.max(0, freeSavings).toLocaleString()}.`,
            });
            return;
          }
        }

        const now = Date.now();
        const created = new Date(vault.createdAt).getTime();
        const maturity = vault.maturityDate 
          ? new Date(vault.maturityDate).getTime() 
          : created + 365 * 24 * 60 * 60 * 1000;

        const isMatured = now >= maturity;
        const isEarlyBreak = !isMatured;

        let breakFee = 0;
        let forfeitedYield = 0;
        let payoutToWallet = numAmount;

        if (isEarlyBreak) {
          // RULE: Users lose their accrued interest amount AND pay a 1% early break fee!
          const daysPassed = Math.max(0, (now - created) / (24 * 60 * 60 * 1000));
          const effectiveDays = Math.min(365, daysPassed);
          forfeitedYield = Math.round(numAmount * 0.05 * (effectiveDays / 365));
          breakFee = Math.round(numAmount * 0.01); // 1% fee paid to Rentilly
          payoutToWallet = Math.max(0, numAmount - breakFee);
        } else {
          // Matured: Payout full principal + full 5% yield
          const earnedYield = Math.round(numAmount * 0.05);
          payoutToWallet = numAmount + earnedYield;
        }

        // 1. Debit Vault
        vault.savedAmount = currentSaved - numAmount;
        vault.updatedAt = new Date().toISOString();
        saveAllVaults(all);

        // 2. Credit User Wallet
        const currentWallet = user.walletBalance || 0;
        const newWalletBal = currentWallet + payoutToWallet;
        await UserStore.updateUser(user.email, {
          walletBalance: newWalletBal,
        });

        // 3. Record Transactions in Ledger
        const txRef = `VAULT-WTH-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
        TransactionStore.addTransaction({
          id: txRef,
          userId: user.id,
          email: user.email,
          title: isEarlyBreak ? `Living Vault Early Break (${vault.title})` : `Living Vault Maturity Payout (${vault.title})`,
          type: isEarlyBreak ? 'VAULT_EARLY_BREAK' : 'VAULT_MATURITY_PAYOUT',
          category: 'withdrawal',
          amount: payoutToWallet,
          isCredit: true,
          reference: txRef,
          status: 'SUCCESSFUL',
          description: isEarlyBreak 
            ? `Early break of ₦${numAmount.toLocaleString()} from "${vault.title}". ₦${breakFee.toLocaleString()} (1% fee) was deducted, and ₦${forfeitedYield.toLocaleString()} accrued yield was forfeited.`
            : `Matured payout from "${vault.title}". Full principal + 5% annual yield credited.`,
          createdAt: new Date().toISOString(),
          metadata: {
            vaultId: vault.id,
            requestedAmount: numAmount,
            payoutToWallet,
            breakFee,
            forfeitedYield,
            isEarlyBreak,
          },
        });

        // 4. Record 1% Penalty Fee to Rentilly Treasury Ledger if early break
        if (breakFee > 0) {
          const feeRef = `FEE-BRK-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
          TransactionStore.addTransaction({
            id: feeRef,
            userId: 'RENTILLY_TREASURY',
            email: 'treasury@myrentilly.com',
            title: `Vault Early Liquidation Penalty Fee (${vault.title})`,
            type: 'PLATFORM_FEE',
            category: 'deposit',
            amount: breakFee,
            isCredit: true,
            reference: feeRef,
            status: 'SUCCESSFUL',
            description: `1% early break fee collected from ${user.fullName} for living vault "${vault.title}".`,
            createdAt: new Date().toISOString(),
            metadata: {
              userId: user.id,
              vaultId: vault.id,
              penaltyPercentage: '1.0%',
              feeAmount: breakFee,
            },
          });
        }

        NotificationDispatcher.dispatchNotification({
          userId: user.id,
          userEmail: user.email,
          title: isEarlyBreak ? `Living Vault Early Break Processed ⚠️` : `Living Vault Matured 🎉`,
          message: isEarlyBreak
            ? `Vault "${vault.title}" was liquidated early. ₦${payoutToWallet.toLocaleString()} was credited to your wallet (1% break fee of ₦${breakFee.toLocaleString()} deducted; accrued interest was forfeited).`
            : `Congratulations! ₦${payoutToWallet.toLocaleString()} (principal + 5% yield) was credited to your wallet.`,
          category: 'vault',
          metadata: {
            vaultId: vault.id,
            breakFee,
            forfeitedYield,
            payoutToWallet,
          },
        }).catch(() => {});

        res.json({
          success: true,
          message: isEarlyBreak
            ? `Vault liquidated early. ₦${payoutToWallet.toLocaleString()} credited to wallet (1% fee of ₦${breakFee.toLocaleString()} deducted; interest forfeited).`
            : `Vault matured! ₦${payoutToWallet.toLocaleString()} credited to your wallet.`,
          isEarlyBreak,
          requestedAmount: numAmount,
          payoutToWallet,
          breakFee,
          forfeitedYield,
          vault: enrichVaultData(vault),
          walletBalance: newWalletBal,
        });
      });
    } catch (err: any) {
      console.error('[VaultController.withdrawFromVault] Error:', err.message);
      res.status(500).json({ success: false, error: err.message });
    }
  }

  // 5. POST /api/vaults/delete (Remove / Delete Saved Vault)
  static async deleteVault(req: Request, res: Response): Promise<void> {
    try {
      const { email, userId, vaultId, refundToWallet = true } = req.body;
      const cleanEmail = (email || '').toLowerCase().trim();

      const user = cleanEmail ? UserStore.getUserByEmail(cleanEmail) : UserStore.getUserById(userId);
      if (!user) {
        res.status(404).json({ success: false, error: 'User account not found.' });
        return;
      }

      await withUserLock(user.id, async () => {
        const all = loadAllVaults();
        const vaultIndex = all.findIndex(v => 
          v.id === vaultId && (v.userId === user.id || v.userEmail.toLowerCase() === user.email.toLowerCase())
        );

        if (vaultIndex === -1) {
          res.status(404).json({ success: false, error: 'Living vault not found.' });
          return;
        }

        const vault = all[vaultIndex];
        const savedAmount = vault.savedAmount || 0;

        // RULE: Users cannot delete any vault that has funds already running!
        // Only empty vaults (savedAmount == 0) can be deleted.
        if (savedAmount > 0) {
          res.status(400).json({
            success: false,
            error: `Cannot delete vault "${vault.title}" because it currently has active running funds of ₦${savedAmount.toLocaleString()}. You can only delete empty vaults with ₦0 balance. Please withdraw all funds first or wait until the 1-year maturity.`,
            savedAmount,
          });
          return;
        }

        // Check collateral lock from active loans (if applicable)
          const userLoans = CreditEngineService.getUserLoans(user.id);
          const activeLoan = userLoans.find(l => l.status === 'active' || l.status === 'overdue');
          if (activeLoan && activeLoan.collateralLocked > 0) {
            const totalUserSavings = all
              .filter(v => v.userId === user.id || v.userEmail.toLowerCase() === user.email.toLowerCase())
              .reduce((sum, v) => sum + (v.savedAmount || 0), 0);
            
            const remainingSavingsIfDeleted = totalUserSavings - savedAmount;
            if (remainingSavingsIfDeleted < activeLoan.collateralLocked) {
              res.status(400).json({
                success: false,
                error: `Cannot delete vault "${vault.title}". ₦${activeLoan.collateralLocked.toLocaleString()} collateral is required for active loan #${activeLoan.id}. Please repay the loan first or withdraw within free limits.`,
              });
              return;
            }
          }

        let newWalletBal = user.walletBalance || 0;

        // Refund any remaining balance to wallet
        if (savedAmount > 0 && refundToWallet) {
          newWalletBal += savedAmount;
          await UserStore.updateUser(user.email, {
            walletBalance: newWalletBal,
          });

          const txRef = `VAULT-DEL-REF-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
          TransactionStore.addTransaction({
            id: txRef,
            userId: user.id,
            email: user.email,
            title: `Living Vault Liquidation Refund (${vault.title})`,
            type: 'VAULT_REFUND',
            category: 'deposit',
            amount: savedAmount,
            isCredit: true,
            reference: txRef,
            status: 'SUCCESSFUL',
            description: `Refunded ₦${savedAmount.toLocaleString()} upon deleting vault "${vault.title}".`,
            createdAt: new Date().toISOString(),
          });
        }

        // Remove from list
        all.splice(vaultIndex, 1);
        saveAllVaults(all);

        NotificationDispatcher.dispatchNotification({
          userId: user.id,
          userEmail: user.email,
          title: `Living Vault Removed: ${vault.title} 🗑️`,
          message: savedAmount > 0 
            ? `Vault "${vault.title}" has been deleted. ₦${savedAmount.toLocaleString()} was credited back to your wallet.` 
            : `Vault "${vault.title}" has been removed.`,
          category: 'vault',
        }).catch(() => {});

        res.json({
          success: true,
          message: `Living vault "${vault.title}" was successfully deleted.${savedAmount > 0 ? ` ₦${savedAmount.toLocaleString()} has been refunded to your wallet.` : ''}`,
          deletedVaultId: vault.id,
          refundedAmount: savedAmount,
          walletBalance: newWalletBal,
        });
      });
    } catch (err: any) {
      console.error('[VaultController.deleteVault] Error:', err.message);
      res.status(500).json({ success: false, error: err.message });
    }
  }

  // 6. POST /api/vaults/sync (Sync all vaults from mobile client or remote)
  static async syncUserVaults(req: Request, res: Response): Promise<void> {
    try {
      const { email, userId, vaults } = req.body;
      const cleanEmail = (email || '').toLowerCase().trim();

      if (!Array.isArray(vaults)) {
        res.status(400).json({ success: false, error: 'Vaults array is required.' });
        return;
      }

      const user = cleanEmail ? UserStore.getUserByEmail(cleanEmail) : UserStore.getUserById(userId);
      if (!user) {
        res.status(404).json({ success: false, error: 'User account not found.' });
        return;
      }

      await withUserLock(user.id, async () => {
        const all = loadAllVaults();
        const otherVaults = all.filter(v => v.userId !== user.id && v.userEmail.toLowerCase() !== user.email.toLowerCase());

        const synced: LivingVault[] = vaults.map((v: any, idx: number) => ({
          id: v.id || `vault_${Date.now()}_${idx}`,
          userId: user.id,
          userEmail: user.email,
          title: v.title || 'Living Vault',
          category: v.category || 'Annual Rent Stash',
          targetAmount: Number(v.target || v.targetAmount || 0),
          savedAmount: Number(v.saved || v.savedAmount || 0),
          yieldRate: v.yieldRate || '5% p.a.',
          yieldNote: v.yieldNote || '5% Annual Yield',
          createdAt: v.createdAt || new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        }));

        saveAllVaults([...otherVaults, ...synced]);

        res.json({
          success: true,
          message: 'Vaults synced successfully!',
          vaults: synced,
          totalSaved: synced.reduce((sum, v) => sum + (v.savedAmount || 0), 0),
        });
      });
    } catch (err: any) {
      console.error('[VaultController.syncUserVaults] Error:', err.message);
      res.status(500).json({ success: false, error: err.message });
    }
  }
}
