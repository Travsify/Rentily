import React, { useState, useEffect, useMemo } from 'react';
import {
  Landmark,
  Wallet,
  ArrowRightLeft,
  CreditCard,
  Coins,
  RefreshCw,
  Search,
  CheckCircle2,
  XCircle,
  ArrowUpRight,
  ArrowDownLeft,
  Copy,
  Check,
  AlertCircle,
  ChevronDown,
  ChevronUp,
  X
} from 'lucide-react';

interface CurrencyBalance {
  currency: string;
  treasuryBalance: number;
  spendBalance: number;
  treasuryBalanceMinor: number;
  spendBalanceMinor: number;
  totalBalance: number;
}

interface MapleradTx {
  id: string;
  category: 'usdt' | 'conversion' | 'card' | 'transfer' | 'general';
  type: string;
  entry: 'CREDIT' | 'DEBIT';
  amount: number;
  amountMinor: number;
  currency: string;
  status: string;
  summary: string;
  reference?: string;
  customer?: {
    name?: string;
    email?: string;
    phone?: string;
  } | null;
  sourceOrCounterparty?: string;
  createdAt: string;
  raw?: any;
}

interface WalletsResponse {
  success: boolean;
  timestamp: string;
  currencies: CurrencyBalance[];
  treasuryWallets: any[];
  spendWallets: any[];
  summary: {
    ngnTreasury: number;
    usdTreasury: number;
    usdSpend: number;
    usdTotal: number;
    usdtTreasury: number;
    usdtSpend: number;
    usdtTotal: number;
  };
}

export function MapleradTab() {
  const [walletsData, setWalletsData] = useState<WalletsResponse | null>(null);
  const [transactions, setTransactions] = useState<MapleradTx[]>([]);
  const [txCounts, setTxCounts] = useState<{ all: number; usdt: number; conversion: number; card: number; transfer: number }>({
    all: 0,
    usdt: 0,
    conversion: 0,
    card: 0,
    transfer: 0
  });

  const [activeCategory, setActiveCategory] = useState<'all' | 'usdt' | 'conversion' | 'card' | 'transfer'>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [showOtherCurrencies, setShowOtherCurrencies] = useState(false);

  // Transfer Modal State
  const [isTransferModalOpen, setIsTransferModalOpen] = useState(false);
  const [transferCurrency, setTransferCurrency] = useState('USD');
  const [transferDirection, setTransferDirection] = useState<'TREASURY_TO_SPEND' | 'SPEND_TO_TREASURY'>('TREASURY_TO_SPEND');
  const [transferAmount, setTransferAmount] = useState('');
  const [isSubmittingTransfer, setIsSubmittingTransfer] = useState(false);
  const [transferStatus, setTransferStatus] = useState<{ success?: boolean; message?: string } | null>(null);

  // FX Conversion Modal State
  const [isFxModalOpen, setIsFxModalOpen] = useState(false);
  const [fxSourceCurrency, setFxSourceCurrency] = useState('USDT');
  const [fxTargetCurrency, setFxTargetCurrency] = useState('USD');
  const [fxAmount, setFxAmount] = useState('');
  const [isGettingQuote, setIsGettingQuote] = useState(false);
  const [fxQuote, setFxQuote] = useState<any | null>(null);
  const [isExecutingFx, setIsExecutingFx] = useState(false);
  const [fxStatus, setFxStatus] = useState<{ success?: boolean; message?: string } | null>(null);

  // Load Data
  const fetchAllData = async () => {
    setIsLoading(true);
    setErrorMsg(null);
    try {
      const [wRes, tRes] = await Promise.all([
        fetch('/api/admin/maplerad/wallets'),
        fetch(`/api/admin/maplerad/transactions?category=${activeCategory}`)
      ]);

      if (!wRes.ok) throw new Error(`Wallets fetch failed with ${wRes.status}`);
      if (!tRes.ok) throw new Error(`Transactions fetch failed with ${tRes.status}`);

      const wData = await wRes.json();
      const tData = await tRes.json();

      setWalletsData(wData);
      setTransactions(tData.transactions || []);
      if (tData.counts) {
        setTxCounts(tData.counts);
      }
    } catch (err: any) {
      console.error('[MapleradTab] Fetch error:', err);
      setErrorMsg(err.message || 'Failed to load Maplerad data');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchAllData();
  }, [activeCategory]);

  // Copy to clipboard
  const handleCopy = (text: string, id: string) => {
    navigator.clipboard.writeText(text);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  // Filtered transactions by client search
  const filteredTxs = useMemo(() => {
    if (!searchQuery.trim()) return transactions;
    const q = searchQuery.toLowerCase();
    return transactions.filter(
      (tx) =>
        tx.summary?.toLowerCase().includes(q) ||
        tx.reference?.toLowerCase().includes(q) ||
        tx.currency?.toLowerCase().includes(q) ||
        tx.sourceOrCounterparty?.toLowerCase().includes(q) ||
        tx.customer?.name?.toLowerCase().includes(q) ||
        tx.customer?.email?.toLowerCase().includes(q)
    );
  }, [transactions, searchQuery]);

  // Handle Transfer Submit
  const handleTransferSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!transferAmount || Number(transferAmount) <= 0) return;

    setIsSubmittingTransfer(true);
    setTransferStatus(null);

    const source_wallet_type = transferDirection === 'TREASURY_TO_SPEND' ? 'TREASURY' : 'SPEND';
    const destination_wallet_type = transferDirection === 'TREASURY_TO_SPEND' ? 'SPEND' : 'TREASURY';

    try {
      const res = await fetch('/api/admin/maplerad/transfer-to-spend', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          currency: transferCurrency,
          source_wallet_type,
          destination_wallet_type,
          amount: Number(transferAmount)
        })
      });

      const data = await res.json();
      if (!res.ok || !data.success) {
        throw new Error(data.error || 'Transfer failed');
      }

      setTransferStatus({ success: true, message: data.message });
      setTransferAmount('');
      fetchAllData();
    } catch (err: any) {
      setTransferStatus({ success: false, message: err.message });
    } finally {
      setIsSubmittingTransfer(false);
    }
  };

  // Handle Get FX Quote
  const handleGetFxQuote = async () => {
    if (!fxAmount || Number(fxAmount) <= 0) return;
    setIsGettingQuote(true);
    setFxQuote(null);
    setFxStatus(null);

    try {
      const res = await fetch('/api/admin/maplerad/fx/quote', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          source_currency: fxSourceCurrency,
          target_currency: fxTargetCurrency,
          amount: Number(fxAmount)
        })
      });

      const data = await res.json();
      if (!res.ok || !data.success) {
        throw new Error(data.error || 'Failed to fetch quote');
      }

      setFxQuote(data.quote);
    } catch (err: any) {
      setFxStatus({ success: false, message: err.message });
    } finally {
      setIsGettingQuote(false);
    }
  };

  // Handle Execute FX Exchange
  const handleExecuteFx = async () => {
    if (!fxQuote?.reference) return;
    setIsExecutingFx(true);
    setFxStatus(null);

    try {
      const res = await fetch('/api/admin/maplerad/fx/exchange', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          quote_reference: fxQuote.reference
        })
      });

      const data = await res.json();
      if (!res.ok || !data.success) {
        throw new Error(data.error || 'Exchange execution failed');
      }

      setFxStatus({ success: true, message: 'Exchange completed successfully!' });
      setFxQuote(null);
      setFxAmount('');
      fetchAllData();
    } catch (err: any) {
      setFxStatus({ success: false, message: err.message });
    } finally {
      setIsExecutingFx(false);
    }
  };

  const formatMoney = (val: number, cur = 'USD') => {
    if (cur === 'NGN') {
      return `₦${val.toLocaleString('en-NG', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
    }
    if (cur === 'USDT') {
      return `${val.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} USDT`;
    }
    return `$${val.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
  };

  return (
    <div className="space-y-6">
      {/* ── Header ────────────────────────────────────────────────────────── */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-slate-900/60 p-5 rounded-2xl border border-slate-800">
        <div className="flex items-center gap-3.5">
          <div className="p-3 bg-emerald-500/10 border border-emerald-500/30 rounded-xl text-emerald-400">
            <Landmark className="w-6 h-6" />
          </div>
          <div>
            <div className="flex items-center gap-2.5">
              <h1 className="text-xl font-bold text-white tracking-tight">Maplerad Treasury & Liquidity Desk</h1>
              <span className="flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-[11px] font-semibold bg-emerald-950/80 border border-emerald-800/60 text-emerald-400">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
                Live Connected
              </span>
            </div>
            <p className="text-xs text-slate-400 mt-0.5">
              Whitelisted IPv4 Egress:{' '}
              <span className="font-mono text-emerald-400 font-semibold bg-slate-950/80 px-1.5 py-0.5 rounded border border-slate-800">
                69.62.127.50
              </span>{' '}
              • Real-time multi-currency wallets, TRC20 USDT, FX conversions & card balances.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2.5 flex-wrap">
          <button
            onClick={() => {
              setTransferStatus(null);
              setIsTransferModalOpen(true);
            }}
            className="flex items-center gap-2 px-3.5 py-2 bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold rounded-xl shadow-lg shadow-emerald-950/40 transition"
          >
            <Wallet className="w-3.5 h-3.5" />
            Transfer to Spend Wallet
          </button>

          <button
            onClick={() => {
              setFxQuote(null);
              setFxStatus(null);
              setIsFxModalOpen(true);
            }}
            className="flex items-center gap-2 px-3.5 py-2 bg-purple-600 hover:bg-purple-500 text-white text-xs font-semibold rounded-xl shadow-lg shadow-purple-950/40 transition"
          >
            <ArrowRightLeft className="w-3.5 h-3.5" />
            Convert Currency (FX)
          </button>

          <button
            onClick={fetchAllData}
            disabled={isLoading}
            className="flex items-center gap-1.5 px-3 py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold rounded-xl border border-slate-700/60 transition disabled:opacity-50"
            title="Refresh Maplerad balances & transactions"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${isLoading ? 'animate-spin text-emerald-400' : ''}`} />
            <span>Refresh</span>
          </button>
        </div>
      </div>

      {errorMsg && (
        <div className="p-4 bg-red-950/40 border border-red-800/60 rounded-xl flex items-center gap-3 text-red-300 text-xs">
          <AlertCircle className="w-4 h-4 shrink-0 text-red-400" />
          <span>{errorMsg}</span>
        </div>
      )}

      {/* ── Currency Balances Cards ────────────────────────────────────────── */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {/* NGN Card */}
        <div className="bg-slate-900/70 border border-slate-800 p-5 rounded-2xl relative overflow-hidden group hover:border-emerald-500/30 transition">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2 text-slate-400 text-xs font-semibold uppercase tracking-wider">
              <span className="w-2 h-2 rounded-full bg-emerald-500" />
              <span>Nigerian Naira (NGN)</span>
            </div>
            <span className="text-[11px] px-2 py-0.5 rounded bg-emerald-500/10 text-emerald-400 font-mono border border-emerald-500/20 font-bold">
              TREASURY
            </span>
          </div>

          <div className="mt-3">
            <div className="text-2xl font-black text-white font-mono tracking-tight">
              {walletsData ? formatMoney(walletsData.summary.ngnTreasury, 'NGN') : '₦0.00'}
            </div>
            <p className="text-[11px] text-slate-400 mt-1">
              Active operating pool for Nigerian bank payouts, instant escrow releases & rent disbursements.
            </p>
          </div>

          <div className="mt-4 pt-3 border-t border-slate-800/80 flex items-center justify-between text-xs text-slate-400">
            <span>Spend Wallet:</span>
            <span className="font-mono text-slate-300 font-semibold">₦0.00</span>
          </div>
        </div>

        {/* USD Card */}
        <div className="bg-slate-900/70 border border-slate-800 p-5 rounded-2xl relative overflow-hidden group hover:border-blue-500/30 transition">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2 text-slate-400 text-xs font-semibold uppercase tracking-wider">
              <span className="w-2 h-2 rounded-full bg-blue-500" />
              <span>US Dollar (USD)</span>
            </div>
            <span className="text-[11px] px-2 py-0.5 rounded bg-blue-500/10 text-blue-400 font-mono border border-blue-500/20 font-bold">
              MULTI-WALLET
            </span>
          </div>

          <div className="mt-3">
            <div className="text-2xl font-black text-white font-mono tracking-tight">
              {walletsData ? formatMoney(walletsData.summary.usdTotal, 'USD') : '$0.00'}
            </div>
            <p className="text-[11px] text-slate-400 mt-1">
              Total USD Holdings (Treasury Reserve + Active Spend Wallet Pool).
            </p>
          </div>

          <div className="mt-4 pt-3 border-t border-slate-800/80 space-y-1.5 text-xs">
            <div className="flex items-center justify-between text-slate-400">
              <span>Spend Wallet (Cards):</span>
              <span className="font-mono text-emerald-400 font-bold">
                {walletsData ? formatMoney(walletsData.summary.usdSpend, 'USD') : '$0.00'}
              </span>
            </div>
            <div className="flex items-center justify-between text-slate-400">
              <span>Treasury Balance:</span>
              <span className="font-mono text-slate-300 font-medium">
                {walletsData ? formatMoney(walletsData.summary.usdTreasury, 'USD') : '$0.00'}
              </span>
            </div>
          </div>
        </div>

        {/* USDT Card */}
        <div className="bg-slate-900/70 border border-slate-800 p-5 rounded-2xl relative overflow-hidden group hover:border-teal-500/30 transition">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2 text-slate-400 text-xs font-semibold uppercase tracking-wider">
              <Coins className="w-3.5 h-3.5 text-teal-400" />
              <span>Tether USDT (TRC20)</span>
            </div>
            <span className="text-[11px] px-2 py-0.5 rounded bg-teal-500/10 text-teal-400 font-mono border border-teal-500/20 font-bold">
              CRYPTO VAULT
            </span>
          </div>

          <div className="mt-3">
            <div className="text-2xl font-black text-white font-mono tracking-tight">
              {walletsData ? formatMoney(walletsData.summary.usdtTotal, 'USDT') : '0.00 USDT'}
            </div>
            <p className="text-[11px] text-slate-400 mt-1">
              TRC20 on-chain collections & fast crypto swap reserve.
            </p>
          </div>

          <div className="mt-4 pt-3 border-t border-slate-800/80 space-y-1.5 text-xs">
            <div className="flex items-center justify-between text-slate-400">
              <span>Spend Wallet Balance:</span>
              <span className="font-mono text-teal-400 font-bold">
                {walletsData ? formatMoney(walletsData.summary.usdtSpend, 'USDT') : '0.00 USDT'}
              </span>
            </div>
            <div className="flex items-center justify-between text-slate-400">
              <span>Treasury Vault:</span>
              <span className="font-mono text-slate-300 font-medium">
                {walletsData ? formatMoney(walletsData.summary.usdtTreasury, 'USDT') : '0.00 USDT'}
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* ── Other Maplerad Currencies Accordion ────────────────────────────── */}
      <div className="bg-slate-900/40 border border-slate-800 rounded-xl overflow-hidden">
        <button
          onClick={() => setShowOtherCurrencies(!showOtherCurrencies)}
          className="w-full px-4 py-3 flex items-center justify-between text-xs text-slate-400 hover:text-slate-200 transition"
        >
          <div className="flex items-center gap-2 font-semibold">
            <Coins className="w-3.5 h-3.5 text-slate-400" />
            <span>Other Maplerad Regional & Settlement Currencies (XOF, GHS, KES, ZAR, RWF, TZS, UGX, USDC, PYUSD)</span>
          </div>
          <div className="flex items-center gap-1 text-[11px] text-slate-500">
            <span>{showOtherCurrencies ? 'Hide Currencies' : 'View All'}</span>
            {showOtherCurrencies ? <ChevronUp className="w-3.5 h-3.5" /> : <ChevronDown className="w-3.5 h-3.5" />}
          </div>
        </button>

        {showOtherCurrencies && walletsData && (
          <div className="p-4 pt-0 grid grid-cols-2 sm:grid-cols-3 md:grid-cols-5 gap-2.5 border-t border-slate-800/60">
            {walletsData.currencies
              .filter((c) => !['NGN', 'USD', 'USDT'].includes(c.currency))
              .map((c) => (
                <div key={c.currency} className="p-2.5 rounded-lg bg-slate-950/60 border border-slate-800 text-xs">
                  <div className="text-[10px] text-slate-500 font-bold uppercase">{c.currency}</div>
                  <div className="font-mono text-slate-300 font-semibold mt-0.5">
                    {c.totalBalance.toFixed(2)} {c.currency}
                  </div>
                  <div className="text-[9px] text-slate-500 mt-1">
                    Treasury: {c.treasuryBalance.toFixed(2)} | Spend: {c.spendBalance.toFixed(2)}
                  </div>
                </div>
              ))}
          </div>
        )}
      </div>

      {/* ── Live Transactions Section ─────────────────────────────────────── */}
      <div className="bg-slate-900/60 border border-slate-800 rounded-2xl overflow-hidden">
        {/* Filter Tabs & Search */}
        <div className="p-4 border-b border-slate-800 flex flex-col md:flex-row md:items-center justify-between gap-3">
          {/* Tabs */}
          <div className="flex items-center gap-1.5 overflow-x-auto pb-1 md:pb-0">
            <button
              onClick={() => setActiveCategory('all')}
              className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition whitespace-nowrap flex items-center gap-1.5 ${
                activeCategory === 'all'
                  ? 'bg-emerald-600 text-white shadow-md shadow-emerald-950/50'
                  : 'bg-slate-800/80 text-slate-400 hover:text-white'
              }`}
            >
              <span>All Activities</span>
              <span className="text-[10px] px-1.5 py-0.2 rounded-full bg-white/20">{txCounts.all}</span>
            </button>

            <button
              onClick={() => setActiveCategory('usdt')}
              className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition whitespace-nowrap flex items-center gap-1.5 ${
                activeCategory === 'usdt'
                  ? 'bg-teal-600 text-white shadow-md shadow-teal-950/50'
                  : 'bg-slate-800/80 text-slate-400 hover:text-white'
              }`}
            >
              <Coins className="w-3 h-3" />
              <span>USDT & Crypto</span>
              <span className="text-[10px] px-1.5 py-0.2 rounded-full bg-white/20">{txCounts.usdt}</span>
            </button>

            <button
              onClick={() => setActiveCategory('conversion')}
              className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition whitespace-nowrap flex items-center gap-1.5 ${
                activeCategory === 'conversion'
                  ? 'bg-purple-600 text-white shadow-md shadow-purple-950/50'
                  : 'bg-slate-800/80 text-slate-400 hover:text-white'
              }`}
            >
              <ArrowRightLeft className="w-3 h-3" />
              <span>Conversions / FX</span>
              <span className="text-[10px] px-1.5 py-0.2 rounded-full bg-white/20">{txCounts.conversion}</span>
            </button>

            <button
              onClick={() => setActiveCategory('card')}
              className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition whitespace-nowrap flex items-center gap-1.5 ${
                activeCategory === 'card'
                  ? 'bg-blue-600 text-white shadow-md shadow-blue-950/50'
                  : 'bg-slate-800/80 text-slate-400 hover:text-white'
              }`}
            >
              <CreditCard className="w-3 h-3" />
              <span>Cards</span>
              <span className="text-[10px] px-1.5 py-0.2 rounded-full bg-white/20">{txCounts.card}</span>
            </button>

            <button
              onClick={() => setActiveCategory('transfer')}
              className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition whitespace-nowrap flex items-center gap-1.5 ${
                activeCategory === 'transfer'
                  ? 'bg-amber-600 text-white shadow-md shadow-amber-950/50'
                  : 'bg-slate-800/80 text-slate-400 hover:text-white'
              }`}
            >
              <ArrowUpRight className="w-3 h-3" />
              <span>Bank Transfers</span>
              <span className="text-[10px] px-1.5 py-0.2 rounded-full bg-white/20">{txCounts.transfer}</span>
            </button>
          </div>

          {/* Search Box */}
          <div className="relative w-full md:w-64">
            <Search className="w-3.5 h-3.5 absolute left-3 top-1/2 -translate-y-1/2 text-slate-500" />
            <input
              type="text"
              placeholder="Search reference, summary..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-9 pr-3 py-1.5 text-xs bg-slate-950 border border-slate-800 rounded-xl text-slate-200 placeholder:text-slate-500 focus:outline-none focus:border-emerald-500"
            />
          </div>
        </div>

        {/* Table */}
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="border-b border-slate-800 bg-slate-950/40 text-[11px] font-bold text-slate-400 uppercase tracking-wider">
                <th className="py-3 px-4">Date / Time</th>
                <th className="py-3 px-4">Category</th>
                <th className="py-3 px-4">Type / Flow</th>
                <th className="py-3 px-4">Amount</th>
                <th className="py-3 px-4">Description / Counterparty</th>
                <th className="py-3 px-4">Reference</th>
                <th className="py-3 px-4 text-right">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60 text-xs">
              {filteredTxs.length === 0 ? (
                <tr>
                  <td colSpan={7} className="py-12 text-center text-slate-500">
                    <p className="font-semibold text-slate-400">No transactions found</p>
                    <p className="text-[11px] mt-1">Try switching tabs or clearing your search term.</p>
                  </td>
                </tr>
              ) : (
                filteredTxs.map((tx) => {
                  const isCredit = tx.entry === 'CREDIT';
                  return (
                    <tr key={tx.id} className="hover:bg-slate-800/30 transition">
                      {/* Date */}
                      <td className="py-3 px-4 whitespace-nowrap text-slate-400 text-[11px] font-mono">
                        {new Date(tx.createdAt).toLocaleDateString('en-GB', {
                          day: '2-digit',
                          month: 'short',
                          year: 'numeric'
                        })}{' '}
                        <span className="text-slate-500">
                          {new Date(tx.createdAt).toLocaleTimeString('en-GB', {
                            hour: '2-digit',
                            minute: '2-digit'
                          })}
                        </span>
                      </td>

                      {/* Category Badge */}
                      <td className="py-3 px-4 whitespace-nowrap">
                        {tx.category === 'usdt' && (
                          <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-teal-500/10 text-teal-300 border border-teal-500/30 inline-flex items-center gap-1">
                            <Coins className="w-2.5 h-2.5" />
                            USDT / Crypto
                          </span>
                        )}
                        {tx.category === 'conversion' && (
                          <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-purple-500/10 text-purple-300 border border-purple-500/30 inline-flex items-center gap-1">
                            <ArrowRightLeft className="w-2.5 h-2.5" />
                            FX Exchange
                          </span>
                        )}
                        {tx.category === 'card' && (
                          <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-blue-500/10 text-blue-300 border border-blue-500/30 inline-flex items-center gap-1">
                            <CreditCard className="w-2.5 h-2.5" />
                            Virtual Card
                          </span>
                        )}
                        {tx.category === 'transfer' && (
                          <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-500/10 text-amber-300 border border-amber-500/30 inline-flex items-center gap-1">
                            <ArrowUpRight className="w-2.5 h-2.5" />
                            Bank Payout
                          </span>
                        )}
                        {tx.category === 'general' && (
                          <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-slate-800 text-slate-300 border border-slate-700 inline-flex items-center gap-1">
                            General
                          </span>
                        )}
                      </td>

                      {/* Type & Flow */}
                      <td className="py-3 px-4 whitespace-nowrap">
                        <div className="flex items-center gap-1.5">
                          {isCredit ? (
                            <span className="p-1 rounded bg-emerald-500/10 text-emerald-400">
                              <ArrowDownLeft className="w-3 h-3" />
                            </span>
                          ) : (
                            <span className="p-1 rounded bg-rose-500/10 text-rose-400">
                              <ArrowUpRight className="w-3 h-3" />
                            </span>
                          )}
                          <span className="font-semibold text-slate-300 text-[11px]">{tx.type}</span>
                        </div>
                      </td>

                      {/* Amount */}
                      <td className="py-3 px-4 whitespace-nowrap">
                        <span
                          className={`font-mono font-bold text-xs ${
                            isCredit ? 'text-emerald-400' : 'text-slate-200'
                          }`}
                        >
                          {isCredit ? '+' : '-'}
                          {formatMoney(tx.amount, tx.currency)}
                        </span>
                      </td>

                      {/* Summary & Counterparty */}
                      <td className="py-3 px-4 max-w-md">
                        <div className="font-medium text-slate-200 text-xs truncate" title={tx.summary}>
                          {tx.summary}
                        </div>
                        {tx.sourceOrCounterparty && (
                          <div className="text-[11px] text-slate-400 truncate mt-0.5">
                            {tx.sourceOrCounterparty}
                          </div>
                        )}
                        {tx.customer && (
                          <div className="text-[10px] text-slate-500">
                            User: {tx.customer.name} {tx.customer.email ? `(${tx.customer.email})` : ''}
                          </div>
                        )}
                      </td>

                      {/* Reference */}
                      <td className="py-3 px-4 whitespace-nowrap text-slate-400 font-mono text-[11px]">
                        <button
                          onClick={() => handleCopy(tx.reference || tx.id, tx.id)}
                          className="flex items-center gap-1 hover:text-emerald-400 transition"
                          title="Click to copy reference"
                        >
                          <span className="truncate max-w-[120px]">{tx.reference || tx.id}</span>
                          {copiedId === tx.id ? (
                            <Check className="w-3 h-3 text-emerald-400" />
                          ) : (
                            <Copy className="w-3 h-3 opacity-60" />
                          )}
                        </button>
                      </td>

                      {/* Status */}
                      <td className="py-3 px-4 whitespace-nowrap text-right">
                        {tx.status === 'SUCCESS' && (
                          <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                            SUCCESS
                          </span>
                        )}
                        {tx.status === 'FAILED' && (
                          <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-rose-500/10 text-rose-400 border border-rose-500/30">
                            FAILED
                          </span>
                        )}
                        {tx.status !== 'SUCCESS' && tx.status !== 'FAILED' && (
                          <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-amber-500/10 text-amber-400 border border-amber-500/30">
                            {tx.status}
                          </span>
                        )}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* ── MODAL 1: Transfer to Spend Wallet ─────────────────────────────── */}
      {isTransferModalOpen && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 w-full max-w-md rounded-2xl overflow-hidden shadow-2xl">
            <div className="p-5 border-b border-slate-800 flex items-center justify-between">
              <div className="flex items-center gap-2.5">
                <div className="p-2 bg-emerald-500/10 border border-emerald-500/30 rounded-lg text-emerald-400">
                  <Wallet className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="font-bold text-white text-sm">Internal Wallet Transfer</h3>
                  <p className="text-[11px] text-slate-400">Move funds between Treasury and Spend wallets</p>
                </div>
              </div>
              <button
                onClick={() => setIsTransferModalOpen(false)}
                className="p-1.5 text-slate-400 hover:text-white rounded-lg hover:bg-slate-800 transition"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleTransferSubmit} className="p-5 space-y-4">
              {transferStatus && (
                <div
                  className={`p-3 rounded-xl text-xs flex items-center gap-2.5 ${
                    transferStatus.success
                      ? 'bg-emerald-950/60 border border-emerald-800 text-emerald-300'
                      : 'bg-red-950/60 border border-red-800 text-red-300'
                  }`}
                >
                  {transferStatus.success ? <CheckCircle2 className="w-4 h-4" /> : <XCircle className="w-4 h-4" />}
                  <span>{transferStatus.message}</span>
                </div>
              )}

              {/* Currency */}
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1.5">Currency</label>
                <select
                  value={transferCurrency}
                  onChange={(e) => setTransferCurrency(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white focus:outline-none focus:border-emerald-500"
                >
                  <option value="USD">USD - US Dollar (Virtual Cards Pool)</option>
                  <option value="USDT">USDT - Tether (TRC20)</option>
                  <option value="NGN">NGN - Nigerian Naira</option>
                </select>
              </div>

              {/* Direction */}
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1.5">Transfer Direction</label>
                <div className="grid grid-cols-2 gap-2">
                  <button
                    type="button"
                    onClick={() => setTransferDirection('TREASURY_TO_SPEND')}
                    className={`p-3 rounded-xl border text-xs text-left transition ${
                      transferDirection === 'TREASURY_TO_SPEND'
                        ? 'bg-emerald-600/10 border-emerald-500 text-emerald-300'
                        : 'bg-slate-950 border-slate-800 text-slate-400 hover:border-slate-700'
                    }`}
                  >
                    <div className="font-bold text-[11px]">TREASURY ➔ SPEND</div>
                    <div className="text-[10px] text-slate-500 mt-0.5">Fund virtual cards pool</div>
                  </button>

                  <button
                    type="button"
                    onClick={() => setTransferDirection('SPEND_TO_TREASURY')}
                    className={`p-3 rounded-xl border text-xs text-left transition ${
                      transferDirection === 'SPEND_TO_TREASURY'
                        ? 'bg-emerald-600/10 border-emerald-500 text-emerald-300'
                        : 'bg-slate-950 border-slate-800 text-slate-400 hover:border-slate-700'
                    }`}
                  >
                    <div className="font-bold text-[11px]">SPEND ➔ TREASURY</div>
                    <div className="text-[10px] text-slate-500 mt-0.5">Return to treasury vault</div>
                  </button>
                </div>
              </div>

              {/* Amount */}
              <div>
                <div className="flex items-center justify-between mb-1.5">
                  <label className="text-xs font-semibold text-slate-300">Amount ({transferCurrency})</label>
                  {walletsData && (
                    <span className="text-[11px] text-slate-500 font-mono">
                      Available:{' '}
                      {transferDirection === 'TREASURY_TO_SPEND'
                        ? formatMoney(
                            transferCurrency === 'USD'
                              ? walletsData.summary.usdTreasury
                              : transferCurrency === 'USDT'
                              ? walletsData.summary.usdtTreasury
                              : walletsData.summary.ngnTreasury,
                            transferCurrency
                          )
                        : formatMoney(
                            transferCurrency === 'USD'
                              ? walletsData.summary.usdSpend
                              : transferCurrency === 'USDT'
                              ? walletsData.summary.usdtSpend
                              : 0,
                            transferCurrency
                          )}
                    </span>
                  )}
                </div>
                <input
                  type="number"
                  step="0.01"
                  min="0.01"
                  placeholder="e.g. 50.00"
                  value={transferAmount}
                  onChange={(e) => setTransferAmount(e.target.value)}
                  required
                  className="w-full px-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-sm font-mono text-white placeholder:text-slate-600 focus:outline-none focus:border-emerald-500"
                />
              </div>

              <div className="pt-2 flex items-center justify-end gap-2.5">
                <button
                  type="button"
                  onClick={() => setIsTransferModalOpen(false)}
                  className="px-4 py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded-xl text-xs font-semibold transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmittingTransfer}
                  className="px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white rounded-xl text-xs font-semibold transition flex items-center gap-1.5 disabled:opacity-50"
                >
                  {isSubmittingTransfer && <RefreshCw className="w-3.5 h-3.5 animate-spin" />}
                  <span>{isSubmittingTransfer ? 'Transferring...' : 'Confirm Transfer'}</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ── MODAL 2: FX Conversion & Exchange ─────────────────────────────── */}
      {isFxModalOpen && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 w-full max-w-md rounded-2xl overflow-hidden shadow-2xl">
            <div className="p-5 border-b border-slate-800 flex items-center justify-between">
              <div className="flex items-center gap-2.5">
                <div className="p-2 bg-purple-500/10 border border-purple-500/30 rounded-lg text-purple-400">
                  <ArrowRightLeft className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="font-bold text-white text-sm">Currency Exchange (FX)</h3>
                  <p className="text-[11px] text-slate-400">Instant on-chain quote & liquidity swap</p>
                </div>
              </div>
              <button
                onClick={() => setIsFxModalOpen(false)}
                className="p-1.5 text-slate-400 hover:text-white rounded-lg hover:bg-slate-800 transition"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="p-5 space-y-4">
              {fxStatus && (
                <div
                  className={`p-3 rounded-xl text-xs flex items-center gap-2.5 ${
                    fxStatus.success
                      ? 'bg-emerald-950/60 border border-emerald-800 text-emerald-300'
                      : 'bg-red-950/60 border border-red-800 text-red-300'
                  }`}
                >
                  {fxStatus.success ? <CheckCircle2 className="w-4 h-4" /> : <XCircle className="w-4 h-4" />}
                  <span>{fxStatus.message}</span>
                </div>
              )}

              {/* From / To currencies */}
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-1.5">Convert From</label>
                  <select
                    value={fxSourceCurrency}
                    onChange={(e) => {
                      setFxSourceCurrency(e.target.value);
                      setFxQuote(null);
                    }}
                    className="w-full px-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white focus:outline-none focus:border-purple-500"
                  >
                    <option value="USDT">USDT (Tether)</option>
                    <option value="USD">USD (Dollar)</option>
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-1.5">Convert To</label>
                  <select
                    value={fxTargetCurrency}
                    onChange={(e) => {
                      setFxTargetCurrency(e.target.value);
                      setFxQuote(null);
                    }}
                    className="w-full px-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white focus:outline-none focus:border-purple-500"
                  >
                    <option value="USD">USD (Dollar)</option>
                    <option value="NGN">NGN (Naira)</option>
                    <option value="USDT">USDT (Tether)</option>
                  </select>
                </div>
              </div>

              {/* Amount */}
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                  Amount to Convert ({fxSourceCurrency})
                </label>
                <div className="flex gap-2">
                  <input
                    type="number"
                    step="0.01"
                    min="0.01"
                    placeholder="e.g. 10.00"
                    value={fxAmount}
                    onChange={(e) => {
                      setFxAmount(e.target.value);
                      setFxQuote(null);
                    }}
                    className="w-full px-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-sm font-mono text-white placeholder:text-slate-600 focus:outline-none focus:border-purple-500"
                  />
                  <button
                    type="button"
                    onClick={handleGetFxQuote}
                    disabled={isGettingQuote || !fxAmount}
                    className="px-3 py-2 bg-purple-600 hover:bg-purple-500 text-white text-xs font-semibold rounded-xl transition whitespace-nowrap disabled:opacity-50 flex items-center gap-1"
                  >
                    {isGettingQuote ? <RefreshCw className="w-3.5 h-3.5 animate-spin" /> : 'Get Quote'}
                  </button>
                </div>
              </div>

              {/* Quote Display */}
              {fxQuote && (
                <div className="p-4 rounded-xl bg-purple-950/30 border border-purple-800/60 space-y-2">
                  <div className="flex items-center justify-between text-xs">
                    <span className="text-slate-400">Live Rate:</span>
                    <span className="font-mono text-purple-300 font-bold">
                      1 {fxQuote.source?.currency} = {fxQuote.rate} {fxQuote.target?.currency}
                    </span>
                  </div>
                  <div className="flex items-center justify-between text-xs">
                    <span className="text-slate-400">You Receive:</span>
                    <span className="font-mono text-emerald-400 font-bold text-sm">
                      {fxQuote.target?.human_readable_amount} {fxQuote.target?.currency}
                    </span>
                  </div>
                  <div className="flex items-center justify-between text-[11px] text-slate-500 pt-1 border-t border-purple-800/40">
                    <span>Reference:</span>
                    <span className="font-mono text-slate-400">{fxQuote.reference?.substring(0, 16)}...</span>
                  </div>
                </div>
              )}

              <div className="pt-2 flex items-center justify-end gap-2.5">
                <button
                  type="button"
                  onClick={() => setIsFxModalOpen(false)}
                  className="px-4 py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded-xl text-xs font-semibold transition"
                >
                  Close
                </button>
                {fxQuote && (
                  <button
                    type="button"
                    onClick={handleExecuteFx}
                    disabled={isExecutingFx}
                    className="px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white rounded-xl text-xs font-semibold transition flex items-center gap-1.5 disabled:opacity-50"
                  >
                    {isExecutingFx && <RefreshCw className="w-3.5 h-3.5 animate-spin" />}
                    <span>{isExecutingFx ? 'Executing...' : 'Execute Swap'}</span>
                  </button>
                )}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
