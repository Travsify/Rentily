import React, { useState, useEffect } from 'react';
import {
  Banknote,
  Search,
  CheckCircle2,
  AlertCircle,
  ShieldCheck,
  RefreshCw,
  Coins,
  ArrowUpRight,
  TrendingUp,
  Flame,
  FileText,
  X
} from 'lucide-react';

interface CreditLoan {
  id: string;
  userId: string;
  userEmail: string;
  userName: string;
  userPhone: string;
  principalAmount: number;
  tenureDays: 30 | 60 | 90;
  monthlyInterestRate: number;
  totalInterestRate: number;
  interestAmount: number;
  totalRepaymentDue: number;
  amountRepaid: number;
  outstandingBalance: number;
  collateralLocked: number;
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

interface CreditSummary {
  totalDisbursed: number;
  totalRepaid: number;
  totalOutstanding: number;
  totalInterestEarned: number;
  activeLoansCount: number;
  repaidLoansCount: number;
  overdueLoansCount: number;
  totalCollateralLocked: number;
}

export const CreditManagementTab: React.FC = () => {
  const [loans, setLoans] = useState<CreditLoan[]>([]);
  const [summary, setSummary] = useState<CreditSummary | null>(null);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [selectedLoan, setSelectedLoan] = useState<CreditLoan | null>(null);
  const [actionLoading, setActionLoading] = useState(false);
  const [toastMessage, setToastMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

  const fetchOverview = async () => {
    setLoading(true);
    try {
      const res = await fetch('/api/credit/admin/overview');
      if (res.ok) {
        const data = await res.json();
        if (data.status) {
          setLoans(data.loans || []);
          setSummary(data.summary || null);
        }
      }
    } catch (err) {
      console.error('Error fetching credit overview:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchOverview();
  }, []);

  const handleAutoSettle = async () => {
    setActionLoading(true);
    try {
      const res = await fetch('/api/credit/admin/auto-settle', { method: 'POST' });
      const data = await res.json();
      if (data.status) {
        setToastMessage({ type: 'success', text: data.message });
        await fetchOverview();
      } else {
        setToastMessage({ type: 'error', text: data.error || 'Failed to trigger settlement.' });
      }
    } catch (err: any) {
      setToastMessage({ type: 'error', text: err.message });
    } finally {
      setActionLoading(false);
      setTimeout(() => setToastMessage(null), 4000);
    }
  };

  const filteredLoans = loans.filter((loan) => {
    const matchesSearch =
      loan.id.toLowerCase().includes(search.toLowerCase()) ||
      loan.userEmail.toLowerCase().includes(search.toLowerCase()) ||
      loan.userName.toLowerCase().includes(search.toLowerCase()) ||
      loan.userPhone.includes(search);

    const matchesStatus = statusFilter === 'all' || loan.status === statusFilter;
    return matchesSearch && matchesStatus;
  });

  return (
    <div className="space-y-6">
      {/* Toast Alert */}
      {toastMessage && (
        <div
          className={`p-4 rounded-xl flex items-center justify-between shadow-lg animate-fade-in ${
            toastMessage.type === 'success'
              ? 'bg-emerald-500/10 border border-emerald-500/30 text-emerald-400'
              : 'bg-rose-500/10 border border-rose-500/30 text-rose-400'
          }`}
        >
          <div className="flex items-center gap-3">
            {toastMessage.type === 'success' ? (
              <CheckCircle2 className="w-5 h-5 text-emerald-400 shrink-0" />
            ) : (
              <AlertCircle className="w-5 h-5 text-rose-400 shrink-0" />
            )}
            <span className="text-sm font-medium">{toastMessage.text}</span>
          </div>
          <button onClick={() => setToastMessage(null)} className="opacity-70 hover:opacity-100">
            <X className="w-4 h-4" />
          </button>
        </div>
      )}

      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-slate-900/60 p-6 rounded-2xl border border-slate-800">
        <div>
          <div className="flex items-center gap-3">
            <div className="p-2.5 bg-emerald-500/10 rounded-xl border border-emerald-500/20 text-emerald-400">
              <Coins className="w-6 h-6" />
            </div>
            <div>
              <h1 className="text-xl font-bold text-white flex items-center gap-2">
                Savings-Backed Credit Desk
                <span className="text-xs px-2.5 py-0.5 rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-mono">
                  80% LTV • 2.5%/MO
                </span>
              </h1>
              <p className="text-sm text-slate-400 mt-0.5">
                Collateralized micro-lending backed by locked rent savings vaults. Zero default risk with automated lien-marking.
              </p>
            </div>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={fetchOverview}
            disabled={loading}
            className="px-3.5 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-sm font-medium flex items-center gap-2 border border-slate-700 transition"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            Refresh
          </button>
          <button
            onClick={handleAutoSettle}
            disabled={actionLoading}
            className="px-4 py-2 rounded-xl bg-gradient-to-r from-amber-500 to-orange-600 hover:from-amber-600 hover:to-orange-700 text-white text-sm font-semibold flex items-center gap-2 shadow-lg shadow-amber-500/20 transition disabled:opacity-50"
          >
            <Flame className="w-4 h-4" />
            {actionLoading ? 'Auditing Overdue...' : 'Run Maturity Auto-Settle'}
          </button>
        </div>
      </div>

      {/* Summary KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-slate-900/60 p-5 rounded-2xl border border-slate-800">
          <div className="flex items-center justify-between text-slate-400 text-xs font-semibold uppercase tracking-wider">
            <span>Total Disbursed</span>
            <ArrowUpRight className="w-4 h-4 text-emerald-400" />
          </div>
          <div className="text-2xl font-black text-white mt-2">
            ₦{(summary?.totalDisbursed || 0).toLocaleString()}
          </div>
          <div className="text-xs text-slate-400 mt-1">
            {summary?.activeLoansCount || 0} active loans
          </div>
        </div>

        <div className="bg-slate-900/60 p-5 rounded-2xl border border-slate-800">
          <div className="flex items-center justify-between text-slate-400 text-xs font-semibold uppercase tracking-wider">
            <span>Total Repaid (Wallet Only)</span>
            <CheckCircle2 className="w-4 h-4 text-cyan-400" />
          </div>
          <div className="text-2xl font-black text-cyan-400 mt-2">
            ₦{(summary?.totalRepaid || 0).toLocaleString()}
          </div>
          <div className="text-xs text-slate-400 mt-1">
            {summary?.repaidLoansCount || 0} fully settled loans
          </div>
        </div>

        <div className="bg-slate-900/60 p-5 rounded-2xl border border-slate-800">
          <div className="flex items-center justify-between text-slate-400 text-xs font-semibold uppercase tracking-wider">
            <span>Active Collateral Locked</span>
            <ShieldCheck className="w-4 h-4 text-indigo-400" />
          </div>
          <div className="text-2xl font-black text-indigo-400 mt-2">
            ₦{(summary?.totalCollateralLocked || 0).toLocaleString()}
          </div>
          <div className="text-xs text-slate-400 mt-1">
            125% of active principal held
          </div>
        </div>

        <div className="bg-slate-900/60 p-5 rounded-2xl border border-slate-800">
          <div className="flex items-center justify-between text-slate-400 text-xs font-semibold uppercase tracking-wider">
            <span>Interest Yield Earned</span>
            <TrendingUp className="w-4 h-4 text-amber-400" />
          </div>
          <div className="text-2xl font-black text-amber-400 mt-2">
            ₦{(summary?.totalInterestEarned || 0).toLocaleString()}
          </div>
          <div className="text-xs text-slate-400 mt-1">
            Fixed 2.5% monthly simple rate
          </div>
        </div>
      </div>

      {/* Filter and Search Bar */}
      <div className="flex flex-col sm:flex-row gap-4 justify-between bg-slate-900/60 p-4 rounded-2xl border border-slate-800">
        <div className="relative flex-1 max-w-md">
          <Search className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
          <input
            type="text"
            placeholder="Search by User Name, Email, Phone, or Loan ID..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pl-10 pr-4 py-2 bg-slate-800/80 border border-slate-700 rounded-xl text-sm text-white placeholder-slate-400 focus:outline-none focus:border-emerald-500"
          />
        </div>

        <div className="flex items-center gap-2">
          {['all', 'active', 'repaid', 'overdue', 'liquidated'].map((status) => (
            <button
              key={status}
              onClick={() => setStatusFilter(status)}
              className={`px-3 py-1.5 rounded-xl text-xs font-semibold capitalize transition ${
                statusFilter === status
                  ? 'bg-emerald-500 text-slate-950 shadow-md shadow-emerald-500/20'
                  : 'bg-slate-800 hover:bg-slate-700 text-slate-300'
              }`}
            >
              {status}
            </button>
          ))}
        </div>
      </div>

      {/* Loans Table */}
      <div className="bg-slate-900/60 rounded-2xl border border-slate-800 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm text-slate-300">
            <thead className="bg-slate-800/80 text-xs uppercase font-semibold text-slate-400 border-b border-slate-700">
              <tr>
                <th className="px-5 py-3.5">Loan ID / Date</th>
                <th className="px-5 py-3.5">Borrower</th>
                <th className="px-5 py-3.5">Principal</th>
                <th className="px-5 py-3.5">Tenure & Rate</th>
                <th className="px-5 py-3.5">Total Due / Repaid</th>
                <th className="px-5 py-3.5">Locked Collateral</th>
                <th className="px-5 py-3.5">Status</th>
                <th className="px-5 py-3.5 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60">
              {filteredLoans.length === 0 ? (
                <tr>
                  <td colSpan={8} className="text-center py-12 text-slate-500">
                    <Banknote className="w-10 h-10 mx-auto opacity-30 mb-2" />
                    No credit loans found matching the criteria.
                  </td>
                </tr>
              ) : (
                filteredLoans.map((loan) => (
                  <tr key={loan.id} className="hover:bg-slate-800/30 transition">
                    <td className="px-5 py-4 font-mono text-xs">
                      <div className="font-bold text-white">{loan.id}</div>
                      <div className="text-slate-500">{new Date(loan.disbursedAt).toLocaleDateString()}</div>
                    </td>
                    <td className="px-5 py-4">
                      <div className="font-medium text-white">{loan.userName}</div>
                      <div className="text-xs text-slate-400">{loan.userEmail}</div>
                      <div className="text-xs text-slate-500">{loan.userPhone}</div>
                    </td>
                    <td className="px-5 py-4 font-semibold text-white">
                      ₦{loan.principalAmount.toLocaleString()}
                    </td>
                    <td className="px-5 py-4">
                      <span className="text-xs px-2 py-0.5 rounded-md bg-slate-800 border border-slate-700 font-medium text-slate-300">
                        {loan.tenureDays} Days
                      </span>
                      <div className="text-xs text-emerald-400 mt-1 font-mono">
                        {(loan.totalInterestRate * 100).toFixed(1)}% (2.5%/mo)
                      </div>
                    </td>
                    <td className="px-5 py-4">
                      <div className="font-semibold text-white">
                        ₦{loan.totalRepaymentDue.toLocaleString()}
                      </div>
                      <div className="text-xs text-slate-400 mt-0.5">
                        Repaid: ₦{loan.amountRepaid.toLocaleString()}
                      </div>
                      <div className="w-24 bg-slate-800 rounded-full h-1.5 mt-1.5 overflow-hidden">
                        <div
                          className="bg-emerald-400 h-full rounded-full"
                          style={{
                            width: `${Math.min(100, (loan.amountRepaid / loan.totalRepaymentDue) * 100)}%`,
                          }}
                        />
                      </div>
                    </td>
                    <td className="px-5 py-4 font-mono text-xs text-indigo-300">
                      ₦{loan.collateralLocked.toLocaleString()}
                    </td>
                    <td className="px-5 py-4">
                      <span
                        className={`text-xs px-2.5 py-1 rounded-full font-semibold uppercase tracking-wider border ${
                          loan.status === 'active'
                            ? 'bg-blue-500/10 border-blue-500/30 text-blue-400'
                            : loan.status === 'repaid'
                            ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-400'
                            : loan.status === 'overdue'
                            ? 'bg-rose-500/10 border-rose-500/30 text-rose-400'
                            : 'bg-amber-500/10 border-amber-500/30 text-amber-400'
                        }`}
                      >
                        {loan.status}
                      </span>
                    </td>
                    <td className="px-5 py-4 text-right">
                      <button
                        onClick={() => setSelectedLoan(loan)}
                        className="px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-xs font-semibold text-slate-300 border border-slate-700 transition"
                      >
                        Audit Details
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Loan Audit Modal */}
      {selectedLoan && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm animate-fade-in">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-lg w-full p-6 space-y-5 shadow-2xl">
            <div className="flex items-center justify-between border-b border-slate-800 pb-4">
              <div className="flex items-center gap-3">
                <div className="p-2 bg-emerald-500/10 rounded-xl text-emerald-400">
                  <FileText className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="font-bold text-white text-base">Loan Audit: {selectedLoan.id}</h3>
                  <p className="text-xs text-slate-400">Borrower: {selectedLoan.userName} ({selectedLoan.userEmail})</p>
                </div>
              </div>
              <button
                onClick={() => setSelectedLoan(null)}
                className="text-slate-400 hover:text-white p-1 rounded-lg hover:bg-slate-800"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="grid grid-cols-2 gap-3 text-xs">
              <div className="p-3 bg-slate-800/60 rounded-xl border border-slate-700/60">
                <span className="text-slate-400">Principal Disbursed</span>
                <p className="text-sm font-bold text-white mt-0.5">₦{selectedLoan.principalAmount.toLocaleString()}</p>
              </div>
              <div className="p-3 bg-slate-800/60 rounded-xl border border-slate-700/60">
                <span className="text-slate-400">Total Due (Principal + Interest)</span>
                <p className="text-sm font-bold text-white mt-0.5">₦{selectedLoan.totalRepaymentDue.toLocaleString()}</p>
              </div>
              <div className="p-3 bg-slate-800/60 rounded-xl border border-slate-700/60">
                <span className="text-slate-400">Locked Savings Collateral</span>
                <p className="text-sm font-bold text-indigo-400 mt-0.5">₦{selectedLoan.collateralLocked.toLocaleString()}</p>
              </div>
              <div className="p-3 bg-slate-800/60 rounded-xl border border-slate-700/60">
                <span className="text-slate-400">Due Date</span>
                <p className="text-sm font-bold text-slate-200 mt-0.5">{new Date(selectedLoan.dueDate).toLocaleDateString()}</p>
              </div>
            </div>

            {/* Repayment History */}
            <div>
              <h4 className="text-xs font-bold uppercase text-slate-400 mb-2">Repayment Logs (Wallet Rails)</h4>
              {selectedLoan.repaymentHistory.length === 0 ? (
                <p className="text-xs text-slate-500 italic p-3 bg-slate-800/30 rounded-xl">No repayments made yet.</p>
              ) : (
                <div className="space-y-2 max-h-40 overflow-y-auto pr-1">
                  {selectedLoan.repaymentHistory.map((rep) => (
                    <div
                      key={rep.id}
                      className="p-2.5 bg-slate-800/50 rounded-xl border border-slate-700/50 flex items-center justify-between text-xs"
                    >
                      <div>
                        <div className="font-semibold text-emerald-400">₦{rep.amount.toLocaleString()}</div>
                        <div className="text-[10px] text-slate-400">{new Date(rep.timestamp).toLocaleString()} • {rep.reference}</div>
                      </div>
                      <span className="text-[10px] px-2 py-0.5 rounded bg-emerald-500/10 text-emerald-400 font-mono">
                        Wallet Deduct
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>

            <button
              onClick={() => setSelectedLoan(null)}
              className="w-full py-2.5 bg-slate-800 hover:bg-slate-700 text-white font-semibold text-xs rounded-xl transition"
            >
              Close Audit
            </button>
          </div>
        </div>
      )}
    </div>
  );
};
