import React, { useState, useEffect } from 'react';
import {
  Globe,
  GraduationCap,
  Save,
  CheckCircle2,
  AlertCircle,
  RefreshCw,
  Search,
  ShieldCheck,
  Zap,
  Sliders,
  Clock
} from 'lucide-react';

interface GlobalPayConfig {
  fxSpreadPercent: number;
  corridorFeesNgn: {
    gbpFpsNgn: number;
    eurSepaNgn: number;
    usdWireNgn: number;
    usdSwiftNgn: number;
    cadEftNgn: number;
  };
  tuitionSemesterLimitUsd: number;
  supplierInvoiceLimitUsd: number;
  featureEnabled: boolean;
  supportedCurrencies: string[];
}

interface OrderItem {
  id: string;
  reference: string;
  userId: string;
  userEmail?: string;
  orderType: 'tuition' | 'supplier';
  destinationCurrency: string;
  destinationAmount: number;
  sourceAmountNgn: number;
  totalDebitedNgn: number;
  customerRate: number;
  corridorFeeNgn: number;
  paymentScheme: string;
  status: 'SUBMITTED' | 'PROCESSING' | 'COMPLETED' | 'FAILED_REFUNDED';
  studentName?: string;
  institutionName?: string;
  invoiceNumber?: string;
  fincraPayoutReference?: string;
  createdAt: string;
}

export const GlobalPayTab: React.FC = () => {
  const [config, setConfig] = useState<GlobalPayConfig>({
    fxSpreadPercent: 1.20,
    corridorFeesNgn: {
      gbpFpsNgn: 3000,
      eurSepaNgn: 5000,
      usdWireNgn: 7500,
      usdSwiftNgn: 15000,
      cadEftNgn: 5000
    },
    tuitionSemesterLimitUsd: 25000,
    supplierInvoiceLimitUsd: 100000,
    featureEnabled: true,
    supportedCurrencies: ['USD', 'GBP', 'EUR', 'CAD']
  });

  const [orders, setOrders] = useState<OrderItem[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [saving, setSaving] = useState<boolean>(false);
  const [saveSuccess, setSaveSuccess] = useState<boolean>(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [filterType, setFilterType] = useState<string>('all');
  const [searchQuery, setSearchQuery] = useState<string>('');

  // Rate calculator test state
  const [calcCurr, setCalcCurr] = useState<'USD' | 'GBP' | 'EUR' | 'CAD'>('GBP');
  const [calcAmt, setCalcAmt] = useState<number>(5000);

  const fetchConfigAndOrders = async () => {
    setLoading(true);
    setErrorMsg(null);
    try {
      const [cfgRes, ordRes] = await Promise.all([
        fetch('/api/admin/global-pay/config').then(r => r.json()).catch(() => null),
        fetch('/api/admin/global-pay/orders').then(r => r.json()).catch(() => null)
      ]);

      if (cfgRes?.status && cfgRes?.data) {
        setConfig(cfgRes.data);
      }
      if (ordRes?.status && Array.isArray(ordRes?.data)) {
        setOrders(ordRes.data);
      }
    } catch (err: any) {
      setErrorMsg(err.message || 'Failed to fetch Global Pay data.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchConfigAndOrders();
  }, []);

  const handleSaveConfig = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setSaveSuccess(false);
    setErrorMsg(null);

    try {
      const res = await fetch('/api/admin/global-pay/config', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(config)
      });
      const data = await res.json();
      if (data.status) {
        setSaveSuccess(true);
        setTimeout(() => setSaveSuccess(false), 4000);
      } else {
        setErrorMsg(data.error || 'Failed to save configuration');
      }
    } catch (err: any) {
      setErrorMsg(err.message || 'Network error while saving');
    } finally {
      setSaving(false);
    }
  };

  const handleManualRefund = async (reference: string) => {
    if (!confirm(`Are you sure you want to trigger a manual emergency reversal and 100% refund for order ${reference}?`)) {
      return;
    }

    try {
      const res = await fetch('/api/admin/global-pay/orders/refund', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ reference, reason: 'Admin manual intervention' })
      });
      const data = await res.json();
      if (data.status) {
        alert(`Order ${reference} refunded successfully!`);
        fetchConfigAndOrders();
      } else {
        alert(data.error || 'Refund failed');
      }
    } catch (e: any) {
      alert(e.message || 'Failed to contact refund API');
    }
  };

  // Calculation simulation
  const benchmarkRate = calcCurr === 'GBP' ? 2025.50 : calcCurr === 'EUR' ? 1685.20 : calcCurr === 'CAD' ? 1142.80 : 1550.00;
  const simulatedCustRate = Math.round(benchmarkRate * (1 + config.fxSpreadPercent / 100) * 100) / 100;
  const simulatedCorridorFee = calcCurr === 'GBP' ? config.corridorFeesNgn.gbpFpsNgn : calcCurr === 'EUR' ? config.corridorFeesNgn.eurSepaNgn : calcCurr === 'CAD' ? config.corridorFeesNgn.cadEftNgn : config.corridorFeesNgn.usdSwiftNgn;
  const simulatedTotalNgn = Math.round(calcAmt * simulatedCustRate) + simulatedCorridorFee;

  const filteredOrders = orders.filter(o => {
    if (filterType !== 'all' && o.orderType !== filterType) return false;
    if (!searchQuery) return true;
    const q = searchQuery.toLowerCase();
    return (
      o.reference.toLowerCase().includes(q) ||
      (o.userEmail || '').toLowerCase().includes(q) ||
      (o.studentName || '').toLowerCase().includes(q) ||
      (o.institutionName || '').toLowerCase().includes(q)
    );
  });

  return (
    <div className="p-6 max-w-7xl mx-auto space-y-6">
      {/* Header Banner */}
      <div className="bg-gradient-to-r from-emerald-950 via-slate-900 to-indigo-950 border border-emerald-500/20 rounded-2xl p-6 shadow-xl relative overflow-hidden">
        <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4 relative z-10">
          <div>
            <div className="flex items-center gap-2 mb-1">
              <span className="bg-emerald-500/20 text-emerald-300 text-xs px-2.5 py-0.5 rounded-full font-semibold border border-emerald-500/30 flex items-center gap-1">
                <Globe className="w-3 h-3 text-emerald-400" /> Fincra Cross-Border Rails
              </span>
              <span className="bg-blue-500/20 text-blue-300 text-xs px-2.5 py-0.5 rounded-full font-semibold border border-blue-500/30">
                100% Atomic Balance Holds
              </span>
            </div>
            <h1 className="text-2xl md:text-3xl font-extrabold text-white tracking-tight flex items-center gap-3">
              Rentilly Global Pay <span className="text-emerald-400 text-lg font-normal">Administration Desk</span>
            </h1>
            <p className="text-slate-400 text-sm mt-1 max-w-2xl">
              Real-time cross-border disbursement pricing, FX spread markup engine, corridor fees, and international tuition & overseas supplier payment monitoring.
            </p>
          </div>

          <div className="flex items-center gap-3">
            <button
              onClick={fetchConfigAndOrders}
              className="px-3.5 py-2 rounded-xl bg-slate-800/80 hover:bg-slate-700 text-slate-200 border border-slate-700 text-sm font-medium transition flex items-center gap-2"
            >
              <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
              Refresh
            </button>
          </div>
        </div>
      </div>

      {/* Notifications */}
      {saveSuccess && (
        <div className="bg-emerald-950/80 border border-emerald-500/40 text-emerald-200 px-4 py-3 rounded-xl flex items-center gap-3">
          <CheckCircle2 className="w-5 h-5 text-emerald-400 flex-shrink-0" />
          <span className="text-sm font-medium">Pricing and corridor configuration saved successfully! Active immediately.</span>
        </div>
      )}
      {errorMsg && (
        <div className="bg-rose-950/80 border border-rose-500/40 text-rose-200 px-4 py-3 rounded-xl flex items-center gap-3">
          <AlertCircle className="w-5 h-5 text-rose-400 flex-shrink-0" />
          <span className="text-sm font-medium">{errorMsg}</span>
        </div>
      )}

      {/* 2-Column Grid: Config Controls & Live Calculator */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left Column: Admin Pricing Form (2 cols) */}
        <div className="lg:col-span-2 bg-slate-900 border border-slate-800 rounded-2xl p-6 shadow-sm">
          <div className="flex items-center justify-between pb-4 border-b border-slate-800 mb-6">
            <div className="flex items-center gap-2">
              <Sliders className="w-5 h-5 text-emerald-400" />
              <h2 className="text-lg font-bold text-white">Dynamic Pricing & Spread Controls</h2>
            </div>
            <label className="flex items-center gap-2 cursor-pointer">
              <input
                type="checkbox"
                checked={config.featureEnabled}
                onChange={e => setConfig({ ...config, featureEnabled: e.target.checked })}
                className="w-4 h-4 text-emerald-500 rounded border-slate-700 focus:ring-emerald-400"
              />
              <span className={`text-xs font-semibold ${config.featureEnabled ? 'text-emerald-400' : 'text-slate-500'}`}>
                {config.featureEnabled ? '● Feature Live' : '○ Disabled'}
              </span>
            </label>
          </div>

          <form onSubmit={handleSaveConfig} className="space-y-6">
            {/* FX Spread Slider & Input */}
            <div className="bg-slate-800/40 border border-slate-800 rounded-xl p-4 space-y-3">
              <div className="flex justify-between items-center">
                <div>
                  <label className="text-sm font-bold text-white">Platform FX Spread Margin</label>
                  <p className="text-xs text-slate-400">Added to Fincra wholesale rate on every conversion.</p>
                </div>
                <div className="flex items-center gap-1.5 bg-slate-800 px-3 py-1.5 rounded-lg border border-slate-700">
                  <input
                    type="number"
                    step="0.05"
                    min="0"
                    max="10"
                    value={config.fxSpreadPercent}
                    onChange={e => setConfig({ ...config, fxSpreadPercent: parseFloat(e.target.value) || 0 })}
                    className="w-16 bg-transparent text-right text-emerald-400 font-bold focus:outline-none"
                  />
                  <span className="text-slate-400 text-sm font-bold">%</span>
                </div>
              </div>
              <input
                type="range"
                min="0.2"
                max="5.0"
                step="0.05"
                value={config.fxSpreadPercent}
                onChange={e => setConfig({ ...config, fxSpreadPercent: parseFloat(e.target.value) || 0 })}
                className="w-full accent-emerald-500 cursor-pointer"
              />
              <div className="flex justify-between text-xs text-slate-500">
                <span>0.20% (Ultra Thin)</span>
                <span>1.20% (Recommended Standard)</span>
                <span>5.00% (High Spread)</span>
              </div>
            </div>

            {/* Corridor Flat Fees */}
            <div>
              <h3 className="text-sm font-bold text-slate-200 mb-3 flex items-center gap-2">
                <Globe className="w-4 h-4 text-indigo-400" /> Corridor Network Flat Fees (₦ NGN)
              </h3>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="bg-slate-800/40 border border-slate-800 rounded-xl p-3.5">
                  <label className="text-xs text-slate-400 block mb-1">🇬🇧 UK Faster Payments (FPS)</label>
                  <div className="flex items-center gap-2">
                    <span className="text-slate-500 font-bold">₦</span>
                    <input
                      type="number"
                      value={config.corridorFeesNgn.gbpFpsNgn}
                      onChange={e => setConfig({
                        ...config,
                        corridorFeesNgn: { ...config.corridorFeesNgn, gbpFpsNgn: parseInt(e.target.value) || 0 }
                      })}
                      className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-1.5 text-white font-medium focus:border-emerald-500 focus:outline-none"
                    />
                  </div>
                </div>

                <div className="bg-slate-800/40 border border-slate-800 rounded-xl p-3.5">
                  <label className="text-xs text-slate-400 block mb-1">🇪🇺 EU SEPA / Instant</label>
                  <div className="flex items-center gap-2">
                    <span className="text-slate-500 font-bold">₦</span>
                    <input
                      type="number"
                      value={config.corridorFeesNgn.eurSepaNgn}
                      onChange={e => setConfig({
                        ...config,
                        corridorFeesNgn: { ...config.corridorFeesNgn, eurSepaNgn: parseInt(e.target.value) || 0 }
                      })}
                      className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-1.5 text-white font-medium focus:border-emerald-500 focus:outline-none"
                    />
                  </div>
                </div>

                <div className="bg-slate-800/40 border border-slate-800 rounded-xl p-3.5">
                  <label className="text-xs text-slate-400 block mb-1">🇺🇸 US Fedwire / ACH</label>
                  <div className="flex items-center gap-2">
                    <span className="text-slate-500 font-bold">₦</span>
                    <input
                      type="number"
                      value={config.corridorFeesNgn.usdWireNgn}
                      onChange={e => setConfig({
                        ...config,
                        corridorFeesNgn: { ...config.corridorFeesNgn, usdWireNgn: parseInt(e.target.value) || 0 }
                      })}
                      className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-1.5 text-white font-medium focus:border-emerald-500 focus:outline-none"
                    />
                  </div>
                </div>

                <div className="bg-slate-800/40 border border-slate-800 rounded-xl p-3.5">
                  <label className="text-xs text-slate-400 block mb-1">🌐 Global SWIFT Wire</label>
                  <div className="flex items-center gap-2">
                    <span className="text-slate-500 font-bold">₦</span>
                    <input
                      type="number"
                      value={config.corridorFeesNgn.usdSwiftNgn}
                      onChange={e => setConfig({
                        ...config,
                        corridorFeesNgn: { ...config.corridorFeesNgn, usdSwiftNgn: parseInt(e.target.value) || 0 }
                      })}
                      className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-1.5 text-white font-medium focus:border-emerald-500 focus:outline-none"
                    />
                  </div>
                </div>

                <div className="bg-slate-800/40 border border-slate-800 rounded-xl p-3.5 sm:col-span-2">
                  <label className="text-xs text-slate-400 block mb-1">🇨🇦 Canada EFT / Direct</label>
                  <div className="flex items-center gap-2">
                    <span className="text-slate-500 font-bold">₦</span>
                    <input
                      type="number"
                      value={config.corridorFeesNgn.cadEftNgn}
                      onChange={e => setConfig({
                        ...config,
                        corridorFeesNgn: { ...config.corridorFeesNgn, cadEftNgn: parseInt(e.target.value) || 0 }
                      })}
                      className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-1.5 text-white font-medium focus:border-emerald-500 focus:outline-none"
                    />
                  </div>
                </div>
              </div>
            </div>

            {/* Transaction Limits */}
            <div>
              <h3 className="text-sm font-bold text-slate-200 mb-3 flex items-center gap-2">
                <ShieldCheck className="w-4 h-4 text-emerald-400" /> Compliance Limits (USD Equivalent)
              </h3>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="bg-slate-800/40 border border-slate-800 rounded-xl p-3.5">
                  <label className="text-xs text-slate-400 block mb-1">🎓 Max Tuition / Semester</label>
                  <div className="flex items-center gap-2">
                    <span className="text-slate-500 font-bold">$</span>
                    <input
                      type="number"
                      value={config.tuitionSemesterLimitUsd}
                      onChange={e => setConfig({ ...config, tuitionSemesterLimitUsd: parseInt(e.target.value) || 0 })}
                      className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-1.5 text-white font-medium focus:border-emerald-500 focus:outline-none"
                    />
                  </div>
                </div>

                <div className="bg-slate-800/40 border border-slate-800 rounded-xl p-3.5">
                  <label className="text-xs text-slate-400 block mb-1">🏢 Max Supplier Invoice</label>
                  <div className="flex items-center gap-2">
                    <span className="text-slate-500 font-bold">$</span>
                    <input
                      type="number"
                      value={config.supplierInvoiceLimitUsd}
                      onChange={e => setConfig({ ...config, supplierInvoiceLimitUsd: parseInt(e.target.value) || 0 })}
                      className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-1.5 text-white font-medium focus:border-emerald-500 focus:outline-none"
                    />
                  </div>
                </div>
              </div>
            </div>

            <button
              type="submit"
              disabled={saving}
              className="w-full py-3 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold transition flex items-center justify-center gap-2 shadow-lg shadow-emerald-900/30"
            >
              <Save className="w-4 h-4" />
              {saving ? 'Saving Changes...' : 'Save Global Pay Configuration'}
            </button>
          </form>
        </div>

        {/* Right Column: Live Rate Simulation & Calculator */}
        <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6 shadow-sm flex flex-col justify-between">
          <div>
            <div className="flex items-center gap-2 pb-4 border-b border-slate-800 mb-6">
              <Zap className="w-5 h-5 text-amber-400" />
              <h2 className="text-lg font-bold text-white">Live Rate Simulator</h2>
            </div>

            <div className="space-y-4">
              <div>
                <label className="text-xs text-slate-400 block mb-1">Target Currency</label>
                <div className="grid grid-cols-4 gap-2">
                  {(['GBP', 'EUR', 'USD', 'CAD'] as const).map(curr => (
                    <button
                      key={curr}
                      type="button"
                      onClick={() => setCalcCurr(curr)}
                      className={`py-2 rounded-lg text-xs font-bold transition border ${
                        calcCurr === curr
                          ? 'bg-emerald-500/20 text-emerald-400 border-emerald-500/40'
                          : 'bg-slate-800 text-slate-400 border-slate-700 hover:bg-slate-700'
                      }`}
                    >
                      {curr}
                    </button>
                  ))}
                </div>
              </div>

              <div>
                <label className="text-xs text-slate-400 block mb-1">Disbursement Amount ({calcCurr})</label>
                <input
                  type="number"
                  value={calcAmt}
                  onChange={e => setCalcAmt(parseFloat(e.target.value) || 0)}
                  className="w-full bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-white font-bold focus:border-emerald-500 focus:outline-none"
                />
              </div>

              <div className="bg-slate-950/60 rounded-xl p-4 space-y-2.5 border border-slate-800/80 text-sm">
                <div className="flex justify-between text-slate-400">
                  <span>Wholesale Base Rate:</span>
                  <span className="font-mono text-slate-300">₦{benchmarkRate.toLocaleString()}/{calcCurr}</span>
                </div>
                <div className="flex justify-between text-slate-400">
                  <span>Rentilly Spread (+{config.fxSpreadPercent}%):</span>
                  <span className="font-mono text-emerald-400">₦{(simulatedCustRate - benchmarkRate).toFixed(2)}</span>
                </div>
                <div className="flex justify-between text-slate-400">
                  <span>Customer Rate:</span>
                  <span className="font-mono text-white font-bold">₦{simulatedCustRate.toLocaleString()}/{calcCurr}</span>
                </div>
                <div className="flex justify-between text-slate-400">
                  <span>Corridor Rail Flat Fee:</span>
                  <span className="font-mono text-indigo-400 font-semibold">₦{simulatedCorridorFee.toLocaleString()}</span>
                </div>
                <div className="border-t border-slate-800 pt-2 flex justify-between items-center">
                  <span className="text-white font-bold">Total Wallet Debit:</span>
                  <span className="text-lg font-black text-emerald-400 font-mono">
                    ₦{simulatedTotalNgn.toLocaleString()}
                  </span>
                </div>
              </div>
            </div>
          </div>

          <div className="mt-6 pt-4 border-t border-slate-800 text-xs text-slate-500 space-y-1">
            <p className="flex items-center gap-1.5">
              <Clock className="w-3.5 h-3.5 text-slate-400" /> Guaranteed quote duration: 15 minutes.
            </p>
            <p className="flex items-center gap-1.5">
              <ShieldCheck className="w-3.5 h-3.5 text-slate-400" /> Funds held atomically until rail confirms.
            </p>
          </div>
        </div>
      </div>

      {/* Orders & Transfer Monitoring Table */}
      <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6 shadow-sm">
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 mb-6">
          <div>
            <h2 className="text-lg font-bold text-white flex items-center gap-2">
              <GraduationCap className="w-5 h-5 text-indigo-400" /> Cross-Border Tuition & Supplier Orders
            </h2>
            <p className="text-xs text-slate-400">Live feed of all international payouts across university and vendor corridors.</p>
          </div>

          <div className="flex flex-wrap items-center gap-3 w-full sm:w-auto">
            {/* Filter Tabs */}
            <div className="flex bg-slate-800 p-1 rounded-xl border border-slate-700 text-xs">
              <button
                onClick={() => setFilterType('all')}
                className={`px-3 py-1.5 rounded-lg font-medium transition ${
                  filterType === 'all' ? 'bg-emerald-600 text-white' : 'text-slate-400 hover:text-white'
                }`}
              >
                All
              </button>
              <button
                onClick={() => setFilterType('tuition')}
                className={`px-3 py-1.5 rounded-lg font-medium transition ${
                  filterType === 'tuition' ? 'bg-indigo-600 text-white' : 'text-slate-400 hover:text-white'
                }`}
              >
                🎓 Tuition
              </button>
              <button
                onClick={() => setFilterType('supplier')}
                className={`px-3 py-1.5 rounded-lg font-medium transition ${
                  filterType === 'supplier' ? 'bg-amber-600 text-white' : 'text-slate-400 hover:text-white'
                }`}
              >
                🏢 Supplier
              </button>
            </div>

            {/* Search Input */}
            <div className="relative flex-1 sm:w-64">
              <Search className="w-4 h-4 text-slate-500 absolute left-3 top-2.5" />
              <input
                type="text"
                placeholder="Search ref, student, school..."
                value={searchQuery}
                onChange={e => setSearchQuery(e.target.value)}
                className="w-full bg-slate-800 border border-slate-700 rounded-xl pl-9 pr-3 py-1.5 text-xs text-white focus:outline-none focus:border-emerald-500"
              />
            </div>
          </div>
        </div>

        {/* Orders Table */}
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-800/60 text-slate-400 uppercase font-semibold border-b border-slate-800">
              <tr>
                <th className="py-3 px-4">Order Ref / Date</th>
                <th className="py-3 px-4">Type & Details</th>
                <th className="py-3 px-4">Foreign Amount</th>
                <th className="py-3 px-4">Naira Debited</th>
                <th className="py-3 px-4">Rail / Scheme</th>
                <th className="py-3 px-4">Status</th>
                <th className="py-3 px-4 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800">
              {filteredOrders.length === 0 ? (
                <tr>
                  <td colSpan={7} className="py-8 text-center text-slate-500">
                    No international orders found matching your criteria.
                  </td>
                </tr>
              ) : (
                filteredOrders.map(order => (
                  <tr key={order.reference} className="hover:bg-slate-800/30 transition">
                    <td className="py-3 px-4">
                      <div className="font-mono font-bold text-white">{order.reference}</div>
                      <div className="text-slate-500 text-[11px]">{new Date(order.createdAt).toLocaleDateString()}</div>
                    </td>
                    <td className="py-3 px-4">
                      {order.orderType === 'tuition' ? (
                        <div>
                          <span className="inline-block bg-indigo-500/20 text-indigo-300 font-semibold px-2 py-0.5 rounded text-[10px] mb-1">
                            🎓 TUITION
                          </span>
                          <div className="text-slate-200 font-medium">{order.institutionName || 'University'}</div>
                          <div className="text-slate-400 text-[11px]">{order.studentName || 'Student'}</div>
                        </div>
                      ) : (
                        <div>
                          <span className="inline-block bg-amber-500/20 text-amber-300 font-semibold px-2 py-0.5 rounded text-[10px] mb-1">
                            🏢 SUPPLIER
                          </span>
                          <div className="text-slate-200 font-medium">{order.invoiceNumber ? `Inv #${order.invoiceNumber}` : 'B2B Vendor'}</div>
                          <div className="text-slate-400 text-[11px]">{order.userEmail}</div>
                        </div>
                      )}
                    </td>
                    <td className="py-3 px-4">
                      <span className="text-sm font-bold text-white font-mono">
                        {order.destinationCurrency} {order.destinationAmount?.toLocaleString()}
                      </span>
                      <div className="text-slate-500 text-[10px]">@ ₦{order.customerRate?.toLocaleString()}</div>
                    </td>
                    <td className="py-3 px-4">
                      <span className="text-sm font-bold text-emerald-400 font-mono">
                        ₦{order.totalDebitedNgn?.toLocaleString()}
                      </span>
                      <div className="text-slate-500 text-[10px]">Fee: ₦{order.corridorFeeNgn?.toLocaleString()}</div>
                    </td>
                    <td className="py-3 px-4">
                      <span className="uppercase text-slate-300 font-semibold bg-slate-800 px-2 py-1 rounded">
                        {order.paymentScheme || 'SWIFT'}
                      </span>
                    </td>
                    <td className="py-3 px-4">
                      <span
                        className={`inline-block px-2.5 py-1 rounded-full text-[11px] font-bold ${
                          order.status === 'COMPLETED'
                            ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/30'
                            : order.status === 'PROCESSING'
                            ? 'bg-amber-500/20 text-amber-300 border border-amber-500/30'
                            : 'bg-rose-500/20 text-rose-300 border border-rose-500/30'
                        }`}
                      >
                        {order.status}
                      </span>
                    </td>
                    <td className="py-3 px-4 text-right">
                      {order.status === 'PROCESSING' && (
                        <button
                          onClick={() => handleManualRefund(order.reference)}
                          className="px-2.5 py-1 text-[11px] bg-rose-600/20 text-rose-400 hover:bg-rose-600 hover:text-white rounded border border-rose-500/30 transition"
                        >
                          Refund Hold
                        </button>
                      )}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};
export default GlobalPayTab;
