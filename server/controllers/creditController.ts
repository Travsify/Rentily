import type { Request, Response } from 'express';
import { CreditEngineService } from '../services/creditEngineService';

export async function getEligibility(req: Request, res: Response) {
  try {
    const userIdOrEmail = (req.query.userId as string) || (req.query.email as string);
    const clientSavings = req.query.savingsBalance ? Number(req.query.savingsBalance) : undefined;

    if (!userIdOrEmail) {
      return res.status(400).json({ status: false, error: 'User ID or Email is required.' });
    }

    const eligibility = await CreditEngineService.getEligibility(userIdOrEmail, clientSavings);
    res.json({
      status: true,
      ...eligibility,
    });
  } catch (err: any) {
    console.error('[CreditController] getEligibility error:', err);
    res.status(500).json({ status: false, error: err.message || 'Failed to check credit eligibility.' });
  }
}

export async function applyForCredit(req: Request, res: Response) {
  try {
    const { userId, email, amount, tenureDays, savingsBalance, pin } = req.body;
    const userIdOrEmail = userId || email;

    if (!userIdOrEmail) {
      return res.status(400).json({ status: false, error: 'User identifier (userId or email) is required.' });
    }

    if (!amount || amount <= 0) {
      return res.status(400).json({ status: false, error: 'Borrow amount must be greater than zero.' });
    }

    if (![30, 60, 90].includes(Number(tenureDays))) {
      return res.status(400).json({ status: false, error: 'Tenure must be 30, 60, or 90 days.' });
    }

    const result = await CreditEngineService.applyForCredit({
      userIdOrEmail,
      amount: Number(amount),
      tenureDays: Number(tenureDays) as 30 | 60 | 90,
      savingsBalance: Number(savingsBalance || 0),
      pin,
    });

    if (!result.success) {
      return res.status(400).json({ status: false, error: result.message });
    }

    res.json({
      status: true,
      ...result,
    });
  } catch (err: any) {
    console.error('[CreditController] applyForCredit error:', err);
    res.status(500).json({ status: false, error: err.message || 'Failed to disburse credit advance.' });
  }
}

export async function repayLoan(req: Request, res: Response) {
  try {
    const { userId, email, loanId, amount, paymentMethod } = req.body;
    const userIdOrEmail = userId || email;

    if (!userIdOrEmail || !loanId) {
      return res.status(400).json({ status: false, error: 'User identifier and Loan ID are required.' });
    }

    // STRICT VALIDATION: Reject any card-based payment method
    if (paymentMethod && paymentMethod !== 'wallet' && paymentMethod !== 'wallet_balance') {
      return res.status(400).json({
        status: false,
        error: 'Card repayments are disabled. All repayments must be completed directly from your Rentilly Wallet balance or virtual bank transfer.',
      });
    }

    if (!amount || Number(amount) <= 0) {
      return res.status(400).json({ status: false, error: 'Repayment amount must be greater than zero.' });
    }

    const result = await CreditEngineService.repayLoan({
      userIdOrEmail,
      loanId,
      amount: Number(amount),
      paymentMethod: 'wallet',
    });

    if (!result.success) {
      return res.status(400).json({ status: false, error: result.message, virtualAccountPrompt: result.virtualAccountPrompt });
    }

    res.json({
      status: true,
      ...result,
    });
  } catch (err: any) {
    console.error('[CreditController] repayLoan error:', err);
    res.status(500).json({ status: false, error: err.message || 'Failed to process loan repayment.' });
  }
}

export async function getUserLoans(req: Request, res: Response) {
  try {
    const userIdOrEmail = (req.query.userId as string) || (req.query.email as string);

    if (!userIdOrEmail) {
      return res.status(400).json({ status: false, error: 'User ID or Email is required.' });
    }

    const loans = await CreditEngineService.getUserLoans(userIdOrEmail);
    res.json({
      status: true,
      loans,
    });
  } catch (err: any) {
    console.error('[CreditController] getUserLoans error:', err);
    res.status(500).json({ status: false, error: err.message || 'Failed to retrieve loans.' });
  }
}

export async function getAdminOverview(_req: Request, res: Response) {
  try {
    const overview = await CreditEngineService.getAllLoans();
    res.json({
      status: true,
      ...overview,
    });
  } catch (err: any) {
    console.error('[CreditController] getAdminOverview error:', err);
    res.status(500).json({ status: false, error: err.message || 'Failed to retrieve credit overview.' });
  }
}

export async function triggerAutoLiquidation(_req: Request, res: Response) {
  try {
    const result = await CreditEngineService.autoSettleOverdueLoans();
    res.json({
      status: true,
      message: `Maturity settlement check complete. ${result.settledCount} overdue loans liquidated.`,
      ...result,
    });
  } catch (err: any) {
    console.error('[CreditController] triggerAutoLiquidation error:', err);
    res.status(500).json({ status: false, error: err.message || 'Auto liquidation failed.' });
  }
}
