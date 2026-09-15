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
  AlertCircle,
  ArrowRightLeft,
  ArrowDownLeft,
  ArrowUpRight,
  Users,
  Download,
  CheckCircle2,
  XCircle,
  Clock,
  Sparkles,
  ChevronRight,
  RotateCcw
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
  failedReason?: string | null;
  reference: string;
  customerReference?: string;
  isRefunded?: boolean;
  createdAt: string;
}

interface FincraCollection {
  id: string | number;
  reference: string;
  merchantReference?: string;
  amount: number;
  currency: string;
  fee: number;
  emtl: number;
  vat: number;
  payeeName: string;
  paymentMethod: string;
  status: string;
  virtualAccountId?: string;
  accountNumber: string;
  assignedUserEmail?: string | null;
  assignedUserName?: string | null;
  createdAt: string;
}

interface FincraBeneficiary {
  _id?: string;
  id?: string;
  accountHolderName?: string;
  accountNumber?: string;
  bankCode?: string;
  email?: string;
  currency?: string;
  destinationCurrency?: string;
}

interface FincraSummary {
  ngnAvailable: number;
  ngnLedger: number;
  usdAvailable: number;
  eurAvailable: number;
  gbpAvailable: number;
  totalVirtualAccounts: number;
  totalPayoutsCount: number;
  totalCollectionsCount?: number;
  isKYCApproved: boolean;
  businessName: string;
  businessTag: number | string;
  webhookCallbackURL: string;
  isWebhookEnabled: boolean;
}

interface BankItem {
  code: string;
  name: string;
  nibssCode?: string;
}

export function FincraTab() {
  const [activeSubTab, setActiveSubTab] = useState<'wallets' | 'collections' | 'payouts' | 'accounts' | 'conversions' | 'beneficiaries'>('wallets');
  const [summary, setSummary] = useState<FincraSummary | null>(null);
  const [wallets, setWallets] = useState<FincraWallet[]>([]);
  const [accounts, setAccounts] = useState<FincraAccount[]>([]);
  const [payouts, setPayouts] = useState<FincraPayout[]>([]);
  const [collections, setCollections] = useState<FincraCollection[]>([]);
  const [beneficiaries, setBeneficiaries] = useState<FincraBeneficiary[]>([]);
  const [banks, setBanks] = useState<BankItem[]>([]);

  const [isLoading, setIsLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('all');
  const [copiedText, setCopiedText] = useState<string | null>(null);

  // New Account Modal
  const [isAccountModalOpen, setIsAccountModalOpen] = useState(false);
  const [newAccEmail, setNewAccEmail] = useState('');
  const [newAccFirstName, setNewAccFirstName] = useState('');
  const [newAccLastName, setNewAccLastName] = useState('');
  const [newAccBvn, setNewAccBvn] = useState('');
  const [newAccType, setNewAccType] = useState<'individual' | 'corporate'>('individual');
  const [isCreatingAcc, setIsCreatingAcc] = useState(false);
  const [accActionStatus, setAccActionStatus] = useState<{ success?: boolean; message?: string } | null>(null);

  // Instant Payout Modal
  const [isPayoutModalOpen, setIsPayoutModalOpen] = useState(false);
  const [payoutAmount, setPayoutAmount] = useState('');
  const [payoutAccNumber, setPayoutAccNumber] = useState('');
  const [payoutBankCode, setPayoutBankCode] = useState('035');
  const [payoutName, setPayoutName] = useState('');
  const [payoutDesc, setPayoutDesc] = useState('Rentilly Admin Payout');
  const [isResolvingAccount, setIsResolvingAccount] = useState(false);
  const [accountResolved, setAccountResolved] = useState(false);
  const [isSubmittingPayout, setIsSubmittingPayout] = useState(false);
  const [payoutActionStatus, setPayoutActionStatus] = useState<{ success?: boolean; message?: string } | null>(null);

  // Collection Reconcile Modal
  const [selectedColForReconcile, setSelectedColForReconcile] = useState<FincraCollection | null>(null);
  const [reconcileEmail, setReconcileEmail] = useState('');
  const [isReconciling, setIsReconciling] = useState(false);
  const [reconcileStatus, setReconcileStatus] = useState<{ success?: boolean; message?: string } | null>(null);

  // FX Conversion Calculator State
  const [fxSourceCurrency, setFxSourceCurrency] = useState('NGN');
  const [fxDestCurrency, setFxDestCurrency] = useState('USD');
  const [fxAmount, setFxAmount] = useState('100000');
  const [fxQuote, setFxQuote] = useState<any>(null);
  const [isGettingQuote, setIsGettingQuote] = useState(false);
  const [isConverting, setIsConverting] = useState(false);
  const [fxActionStatus, setFxActionStatus] = useState<{ success?: boolean; message?: string } | null>(null);

  // Refund / Reversal State
  const [refundingRef, setRefundingRef] = useState<string | null>(null);

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
        setCollections(data.collections || []);
      } else {
        setErrorMsg(data.error || 'Failed to fetch Fincra overview');
      }

      // Fetch banks asynchronously
      fetch('/api/admin/fincra/banks')
        .then(r => r.json())
        .then(b => {
          if (b.data && Array.isArray(b.data)) setBanks(b.data);
        })
        .catch(() => {});

      // Fetch beneficiaries asynchronously
      fetch('/api/admin/fincra/beneficiaries')
        .then(r => r.json())
        .then(b => {
          if (b.data?.results && Array.isArray(b.data.results)) {
            setBeneficiaries(b.data.results);
          }
        })
        .catch(() => {});
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

  // Real-Time Account Resolution
  useEffect(() => {
    const cleanAcc = payoutAccNumber.trim();
    if (cleanAcc.length === 10 && payoutBankCode) {
      setIsResolvingAccount(true);
      setAccountResolved(false);
      fetch(`/api/admin/fincra/resolve-account?accountNumber=${cleanAcc}&bankCode=${payoutBankCode}`)
        .then(r => r.json())
        .then(data => {
          if (data.status && data.accountName) {
            setPayoutName(data.accountName);
            setAccountResolved(true);
          }
        })
        .catch(() => {})
        .finally(() => setIsResolvingAccount(false));
    } else {
      setAccountResolved(false);
    }
  }, [payoutAccNumber, payoutBankCode]);

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
          accountHolderName: payoutName || 'Rentilly Beneficiary',
          description: payoutDesc
        })
      });
      const d = await res.json();
      if (d.status || d.success) {
        setPayoutActionStatus({
          success: true,
          message: `₦${Number(payoutAmount).toLocaleString()} disbursed successfully via Fincra NIP!`
        });
        setTimeout(() => {
          setIsPayoutModalOpen(false);
          setPayoutActionStatus(null);
          setPayoutAmount('');
          setPayoutAccNumber('');
          setPayoutName('');
          fetchData();
        }, 1800);
      } else {
        setPayoutActionStatus({ success: false, message: d.message || d.error || 'Disbursement failed' });
      }
    } catch (err: any) {
      setPayoutActionStatus({ success: false, message: err.message });
    } finally {
      setIsSubmittingPayout(false);
    }
  };

  const handleManualReconcile = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedColForReconcile || !reconcileEmail) return;
    setIsReconciling(true);
    setReconcileStatus(null);
    try {
      const res = await fetch('/api/admin/fincra/collections/reconcile', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          reference: selectedColForReconcile.reference,
          email: reconcileEmail,
          amount: selectedColForReconcile.amount
        })
      });
      const d = await res.json();
      if (d.success) {
        setReconcileStatus({ success: true, message: `₦${selectedColForReconcile.amount.toLocaleString()} successfully credited to ${reconcileEmail}!` });
        setTimeout(() => {
          setSelectedColForReconcile(null);
          setReconcileEmail('');
          setReconcileStatus(null);
          fetchData();
        }, 1800);
      } else {
        setReconcileStatus({ success: false, message: d.error || 'Reconciliation failed' });
      }
    } catch (err: any) {
      setReconcileStatus({ success: false, message: err.message });
    } finally {
      setIsReconciling(false);
    }
  };

  const handleGenerateQuote = async () => {
    if (!fxAmount || Number(fxAmount) <= 0) return;
    setIsGettingQuote(true);
    setFxActionStatus(null);
    try {
      const res = await fetch('/api/admin/fincra/quotes/generate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          sourceCurrency: fxSourceCurrency,
          destinationCurrency: fxDestCurrency,
          amount: Number(fxAmount),
          action: 'receive'
        })
      });
      const d = await res.json();
      if (d.success && d.data) {
        setFxQuote(d.data);
      } else {
        setFxActionStatus({ success: false, message: d.error || d.message || 'Failed to generate quote' });
      }
    } catch (err: any) {
      setFxActionStatus({ success: false, message: err.message });
    } finally {
      setIsGettingQuote(false);
    }
  };

  const handleExecuteConversion = async () => {
    if (!fxQuote?.reference) return;
    setIsConverting(true);
    setFxActionStatus(null);
    try {
      const res = await fetch('/api/admin/fincra/conversions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ quoteReference: fxQuote.reference })
      });
      const d = await res.json();
      if (d.success || d.status) {
        setFxActionStatus({
          success: true,
          message: `Conversion successful! Swapped ${fxSourceCurrency} for ${fxDestCurrency}.`
        });
        setFxQuote(null);
        fetchData();
      } else {
        setFxActionStatus({ success: false, message: d.error || d.message || 'Conversion execution failed' });
      }
    } catch (err: any) {
      setFxActionStatus({ success: false, message: err.message });
    } finally {
      setIsConverting(false);
    }
  };

  const handleInstantRefund = async (p: FincraPayout) => {
    const ref = p.customerReference || p.reference;
    setRefundingRef(ref);
    try {
      const res = await fetch('/api/admin/fincra/payouts/refund', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          reference: p.reference,
          customerReference: p.customerReference,
          amount: p.amount + (p.fee || 65),
          failedReason: p.failedReason || 'Destination bank rejected transfer',
          beneficiaryName: p.beneficiaryName,
          accountNumber: p.accountNumber
        })
      });
      const d = await res.json();
      if (d.success) {
        fetchData();
      } else {
        alert(d.reason || d.error || 'Refund could not be completed');
      }
    } catch (err: any) {
      alert(err.message);
    } finally {
      setRefundingRef(null);
    }
  };

  // CSV Export utility
  const exportToCSV = (data: any[], filename: string) => {
    if (!data || data.length === 0) return;
    const headers = Object.keys(data[0]);
    const csvRows = [
      headers.join(','),
      ...data.map(row => headers.map(h => JSON.stringify(row[h] ?? '')).join(','))
    ];
    const blob = new Blob([csvRows.join('\n')], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${filename}_${new Date().toISOString().split('T')[0]}.csv`;
    a.click();
    window.URL.revokeObjectURL(url);
  };

  // Filtering
  const filteredAccounts = useMemo(() => {
    let result = accounts;
    if (statusFilter !== 'all') {
      result = result.filter(a => (statusFilter === 'active' ? a.isActive : !a.isActive));
    }
    if (searchQuery) {
      const q = searchQuery.toLowerCase();
      result = result.filter(
        a =>
          a.accountNumber.includes(q) ||
          a.accountName.toLowerCase().includes(q) ||
          a.bankName.toLowerCase().includes(q) ||
          (a.assignedUserEmail && a.assignedUserEmail.toLowerCase().includes(q))
      );
    }
    return result;
  }, [accounts, searchQuery, statusFilter]);

  const filteredPayouts = useMemo(() => {
    let result = payouts;
    if (statusFilter !== 'all') {
      result = result.filter(p => (p.status || '').toLowerCase() === statusFilter.toLowerCase());
    }
    if (searchQuery) {
      const q = searchQuery.toLowerCase();
      result = result.filter(
        p =>
          p.beneficiaryName.toLowerCase().includes(q) ||
          p.accountNumber.includes(q) ||
          (p.reference && p.reference.toLowerCase().includes(q)) ||
          (p.customerReference && p.customerReference.toLowerCase().includes(q))
      );
    }
    return result;
  }, [payouts, searchQuery, statusFilter]);

  const filteredCollections = useMemo(() => {
    let result = collections;
    if (statusFilter !== 'all') {
      result = result.filter(c => (c.status || '').toLowerCase() === statusFilter.toLowerCase());
    }
    if (searchQuery) {
      const q = searchQuery.toLowerCase();
      result = result.filter(
        c =>
          c.payeeName.toLowerCase().includes(q) ||
          c.reference.toLowerCase().includes(q) ||
          c.accountNumber.includes(q) ||
          (c.assignedUserEmail && c.assignedUserEmail.toLowerCase().includes(q))
      );
    }
    return result;
  }, [collections, searchQuery, statusFilter]);

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
                <h1 className="text-xl font-bold text-white tracking-tight">Fincra Master Ledger & Treasury Desk</h1>
                <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/30 flex items-center gap-1">
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
                  Live IP Whitelisted
                </span>
                <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-blue-500/10 text-blue-400 border border-blue-500/30">
                  Wema Bank Commercial Rail
                </span>
              </div>
              <p className="text-xs text-slate-400 mt-1">
                Full Merchant Operations: Multi-currency treasury, instant NIP disbursements, inbound collections capture, FX swaps, and automatic failed transfer reversals.
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
            New Virtual Account
          </button>
          <button
            onClick={() => setIsPayoutModalOpen(true)}
            className="flex-1 md:flex-none px-4 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-medium text-xs flex items-center justify-center gap-2 transition-all shadow-lg shadow-emerald-600/20 active:scale-95"
          >
            <Send className="w-4 h-4" />
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

      {errorMsg && (
        <div className="p-3.5 bg-rose-500/10 border border-rose-500/30 rounded-xl text-xs text-rose-300 flex items-center gap-2 shadow-md">
          <AlertCircle className="w-4 h-4 text-rose-400 shrink-0" />
          <span>{errorMsg}</span>
        </div>
      )}

      {/* ── Business Profile & Webhook Status Strip ───────────────────── */}
      {summary && (
        <div className="bg-slate-900/40 border border-slate-800/80 rounded-xl px-5 py-3 flex flex-wrap items-center justify-between gap-4 text-xs text-slate-300">
          <div className="flex items-center gap-2">
            <Building2 className="w-4 h-4 text-blue-400" />
            <span className="font-semibold text-white">{summary.businessName}</span>
            <span className="text-slate-500">•</span>
            <span>Tag: <strong className="text-slate-200">#{summary.businessTag}</strong></span>
            <span className="text-slate-500">•</span>
            <span className="text-emerald-400 flex items-center gap-1 font-medium">
              <ShieldCheck className="w-3.5 h-3.5" /> Institutional KYC Verified
            </span>
          </div>

          <div className="flex items-center gap-3">
            <span className="text-slate-400">Webhook Rail:</span>
            <code className="px-2 py-1 rounded bg-slate-950 border border-slate-800 text-[11px] text-blue-300 font-mono">
              {summary.webhookCallbackURL}
            </code>
            <span className="px-2 py-0.5 rounded text-[10px] font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
              Active (200 OK)
            </span>
          </div>
        </div>
      )}

      {/* ── High-Level Financial Metrics ──────────────────────────────── */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Card 1: NGN Treasury */}
        <div className="bg-gradient-to-br from-slate-900/90 to-slate-950 border border-slate-800 p-5 rounded-2xl shadow-lg relative overflow-hidden">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 tracking-wide uppercase">NGN Master Available</span>
            <div className="w-8 h-8 rounded-lg bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center text-emerald-400 font-bold">
              ₦
            </div>
          </div>
          <div className="mt-3">
            <h3 className="text-2xl font-black text-white tracking-tight">
              ₦{(summary?.ngnAvailable || 0).toLocaleString('en-NG', { minimumFractionDigits: 2 })}
            </h3>
            <p className="text-xs text-slate-400 mt-1 flex items-center gap-1.5">
              <span>Ledger: ₦{(summary?.ngnLedger || 0).toLocaleString('en-NG', { minimumFractionDigits: 2 })}</span>
              <span className="text-emerald-400 font-medium">• Instant</span>
            </p>
          </div>
        </div>

        {/* Card 2: USD Treasury */}
        <div className="bg-gradient-to-br from-slate-900/90 to-slate-950 border border-slate-800 p-5 rounded-2xl shadow-lg relative overflow-hidden">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 tracking-wide uppercase">USD Treasury Wallet</span>
            <div className="w-8 h-8 rounded-lg bg-blue-500/10 border border-blue-500/30 flex items-center justify-center text-blue-400">
              <DollarSign className="w-4 h-4" />
            </div>
          </div>
          <div className="mt-3">
            <h3 className="text-2xl font-black text-white tracking-tight">
              ${(summary?.usdAvailable || 0).toLocaleString('en-US', { minimumFractionDigits: 2 })}
            </h3>
            <p className="text-xs text-slate-400 mt-1 flex items-center gap-2">
              <span>EUR: €{(summary?.eurAvailable || 0).toFixed(2)}</span>
              <span>•</span>
              <span>GBP: £{(summary?.gbpAvailable || 0).toFixed(2)}</span>
            </p>
          </div>
        </div>

        {/* Card 3: Inbound Collections */}
        <div className="bg-gradient-to-br from-slate-900/90 to-slate-950 border border-slate-800 p-5 rounded-2xl shadow-lg relative overflow-hidden">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 tracking-wide uppercase">Collections / Inflows</span>
            <div className="w-8 h-8 rounded-lg bg-teal-500/10 border border-teal-500/30 flex items-center justify-center text-teal-400">
              <ArrowDownLeft className="w-4 h-4" />
            </div>
          </div>
          <div className="mt-3">
            <h3 className="text-2xl font-black text-white tracking-tight">
              {collections.length} Captured
            </h3>
            <p className="text-xs text-slate-400 mt-1">
              ₦{collections.filter(c => c.status === 'successful').reduce((acc, c) => acc + c.amount, 0).toLocaleString()} Total Inbound
            </p>
          </div>
        </div>

        {/* Card 4: Outbound Disbursements */}
        <div className="bg-gradient-to-br from-slate-900/90 to-slate-950 border border-slate-800 p-5 rounded-2xl shadow-lg relative overflow-hidden">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 tracking-wide uppercase">Disbursements / Payouts</span>
            <div className="w-8 h-8 rounded-lg bg-indigo-500/10 border border-indigo-500/30 flex items-center justify-center text-indigo-400">
              <ArrowUpRight className="w-4 h-4" />
            </div>
          </div>
          <div className="mt-3">
            <h3 className="text-2xl font-black text-white tracking-tight">
              {payouts.length} Executed
            </h3>
            <p className="text-xs text-slate-400 mt-1 flex items-center gap-1.5">
              <span>{payouts.filter(p => p.status === 'successful').length} successful</span>
              <span>•</span>
              <span className="text-rose-400">{payouts.filter(p => p.status === 'failed').length} failed</span>
            </p>
          </div>
        </div>
      </div>

      {/* ── Navigation Sub-Tabs ───────────────────────────────────────── */}
      <div className="flex flex-wrap items-center justify-between gap-4 border-b border-slate-800 pb-2">
        <div className="flex items-center gap-1 bg-slate-900/80 p-1 rounded-xl border border-slate-800">
          <button
            onClick={() => { setActiveSubTab('wallets'); setStatusFilter('all'); }}
            className={`px-4 py-2 rounded-lg text-xs font-medium transition-all flex items-center gap-2 ${
              activeSubTab === 'wallets'
                ? 'bg-blue-600 text-white shadow-md'
                : 'text-slate-400 hover:text-white hover:bg-slate-800/50'
            }`}
          >
            <Building2 className="w-3.5 h-3.5" />
            Treasury Wallets ({wallets.length})
          </button>

          <button
            onClick={() => { setActiveSubTab('collections'); setStatusFilter('all'); }}
            className={`px-4 py-2 rounded-lg text-xs font-medium transition-all flex items-center gap-2 ${
              activeSubTab === 'collections'
                ? 'bg-blue-600 text-white shadow-md'
                : 'text-slate-400 hover:text-white hover:bg-slate-800/50'
            }`}
          >
            <ArrowDownLeft className="w-3.5 h-3.5" />
            Collections ({collections.length})
          </button>

          <button
            onClick={() => { setActiveSubTab('payouts'); setStatusFilter('all'); }}
            className={`px-4 py-2 rounded-lg text-xs font-medium transition-all flex items-center gap-2 ${
              activeSubTab === 'payouts'
                ? 'bg-blue-600 text-white shadow-md'
                : 'text-slate-400 hover:text-white hover:bg-slate-800/50'
            }`}
          >
            <ArrowUpRight className="w-3.5 h-3.5" />
            Payouts ({payouts.length})
          </button>

          <button
            onClick={() => { setActiveSubTab('accounts'); setStatusFilter('all'); }}
            className={`px-4 py-2 rounded-lg text-xs font-medium transition-all flex items-center gap-2 ${
              activeSubTab === 'accounts'
                ? 'bg-blue-600 text-white shadow-md'
                : 'text-slate-400 hover:text-white hover:bg-slate-800/50'
            }`}
          >
            <Landmark className="w-3.5 h-3.5" />
            Virtual Accounts ({accounts.length})
          </button>

          <button
            onClick={() => { setActiveSubTab('conversions'); setStatusFilter('all'); }}
            className={`px-4 py-2 rounded-lg text-xs font-medium transition-all flex items-center gap-2 ${
              activeSubTab === 'conversions'
                ? 'bg-blue-600 text-white shadow-md'
                : 'text-slate-400 hover:text-white hover:bg-slate-800/50'
            }`}
          >
            <ArrowRightLeft className="w-3.5 h-3.5" />
            FX Conversions
          </button>

          <button
            onClick={() => { setActiveSubTab('beneficiaries'); setStatusFilter('all'); }}
            className={`px-4 py-2 rounded-lg text-xs font-medium transition-all flex items-center gap-2 ${
              activeSubTab === 'beneficiaries'
                ? 'bg-blue-600 text-white shadow-md'
                : 'text-slate-400 hover:text-white hover:bg-slate-800/50'
            }`}
          >
            <Users className="w-3.5 h-3.5" />
            Beneficiaries ({beneficiaries.length})
          </button>
        </div>

        {/* Global Search & Export Strip */}
        <div className="flex items-center gap-3">
          {activeSubTab !== 'wallets' && activeSubTab !== 'conversions' && (
            <div className="relative">
              <Search className="w-3.5 h-3.5 text-slate-500 absolute left-3 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                placeholder="Search reference, account, name..."
                value={searchQuery}
                onChange={e => setSearchQuery(e.target.value)}
                className="bg-slate-900 border border-slate-800 text-xs text-slate-200 pl-9 pr-4 py-2 rounded-xl focus:outline-none focus:border-blue-500 w-56 md:w-64"
              />
            </div>
          )}

          {activeSubTab === 'collections' && (
            <button
              onClick={() => exportToCSV(filteredCollections, 'fincra_collections')}
              className="p-2 rounded-xl bg-slate-900 hover:bg-slate-800 border border-slate-800 text-slate-300 hover:text-white text-xs flex items-center gap-1.5"
              title="Export Collections CSV"
            >
              <Download className="w-3.5 h-3.5" />
              CSV
            </button>
          )}

          {activeSubTab === 'payouts' && (
            <button
              onClick={() => exportToCSV(filteredPayouts, 'fincra_payouts')}
              className="p-2 rounded-xl bg-slate-900 hover:bg-slate-800 border border-slate-800 text-slate-300 hover:text-white text-xs flex items-center gap-1.5"
              title="Export Payouts CSV"
            >
              <Download className="w-3.5 h-3.5" />
              CSV
            </button>
          )}

          {activeSubTab === 'accounts' && (
            <button
              onClick={() => exportToCSV(filteredAccounts, 'fincra_virtual_accounts')}
              className="p-2 rounded-xl bg-slate-900 hover:bg-slate-800 border border-slate-800 text-slate-300 hover:text-white text-xs flex items-center gap-1.5"
              title="Export Virtual Accounts CSV"
            >
              <Download className="w-3.5 h-3.5" />
              CSV
            </button>
          )}
        </div>
      </div>

      {/* ── SUB-TAB 1: TREASURY WALLETS ──────────────────────────────── */}
      {activeSubTab === 'wallets' && (
        <div className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-4">
            {wallets.map(w => (
              <div
                key={w.id}
                className="bg-slate-900/60 border border-slate-800 p-5 rounded-2xl relative flex flex-col justify-between hover:border-slate-700 transition-all shadow-md"
              >
                <div>
                  <div className="flex items-center justify-between">
                    <span className="px-2.5 py-1 rounded-lg text-xs font-black tracking-wider bg-blue-500/10 text-blue-400 border border-blue-500/30 uppercase">
                      {w.currency} Treasury
                    </span>
                    <span className="text-[11px] font-mono text-slate-500">#{w.walletNumber}</span>
                  </div>

                  <div className="mt-4">
                    <span className="text-[11px] text-slate-400 uppercase tracking-wider font-semibold">Available</span>
                    <div className="text-2xl font-black text-white mt-0.5">
                      {w.currency === 'NGN' ? '₦' : w.currency === 'USD' ? '$' : w.currency === 'EUR' ? '€' : '£'}
                      {w.availableBalance.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                    </div>
                  </div>

                  <div className="mt-4 pt-3 border-t border-slate-800/80 space-y-1.5 text-xs text-slate-400">
                    <div className="flex items-center justify-between">
                      <span>Ledger Balance:</span>
                      <span className="font-semibold text-slate-200">
                        {w.currency === 'NGN' ? '₦' : w.currency === 'USD' ? '$' : w.currency === 'EUR' ? '€' : '£'}
                        {w.ledgerBalance.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                      </span>
                    </div>
                    <div className="flex items-center justify-between">
                      <span>Locked Reserve:</span>
                      <span className="font-semibold text-slate-200">
                        {w.currency === 'NGN' ? '₦' : w.currency === 'USD' ? '$' : w.currency === 'EUR' ? '€' : '£'}
                        {w.lockedBalance.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                      </span>
                    </div>
                  </div>
                </div>

                <div className="mt-5 pt-3 border-t border-slate-800 flex items-center justify-between">
                  <span className="inline-flex items-center gap-1.5 text-[11px] font-medium text-emerald-400">
                    <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
                    Active Settlement
                  </span>
                  <button
                    onClick={() => {
                      setFxSourceCurrency(w.currency);
                      setActiveSubTab('conversions');
                    }}
                    className="text-xs text-blue-400 hover:text-blue-300 font-medium flex items-center gap-1 hover:underline"
                  >
                    Convert FX <ChevronRight className="w-3 h-3" />
                  </button>
                </div>
              </div>
            ))}
          </div>

          {/* Treasury Action Strip */}
          <div className="bg-slate-900/40 border border-slate-800 p-5 rounded-2xl flex flex-col md:flex-row items-center justify-between gap-4">
            <div>
              <h4 className="text-sm font-bold text-white">Need to fund or top up your Fincra Master Treasury?</h4>
              <p className="text-xs text-slate-400 mt-0.5">
                Execute direct commercial interbank transfer into your master Wema Bank settling account or trigger an institutional swap.
              </p>
            </div>
            <div className="flex items-center gap-3">
              <button
                onClick={() => {
                  setPayoutBankCode('035');
                  setIsPayoutModalOpen(true);
                }}
                className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 border border-slate-700 text-xs font-semibold text-white flex items-center gap-2"
              >
                <Send className="w-3.5 h-3.5 text-emerald-400" />
                Disburse Payout
              </button>
              <button
                onClick={() => setActiveSubTab('conversions')}
                className="px-4 py-2 rounded-xl bg-blue-600 hover:bg-blue-500 text-xs font-semibold text-white flex items-center gap-2"
              >
                <ArrowRightLeft className="w-3.5 h-3.5" />
                FX Conversion Desk
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── SUB-TAB 2: INBOUND COLLECTIONS ───────────────────────────── */}
      {activeSubTab === 'collections' && (
        <div className="space-y-4">
          <div className="flex flex-wrap items-center justify-between gap-3 bg-slate-900/60 border border-slate-800 p-4 rounded-xl">
            <div className="flex items-center gap-2">
              <span className="text-xs font-semibold text-slate-400">Filter Status:</span>
              {(['all', 'successful', 'pending', 'failed'] as const).map(s => (
                <button
                  key={s}
                  onClick={() => setStatusFilter(s)}
                  className={`px-3 py-1 rounded-lg text-xs font-medium capitalize transition-all ${
                    statusFilter === s
                      ? 'bg-blue-600 text-white'
                      : 'bg-slate-800 text-slate-400 hover:text-white'
                  }`}
                >
                  {s}
                </button>
              ))}
            </div>
            <span className="text-xs text-slate-400">
              Showing <strong>{filteredCollections.length}</strong> collections
            </span>
          </div>

          <div className="bg-slate-900/60 border border-slate-800 rounded-2xl overflow-hidden shadow-xl">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead>
                  <tr className="bg-slate-950/80 border-b border-slate-800 text-slate-400 font-semibold uppercase tracking-wider text-[10px]">
                    <th className="py-3 px-4">Payee / Sender</th>
                    <th className="py-3 px-4">Amount</th>
                    <th className="py-3 px-4">EMTL / Fee</th>
                    <th className="py-3 px-4">Destination Virtual Account</th>
                    <th className="py-3 px-4">Status</th>
                    <th className="py-3 px-4">Reference</th>
                    <th className="py-3 px-4">Date</th>
                    <th className="py-3 px-4 text-right">Action</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-800/60 text-slate-300">
                  {filteredCollections.length === 0 ? (
                    <tr>
                      <td colSpan={8} className="py-8 text-center text-slate-500">
                        No collections matching filter criteria.
                      </td>
                    </tr>
                  ) : (
                    filteredCollections.map(c => (
                      <tr key={c.id} className="hover:bg-slate-850/40 transition-colors">
                        <td className="py-3.5 px-4 font-semibold text-white">
                          <div>{c.payeeName}</div>
                          <div className="text-[11px] text-slate-500 capitalize">{c.paymentMethod?.replace('_', ' ')}</div>
                        </td>
                        <td className="py-3.5 px-4 font-bold text-emerald-400 text-sm">
                          +₦{c.amount.toLocaleString()}
                        </td>
                        <td className="py-3.5 px-4 text-slate-400">
                          ₦{c.fee}
                          {c.emtl > 0 && <span className="text-[10px] text-slate-500 block">Levy: ₦{c.emtl}</span>}
                        </td>
                        <td className="py-3.5 px-4">
                          <span className="font-mono text-slate-200">{c.accountNumber}</span>
                          {c.assignedUserEmail && (
                            <span className="text-[11px] text-blue-400 block font-sans">
                              {c.assignedUserEmail}
                            </span>
                          )}
                        </td>
                        <td className="py-3.5 px-4">
                          <span
                            className={`px-2.5 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider inline-flex items-center gap-1 ${
                              c.status === 'successful'
                                ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/30'
                                : c.status === 'pending'
                                ? 'bg-amber-500/10 text-amber-400 border border-amber-500/30'
                                : 'bg-rose-500/10 text-rose-400 border border-rose-500/30'
                            }`}
                          >
                            {c.status === 'successful' ? <CheckCircle2 className="w-3 h-3" /> : <Clock className="w-3 h-3" />}
                            {c.status}
                          </span>
                        </td>
                        <td className="py-3.5 px-4">
                          <button
                            onClick={() => handleCopy(c.reference)}
                            className="font-mono text-[11px] text-slate-400 hover:text-white flex items-center gap-1"
                            title="Copy Reference"
                          >
                            {c.reference.slice(0, 14)}...
                            {copiedText === c.reference ? <Check className="w-3 h-3 text-emerald-400" /> : <Copy className="w-3 h-3" />}
                          </button>
                        </td>
                        <td className="py-3.5 px-4 text-slate-400 text-[11px]">
                          {new Date(c.createdAt).toLocaleString('en-US', { dateStyle: 'short', timeStyle: 'short' })}
                        </td>
                        <td className="py-3.5 px-4 text-right">
                          <button
                            onClick={() => {
                              setSelectedColForReconcile(c);
                              setReconcileEmail(c.assignedUserEmail || '');
                            }}
                            className="px-2.5 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-xs text-blue-400 hover:text-white border border-slate-700 transition-all"
                          >
                            Reconcile
                          </button>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* ── SUB-TAB 3: DISBURSEMENTS & PAYOUTS ───────────────────────── */}
      {activeSubTab === 'payouts' && (
        <div className="space-y-4">
          <div className="flex flex-wrap items-center justify-between gap-3 bg-slate-900/60 border border-slate-800 p-4 rounded-xl">
            <div className="flex items-center gap-2">
              <span className="text-xs font-semibold text-slate-400">Status:</span>
              {(['all', 'successful', 'processing', 'failed'] as const).map(s => (
                <button
                  key={s}
                  onClick={() => setStatusFilter(s)}
                  className={`px-3 py-1 rounded-lg text-xs font-medium capitalize transition-all ${
                    statusFilter === s
                      ? 'bg-blue-600 text-white'
                      : 'bg-slate-800 text-slate-400 hover:text-white'
                  }`}
                >
                  {s}
                </button>
              ))}
            </div>
            <div className="flex items-center gap-3">
              <span className="text-xs text-slate-400">
                Total: <strong>{filteredPayouts.length}</strong> transfers
              </span>
              <button
                onClick={() => setIsPayoutModalOpen(true)}
                className="px-3 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold flex items-center gap-1.5"
              >
                <Send className="w-3.5 h-3.5" />
                New Transfer
              </button>
            </div>
          </div>

          <div className="bg-slate-900/60 border border-slate-800 rounded-2xl overflow-hidden shadow-xl">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead>
                  <tr className="bg-slate-950/80 border-b border-slate-800 text-slate-400 font-semibold uppercase tracking-wider text-[10px]">
                    <th className="py-3 px-4">Beneficiary</th>
                    <th className="py-3 px-4">Account Number</th>
                    <th className="py-3 px-4">Bank Code / Name</th>
                    <th className="py-3 px-4">Amount</th>
                    <th className="py-3 px-4">Status</th>
                    <th className="py-3 px-4">Reversal / Refund</th>
                    <th className="py-3 px-4">Reference</th>
                    <th className="py-3 px-4">Date</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-800/60 text-slate-300">
                  {filteredPayouts.length === 0 ? (
                    <tr>
                      <td colSpan={8} className="py-8 text-center text-slate-500">
                        No disbursements found matching query.
                      </td>
                    </tr>
                  ) : (
                    filteredPayouts.map(p => (
                      <tr key={p.id} className="hover:bg-slate-850/40 transition-colors">
                        <td className="py-3.5 px-4 font-semibold text-white">
                          <div>{p.beneficiaryName}</div>
                          {p.failedReason && (
                            <div className="text-[10px] text-rose-400 mt-0.5 line-clamp-1" title={p.failedReason}>
                              {p.failedReason}
                            </div>
                          )}
                        </td>
                        <td className="py-3.5 px-4 font-mono text-slate-200">
                          {p.accountNumber}
                        </td>
                        <td className="py-3.5 px-4 text-slate-400">
                          {p.bankName}
                        </td>
                        <td className="py-3.5 px-4 font-bold text-white text-sm">
                          ₦{p.amount.toLocaleString()}
                          <span className="text-[10px] text-slate-500 font-normal block">Fee: ₦{p.fee}</span>
                        </td>
                        <td className="py-3.5 px-4">
                          <span
                            className={`px-2.5 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider inline-flex items-center gap-1 ${
                              p.status === 'successful'
                                ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/30'
                                : p.status === 'processing'
                                ? 'bg-blue-500/10 text-blue-400 border border-blue-500/30'
                                : 'bg-rose-500/10 text-rose-400 border border-rose-500/30'
                            }`}
                          >
                            {p.status === 'successful' ? (
                              <CheckCircle2 className="w-3 h-3" />
                            ) : p.status === 'processing' ? (
                              <Clock className="w-3 h-3 animate-spin" />
                            ) : (
                              <XCircle className="w-3 h-3" />
                            )}
                            {p.status}
                          </span>
                        </td>
                        <td className="py-3.5 px-4">
                          {p.status === 'failed' ? (
                            p.isRefunded ? (
                              <span className="px-2.5 py-1 rounded-md text-[10px] font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/30 inline-flex items-center gap-1">
                                <Check className="w-3 h-3" /> Refunded
                              </span>
                            ) : (
                              <button
                                onClick={() => handleInstantRefund(p)}
                                disabled={refundingRef === (p.customerReference || p.reference)}
                                className="px-2.5 py-1 rounded-md text-[10px] font-bold bg-rose-600 hover:bg-rose-500 text-white transition-all flex items-center gap-1 disabled:opacity-50"
                              >
                                <RotateCcw className={`w-3 h-3 ${refundingRef === (p.customerReference || p.reference) ? 'animate-spin' : ''}`} />
                                Refund User
                              </button>
                            )
                          ) : (
                            <span className="text-slate-600 text-[11px]">—</span>
                          )}
                        </td>
                        <td className="py-3.5 px-4">
                          <button
                            onClick={() => handleCopy(p.customerReference || p.reference)}
                            className="font-mono text-[11px] text-slate-400 hover:text-white flex items-center gap-1"
                            title="Copy Ref"
                          >
                            {(p.customerReference || p.reference).slice(0, 14)}...
                            {copiedText === (p.customerReference || p.reference) ? <Check className="w-3 h-3 text-emerald-400" /> : <Copy className="w-3 h-3" />}
                          </button>
                        </td>
                        <td className="py-3.5 px-4 text-slate-400 text-[11px]">
                          {new Date(p.createdAt).toLocaleString('en-US', { dateStyle: 'short', timeStyle: 'short' })}
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* ── SUB-TAB 4: VIRTUAL ACCOUNTS ──────────────────────────────── */}
      {activeSubTab === 'accounts' && (
        <div className="space-y-4">
          <div className="flex flex-wrap items-center justify-between gap-3 bg-slate-900/60 border border-slate-800 p-4 rounded-xl">
            <span className="text-xs text-slate-400">
              Total Issued: <strong>{filteredAccounts.length}</strong> Wema Bank Accounts
            </span>
            <button
              onClick={() => setIsAccountModalOpen(true)}
              className="px-3.5 py-1.5 rounded-xl bg-blue-600 hover:bg-blue-500 text-white text-xs font-semibold flex items-center gap-1.5"
            >
              <PlusCircle className="w-3.5 h-3.5" />
              Generate Virtual Account
            </button>
          </div>

          <div className="bg-slate-900/60 border border-slate-800 rounded-2xl overflow-hidden shadow-xl">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead>
                  <tr className="bg-slate-950/80 border-b border-slate-800 text-slate-400 font-semibold uppercase tracking-wider text-[10px]">
                    <th className="py-3 px-4">Account Number</th>
                    <th className="py-3 px-4">Account Name</th>
                    <th className="py-3 px-4">Bank</th>
                    <th className="py-3 px-4">Assigned User</th>
                    <th className="py-3 px-4">Type</th>
                    <th className="py-3 px-4">Status</th>
                    <th className="py-3 px-4">Created Date</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-800/60 text-slate-300">
                  {filteredAccounts.length === 0 ? (
                    <tr>
                      <td colSpan={7} className="py-8 text-center text-slate-500">
                        No virtual accounts found.
                      </td>
                    </tr>
                  ) : (
                    filteredAccounts.map(acc => (
                      <tr key={acc.id} className="hover:bg-slate-850/40 transition-colors">
                        <td className="py-3.5 px-4 font-mono font-bold text-white text-sm">
                          <button
                            onClick={() => handleCopy(acc.accountNumber)}
                            className="flex items-center gap-1.5 hover:text-blue-400 transition-colors"
                            title="Copy Account Number"
                          >
                            {acc.accountNumber}
                            {copiedText === acc.accountNumber ? (
                              <Check className="w-3 h-3 text-emerald-400" />
                            ) : (
                              <Copy className="w-3 h-3 text-slate-500" />
                            )}
                          </button>
                        </td>
                        <td className="py-3.5 px-4 font-semibold text-white">
                          {acc.accountName}
                        </td>
                        <td className="py-3.5 px-4 text-slate-400">
                          {acc.bankName} (035)
                        </td>
                        <td className="py-3.5 px-4">
                          {acc.assignedUserEmail ? (
                            <div>
                              <div className="text-white font-medium">{acc.assignedUserName || 'User'}</div>
                              <div className="text-[11px] text-blue-400">{acc.assignedUserEmail}</div>
                            </div>
                          ) : (
                            <span className="text-slate-500 italic">Unlinked Pool Account</span>
                          )}
                        </td>
                        <td className="py-3.5 px-4">
                          <span className="px-2 py-0.5 rounded text-[10px] font-semibold bg-slate-800 text-slate-300 border border-slate-700 uppercase">
                            {acc.accountType}
                          </span>
                        </td>
                        <td className="py-3.5 px-4">
                          <span className="px-2.5 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider bg-emerald-500/10 text-emerald-400 border border-emerald-500/30 inline-flex items-center gap-1">
                            <CheckCircle2 className="w-3 h-3" /> Active
                          </span>
                        </td>
                        <td className="py-3.5 px-4 text-slate-400 text-[11px]">
                          {new Date(acc.createdAt).toLocaleDateString()}
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* ── SUB-TAB 5: FX CONVERSIONS DESK ───────────────────────────── */}
      {activeSubTab === 'conversions' && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Conversion Box */}
          <div className="bg-slate-900/60 border border-slate-800 p-6 rounded-2xl space-y-5">
            <div>
              <h3 className="text-base font-bold text-white flex items-center gap-2">
                <ArrowRightLeft className="w-4 h-4 text-blue-400" />
                Treasury Multi-Currency Swap Desk
              </h3>
              <p className="text-xs text-slate-400 mt-1">
                Real-time currency exchange between master wallets (NGN, USD, EUR, GBP) directly via Fincra's institutional FX rates.
              </p>
            </div>

            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider">From Currency</label>
                  <select
                    value={fxSourceCurrency}
                    onChange={e => setFxSourceCurrency(e.target.value)}
                    className="w-full mt-1.5 bg-slate-950 border border-slate-800 rounded-xl px-3 py-2.5 text-xs text-white focus:outline-none focus:border-blue-500 font-semibold"
                  >
                    <option value="NGN">NGN (Nigerian Naira)</option>
                    <option value="USD">USD (US Dollar)</option>
                    <option value="EUR">EUR (Euro)</option>
                    <option value="GBP">GBP (British Pound)</option>
                  </select>
                </div>

                <div>
                  <label className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider">To Currency</label>
                  <select
                    value={fxDestCurrency}
                    onChange={e => setFxDestCurrency(e.target.value)}
                    className="w-full mt-1.5 bg-slate-950 border border-slate-800 rounded-xl px-3 py-2.5 text-xs text-white focus:outline-none focus:border-blue-500 font-semibold"
                  >
                    <option value="USD">USD (US Dollar)</option>
                    <option value="NGN">NGN (Nigerian Naira)</option>
                    <option value="EUR">EUR (Euro)</option>
                    <option value="GBP">GBP (British Pound)</option>
                  </select>
                </div>
              </div>

              <div>
                <label className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider">
                  Amount to Swap ({fxSourceCurrency})
                </label>
                <div className="relative mt-1.5">
                  <input
                    type="number"
                    value={fxAmount}
                    onChange={e => setFxAmount(e.target.value)}
                    placeholder="Enter amount"
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2.5 text-sm text-white font-mono font-bold focus:outline-none focus:border-blue-500"
                  />
                  <span className="absolute right-3 top-1/2 -translate-y-1/2 text-xs font-bold text-slate-400">
                    {fxSourceCurrency}
                  </span>
                </div>
              </div>

              <button
                onClick={handleGenerateQuote}
                disabled={isGettingQuote || !fxAmount}
                className="w-full py-2.5 rounded-xl bg-blue-600 hover:bg-blue-500 text-white text-xs font-bold transition-all flex items-center justify-center gap-2 shadow-lg shadow-blue-600/20 disabled:opacity-50"
              >
                {isGettingQuote ? <RefreshCw className="w-4 h-4 animate-spin" /> : <Sparkles className="w-4 h-4" />}
                Get Live Fincra Quote
              </button>

              {fxActionStatus && (
                <div
                  className={`p-3 rounded-xl text-xs flex items-center gap-2 ${
                    fxActionStatus.success
                      ? 'bg-emerald-500/10 border border-emerald-500/30 text-emerald-300'
                      : 'bg-rose-500/10 border border-rose-500/30 text-rose-300'
                  }`}
                >
                  {fxActionStatus.success ? <CheckCircle2 className="w-4 h-4" /> : <AlertCircle className="w-4 h-4" />}
                  {fxActionStatus.message}
                </div>
              )}
            </div>
          </div>

          {/* Live Quote Preview Box */}
          <div className="bg-slate-900/60 border border-slate-800 p-6 rounded-2xl flex flex-col justify-between">
            <div>
              <h3 className="text-base font-bold text-white flex items-center gap-2">
                <Sparkles className="w-4 h-4 text-emerald-400" />
                Live Quote Summary
              </h3>
              <p className="text-xs text-slate-400 mt-1">
                Guaranteed execution price directly from Fincra liquidity pool.
              </p>

              {fxQuote ? (
                <div className="mt-5 space-y-4">
                  <div className="bg-slate-950 p-4 rounded-xl border border-slate-800 space-y-3">
                    <div className="flex items-center justify-between text-xs">
                      <span className="text-slate-400">You Pay:</span>
                      <span className="font-mono font-bold text-white text-sm">
                        {fxQuote.sourceAmount?.toLocaleString()} {fxQuote.sourceCurrency}
                      </span>
                    </div>

                    <div className="flex items-center justify-between text-xs">
                      <span className="text-slate-400">You Receive:</span>
                      <span className="font-mono font-black text-emerald-400 text-base">
                        {fxQuote.destinationAmount?.toLocaleString()} {fxQuote.destinationCurrency}
                      </span>
                    </div>

                    <div className="flex items-center justify-between text-xs pt-2 border-t border-slate-850">
                      <span className="text-slate-400">Exchange Rate:</span>
                      <span className="font-mono text-slate-300">
                        1 {fxQuote.sourceCurrency} = {fxQuote.rate} {fxQuote.destinationCurrency}
                        {fxQuote.price && <span className="text-slate-500 block text-[10px]">Price: ₦{fxQuote.price}/$</span>}
                      </span>
                    </div>

                    <div className="flex items-center justify-between text-xs">
                      <span className="text-slate-400">Settlement Fee:</span>
                      <span className="font-mono text-emerald-400">₦0.00 (Free)</span>
                    </div>
                  </div>

                  <button
                    onClick={handleExecuteConversion}
                    disabled={isConverting}
                    className="w-full py-3 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold transition-all flex items-center justify-center gap-2 shadow-lg shadow-emerald-600/20 active:scale-95 disabled:opacity-50"
                  >
                    {isConverting ? <RefreshCw className="w-4 h-4 animate-spin" /> : <Check className="w-4 h-4" />}
                    Confirm & Execute Treasury Swap
                  </button>
                </div>
              ) : (
                <div className="mt-12 text-center text-slate-500 space-y-2">
                  <ArrowRightLeft className="w-8 h-8 mx-auto opacity-30" />
                  <p className="text-xs">Enter amounts and click "Get Live Fincra Quote" to view execution pricing.</p>
                </div>
              )}
            </div>

            <div className="mt-6 pt-4 border-t border-slate-800/80 text-[11px] text-slate-500">
              Quotes are locked for 60 seconds upon generation. Balances settle instantly across your multi-currency master ledger upon confirmation.
            </div>
          </div>
        </div>
      )}

      {/* ── SUB-TAB 6: BENEFICIARIES DIRECTORY ────────────────────────── */}
      {activeSubTab === 'beneficiaries' && (
        <div className="space-y-4">
          <div className="flex items-center justify-between bg-slate-900/60 border border-slate-800 p-4 rounded-xl">
            <span className="text-xs text-slate-400">
              Saved Business Beneficiaries: <strong>{beneficiaries.length}</strong>
            </span>
            <button
              onClick={() => setIsPayoutModalOpen(true)}
              className="px-3 py-1.5 rounded-xl bg-blue-600 hover:bg-blue-500 text-white text-xs font-semibold flex items-center gap-1.5"
            >
              <Send className="w-3.5 h-3.5" />
              Transfer to Beneficiary
            </button>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
            {beneficiaries.map((b, idx) => (
              <div
                key={b._id || b.id || idx}
                className="bg-slate-900/60 border border-slate-800 p-4 rounded-2xl flex flex-col justify-between hover:border-slate-700 transition-all"
              >
                <div>
                  <div className="flex items-center justify-between">
                    <div className="font-bold text-white text-sm truncate">
                      {b.accountHolderName || b.email || 'Beneficiary'}
                    </div>
                    <span className="px-2 py-0.5 rounded text-[10px] font-semibold bg-slate-800 text-slate-300">
                      {b.destinationCurrency || b.currency || 'NGN'}
                    </span>
                  </div>

                  <div className="mt-3 space-y-1 text-xs text-slate-400">
                    <div className="flex items-center justify-between">
                      <span>Account:</span>
                      <span className="font-mono text-slate-200">{b.accountNumber || '—'}</span>
                    </div>
                    <div className="flex items-center justify-between">
                      <span>Bank Code:</span>
                      <span className="font-mono text-slate-200">{b.bankCode || '—'}</span>
                    </div>
                  </div>
                </div>

                <div className="mt-4 pt-3 border-t border-slate-800 flex items-center justify-end">
                  <button
                    onClick={() => {
                      if (b.accountNumber) setPayoutAccNumber(b.accountNumber);
                      if (b.bankCode) setPayoutBankCode(b.bankCode);
                      if (b.accountHolderName) setPayoutName(b.accountHolderName);
                      setIsPayoutModalOpen(true);
                    }}
                    className="px-3 py-1.5 rounded-lg bg-emerald-600/10 hover:bg-emerald-600 text-emerald-400 hover:text-white border border-emerald-500/30 text-xs font-semibold transition-all flex items-center gap-1.5"
                  >
                    <Send className="w-3 h-3" />
                    Pay Now
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* ── MODAL 1: INSTANT PAYOUT DISBURSEMENT ──────────────────────── */}
      {isPayoutModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/75 backdrop-blur-sm p-4 animate-fadeIn">
          <div className="bg-slate-900 border border-slate-800 w-full max-w-lg rounded-2xl p-6 shadow-2xl space-y-5">
            <div className="flex items-center justify-between">
              <h3 className="text-base font-bold text-white flex items-center gap-2">
                <Send className="w-4 h-4 text-emerald-400" />
                Disburse Instant Payout (NIP Direct)
              </h3>
              <button
                onClick={() => { setIsPayoutModalOpen(false); setPayoutActionStatus(null); }}
                className="text-slate-400 hover:text-white text-lg font-bold"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleDisbursePayout} className="space-y-4">
              <div>
                <label className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider">
                  Beneficiary Bank (650+ NIBSS Banks)
                </label>
                <select
                  value={payoutBankCode}
                  onChange={e => setPayoutBankCode(e.target.value)}
                  className="w-full mt-1.5 bg-slate-950 border border-slate-800 rounded-xl px-3 py-2.5 text-xs text-white focus:outline-none focus:border-blue-500 font-semibold"
                >
                  <option value="035">Wema Bank (035)</option>
                  <option value="058">GTBank (058)</option>
                  <option value="057">Zenith Bank (057)</option>
                  <option value="011">First Bank of Nigeria (011)</option>
                  <option value="044">Access Bank (044)</option>
                  <option value="033">United Bank for Africa (033)</option>
                  <option value="070">Fidelity Bank (070)</option>
                  <option value="214">First City Monument Bank (214)</option>
                  <option value="221">Stanbic IBTC Bank (221)</option>
                  <option value="232">Sterling Bank (232)</option>
                  <option value="305">OPay / Paycom (305)</option>
                  <option value="100033">PalmPay (100033)</option>
                  <option value="50515">Moniepoint MFB (50515)</option>
                  <option value="50211">Kuda Bank (50211)</option>
                  <option value="101">Providus Bank (101)</option>
                  {banks.map(b => (
                    <option key={b.code} value={b.code}>
                      {b.name} ({b.code})
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider flex items-center justify-between">
                  <span>10-Digit Account Number</span>
                  {isResolvingAccount && (
                    <span className="text-[10px] text-blue-400 flex items-center gap-1">
                      <RefreshCw className="w-2.5 h-2.5 animate-spin" /> Verifying beneficiary...
                    </span>
                  )}
                  {accountResolved && (
                    <span className="text-[10px] text-emerald-400 flex items-center gap-1">
                      <CheckCircle2 className="w-2.5 h-2.5" /> Verified
                    </span>
                  )}
                </label>
                <input
                  type="text"
                  maxLength={10}
                  value={payoutAccNumber}
                  onChange={e => setPayoutAccNumber(e.target.value)}
                  placeholder="e.g. 0123456789"
                  className="w-full mt-1.5 bg-slate-950 border border-slate-800 rounded-xl px-3 py-2.5 text-xs text-white font-mono font-bold focus:outline-none focus:border-blue-500"
                  required
                />
              </div>

              <div>
                <label className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider">
                  Verified Account Holder Name
                </label>
                <input
                  type="text"
                  value={payoutName}
                  onChange={e => setPayoutName(e.target.value)}
                  placeholder="Auto-resolved or enter manually"
                  className={`w-full mt-1.5 bg-slate-950 border rounded-xl px-3 py-2.5 text-xs text-white font-semibold focus:outline-none ${
                    accountResolved ? 'border-emerald-500/50 bg-emerald-500/5 text-emerald-200' : 'border-slate-800 focus:border-blue-500'
                  }`}
                  required
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider">
                    Amount (₦ NGN)
                  </label>
                  <input
                    type="number"
                    value={payoutAmount}
                    onChange={e => setPayoutAmount(e.target.value)}
                    placeholder="e.g. 50000"
                    className="w-full mt-1.5 bg-slate-950 border border-slate-800 rounded-xl px-3 py-2.5 text-sm text-white font-mono font-bold focus:outline-none focus:border-blue-500"
                    required
                  />
                </div>

                <div>
                  <label className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider">
                    Transfer Fee
                  </label>
                  <div className="mt-1.5 bg-slate-950 border border-slate-800 rounded-xl px-3 py-2.5 text-xs text-slate-300 font-mono">
                    ₦50.00 (Fincra NIP)
                  </div>
                </div>
              </div>

              <div>
                <label className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider">
                  Narration / Description
                </label>
                <input
                  type="text"
                  value={payoutDesc}
                  onChange={e => setPayoutDesc(e.target.value)}
                  placeholder="Reason for payment"
                  className="w-full mt-1.5 bg-slate-950 border border-slate-800 rounded-xl px-3 py-2.5 text-xs text-white focus:outline-none focus:border-blue-500"
                />
              </div>

              {payoutActionStatus && (
                <div
                  className={`p-3 rounded-xl text-xs flex items-center gap-2 ${
                    payoutActionStatus.success
                      ? 'bg-emerald-500/10 border border-emerald-500/30 text-emerald-300'
                      : 'bg-rose-500/10 border border-rose-500/30 text-rose-300'
                  }`}
                >
                  {payoutActionStatus.success ? <CheckCircle2 className="w-4 h-4" /> : <AlertCircle className="w-4 h-4" />}
                  {payoutActionStatus.message}
                </div>
              )}

              <div className="pt-2 flex items-center justify-end gap-3">
                <button
                  type="button"
                  onClick={() => setIsPayoutModalOpen(false)}
                  className="px-4 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-xs font-semibold text-slate-300"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmittingPayout || !payoutAmount || !payoutAccNumber}
                  className="px-5 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold transition-all shadow-lg shadow-emerald-600/20 active:scale-95 disabled:opacity-50"
                >
                  {isSubmittingPayout ? 'Disbursing...' : 'Confirm & Send Payout'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ── MODAL 2: GENERATE VIRTUAL ACCOUNT ────────────────────────── */}
      {isAccountModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/75 backdrop-blur-sm p-4 animate-fadeIn">
          <div className="bg-slate-900 border border-slate-800 w-full max-w-lg rounded-2xl p-6 shadow-2xl space-y-5">
            <div className="flex items-center justify-between">
              <h3 className="text-base font-bold text-white flex items-center gap-2">
                <PlusCircle className="w-4 h-4 text-blue-400" />
                Generate Fincra Virtual Account (Wema Bank)
              </h3>
              <button
                onClick={() => { setIsAccountModalOpen(false); setAccActionStatus(null); }}
                className="text-slate-400 hover:text-white text-lg font-bold"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleCreateAccount} className="space-y-4">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider">Account Type</label>
                  <select
                    value={newAccType}
                    onChange={e => setNewAccType(e.target.value as any)}
                    className="w-full mt-1.5 bg-slate-950 border border-slate-800 rounded-xl px-3 py-2.5 text-xs text-white focus:outline-none focus:border-blue-500 font-semibold"
                  >
                    <option value="individual">Individual</option>
                    <option value="corporate">Corporate</option>
                  </select>
                </div>
                <div>
                  <label className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider">Settlement Rail</label>
                  <div className="mt-1.5 bg-slate-950 border border-slate-800 rounded-xl px-3 py-2.5 text-xs text-slate-300 font-semibold">
                    Wema Bank (035)
                  </div>
                </div>
              </div>

              <div>
                <label className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider">User Email Address</label>
                <input
                  type="email"
                  value={newAccEmail}
                  onChange={e => setNewAccEmail(e.target.value)}
                  placeholder="user@myrentilly.com"
                  className="w-full mt-1.5 bg-slate-950 border border-slate-800 rounded-xl px-3 py-2.5 text-xs text-white focus:outline-none focus:border-blue-500"
                  required
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider">First Name</label>
                  <input
                    type="text"
                    value={newAccFirstName}
                    onChange={e => setNewAccFirstName(e.target.value)}
                    placeholder="Patrick"
                    className="w-full mt-1.5 bg-slate-950 border border-slate-800 rounded-xl px-3 py-2.5 text-xs text-white focus:outline-none focus:border-blue-500"
                  />
                </div>
                <div>
                  <label className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider">Last Name</label>
                  <input
                    type="text"
                    value={newAccLastName}
                    onChange={e => setNewAccLastName(e.target.value)}
                    placeholder="Achua"
                    className="w-full mt-1.5 bg-slate-950 border border-slate-800 rounded-xl px-3 py-2.5 text-xs text-white focus:outline-none focus:border-blue-500"
                  />
                </div>
              </div>

              <div>
                <label className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider">
                  Bank Verification Number (BVN)
                </label>
                <input
                  type="text"
                  maxLength={11}
                  value={newAccBvn}
                  onChange={e => setNewAccBvn(e.target.value)}
                  placeholder="11-digit BVN"
                  className="w-full mt-1.5 bg-slate-950 border border-slate-800 rounded-xl px-3 py-2.5 text-xs text-white font-mono font-bold focus:outline-none focus:border-blue-500"
                  required
                />
              </div>

              {accActionStatus && (
                <div
                  className={`p-3 rounded-xl text-xs flex items-center gap-2 ${
                    accActionStatus.success
                      ? 'bg-emerald-500/10 border border-emerald-500/30 text-emerald-300'
                      : 'bg-rose-500/10 border border-rose-500/30 text-rose-300'
                  }`}
                >
                  {accActionStatus.success ? <CheckCircle2 className="w-4 h-4" /> : <AlertCircle className="w-4 h-4" />}
                  {accActionStatus.message}
                </div>
              )}

              <div className="pt-2 flex items-center justify-end gap-3">
                <button
                  type="button"
                  onClick={() => setIsAccountModalOpen(false)}
                  className="px-4 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-xs font-semibold text-slate-300"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isCreatingAcc || !newAccEmail || !newAccBvn}
                  className="px-5 py-2.5 rounded-xl bg-blue-600 hover:bg-blue-500 text-white text-xs font-bold transition-all shadow-lg shadow-blue-600/20 active:scale-95 disabled:opacity-50"
                >
                  {isCreatingAcc ? 'Provisioning...' : 'Provision Account'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ── MODAL 3: COLLECTION RECONCILE TO USER ─────────────────────── */}
      {selectedColForReconcile && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/75 backdrop-blur-sm p-4 animate-fadeIn">
          <div className="bg-slate-900 border border-slate-800 w-full max-w-md rounded-2xl p-6 shadow-2xl space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-base font-bold text-white flex items-center gap-2">
                <ArrowDownLeft className="w-4 h-4 text-emerald-400" />
                Reconcile & Credit Collection
              </h3>
              <button
                onClick={() => setSelectedColForReconcile(null)}
                className="text-slate-400 hover:text-white text-lg font-bold"
              >
                ✕
              </button>
            </div>

            <div className="bg-slate-950 p-4 rounded-xl border border-slate-800 text-xs space-y-2">
              <div className="flex justify-between text-slate-400">
                <span>Amount:</span>
                <span className="font-bold text-emerald-400 font-mono text-sm">
                  ₦{selectedColForReconcile.amount.toLocaleString()}
                </span>
              </div>
              <div className="flex justify-between text-slate-400">
                <span>Payee / Sender:</span>
                <span className="text-slate-200 font-medium">{selectedColForReconcile.payeeName}</span>
              </div>
              <div className="flex justify-between text-slate-400">
                <span>Reference:</span>
                <span className="font-mono text-slate-300">{selectedColForReconcile.reference}</span>
              </div>
            </div>

            <form onSubmit={handleManualReconcile} className="space-y-4">
              <div>
                <label className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider">
                  Target User Email to Credit
                </label>
                <input
                  type="email"
                  value={reconcileEmail}
                  onChange={e => setReconcileEmail(e.target.value)}
                  placeholder="user@myrentilly.com"
                  className="w-full mt-1.5 bg-slate-950 border border-slate-800 rounded-xl px-3 py-2.5 text-xs text-white focus:outline-none focus:border-blue-500 font-medium"
                  required
                />
              </div>

              {reconcileStatus && (
                <div
                  className={`p-3 rounded-xl text-xs flex items-center gap-2 ${
                    reconcileStatus.success
                      ? 'bg-emerald-500/10 border border-emerald-500/30 text-emerald-300'
                      : 'bg-rose-500/10 border border-rose-500/30 text-rose-300'
                  }`}
                >
                  {reconcileStatus.success ? <CheckCircle2 className="w-4 h-4" /> : <AlertCircle className="w-4 h-4" />}
                  {reconcileStatus.message}
                </div>
              )}

              <div className="pt-2 flex items-center justify-end gap-3">
                <button
                  type="button"
                  onClick={() => setSelectedColForReconcile(null)}
                  className="px-4 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-xs font-semibold text-slate-300"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isReconciling || !reconcileEmail}
                  className="px-5 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold transition-all shadow-lg shadow-emerald-600/20 active:scale-95 disabled:opacity-50"
                >
                  {isReconciling ? 'Crediting...' : 'Credit Wallet Now'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
