import React, { useState, useEffect } from 'react';
import { 
  Wallet, 
  Search, 
  ArrowUpRight, 
  ArrowDownLeft, 
  Download, 
  RefreshCw, 
  Zap, 
  ShieldCheck, 
  BadgePercent
} from 'lucide-react';

interface LedgerItem {
  id: string;
  userId?: string;
  email: string;
  title: string;
  type: string;
  category: string;
  amount: number;
  isCredit: boolean;
  reference: string;
  sender?: string;
  beneficiary?: string;
  recipientAccount?: string;
  recipientBank?: string;
  status: string;
  date: string;
}

interface LedgerStats {
  totalVolume: number;
  totalDeposits: number;
  totalWithdrawals: number;
  totalUtilityVolume: number;
  totalFeesCollected: number;
  transactionCount: number;
  feeConfig?: {
    withdrawalFee: number;
    electricityFee: number;
  };
}

export const MasterLedgerTab: React.FC = () => {
  const [transactions, setTransactions] = useState<LedgerItem[]>([]);
  const [stats, setStats] = useState<LedgerStats | null>(null);
  const [categoryFilter, setCategoryFilter] = useState('all');
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);

  const fetchData = async () => {
    try {
      const [txRes, statsRes] = await Promise.all([
        fetch('/api/ledger/transactions'),
        fetch('/api/ledger/stats')
      ]);

      if (txRes.ok) {
        const d = await txRes.json();
        setTransactions(d.transactions || []);
      }
      if (statsRes.ok) {
        const s = await statsRes.json();
        setStats(s.stats);
      }
    } catch (_) {}
    setLoading(false);
  };

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 15000);
    return () => clearInterval(interval);
  }, []);

  const filtered = transactions.filter((t) => {
    const matchesCategory = categoryFilter === 'all' || t.category === categoryFilter;
    const matchesSearch = 
      t.title.toLowerCase().includes(search.toLowerCase()) ||
      t.reference.toLowerCase().includes(search.toLowerCase()) ||
      (t.email && t.email.toLowerCase().includes(search.toLowerCase())) ||
      (t.beneficiary && t.beneficiary.toLowerCase().includes(search.toLowerCase())) ||
      (t.recipientAccount && t.recipientAccount.includes(search));

    return matchesCategory && matchesSearch;
  });

  const exportToCSV = () => {
    if (filtered.length === 0) return;
    const headers = ['Tx ID', 'Date', 'Type', 'Category', 'Title', 'Amount (NGN)', 'Status', 'User', 'Reference', 'Beneficiary'];
    const rows = filtered.map(t => [
      t.id,
      t.date,
      t.type,
      t.category,
      `"${(t.title || '').replace(/"/g, '""')}"`,
      t.amount,
      t.status,
      t.email,
      t.reference,
      `"${(t.beneficiary || '').replace(/"/g, '""')}"`
    ]);
    const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map(e => e.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `rentilly_financial_ledger_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="space-y-6 font-sans">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold text-white flex items-center gap-2">
            <Wallet className="w-6 h-6 text-emerald-400" />
            <span>Master Financial & Wallet Ledger</span>
          </h1>
          <p className="text-xs text-slate-400 mt-0.5">
            Audit all wallet funding, outbound bank withdrawals, P2P transfers, utility bill payments, and platform fee profits.
          </p>
        </div>

        <div className="flex items-center gap-2 self-start sm:self-auto">
          <button
            onClick={fetchData}
            title="Refresh Ledger"
            className="p-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-400 hover:text-white transition"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
          </button>
          {filtered.length > 0 && (
            <button
              onClick={exportToCSV}
              className="flex items-center gap-2 px-4 py-2 rounded-xl bg-slate-900 border border-slate-700 hover:border-slate-600 text-xs font-semibold text-white shadow-sm transition"
            >
              <Download className="w-4 h-4 text-emerald-400" />
              <span>Export Ledger (CSV)</span>
            </button>
          )}
        </div>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Gross Transaction Volume</span>
          <div className="text-2xl font-bold text-white mt-1">₦{(stats?.totalVolume || 0).toLocaleString()}</div>
          <span className="text-[10px] text-slate-400">{stats?.transactionCount || 0} total platform transactions</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Outbound Bank Payouts</span>
            <ArrowUpRight className="w-4 h-4 text-red-400" />
          </div>
          <div className="text-2xl font-bold text-red-400 mt-1">₦{(stats?.totalWithdrawals || 0).toLocaleString()}</div>
          <span className="text-[10px] text-slate-400">Withdrawals to NUBAN bank accounts</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Inbound Bank Deposits</span>
            <ArrowDownLeft className="w-4 h-4 text-emerald-400" />
          </div>
          <div className="text-2xl font-bold text-emerald-400 mt-1">₦{(stats?.totalDeposits || 0).toLocaleString()}</div>
          <span className="text-[10px] text-slate-400">Via Dedicated Flutterwave NUBANs</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900 border border-emerald-500/30">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-emerald-400 uppercase tracking-wider">Platform Fee Revenue</span>
            <BadgePercent className="w-4 h-4 text-emerald-400" />
          </div>
          <div className="text-2xl font-bold text-white mt-1">₦{(stats?.totalFeesCollected || 0).toLocaleString()}</div>
          <span className="text-[10px] text-emerald-400/80">Withdrawal fees (₦50) + Disco fees (₦100) + Leases</span>
        </div>
      </div>

      {/* Filter and Search Bar */}
      <div className="flex flex-col md:flex-row gap-3 items-center justify-between bg-slate-900/60 p-3.5 rounded-2xl border border-slate-800">
        <div className="relative w-full md:w-80">
          <Search className="w-4 h-4 text-slate-500 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by ref, email, beneficiary, account..."
            className="w-full pl-9 pr-4 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-200 focus:outline-none focus:border-emerald-500"
          />
        </div>

        <div className="flex items-center gap-2 overflow-x-auto w-full md:w-auto">
          <select
            value={categoryFilter}
            onChange={(e) => setCategoryFilter(e.target.value)}
            className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-300 focus:outline-none focus:border-emerald-500"
          >
            <option value="all">All Transaction Types</option>
            <option value="deposit">Inbound Deposits (Virtual Account)</option>
            <option value="withdrawal">Outbound Bank Withdrawals</option>
            <option value="utility">Utility & Bills (Data / Power)</option>
            <option value="escrow">Property Escrow Payments</option>
            <option value="commission">Partner Brokerage Commissions</option>
          </select>
        </div>
      </div>

      {/* Table */}
      {filtered.length === 0 ? (
        <div className="p-12 text-center rounded-3xl bg-slate-900/40 border border-slate-800/80 space-y-3">
          <div className="w-12 h-12 rounded-2xl bg-slate-800/80 flex items-center justify-center mx-auto text-slate-500">
            <Wallet className="w-6 h-6" />
          </div>
          <div className="space-y-1">
            <h3 className="text-sm font-bold text-white">No Ledger Transactions Found</h3>
            <p className="text-xs text-slate-400">
              Transactions, wallet movements, and platform fee deductions will appear here in real-time.
            </p>
          </div>
        </div>
      ) : (
        <div className="rounded-2xl bg-slate-900 border border-slate-800 overflow-hidden shadow-sm">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="border-b border-slate-800 text-slate-400 uppercase font-semibold text-[10px] tracking-wider bg-slate-950/40">
                <tr>
                  <th className="py-3.5 px-4 font-semibold">Transaction & Date</th>
                  <th className="py-3.5 font-semibold">Category</th>
                  <th className="py-3.5 font-semibold">Sender / Beneficiary</th>
                  <th className="py-3.5 font-semibold">Amount</th>
                  <th className="py-3.5 font-semibold">Reference</th>
                  <th className="py-3.5 px-4 font-semibold text-right">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60">
                {filtered.map((t) => {
                  const isCredit = t.isCredit || t.category === 'deposit' || t.category === 'commission';
                  return (
                    <tr key={t.id} className="hover:bg-slate-850/50 transition">
                      <td className="py-3 px-4">
                        <div className="font-bold text-white">{t.title}</div>
                        <div className="text-[10px] text-slate-500 font-mono">
                          {new Date(t.date).toLocaleString()}
                        </div>
                      </td>
                      <td className="py-3">
                        <span className={`inline-flex items-center gap-1 text-[10px] font-bold uppercase px-2 py-0.5 rounded-full ${
                          t.category === 'withdrawal'
                            ? 'bg-red-500/10 text-red-400 border border-red-500/20'
                            : t.category === 'utility'
                            ? 'bg-amber-500/10 text-amber-400 border border-amber-500/20'
                            : t.category === 'commission'
                            ? 'bg-blue-500/10 text-blue-400 border border-blue-500/20'
                            : 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20'
                        }`}>
                          {t.category === 'utility' && <Zap className="w-3 h-3" />}
                          {t.category === 'withdrawal' && <ArrowUpRight className="w-3 h-3" />}
                          {t.category === 'deposit' && <ArrowDownLeft className="w-3 h-3" />}
                          {t.category === 'commission' && <ShieldCheck className="w-3 h-3" />}
                          <span>{t.category}</span>
                        </span>
                      </td>
                      <td className="py-3">
                        <div className="font-medium text-slate-200">
                          {t.beneficiary || t.sender || t.email}
                        </div>
                        {t.recipientAccount && (
                          <div className="text-[10px] text-slate-400 font-mono">
                            {t.recipientBank || 'Bank'}: {t.recipientAccount}
                          </div>
                        )}
                      </td>
                      <td className="py-3 font-mono font-bold">
                        <span className={isCredit ? 'text-emerald-400' : 'text-red-400'}>
                          {isCredit ? '+' : '-'}₦{Number(t.amount || 0).toLocaleString()}
                        </span>
                      </td>
                      <td className="py-3 font-mono text-[11px] text-slate-400">
                        {t.reference}
                      </td>
                      <td className="py-3 px-4 text-right">
                        <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold uppercase ${
                          t.status === 'SUCCESSFUL'
                            ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/30'
                            : 'bg-amber-500/10 text-amber-400 border border-amber-500/30'
                        }`}>
                          {t.status}
                        </span>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
};
