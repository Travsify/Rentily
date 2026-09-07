import React, { useState, useEffect, useMemo } from 'react';
import {
  Landmark,
  RefreshCw,
  Search,
  Copy,
  Check,
  Building2,
  ShieldCheck,
  Send,
  PlusCircle,
  DollarSign,
  AlertCircle
} from 'lucide-react';

interface FincraWallet {
  id: string | number;
  currency: string;
  ledgerBalance: number;
  availableBalance: number;
  lockedBalance: number;
  rollingReserveBalance: number;
  walletNumber: string | number;
  status: string;
  updatedAt?: string;
}

interface FincraAccount {
  id: string;
  accountNumber: string;
  accountName: string;
  bankName: string;
  bankCode: string;
  currency: string;
  status: string;
  isActive: boolean;
  accountType: string;
  isPermanent: boolean;
  assignedUserEmail?: string | null;
  assignedUserName?: string | null;
  createdAt: string;
}

interface FincraPayout {
  id: string | number;
  amount: number;
  currency: string;
  fee: number;
  beneficiaryName: string;
  accountNumber: string;
  bankName: string;
  status: string;
  reference: string;
  customerReference?: string;
  createdAt: string;
}

interface FincraSummary {
  ngnAvailable: number;
  ngnLedger: number;
  usdAvailable: number;
  eurAvailable: number;
  gbpAvailable: number;
  totalVirtualAccounts: number;
  totalPayoutsCount: number;
  isKYCApproved: boolean;
  businessName: string;
  businessTag: number | string;
  webhookCallbackURL: string;
  isWebhookEnabled: boolean;
}

export function FincraTab() {
  const [activeSubTab, setActiveSubTab] = useState<'wallets' | 'accounts' | 'payouts'>('wallets');
  const [summary, setSummary] = useState<FincraSummary | null>(null);
  const [wallets, setWallets] = useState<FincraWallet[]>([]);
  const [accounts, setAccounts] = useState<FincraAccount[]>([]);
  const [payouts, setPayouts] = useState<FincraPayout[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [copiedText, setCopiedText] = useState<string | null>(null);

  // New Account Modal State
  const [isAccountModalOpen, setIsAccountModalOpen] = useState(false);
  const [newAccEmail, setNewAccEmail] = useState('');
  const [newAccFirstName, setNewAccFirstName] = useState('');
  const [newAccLastName, setNewAccLastName] = useState('');
  const [newAccBvn, setNewAccBvn] = useState('');
  const [newAccType, setNewAccType] = useState<'individual' | 'corporate'>('individual');
  const [isCreatingAcc, setIsCreatingAcc] = useState(false);
  const [accActionStatus, setAccActionStatus] = useState<{ success?: boolean; message?: string } | null>(null);

  // Disbursement Modal State
  const [isPayoutModalOpen, setIsPayoutModalOpen] = useState(false);
  const [payoutAmount, setPayoutAmount] = useState('');
  const [payoutAccNumber, setPayoutAccNumber] = useState('');
  const [payoutBankCode, setPayoutBankCode] = useState('035');
  const [payoutName, setPayoutName] = useState('');
  const [payoutDesc, setPayoutDesc] = useState('Rentilly Admin Payout');
  const [isSubmittingPayout, setIsSubmittingPayout] = useState(false);
  const [payoutActionStatus, setPayoutActionStatus] = useState<{ success?: boolean; message?: string } | null>(null);

  const fetchData = async () => {
    setIsLoading(true);
    setErrorMsg(null);
    try {
      const res = await fetch('/api/admin/fincra/overview');
      const data = await res.json();
      if (data.success) {
        setSummary(data.summary);
        setWallets(data.wallets || []);
        setAccounts(data.virtualAccounts || []);
        setPayouts(data.payouts || []);
      } else {
        setErrorMsg(data.error || 'Failed to fetch Fincra data');
      }
    } catch (err: any) {
      setErrorMsg(err.message || 'Error connecting to Fincra backend');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  const handleCopy = (text: string) => {
    navigator.clipboard.writeText(text);
    setCopiedText(text);
    setTimeout(() => setCopiedText(null), 2000);
  };

  const handleCreateAccount = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newAccEmail || !newAccBvn) return;
    setIsCreatingAcc(true);
    setAccActionStatus(null);
    try {
      const res = await fetch('/api/admin/fincra/virtual-accounts/create', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: newAccEmail,
          firstName: newAccFirstName,
          lastName: newAccLastName,
          bvn: newAccBvn,
          accountType: newAccType,
          channel: 'wema'
        })
      });
      const d = await res.json();
      if (d.status || d.success) {
        setAccActionStatus({ success: true, message: 'Virtual account created successfully!' });
        setTimeout(() => {
          setIsAccountModalOpen(false);
          setAccActionStatus(null);
          fetchData();
        }, 1500);
      } else {
        setAccActionStatus({ success: false, message: d.message || d.error || 'Failed to create account' });
      }
    } catch (err: any) {
      setAccActionStatus({ success: false, message: err.message });
    } finally {
      setIsCreatingAcc(false);
    }
  };

  const handleDisbursePayout = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!payoutAmount || !payoutAccNumber || !payoutBankCode) return;
    setIsSubmittingPayout(true);
    setPayoutActionStatus(null);
    try {
      const res = await fetch('/api/admin/fincra/payouts/disburse', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          amount: Number(payoutAmount),
          accountNumber: payoutAccNumber,
          bankCode: payoutBankCode,
          accountHolderName: payoutName,
          description: payoutDesc
        })
      });
      const d = await res.json();
      if (d.status || d.success) {
        setPayoutActionStatus({ success: true, message: 'Disbursement submitted successfully!' });
        setTimeout(() => {
          setIsPayoutModalOpen(false);
          setPayoutActionStatus(null);
          fetchData();
        }, 1500);
      } else {
        setPayoutActionStatus({ success: false, message: d.message || d.error || 'Payout rejected' });
      }
    } catch (err: any) {
      setPayoutActionStatus({ success: false, message: err.message });
    } finally {
      setIsSubmittingPayout(false);
    }
  };

  const filteredAccounts = useMemo(() => {
    if (!searchQuery) return accounts;
    const q = searchQuery.toLowerCase();
    return accounts.filter(
      a =>
        a.accountNumber.includes(q) ||
        a.accountName.toLowerCase().includes(q) ||
        a.bankName.toLowerCase().includes(q) ||
        (a.assignedUserEmail && a.assignedUserEmail.toLowerCase().includes(q))
    );
  }, [accounts, searchQuery]);

  const filteredPayouts = useMemo(() => {
    if (!searchQuery) return payouts;
    const q = searchQuery.toLowerCase();
    return payouts.filter(
      p =>
        p.beneficiaryName.toLowerCase().includes(q) ||
        p.accountNumber.includes(q) ||
        (p.reference && p.reference.toLowerCase().includes(q))
    );
  }, [payouts, searchQuery]);

  return (
    <div className="space-y-6 animate-fadeIn pb-12">
      {/* ── Top Header Bar ────────────────────────────────────────────── */}
      <div className="bg-slate-900/60 border border-slate-800 backdrop-blur-xl p-6 rounded-2xl flex flex-col md:flex-row items-start md:items-center justify-between gap-4 shadow-xl shadow-black/20">
        <div>
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-blue-500/10 border border-blue-500/30 flex items-center justify-center text-blue-400 font-bold shadow-inner">
              <Landmark className="w-5 h-5" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h1 className="text-xl font-bold text-white tracking-tight">Fincra Master Ledger & Treasury</h1>
                <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/30 flex items-center gap-1">
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
                  Live IP Whitelisted
                </span>
                <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-blue-500/10 text-blue-400 border border-blue-500/30">
                  Wema Bank (035) Rail
                </span>
              </div>
              <p className="text-xs text-slate-400 mt-1">
                Institutional commercial bank accounts, zero ₦50k PSB limits, real-time master ledger balances, and instant NIP disbursements.
              </p>
            </div>
          </div>
        </div>

        <div className="flex items-center gap-3 w-full md:w-auto">
          <button
            onClick={() => setIsAccountModalOpen(true)}
            className="flex-1 md:flex-none px-4 py-2.5 rounded-xl bg-blue-600 hover:bg-blue-500 text-white font-medium text-xs flex items-center justify-center gap-2 transition-all shadow-lg shadow-blue-600/20 active:scale-95"
          >
            <PlusCircle className="w-4 h-4" />
            Generate Virtual Account
          </button>
          <button
            onClick={() => setIsPayoutModalOpen(true)}
            className="flex-1 md:flex-none px-4 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 border border-slate-700 text-slate-200 font-medium text-xs flex items-center justify-center gap-2 transition-all active:scale-95"
          >
            <Send className="w-4 h-4 text-emerald-400" />
            Instant Payout
          </button>
          <button
            onClick={fetchData}
            disabled={isLoading}
            className="p-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 border border-slate-700 text-slate-300 hover:text-white transition-all disabled:opacity-50"
            title="Refresh Fincra Ledger"
          >
            <RefreshCw className={`w-4 h-4 ${isLoading ? 'animate-spin' : ''}`} />
          </button>
        </div>
      </div>

      {/* ── Business & Webhook Status Strip ───────────────────────────── */}
      {summary && (
        <div className="bg-slate-900/40 border border-slate-800/80 rounded-xl px-5 py-3 flex flex-wrap items-center justify-between gap-4 text-xs text-slate-300">
          <div className="flex items-center gap-2">
            <Building2 className="w-4 h-4 text-blue-400" />
            <span className="font-semibold text-white">{summary.businessName}</span>
            <span className="text-slate-500">•</span>
            <span>Tag: <strong className="text-slate-200">#{summary.businessTag}</strong></span>
            <span className="text-slate-500">•</span>
            <span className="text-emerald-400 flex items-center gap-1 font-medium">
              <ShieldCheck className="w-3.5 h-3.5" /> KYC Approved
            </span>
          </div>

          <div className="flex items-center gap-3">
            <span className="text-slate-400">Webhook Rail:</span>
            <code className="px-2 py-1 rounded bg-slate-950 border border-slate-800 text-[11px] text-blue-300 font-mono">
              {summary.webhookCallbackURL}
            </code>
            <span className="px-2 py-0.5 rounded text-[10px] font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
              Active (200)
            </span>
          </div>
        </div>
      )}

      {/* ── Summary Cards Row ─────────────────────────────────────────── */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Card 1: NGN Treasury */}
        <div className="bg-gradient-to-br from-slate-900/90 to-slate-950 border border-slate-800 p-5 rounded-2xl shadow-lg relative overflow-hidden">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 tracking-wide uppercase">NGN Master Available</span>
            <div className="w-8 h-8 rounded-lg bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center text-emerald-400">
              ₦
            </div>
          </div>
          <div className="mt-3">
            <h3 className="text-2xl font-black text-white tracking-tight">
              ₦{(summary?.ngnAvailable || 0).toLocaleString('en-NG', { minimumFractionDigits: 2 })}
            </h3>
            <p className="text-xs text-slate-400 mt-1 flex items-center gap-1.5">
              <span>Ledger: ₦{(summary?.ngnLedger || 0).toLocaleString('en-NG', { minimumFractionDigits: 2 })}</span>
              <span className="text-emerald-400 font-medium">• Instant Settlement</span>
            </p>
          </div>
        </div>

        {/* Card 2: USD & FX Wallets */}
        <div className="bg-gradient-to-br from-slate-900/90 to-slate-950 border border-slate-800 p-5 rounded-2xl shadow-lg relative overflow-hidden">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 tracking-wide uppercase">USD Multi-Currency</span>
            <div className="w-8 h-8 rounded-lg bg-blue-500/10 border border-blue-500/30 flex items-center justify-center text-blue-400">
              <DollarSign className="w-4 h-4" />
            </div>
          </div>
          <div className="mt-3">
            <h3 className="text-2xl font-black text-white tracking-tight">
              ${(summary?.usdAvailable || 0).toFixed(2)}
            </h3>
            <p className="text-xs text-slate-400 mt-1 flex items-center gap-2">
              <span>EUR: €{(summary?.eurAvailable || 0).toFixed(2)}</span>
              <span>•</span>
              <span>GBP: £{(summary?.gbpAvailable || 0).toFixed(2)}</span>
            </p>
          </div>
        </div>

        {/* Card 3: Virtual Accounts Count */}
        <div className="bg-gradient-to-br from-slate-900/90 to-slate-950 border border-slate-800 p-5 rounded-2xl shadow-lg relative overflow-hidden">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 tracking-wide uppercase">Active Wema Accounts</span>
            <div className="w-8 h-8 rounded-lg bg-purple-500/10 border border-purple-500/30 flex items-center justify-center text-purple-400">
              <Building2 className="w-4 h-4" />
            </div>
          </div>
          <div className="mt-3">
            <h3 className="text-2xl font-black text-white tracking-tight">
              {summary?.totalVirtualAccounts || accounts.length || 0}
            </h3>
            <p className="text-xs text-purple-400 mt-1 font-medium">
              Zero ₦50k Caps • Commercial Rail
            </p>
          </div>
        </div>

        {/* Card 4: Total Payouts */}
        <div className="bg-gradient-to-br from-slate-900/90 to-slate-950 border border-slate-800 p-5 rounded-2xl shadow-lg relative overflow-hidden">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 tracking-wide uppercase">Disbursements Audit</span>
            <div className="w-8 h-8 rounded-lg bg-amber-500/10 border border-amber-500/30 flex items-center justify-center text-amber-400">
              <Send className="w-4 h-4" />
            </div>
          </div>
          <div className="mt-3">
            <h3 className="text-2xl font-black text-white tracking-tight">
              {summary?.totalPayoutsCount || payouts.length || 0}
            </h3>
            <p className="text-xs text-slate-400 mt-1">
              Automated 24/7 NIP transfers
            </p>
          </div>
        </div>
      </div>

      {/* ── Sub Tabs Bar ──────────────────────────────────────────────── */}
      <div className="flex items-center justify-between border-b border-slate-800 pb-2">
        <div className="flex items-center gap-2">
          <button
            onClick={() => setActiveSubTab('wallets')}
            className={`px-4 py-2 rounded-xl text-xs font-semibold transition-all ${
              activeSubTab === 'wallets'
                ? 'bg-blue-600 text-white shadow-lg shadow-blue-600/20'
                : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/50'
            }`}
          >
            Multi-Currency Wallets ({wallets.length})
          </button>
          <button
            onClick={() => setActiveSubTab('accounts')}
            className={`px-4 py-2 rounded-xl text-xs font-semibold transition-all ${
              activeSubTab === 'accounts'
                ? 'bg-blue-600 text-white shadow-lg shadow-blue-600/20'
                : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/50'
            }`}
          >
            Virtual Accounts ({accounts.length})
          </button>
          <button
            onClick={() => setActiveSubTab('payouts')}
            className={`px-4 py-2 rounded-xl text-xs font-semibold transition-all ${
              activeSubTab === 'payouts'
                ? 'bg-blue-600 text-white shadow-lg shadow-blue-600/20'
                : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/50'
            }`}
          >
            Outbound Payouts ({payouts.length})
          </button>
        </div>

        {activeSubTab !== 'wallets' && (
          <div className="relative w-64">
            <Search className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
              placeholder="Search account, name, ref..."
              className="w-full bg-slate-900 border border-slate-800 pl-8 pr-3 py-1.5 rounded-lg text-xs text-white placeholder-slate-500 focus:outline-none focus:border-blue-500"
            />
          </div>
        )}
      </div>

      {/* ── Error Banner ──────────────────────────────────────────────── */}
      {errorMsg && (
        <div className="bg-red-500/10 border border-red-500/30 text-red-400 px-4 py-3 rounded-xl text-xs flex items-center gap-2">
          <AlertCircle className="w-4 h-4 flex-shrink-0" />
          <span>{errorMsg}</span>
        </div>
      )}

      {/* ── TAB 1: Wallets Table ──────────────────────────────────────── */}
      {activeSubTab === 'wallets' && (
        <div className="bg-slate-900/60 border border-slate-800 rounded-2xl overflow-hidden shadow-xl">
          <div className="px-6 py-4 border-b border-slate-800/80 flex items-center justify-between">
            <h3 className="text-sm font-semibold text-white">Master Ledger Currency Pools</h3>
            <span className="text-xs text-slate-400">15 Currencies Provisioned & Enabled</span>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="bg-slate-950/50 text-slate-400 border-b border-slate-800 font-semibold uppercase tracking-wider text-[10px]">
                <tr>
                  <th className="py-3 px-6">Currency</th>
                  <th className="py-3 px-6">Wallet Number</th>
                  <th className="py-3 px-6 text-right">Available Balance</th>
                  <th className="py-3 px-6 text-right">Ledger Balance</th>
                  <th className="py-3 px-6 text-right">Locked / Reserve</th>
                  <th className="py-3 px-6 text-center">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/50 text-slate-300 font-mono">
                {wallets.map(w => (
                  <tr key={w.id} className="hover:bg-slate-800/30 transition-colors">
                    <td className="py-3.5 px-6 font-sans">
                      <div className="flex items-center gap-2.5">
                        <span className={`w-7 h-7 rounded-lg flex items-center justify-center font-bold text-[11px] ${
                          w.currency === 'NGN' ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/30' :
                          w.currency === 'USD' ? 'bg-blue-500/10 text-blue-400 border border-blue-500/30' :
                          'bg-slate-800 text-slate-300 border border-slate-700'
                        }`}>
                          {w.currency}
                        </span>
                        <div>
                          <p className="font-semibold text-white text-xs">{w.currency}</p>
                          <p className="text-[10px] text-slate-500 font-sans">
                            {w.currency === 'NGN' ? 'Nigerian Naira (Primary Rail)' :
                             w.currency === 'USD' ? 'US Dollar' :
                             w.currency === 'EUR' ? 'Euro' :
                             w.currency === 'GBP' ? 'British Pound' :
                             w.currency === 'CAD' ? 'Canadian Dollar' : `${w.currency} Settlement Pool`}
                          </p>
                        </div>
                      </div>
                    </td>
                    <td className="py-3.5 px-6 text-slate-400 text-xs">{w.walletNumber}</td>
                    <td className="py-3.5 px-6 text-right text-white font-bold text-xs">
                      {w.currency === 'NGN' ? '₦' : w.currency === 'USD' ? '$' : w.currency === 'EUR' ? '€' : w.currency === 'GBP' ? '£' : ''}
                      {w.availableBalance.toLocaleString(undefined, { minimumFractionDigits: 2 })}
                    </td>
                    <td className="py-3.5 px-6 text-right text-slate-400 text-xs">
                      {w.currency === 'NGN' ? '₦' : w.currency === 'USD' ? '$' : ''}
                      {w.ledgerBalance.toLocaleString(undefined, { minimumFractionDigits: 2 })}
                    </td>
                    <td className="py-3.5 px-6 text-right text-slate-500 text-xs">
                      {w.lockedBalance.toFixed(2)}
                    </td>
                    <td className="py-3.5 px-6 text-center font-sans">
                      <span className="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                        {w.status}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ── TAB 2: Virtual Accounts Table ─────────────────────────────── */}
      {activeSubTab === 'accounts' && (
        <div className="bg-slate-900/60 border border-slate-800 rounded-2xl overflow-hidden shadow-xl">
          <div className="px-6 py-4 border-b border-slate-800/80 flex items-center justify-between">
            <div>
              <h3 className="text-sm font-semibold text-white">Commercial Virtual Bank Accounts</h3>
              <p className="text-xs text-slate-400 mt-0.5">Accounts backed by Wema Bank (035), Globus Bank, and Sterling Bank with institutional limits.</p>
            </div>
            <span className="text-xs text-slate-400 font-medium">Total: {filteredAccounts.length}</span>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="bg-slate-950/50 text-slate-400 border-b border-slate-800 font-semibold uppercase tracking-wider text-[10px]">
                <tr>
                  <th className="py-3 px-6">Account Number</th>
                  <th className="py-3 px-6">Account Name</th>
                  <th className="py-3 px-6">Bank Rail</th>
                  <th className="py-3 px-6">Account Type</th>
                  <th className="py-3 px-6">Assigned Rentilly User</th>
                  <th className="py-3 px-6 text-center">Status</th>
                  <th className="py-3 px-6 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/50 text-slate-300">
                {filteredAccounts.map(a => (
                  <tr key={a.id} className="hover:bg-slate-800/30 transition-colors">
                    <td className="py-3.5 px-6 font-mono font-bold text-white text-xs">
                      <div className="flex items-center gap-2">
                        <span>{a.accountNumber}</span>
                        <button
                          onClick={() => handleCopy(a.accountNumber)}
                          className="text-slate-500 hover:text-slate-300 transition-colors"
                          title="Copy Account Number"
                        >
                          {copiedText === a.accountNumber ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
                        </button>
                      </div>
                    </td>
                    <td className="py-3.5 px-6 font-medium text-slate-200">
                      {a.accountName}
                    </td>
                    <td className="py-3.5 px-6">
                      <span className="px-2 py-0.5 rounded text-[11px] font-semibold bg-blue-500/10 text-blue-400 border border-blue-500/20">
                        {a.bankName.toUpperCase()} ({a.bankCode})
                      </span>
                    </td>
                    <td className="py-3.5 px-6 capitalize text-slate-400">
                      {a.accountType}
                    </td>
                    <td className="py-3.5 px-6">
                      {a.assignedUserEmail ? (
                        <div>
                          <p className="font-semibold text-white">{a.assignedUserName || 'User'}</p>
                          <p className="text-[11px] text-slate-400 font-mono">{a.assignedUserEmail}</p>
                        </div>
                      ) : (
                        <span className="text-slate-500 italic">Available Pool</span>
                      )}
                    </td>
                    <td className="py-3.5 px-6 text-center">
                      <span className="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                        {a.status}
                      </span>
                    </td>
                    <td className="py-3.5 px-6 text-right font-mono text-[11px] text-slate-400">
                      {new Date(a.createdAt).toLocaleDateString()}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ── TAB 3: Outbound Payouts Table ─────────────────────────────── */}
      {activeSubTab === 'payouts' && (
        <div className="bg-slate-900/60 border border-slate-800 rounded-2xl overflow-hidden shadow-xl">
          <div className="px-6 py-4 border-b border-slate-800/80 flex items-center justify-between">
            <div>
              <h3 className="text-sm font-semibold text-white">Outbound Disbursements Audit Trail</h3>
              <p className="text-xs text-slate-400 mt-0.5">Real-time record of all transfers disbursed through Fincra's instant NIP payout rail.</p>
            </div>
            <span className="text-xs text-slate-400 font-medium">Total: {filteredPayouts.length}</span>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="bg-slate-950/50 text-slate-400 border-b border-slate-800 font-semibold uppercase tracking-wider text-[10px]">
                <tr>
                  <th className="py-3 px-6">Reference</th>
                  <th className="py-3 px-6">Beneficiary</th>
                  <th className="py-3 px-6">Account & Bank</th>
                  <th className="py-3 px-6 text-right">Amount</th>
                  <th className="py-3 px-6 text-right">Fee</th>
                  <th className="py-3 px-6 text-center">Status</th>
                  <th className="py-3 px-6 text-right">Date</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/50 text-slate-300 font-mono">
                {filteredPayouts.map(p => (
                  <tr key={p.id} className="hover:bg-slate-800/30 transition-colors">
                    <td className="py-3.5 px-6 text-xs text-white">
                      <div className="flex items-center gap-1.5">
                        <span>{p.reference}</span>
                        <button
                          onClick={() => handleCopy(p.reference)}
                          className="text-slate-500 hover:text-slate-300"
                        >
                          {copiedText === p.reference ? <Check className="w-3 h-3 text-emerald-400" /> : <Copy className="w-3 h-3" />}
                        </button>
                      </div>
                    </td>
                    <td className="py-3.5 px-6 font-sans font-medium text-slate-200">
                      {p.beneficiaryName}
                    </td>
                    <td className="py-3.5 px-6 font-sans">
                      <p className="text-white font-mono text-xs">{p.accountNumber}</p>
                      <p className="text-[10px] text-slate-400">{p.bankName}</p>
                    </td>
                    <td className="py-3.5 px-6 text-right font-bold text-white text-xs">
                      ₦{p.amount.toLocaleString(undefined, { minimumFractionDigits: 2 })}
                    </td>
                    <td className="py-3.5 px-6 text-right text-slate-400 text-xs">
                      ₦{p.fee.toFixed(2)}
                    </td>
                    <td className="py-3.5 px-6 text-center font-sans">
                      <span className={`px-2 py-0.5 rounded-full text-[10px] font-semibold ${
                        p.status === 'successful' ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' :
                        p.status === 'failed' ? 'bg-red-500/10 text-red-400 border border-red-500/20' :
                        'bg-amber-500/10 text-amber-400 border border-amber-500/20'
                      }`}>
                        {p.status}
                      </span>
                    </td>
                    <td className="py-3.5 px-6 text-right text-slate-400 text-[11px]">
                      {new Date(p.createdAt).toLocaleString()}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ── Modal: Create Virtual Account ─────────────────────────────── */}
      {isAccountModalOpen && (
        <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 w-full max-w-md rounded-2xl p-6 shadow-2xl animate-scaleIn">
            <h3 className="text-lg font-bold text-white">Generate Fincra Virtual Account</h3>
            <p className="text-xs text-slate-400 mt-1">
              Issues a dedicated commercial account backed by Wema Bank (035) with zero ₦50k PSB limits.
            </p>

            <form onSubmit={handleCreateAccount} className="space-y-4 mt-5">
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">Account Type</label>
                <div className="grid grid-cols-2 gap-2">
                  <button
                    type="button"
                    onClick={() => setNewAccType('individual')}
                    className={`py-2 text-xs font-semibold rounded-lg border transition-all ${
                      newAccType === 'individual'
                        ? 'bg-blue-600/20 border-blue-500 text-blue-300'
                        : 'border-slate-800 text-slate-400 hover:bg-slate-800'
                    }`}
                  >
                    Individual KYC
                  </button>
                  <button
                    type="button"
                    onClick={() => setNewAccType('corporate')}
                    className={`py-2 text-xs font-semibold rounded-lg border transition-all ${
                      newAccType === 'corporate'
                        ? 'bg-blue-600/20 border-blue-500 text-blue-300'
                        : 'border-slate-800 text-slate-400 hover:bg-slate-800'
                    }`}
                  >
                    Corporate (Ehomes)
                  </button>
                </div>
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">User Email *</label>
                <input
                  type="email"
                  required
                  value={newAccEmail}
                  onChange={e => setNewAccEmail(e.target.value)}
                  placeholder="user@example.com"
                  className="w-full bg-slate-950 border border-slate-800 px-3.5 py-2.5 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:border-blue-500"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-1">First Name</label>
                  <input
                    type="text"
                    value={newAccFirstName}
                    onChange={e => setNewAccFirstName(e.target.value)}
                    placeholder="Patrick"
                    className="w-full bg-slate-950 border border-slate-800 px-3.5 py-2.5 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:border-blue-500"
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-1">Last Name</label>
                  <input
                    type="text"
                    value={newAccLastName}
                    onChange={e => setNewAccLastName(e.target.value)}
                    placeholder="Achua"
                    className="w-full bg-slate-950 border border-slate-800 px-3.5 py-2.5 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:border-blue-500"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">BVN (11 Digits) *</label>
                <input
                  type="text"
                  required
                  maxLength={11}
                  value={newAccBvn}
                  onChange={e => setNewAccBvn(e.target.value)}
                  placeholder="22222222222"
                  className="w-full bg-slate-950 border border-slate-800 px-3.5 py-2.5 rounded-xl text-xs text-white placeholder-slate-500 font-mono focus:outline-none focus:border-blue-500"
                />
              </div>

              {accActionStatus && (
                <div className={`p-3 rounded-xl text-xs ${accActionStatus.success ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' : 'bg-red-500/10 text-red-400 border border-red-500/20'}`}>
                  {accActionStatus.message}
                </div>
              )}

              <div className="flex items-center justify-end gap-3 pt-3">
                <button
                  type="button"
                  onClick={() => setIsAccountModalOpen(false)}
                  className="px-4 py-2.5 rounded-xl text-xs text-slate-400 hover:text-white"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isCreatingAcc}
                  className="px-5 py-2.5 rounded-xl bg-blue-600 hover:bg-blue-500 text-white font-medium text-xs flex items-center gap-2 transition-all disabled:opacity-50"
                >
                  {isCreatingAcc && <RefreshCw className="w-3.5 h-3.5 animate-spin" />}
                  {isCreatingAcc ? 'Provisioning...' : 'Create Account'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ── Modal: Instant Payout ─────────────────────────────────────── */}
      {isPayoutModalOpen && (
        <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 w-full max-w-md rounded-2xl p-6 shadow-2xl animate-scaleIn">
            <h3 className="text-lg font-bold text-white">Disburse Instant Payout via Fincra</h3>
            <p className="text-xs text-slate-400 mt-1">
              Direct NIP interbank transfer processed immediately from Fincra Master NGN ledger.
            </p>

            <form onSubmit={handleDisbursePayout} className="space-y-4 mt-5">
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">Amount (NGN) *</label>
                <input
                  type="number"
                  required
                  min={100}
                  value={payoutAmount}
                  onChange={e => setPayoutAmount(e.target.value)}
                  placeholder="5000"
                  className="w-full bg-slate-950 border border-slate-800 px-3.5 py-2.5 rounded-xl text-xs text-white placeholder-slate-500 font-mono focus:outline-none focus:border-blue-500"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-1">Account Number *</label>
                  <input
                    type="text"
                    required
                    maxLength={10}
                    value={payoutAccNumber}
                    onChange={e => setPayoutAccNumber(e.target.value)}
                    placeholder="0123456789"
                    className="w-full bg-slate-950 border border-slate-800 px-3.5 py-2.5 rounded-xl text-xs text-white font-mono placeholder-slate-500 focus:outline-none focus:border-blue-500"
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-1">Bank Code *</label>
                  <input
                    type="text"
                    required
                    value={payoutBankCode}
                    onChange={e => setPayoutBankCode(e.target.value)}
                    placeholder="035 (Wema)"
                    className="w-full bg-slate-950 border border-slate-800 px-3.5 py-2.5 rounded-xl text-xs text-white font-mono placeholder-slate-500 focus:outline-none focus:border-blue-500"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">Recipient Account Name</label>
                <input
                  type="text"
                  value={payoutName}
                  onChange={e => setPayoutName(e.target.value)}
                  placeholder="Recipient Name"
                  className="w-full bg-slate-950 border border-slate-800 px-3.5 py-2.5 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:border-blue-500"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">Narration / Description</label>
                <input
                  type="text"
                  value={payoutDesc}
                  onChange={e => setPayoutDesc(e.target.value)}
                  placeholder="Rentilly Escrow Disbursement"
                  className="w-full bg-slate-950 border border-slate-800 px-3.5 py-2.5 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:border-blue-500"
                />
              </div>

              {payoutActionStatus && (
                <div className={`p-3 rounded-xl text-xs ${payoutActionStatus.success ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' : 'bg-red-500/10 text-red-400 border border-red-500/20'}`}>
                  {payoutActionStatus.message}
                </div>
              )}

              <div className="flex items-center justify-end gap-3 pt-3">
                <button
                  type="button"
                  onClick={() => setIsPayoutModalOpen(false)}
                  className="px-4 py-2.5 rounded-xl text-xs text-slate-400 hover:text-white"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmittingPayout}
                  className="px-5 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-medium text-xs flex items-center gap-2 transition-all disabled:opacity-50"
                >
                  {isSubmittingPayout && <RefreshCw className="w-3.5 h-3.5 animate-spin" />}
                  {isSubmittingPayout ? 'Processing...' : 'Send Payout'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
