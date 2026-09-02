import type { Request, Response } from 'express';
import { UserStore } from '../services/userStore';
import { TransactionStore } from '../services/transactionStore';
import { PaystackService } from '../services/paystackService';
import { FlutterwaveService } from '../services/flutterwaveService';

export interface ReconciliationReport {
  timestamp: string;
  totalUserWalletObligations: number;
  totalInboundCollections: number;
  totalOutboundPayouts: number;
  netProtocolSettlementBalance: number;
  paystackLiveConnected: boolean;
  flutterwaveLiveConnected: boolean;
  activeAccountsAudited: number;
  variance: number;
  auditStatus: 'HEALTHY & BALANCED' | 'ATTENTION REQUIRED';
}

export async function runReconciliationAudit(_req: Request, res: Response) {
  try {
    const users = await UserStore.getAllUsers();
    const transactions = TransactionStore.getAllTransactions();

    const totalWalletObligations = users.reduce((acc, u) => acc + (u.walletBalance || 0), 0);
    const totalInbound = transactions
      .filter(t => t.category === 'deposit' || t.category === 'wallet_funding')
      .reduce((acc, t) => acc + Number(t.amount || 0), 0);
    const totalOutbound = transactions
      .filter(t => t.category === 'withdrawal')
      .reduce((acc, t) => acc + Number(t.amount || 0), 0);

    const netSettlement = totalInbound - totalOutbound;
    const variance = Math.abs(netSettlement - totalWalletObligations);

    const report: ReconciliationReport = {
      timestamp: new Date().toISOString(),
      totalUserWalletObligations: totalWalletObligations,
      totalInboundCollections: totalInbound,
      totalOutboundPayouts: totalOutbound,
      netProtocolSettlementBalance: netSettlement,
      paystackLiveConnected: PaystackService.isConfigured(),
      flutterwaveLiveConnected: FlutterwaveService.isConfigured(),
      activeAccountsAudited: users.length,
      variance,
      auditStatus: variance < 1000 ? 'HEALTHY & BALANCED' : 'ATTENTION REQUIRED'
    };

    res.json({
      success: true,
      report
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}
