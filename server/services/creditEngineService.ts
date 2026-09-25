import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { UserStore } from './userStore';
import { TransactionStore } from './transactionStore';
import { NotificationDispatcher } from './notificationDispatcher';

export interface CreditLoan {
  id: string;
  userId: string;
  userEmail: string;
  userName: string;
  userPhone: string;
  principalAmount: number;
  tenureDays: 30 | 60 | 90;
  monthlyInterestRate: number; // 0.025 (2.5%)
  totalInterestRate: number; // 0.025, 0.05, or 0.075
  interestAmount: number;
  totalRepaymentDue: number;
  amountRepaid: number;
  outstandingBalance: number;
  collateralLocked: number;
  collateralRemaining: number;
  savingsBalanceAtBorrow: number;
  status: 'active' | 'repaid' | 'liquidated' | 'overdue';
  disbursedAt: string;
  dueDate: string;
  settledAt?: string;
  repaymentHistory: Array<{
    id: string;
    amount: number;
    timestamp: string;
    method: 'wallet_balance';
    previousBalance: number;
    newBalance: number;
    reference: string;
  }>;
}

export interface CreditEligibility {
  isEligible: boolean;
  minSavingsThreshold: number; // 20,000 NGN
  currentSavingsBalance: number;
  maxBorrowableAmount: number; // 80% of savings
  activeLoan: CreditLoan | null;
  interestRatePerMonth: number; // 2.5%
  annualSavingsYieldRate: number; // 2.5% p.a.
  reason?: string;
  tenureOptions: Array<{
    days: 30 | 60 | 90;
    label: string;
    ratePct: number;
    monthlyInterestPct: number;
  }>;
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
      fs.writeFileSync(path.join(dir, '.write_test_credit'), 'ok', 'utf-8');
      fs.unlinkSync(path.join(dir, '.write_test_credit'));
      return dir;
    } catch {
      continue;
    }
  }
  return '/tmp';
}

let _DATA_DIR: string | null = null;
function getStoragePath(): string {
  if (!_DATA_DIR) _DATA_DIR = getDataDir();
  return path.join(_DATA_DIR, 'credit_loans.json');
}

let _loansCache: CreditLoan[] | null = null;

// User-Keyed Mutex for Concurrency Protection
const _userMutexes: Map<string, Promise<any>> = new Map();

async function withUserLock<T>(userId: string, fn: () => Promise<T>): Promise<T> {
  const currentLock = _userMutexes.get(userId) || Promise.resolve();
  let release: () => void;
  const nextLock = new Promise<void>((res) => {
    release = res;
  });
  _userMutexes.set(userId, currentLock.then(() => nextLock));

  try {
    await currentLock;
    return await fn();
  } finally {
    release!();
    if (_userMutexes.get(userId) === nextLock) {
      _userMutexes.delete(userId);
    }
  }
}

function loadLoansFromDisk(): CreditLoan[] {
  if (_loansCache) return _loansCache;
  const filePath = getStoragePath();
  try {
    if (fs.existsSync(filePath)) {
      const raw = fs.readFileSync(filePath, 'utf-8');
      _loansCache = JSON.parse(raw);
      return _loansCache || [];
    }
  } catch (err) {
    console.error('[CreditEngineService] Error reading loans data file:', err);
  }
  _loansCache = [];
  return _loansCache;
}

function saveLoansToDisk(loans: CreditLoan[]): void {
  _loansCache = loans;
  const filePath = getStoragePath();
  try {
    fs.writeFileSync(filePath, JSON.stringify(loans, null, 2), 'utf-8');
  } catch (err) {
    console.error('[CreditEngineService] Error writing loans data file:', err);
  }
}

export class CreditEngineService {
  public static readonly MIN_SAVINGS_THRESHOLD = 20000; // ₦20,000 NGN
  public static readonly MAX_LTV_RATIO = 0.80; // 80% Max Loan to Value
  public static readonly MONTHLY_INTEREST_RATE = 0.025; // 2.5% per month

  /**
   * Calculate credit eligibility for a given user and savings balance
   */
  public static async getEligibility(userIdOrEmail: string, clientSavingsBalance?: number): Promise<CreditEligibility> {
    const user = (await UserStore.findById(userIdOrEmail)) || (await UserStore.findByEmail(userIdOrEmail));
    
    // Check if there is an active loan
    const loans = loadLoansFromDisk();
    const activeLoan = loans.find(
      (l) =>
        (l.userId === userIdOrEmail || (user && l.userId === user.id) || l.userEmail.toLowerCase() === userIdOrEmail.toLowerCase()) &&
        (l.status === 'active' || l.status === 'overdue')
    ) || null;

    // Use verified savings balance or passed client savings balance
    let savingsBalance = Number(clientSavingsBalance ?? 0);
    if ((!Number.isFinite(savingsBalance) || savingsBalance <= 0) && user) {
      savingsBalance = Number((user as any).savingsBalance ?? 0);
    }
    if (!Number.isFinite(savingsBalance) || savingsBalance < 0) {
      savingsBalance = 0;
    }

    const isAboveMinThreshold = savingsBalance >= this.MIN_SAVINGS_THRESHOLD;
    const maxBorrowableAmount = isAboveMinThreshold ? Math.floor(savingsBalance * this.MAX_LTV_RATIO) : 0;

    let reason: string | undefined;
    if (activeLoan) {
      reason = `You currently have an active credit loan of ₦${activeLoan.principalAmount.toLocaleString()} due on ${new Date(activeLoan.dueDate).toLocaleDateString()}. Please repay your active loan to unlock further borrowing.`;
    } else if (!isAboveMinThreshold) {
      reason = `Minimum savings balance of ₦${this.MIN_SAVINGS_THRESHOLD.toLocaleString()} required to unlock up to 80% credit advance. Your current savings balance is ₦${savingsBalance.toLocaleString()}.`;
    }

    return {
      isEligible: isAboveMinThreshold && activeLoan === null,
      minSavingsThreshold: this.MIN_SAVINGS_THRESHOLD,
      currentSavingsBalance: savingsBalance,
      maxBorrowableAmount,
      activeLoan,
      interestRatePerMonth: this.MONTHLY_INTEREST_RATE,
      annualSavingsYieldRate: 0.025,
      reason,
      tenureOptions: [
        { days: 30, label: '30 Days (1 Month)', ratePct: 2.5, monthlyInterestPct: 2.5 },
        { days: 60, label: '60 Days (2 Months)', ratePct: 5.0, monthlyInterestPct: 2.5 },
        { days: 90, label: '90 Days (3 Months)', ratePct: 7.5, monthlyInterestPct: 2.5 },
      ],
    };
  }

  /**
   * Request / Apply for a savings-backed credit advance.
   * Instant disbursement directly into the user's Rentilly walletBalance.
   * Protected with Mutex lock against concurrent duplicate applications.
   */
  public static async applyForCredit(params: {
    userIdOrEmail: string;
    amount: number;
    tenureDays: 30 | 60 | 90;
    savingsBalance: number;
    pin?: string;
  }): Promise<{ success: boolean; loan?: CreditLoan; newWalletBalance?: number; message: string }> {
    const { userIdOrEmail, amount, tenureDays, savingsBalance } = params;

    const initialUser = (await UserStore.findById(userIdOrEmail)) || (await UserStore.findByEmail(userIdOrEmail));
    if (!initialUser) {
      return { success: false, message: 'User account not found.' };
    }

    return withUserLock(initialUser.id, async () => {
      // Re-fetch fresh user state inside lock
      const user = (await UserStore.findById(initialUser.id)) || initialUser;

      // Validate tenure
      if (![30, 60, 90].includes(tenureDays)) {
        return { success: false, message: 'Invalid tenure. Tenure must be 30, 60, or 90 days.' };
      }

      // Validate verified savings
      let verifiedSavings = Number(savingsBalance);
      if (!Number.isFinite(verifiedSavings) || verifiedSavings <= 0) {
        verifiedSavings = Number((user as any).savingsBalance ?? 0);
      }
      if (!Number.isFinite(verifiedSavings) || verifiedSavings < this.MIN_SAVINGS_THRESHOLD) {
        return {
          success: false,
          message: `Insufficient savings. A minimum savings balance of ₦${this.MIN_SAVINGS_THRESHOLD.toLocaleString()} is required.`,
        };
      }

      // Validate 80% LTV
      const maxAllowed = Math.floor(verifiedSavings * this.MAX_LTV_RATIO);
      if (!Number.isFinite(amount) || amount <= 0 || amount > maxAllowed) {
        return {
          success: false,
          message: `Requested amount ₦${amount.toLocaleString()} exceeds maximum 80% borrowing limit of ₦${maxAllowed.toLocaleString()}.`,
        };
      }

      // Check existing active loans
      const loans = loadLoansFromDisk();
      const existingActive = loans.find(
        (l) =>
          (l.userId === user.id || l.userEmail.toLowerCase() === user.email.toLowerCase()) &&
          (l.status === 'active' || l.status === 'overdue')
      );
      if (existingActive) {
        return {
          success: false,
          message: 'You already have an active loan. Please repay your current loan before applying for a new advance.',
        };
      }

      // Calculate Interest & Repayment
      // 30 days = 1 month (2.5%), 60 days = 2 months (5.0%), 90 days = 3 months (7.5%)
      const months = tenureDays / 30;
      const totalInterestRate = this.MONTHLY_INTEREST_RATE * months;
      const interestAmount = Math.round(amount * totalInterestRate);
      const totalRepaymentDue = amount + interestAmount;
      const requiredCollateral = Math.ceil(amount / this.MAX_LTV_RATIO); // Amount / 0.8 = 1.25x

      const now = new Date();
      const dueDate = new Date(now.getTime() + tenureDays * 24 * 60 * 60 * 1000);

      const loanId = `LN-${Date.now().toString(36).toUpperCase()}-${crypto.randomBytes(3).toString('hex').toUpperCase()}`;

      const newLoan: CreditLoan = {
        id: loanId,
        userId: user.id,
        userEmail: user.email,
        userName: user.fullName || 'Rentilly Member',
        userPhone: user.phoneNumber || '',
        principalAmount: amount,
        tenureDays,
        monthlyInterestRate: this.MONTHLY_INTEREST_RATE,
        totalInterestRate,
        interestAmount,
        totalRepaymentDue,
        amountRepaid: 0,
        outstandingBalance: totalRepaymentDue,
        collateralLocked: requiredCollateral,
        collateralRemaining: requiredCollateral,
        savingsBalanceAtBorrow: verifiedSavings,
        status: 'active',
        disbursedAt: now.toISOString(),
        dueDate: dueDate.toISOString(),
        repaymentHistory: [],
      };

      // Instant Wallet Disbursement
      const currentBalance = Number(user.walletBalance || 0);
      const newWalletBalance = currentBalance + amount;

      UserStore.upsertUser({
        ...user,
        walletBalance: newWalletBalance,
        lockedCollateral: (Number((user as any).lockedCollateral || 0)) + requiredCollateral,
      } as any);

      // Record Ledger & Transaction Record
      TransactionStore.addTransaction({
        id: `TX-${loanId}`,
        userId: user.id,
        email: user.email,
        title: '80% Savings-Backed Credit Advance',
        type: 'Credit Disbursement (Savings-Backed)',
        category: 'deposit',
        amount: amount,
        isCredit: true,
        status: 'SUCCESSFUL',
        reference: `DISB-${loanId}`,
        description: `Instant 80% Savings-Backed Credit Advance for ${tenureDays} days @ 2.5%/mo. (Loan ID: ${loanId})`,
        createdAt: now.toISOString(),
      });

      // Save Loan to store
      loans.push(newLoan);
      saveLoansToDisk(loans);

      // Dispatch Notifications (Push / SMS / Email)
      NotificationDispatcher.dispatch({
        userId: user.id,
        email: user.email,
        phoneNumber: user.phoneNumber,
        title: '₦' + amount.toLocaleString() + ' Credit Advance Disbursed! 🚀',
        message: `Your savings-backed loan of ₦${amount.toLocaleString()} has been credited to your Rentilly Wallet. Due on ${dueDate.toLocaleDateString()} (Total: ₦${totalRepaymentDue.toLocaleString()}).`,
        category: 'wallet',
        metadata: { loanId, amount, dueDate: dueDate.toISOString() },
      }).catch((e) => console.warn('[CreditEngineService] Notification error:', e));

      return {
        success: true,
        loan: newLoan,
        newWalletBalance,
        message: `₦${amount.toLocaleString()} has been credited to your Rentilly Wallet instantly!`,
      };
    });
  }

  /**
   * Repay an active credit loan.
   * REPAYMENT RULE: Strictly NO card repayments. Repayments MUST come directly
   * from the user's Rentilly walletBalance or by funding their Rentilly virtual account.
   * Protected with Mutex lock against concurrent duplicate repayments.
   */
  public static async repayLoan(params: {
    userIdOrEmail: string;
    loanId: string;
    amount: number;
    paymentMethod: 'wallet'; // Strictly wallet only
  }): Promise<{
    success: boolean;
    loan?: CreditLoan;
    newWalletBalance?: number;
    remainingBalance?: number;
    collateralReleased?: number;
    message: string;
    virtualAccountPrompt?: {
      bankName: string;
      accountNumber: string;
      accountName: string;
    };
  }> {
    const { userIdOrEmail, loanId, amount, paymentMethod } = params;

    // Enforce wallet-only repayment rule
    if (paymentMethod !== 'wallet') {
      return {
        success: false,
        message: 'Card repayments are disabled. All repayments must be completed via your Rentilly Wallet balance or virtual account transfer.',
      };
    }

    const initialUser = (await UserStore.findById(userIdOrEmail)) || (await UserStore.findByEmail(userIdOrEmail));
    if (!initialUser) {
      return { success: false, message: 'User account not found.' };
    }

    return withUserLock(initialUser.id, async () => {
      // Re-fetch fresh user state inside lock
      const user = (await UserStore.findById(initialUser.id)) || initialUser;

      const loans = loadLoansFromDisk();
      const loanIndex = loans.findIndex(
        (l) =>
          l.id === loanId &&
          (l.userId === user.id || l.userEmail.toLowerCase() === user.email.toLowerCase())
      );

      if (loanIndex === -1) {
        return { success: false, message: 'Active loan record not found.' };
      }

      const loan = loans[loanIndex];
      if (loan.status !== 'active' && loan.status !== 'overdue') {
        return { success: false, message: `Loan is already marked as ${loan.status}.` };
      }

      if (!Number.isFinite(amount) || amount <= 0) {
        return { success: false, message: 'Repayment amount must be greater than zero.' };
      }

      const maxNeeded = loan.outstandingBalance;
      const actualRepayAmount = Math.min(amount, maxNeeded);

      // Check user's Rentilly wallet balance
      const currentWalletBalance = Number(user.walletBalance || 0);
      if (currentWalletBalance < actualRepayAmount) {
        const shortfall = actualRepayAmount - currentWalletBalance;
        return {
          success: false,
          message: `Insufficient wallet balance. You have ₦${currentWalletBalance.toLocaleString()}, but need ₦${actualRepayAmount.toLocaleString()} (Shortfall: ₦${shortfall.toLocaleString()}). Please fund your Rentilly Virtual Account first.`,
          virtualAccountPrompt: {
            bankName: user.bankName || 'Wema Bank / Rentilly MFB',
            accountNumber: user.accountNumber || '0123456789',
            accountName: user.fullName || 'Rentilly Member',
          },
        };
      }

      // Deduct from Wallet Balance
      const newWalletBalance = currentWalletBalance - actualRepayAmount;
      const newAmountRepaid = loan.amountRepaid + actualRepayAmount;
      const rawOutstanding = loan.totalRepaymentDue - newAmountRepaid;
      const newOutstanding = rawOutstanding <= 0.01 ? 0 : Math.max(0, rawOutstanding);
      const isFullyRepaid = newOutstanding === 0;

      // Ensure collateral remaining is tracked
      const currentCollateralRemaining = loan.collateralRemaining ?? loan.collateralLocked;

      // Calculate collateral release
      let collateralReleased = 0;
      if (isFullyRepaid) {
        collateralReleased = currentCollateralRemaining;
      } else {
        const proportionalRelease = Math.floor(
          (actualRepayAmount / loan.totalRepaymentDue) * loan.collateralLocked
        );
        collateralReleased = Math.min(currentCollateralRemaining, proportionalRelease);
      }

      const newCollateralRemaining = Math.max(0, currentCollateralRemaining - collateralReleased);
      loan.collateralRemaining = newCollateralRemaining;

      // Update User Profile locked collateral safely
      const currentLockedCollateral = Math.max(
        0,
        Number((user as any).lockedCollateral || 0) - collateralReleased
      );

      UserStore.upsertUser({
        ...user,
        walletBalance: newWalletBalance,
        lockedCollateral: currentLockedCollateral,
      } as any);

      const repayRef = `RPY-${loanId}-${Date.now().toString(36).toUpperCase()}`;

      // Update Loan Record
      loan.amountRepaid = newAmountRepaid;
      loan.outstandingBalance = newOutstanding;
      if (isFullyRepaid) {
        loan.status = 'repaid';
        loan.settledAt = new Date().toISOString();
      }

      loan.repaymentHistory.push({
        id: repayRef,
        amount: actualRepayAmount,
        timestamp: new Date().toISOString(),
        method: 'wallet_balance',
        previousBalance: currentWalletBalance,
        newBalance: newWalletBalance,
        reference: repayRef,
      });

      loans[loanIndex] = loan;
      saveLoansToDisk(loans);

      // Record Ledger Transaction
      TransactionStore.addTransaction({
        id: `TX-${repayRef}`,
        userId: user.id,
        email: user.email,
        title: 'Credit Advance Repayment',
        type: 'Credit Repayment (Wallet Debit)',
        category: 'withdrawal',
        amount: actualRepayAmount,
        isCredit: false,
        status: 'SUCCESSFUL',
        reference: repayRef,
        description: `Savings Credit Repayment for Loan ${loanId}. ${isFullyRepaid ? 'Full Settlement' : 'Partial Payment'}.`,
        createdAt: new Date().toISOString(),
      });

      // Dispatch Notification
      NotificationDispatcher.dispatch({
        userId: user.id,
        email: user.email,
        phoneNumber: user.phoneNumber,
        title: isFullyRepaid ? '🎉 Credit Advance Fully Settled!' : 'Credit Payment Received 💳',
        message: isFullyRepaid
          ? `Your loan of ₦${loan.principalAmount.toLocaleString()} has been fully repaid! ₦${collateralReleased.toLocaleString()} in locked savings is now unlocked.`
          : `₦${actualRepayAmount.toLocaleString()} received towards Loan ${loanId}. Remaining balance: ₦${newOutstanding.toLocaleString()}.`,
        category: 'wallet',
        metadata: { loanId, amountRepaid: actualRepayAmount, remainingBalance: newOutstanding, collateralReleased },
      }).catch((e) => console.warn('[CreditEngineService] Notification error:', e));

      return {
        success: true,
        loan,
        newWalletBalance,
        remainingBalance: newOutstanding,
        collateralReleased,
        message: isFullyRepaid
          ? `Congratulations! Loan ${loanId} is fully settled and ₦${collateralReleased.toLocaleString()} savings collateral is released.`
          : `₦${actualRepayAmount.toLocaleString()} repaid successfully. Remaining balance: ₦${newOutstanding.toLocaleString()}.`,
      };
    });
  }

  /**
   * Get all loans for a specific user
   */
  public static async getUserLoans(userIdOrEmail: string): Promise<CreditLoan[]> {
    const loans = loadLoansFromDisk();
    const user = (await UserStore.findById(userIdOrEmail)) || (await UserStore.findByEmail(userIdOrEmail));
    return loans.filter(
      (l) => l.userId === userIdOrEmail || (user && l.userId === user.id) || l.userEmail.toLowerCase() === userIdOrEmail.toLowerCase()
    );
  }

  /**
   * Get all loans across the platform for Admin oversight
   */
  public static async getAllLoans(): Promise<{
    loans: CreditLoan[];
    summary: {
      totalDisbursed: number;
      totalRepaid: number;
      totalOutstanding: number;
      totalInterestEarned: number;
      activeLoansCount: number;
      repaidLoansCount: number;
      overdueLoansCount: number;
      totalCollateralLocked: number;
    };
  }> {
    const loans = loadLoansFromDisk();
    
    // Auto-check and mark overdue loans
    const now = new Date();
    let updatedAny = false;
    for (const loan of loans) {
      if (loan.status === 'active' && new Date(loan.dueDate) < now) {
        loan.status = 'overdue';
        updatedAny = true;
      }
    }
    if (updatedAny) {
      saveLoansToDisk(loans);
    }

    const totalDisbursed = loans.reduce((acc, l) => acc + l.principalAmount, 0);
    const totalRepaid = loans.reduce((acc, l) => acc + l.amountRepaid, 0);
    const totalOutstanding = loans
      .filter((l) => l.status === 'active' || l.status === 'overdue')
      .reduce((acc, l) => acc + l.outstandingBalance, 0);
    const totalInterestEarned = loans
      .filter((l) => l.status === 'repaid' || l.amountRepaid > l.principalAmount)
      .reduce((acc, l) => acc + (l.amountRepaid > l.principalAmount ? l.amountRepaid - l.principalAmount : l.interestAmount), 0);
    const activeLoansCount = loans.filter((l) => l.status === 'active').length;
    const repaidLoansCount = loans.filter((l) => l.status === 'repaid').length;
    const overdueLoansCount = loans.filter((l) => l.status === 'overdue').length;
    const totalCollateralLocked = loans
      .filter((l) => l.status === 'active' || l.status === 'overdue')
      .reduce((acc, l) => acc + (l.collateralRemaining ?? l.collateralLocked), 0);

    return {
      loans,
      summary: {
        totalDisbursed,
        totalRepaid,
        totalOutstanding,
        totalInterestEarned,
        activeLoansCount,
        repaidLoansCount,
        overdueLoansCount,
        totalCollateralLocked,
      },
    };
  }

  /**
   * Auto-Liquidation Worker:
   * Checks for overdue loans past grace period and settles unpaid balance from locked savings vault.
   */
  public static async autoSettleOverdueLoans(): Promise<{ settledCount: number; liquidatedAmount: number }> {
    const loans = loadLoansFromDisk();
    const now = new Date();
    let settledCount = 0;
    let liquidatedAmount = 0;

    for (let i = 0; i < loans.length; i++) {
      const loan = loans[i];
      if ((loan.status === 'active' || loan.status === 'overdue') && new Date(loan.dueDate) < now) {
        // Liquidate from locked collateral
        const user = await UserStore.findById(loan.userId);
        if (user) {
          const unpaid = loan.outstandingBalance;
          loan.status = 'liquidated';
          loan.settledAt = now.toISOString();
          loan.amountRepaid += unpaid;
          loan.outstandingBalance = 0;

          const remainingCol = loan.collateralRemaining ?? loan.collateralLocked;
          loan.collateralRemaining = 0;

          // Release remaining locked collateral & deduct unpaid loan balance from user's savings vault
          const currentLocked = Math.max(0, Number((user as any).lockedCollateral || 0) - remainingCol);
          const currentSavings = Math.max(0, Number((user as any).savingsBalance || 0) - unpaid);

          UserStore.upsertUser({
            ...user,
            savingsBalance: currentSavings,
            lockedCollateral: currentLocked,
          } as any);

          // Record Ledger entry
          TransactionStore.addTransaction({
            id: `TX-LIQ-${loan.id}`,
            userId: user.id,
            email: user.email,
            title: 'Credit Maturity Liquidation',
            type: 'Credit Auto-Settlement (Vault Liquidation)',
            category: 'withdrawal',
            amount: unpaid,
            isCredit: false,
            status: 'SUCCESSFUL',
            reference: `LIQ-${loan.id}`,
            description: `Automated maturity settlement for Overdue Loan ${loan.id} liquidated from locked savings.`,
            createdAt: now.toISOString(),
          });

          // Dispatch Notification
          NotificationDispatcher.dispatch({
            userId: user.id,
            email: user.email,
            phoneNumber: user.phoneNumber,
            title: '⚠️ Savings Vault Loan Settlement',
            message: `Your overdue loan (${loan.id}) of ₦${unpaid.toLocaleString()} was settled automatically from your savings vault. Remaining collateral released.`,
            category: 'wallet',
            metadata: { loanId: loan.id, liquidatedAmount: unpaid },
          }).catch((e) => console.warn('[CreditEngineService] Notification error:', e));

          settledCount++;
          liquidatedAmount += unpaid;
        }
      }
    }

    if (settledCount > 0) {
      saveLoansToDisk(loans);
    }

    return { settledCount, liquidatedAmount };
  }
}
