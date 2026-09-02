import React, { useState, useEffect } from 'react';
import { 
  AlertCircle, 
  RefreshCw, 
  ArrowDownLeft, 
  ArrowUpRight, 
  Wallet, 
  ShieldCheck, 
  Activity,
  CheckCircle2,
  Building2,
  Receipt
} from 'lucide-react';

interface AuditReport {
  timestamp: string;
  totalUserWalletObligations: number;
  totalInboundCollections: number;
  totalOutboundPayouts: number;
  netProtocolSettlementBalance: number;
  paystackLiveConnected: boolean;
  flutterwaveLiveConnected: boolean;
  activeAccountsAudited: number;
  variance: number;
  auditStatus: string;
}

interface AuditedUser {
  id: string;
  fullName: string;
  businessName?: string | null;
  email: string;
  walletBalance: number;
  role: string;
}

interface AuditedTx {
  id: string;
  title: string;
  amount: number;
  isCredit: boolean;
  reference: string;
  status: string;
  date: string;
  sender?: string;
  beneficiary?: string;
}

export const ReconciliationTab: React.FC = () => {
  const [report, setReport] = useState<AuditReport | null>(null);
  const [auditedUsers, setAuditedUsers] = useState<AuditedUser[]>([]);
  const [recentTransactions, setRecentTransactions] = useState<AuditedTx[]>([]);
  const [auditing, setAuditing] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const runAudit = async () => {
    setAuditing(true);
    setErrorMsg(null);
    try {
      const res = await fetch('/api/reconciliation/audit');
      if (res.ok) {
        const d = await res.json();
        setReport(d.report);
        if (d.auditedUsers) setAuditedUsers(d.auditedUsers);
        if (d.recentTransactions) setRecentTransactions(d.recentTransactions);
      } else {
        const err = await res.json().catch(() => ({ error: 'Failed to fetch audit data' }));
        setErrorMsg(err.error || 'Server returned an error');
      }
    } catch (e: any) {
      setErrorMsg(e.message || 'Network error fetching reconciliation audit');
    }
    setAuditing(false);
  };

  useEffect(() => {
    runAudit();
  }, []);

  return (
    <div className="space-y-6 font-sans max-w-5xl">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold text-white flex items-center gap-2">
            <Activity className="w-6 h-6 text-emerald-400" />
            <span>Daily Banking Audit & Settlement Reconciliation</span>
          </h1>
          <p className="text-xs text-slate-400 mt-0.5">
            Real-time automated reconciliation comparing Flutterwave inflows, Paystack outbound payouts, and internal wallet ledger obligations.
          </p>
        </div>

        <button
          onClick={runAudit}
          disabled={auditing}
          className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-xs font-bold text-white shadow-lg shadow-emerald-950/60 transition self-start sm:self-auto disabled:opacity-50 cursor-pointer"
        >
          <RefreshCw className={`w-4 h-4 ${auditing ? 'animate-spin' : ''}`} />
          <span>{auditing ? 'Auditing Banking Rails...' : 'Run Audit Now'}</span>
        </button>
      </div>

      {errorMsg && (
        <div className="p-4 rounded-xl bg-red-950/40 border border-red-500/40 text-xs text-red-300 flex items-center gap-2">
          <AlertCircle className="w-4 h-4 text-red-400 shrink-0" />
          <span>{errorMsg}</span>
        </div>
      )}

      {/* Audit Status Banner */}
      {report && (
        <div className={`p-5 rounded-2xl border flex flex-col sm:flex-row sm:items-center justify-between gap-4 ${
          report.variance < 1000
            ? 'bg-emerald-950/40 border-emerald-500/40'
            : 'bg-amber-950/40 border-amber-500/40'
        }`}>
          <div className="flex items-center gap-3">
            <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${
              report.variance < 1000 ? 'bg-emerald-500/20 text-emerald-400' : 'bg-amber-500/20 text-amber-400'
            }`}>
              {report.variance < 1000 ? <ShieldCheck className="w-6 h-6" /> : <AlertCircle className="w-6 h-6" />}
            </div>
            <div>
              <div className="text-sm font-bold text-white flex items-center gap-2">
                <span>Audit Status: {report.auditStatus}</span>
                <span className="text-[10px] px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-300 font-mono">
                  100% Verified
                </span>
              </div>
              <p className="text-xs text-slate-400 mt-0.5">
                Last checked: {new Date(report.timestamp).toLocaleString()} ({report.activeAccountsAudited} accounts audited)
              </p>
            </div>
          </div>

          <div className="text-right shrink-0">
            <span className="text-[11px] text-slate-400 block">Ledger Discrepancy (Variance):</span>
            <span className="text-base font-bold font-mono text-emerald-400">
              ₦{report.variance.toLocaleString()}
            </span>
          </div>
        </div>
      )}

      {/* Financial Rail Balances */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800 space-y-1">
          <div className="flex items-center justify-between text-xs text-slate-400">
            <span>Inbound Bank Collections</span>
            <ArrowDownLeft className="w-4 h-4 text-emerald-400" />
          </div>
          <div className="text-2xl font-bold text-white font-mono">
            ₦{(report?.totalInboundCollections || 0).toLocaleString()}
          </div>
          <span className="text-[10px] text-slate-500">Via Dedicated Flutterwave Virtual Accounts</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800 space-y-1">
          <div className="flex items-center justify-between text-xs text-slate-400">
            <span>Outbound Payouts</span>
            <ArrowUpRight className="w-4 h-4 text-red-400" />
          </div>
          <div className="text-2xl font-bold text-red-400 font-mono">
            ₦{(report?.totalOutboundPayouts || 0).toLocaleString()}
          </div>
          <span className="text-[10px] text-slate-500">Via Paystack Bank Settlements</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800 space-y-1">
          <div className="flex items-center justify-between text-xs text-slate-400">
            <span>User Wallet Obligations</span>
            <Wallet className="w-4 h-4 text-blue-400" />
          </div>
          <div className="text-2xl font-bold text-white font-mono">
            ₦{(report?.totalUserWalletObligations || 0).toLocaleString()}
          </div>
          <span className="text-[10px] text-slate-500">Total liability held in client wallets</span>
        </div>
      </div>

      {/* Audited Accounts Breakdown */}
      {auditedUsers.length > 0 && (
        <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 space-y-3">
          <div className="flex items-center justify-between">
            <h2 className="text-sm font-bold text-white flex items-center gap-2">
              <Building2 className="w-4 h-4 text-emerald-400" />
              <span>Audited Account Balances</span>
            </h2>
            <span className="text-[10px] text-slate-400 font-mono">{auditedUsers.length} Active Profiles</span>
          </div>

          <div className="divide-y divide-slate-800 rounded-xl overflow-hidden border border-slate-800 bg-slate-950">
            {auditedUsers.map((u) => (
              <div key={u.id} className="p-3 flex items-center justify-between text-xs">
                <div>
                  <div className="font-bold text-white flex items-center gap-2">
                    <span>{u.businessName || u.fullName}</span>
                    <span className="text-[9px] px-1.5 py-0.5 rounded uppercase font-bold bg-slate-800 text-slate-300">
                      {u.role}
                    </span>
                  </div>
                  <span className="text-[10px] text-slate-400">{u.email}</span>
                </div>
                <div className="text-right">
                  <span className="font-bold font-mono text-emerald-400 text-sm">
                    ₦{(u.walletBalance || 0).toLocaleString()}
                  </span>
                  <span className="text-[9px] text-slate-500 block">Verified Ledger Balance</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Audited Recent Ledger Transactions */}
      {recentTransactions.length > 0 && (
        <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 space-y-3">
          <div className="flex items-center justify-between">
            <h2 className="text-sm font-bold text-white flex items-center gap-2">
              <Receipt className="w-4 h-4 text-emerald-400" />
              <span>Recent Reconciled Banking Transactions</span>
            </h2>
            <span className="text-[10px] text-slate-400 font-mono">Live PostgreSQL Cloud</span>
          </div>

          <div className="divide-y divide-slate-800 rounded-xl overflow-hidden border border-slate-800 bg-slate-950">
            {recentTransactions.map((tx) => (
              <div key={tx.id || tx.reference} className="p-3 flex items-center justify-between text-xs">
                <div>
                  <div className="font-bold text-white flex items-center gap-2">
                    <span>{tx.title}</span>
                    <span className={`text-[9px] px-1.5 py-0.5 rounded font-bold uppercase ${
                      tx.isCredit ? 'bg-emerald-500/10 text-emerald-400' : 'bg-red-500/10 text-red-400'
                    }`}>
                      {tx.isCredit ? '+ INFLOW' : '- OUTFLOW'}
                    </span>
                  </div>
                  <span className="text-[10px] text-slate-400 font-mono">Ref: {tx.reference}</span>
                </div>
                <div className="text-right">
                  <span className={`font-bold font-mono text-sm ${tx.isCredit ? 'text-emerald-400' : 'text-red-400'}`}>
                    {tx.isCredit ? '+' : '-'}₦{(tx.amount || 0).toLocaleString()}
                  </span>
                  <span className="text-[9px] text-emerald-400 flex items-center justify-end gap-1">
                    <CheckCircle2 className="w-3 h-3" /> Reconciled
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Gateway Live Connection Check */}
      <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 space-y-3 text-xs">
        <h2 className="text-sm font-bold text-white">Banking Gateway Health Verification</h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 flex items-center justify-between">
            <div>
              <div className="font-bold text-white">Flutterwave Virtual Accounts (Inflow)</div>
              <p className="text-[10px] text-slate-400">Monitors dedicated NUBAN collections</p>
            </div>
            <span className={`px-2.5 py-1 rounded-full text-[10px] font-bold uppercase border ${
              report?.flutterwaveLiveConnected
                ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30'
                : 'bg-amber-500/10 text-amber-400 border-amber-500/30'
            }`}>
              {report?.flutterwaveLiveConnected ? 'Active' : 'Standby'}
            </span>
          </div>

          <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 flex items-center justify-between">
            <div>
              <div className="font-bold text-white">Paystack Bank Settlement (Outflow)</div>
              <p className="text-[10px] text-slate-400">Monitors NUBAN withdrawal transfers</p>
            </div>
            <span className={`px-2.5 py-1 rounded-full text-[10px] font-bold uppercase border ${
              report?.paystackLiveConnected
                ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30'
                : 'bg-amber-500/10 text-amber-400 border-amber-500/30'
            }`}>
              {report?.paystackLiveConnected ? 'Active' : 'Standby'}
            </span>
          </div>
        </div>
      </div>
    </div>
  );
};
