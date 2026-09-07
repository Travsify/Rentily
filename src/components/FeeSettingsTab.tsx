import React, { useState, useEffect } from 'react';
import { 
  BadgePercent, 
  Save, 
  CheckCircle2, 
  AlertCircle, 
  ArrowUpRight, 
  ArrowDownLeft,
  Zap, 
  Calculator,
  ShieldCheck,
  Building2
} from 'lucide-react';

interface FeeConfig {
  withdrawalFee: number;            // ₦ flat fee on bank withdrawals (default 65)
  corporatePayoutFee: number;       // ₦ flat fee on corporate/B2B disbursements (default 100)
  inflowFeePct: number;             // % fee on inbound collections (default 0.75%)
  inflowFeeCap: number;             // ₦ max cap on inbound collections (default 750)
  inflowFlatFeeHighTicket: number;  // ₦ flat fee for high-ticket rent over threshold (default 600)
  highTicketThreshold: number;      // ₦ threshold for high-ticket flat fee (default 100000)
  inflowPricingMode: 'percentage_capped' | 'tiered_flat' | 'hybrid'; // Default 'percentage_capped'
  fincraBaseInflowCost: number;     // ₦ base cost from Fincra for inbound collections (default 300)
  fincraBaseOutflowCost: number;    // ₦ base cost from Fincra for payouts (default 50)
  usdtWithdrawalFeePct: number;
  electricityFee: number;
  airtimeDataMarginPct: number;
  rentLegalFeePct: number;
  saleEscrowFeePct: number;
  partnerCommissionRentPct: number;
  partnerCommissionSalePct: number;
  depositStampDuty: number;
  minWithdrawal: number;
  maxWithdrawal: number;
  updatedAt?: string;
}

export const FeeSettingsTab: React.FC = () => {
  const [fees, setFees] = useState<FeeConfig>({
    withdrawalFee: 65,
    corporatePayoutFee: 100,
    inflowFeePct: 0.75,
    inflowFeeCap: 750,
    inflowFlatFeeHighTicket: 600,
    highTicketThreshold: 100000,
    inflowPricingMode: 'percentage_capped',
    fincraBaseInflowCost: 300,
    fincraBaseOutflowCost: 50,
    usdtWithdrawalFeePct: 2.0,
    electricityFee: 100,
    airtimeDataMarginPct: 2.5,
    rentLegalFeePct: 10.0,
    saleEscrowFeePct: 5.0,
    partnerCommissionRentPct: 2.5,
    partnerCommissionSalePct: 2.0,
    depositStampDuty: 50,
    minWithdrawal: 500,
    maxWithdrawal: 5000000
  });

  const [saving, setSaving] = useState(false);
  const [statusMessage, setStatusMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

  // Live Simulator State
  const [simAmount, setSimAmount] = useState<number>(500000);

  useEffect(() => {
    fetch('/api/config/fees')
      .then(res => res.json())
      .then(data => {
        if (data.fees) setFees(prev => ({ ...prev, ...data.fees }));
      })
      .catch(() => {});
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setStatusMessage(null);

    try {
      const res = await fetch('/api/config/fees', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(fees)
      });

      if (res.ok) {
        setStatusMessage({ type: 'success', text: 'Platform transaction fees & tariffs successfully updated!' });
      } else {
        throw new Error('Failed to update platform fees.');
      }
    } catch (err: any) {
      setStatusMessage({ type: 'error', text: err.message || 'Error updating tariffs.' });
    } finally {
      setSaving(false);
    }
  };

  // Compute live simulation values
  const computeInflowFee = (amount: number) => {
    if (fees.inflowPricingMode === 'tiered_flat') {
      if (amount >= (fees.highTicketThreshold || 100000)) return fees.inflowFlatFeeHighTicket || 600;
      if (amount > 20000) return 250;
      return 100;
    }
    if (fees.inflowPricingMode === 'hybrid') {
      if (amount >= (fees.highTicketThreshold || 100000)) return fees.inflowFlatFeeHighTicket || 600;
      const pctFee = (amount * (fees.inflowFeePct || 0.75)) / 100;
      return Math.min(pctFee, fees.inflowFeeCap || 750);
    }
    // Default percentage_capped
    const pctFee = (amount * (fees.inflowFeePct || 0.75)) / 100;
    return Math.min(pctFee, fees.inflowFeeCap || 750);
  };

  const simClientFee = computeInflowFee(simAmount);
  const simCompetitorFee = Math.min((simAmount * 1.5) / 100, 2000);
  const simSavings = Math.max(simCompetitorFee - simClientFee, 0);
  const simSavingsPct = simCompetitorFee > 0 ? ((simSavings / simCompetitorFee) * 100).toFixed(0) : '0';
  const simNetProfit = simClientFee - (fees.fincraBaseInflowCost || 300);

  return (
    <div className="space-y-6 font-sans max-w-5xl">
      {/* Header */}
      <div>
        <h1 className="text-xl font-bold text-white flex items-center gap-2">
          <BadgePercent className="w-6 h-6 text-emerald-400" />
          <span>Platform Fee & Tariff Configuration</span>
        </h1>
        <p className="text-xs text-slate-400 mt-0.5">
          Configure inbound collection fees, outbound withdrawal/disbursement charges, underlying provider costs, and real-time margin thresholds.
        </p>
      </div>

      {statusMessage && (
        <div className={`p-4 rounded-xl text-xs flex items-center gap-2 ${
          statusMessage.type === 'success'
            ? 'bg-emerald-500/10 border border-emerald-500/30 text-emerald-300'
            : 'bg-red-500/10 border border-red-500/30 text-red-300'
        }`}>
          {statusMessage.type === 'success' ? <CheckCircle2 className="w-4 h-4 text-emerald-400" /> : <AlertCircle className="w-4 h-4 text-red-400" />}
          <span>{statusMessage.text}</span>
        </div>
      )}

      {/* Interactive Pitch & Profit Margin Simulator */}
      <div className="p-5 rounded-2xl bg-gradient-to-br from-slate-900 to-slate-950 border border-emerald-500/30 space-y-4 shadow-xl">
        <div className="flex flex-wrap items-center justify-between gap-2 pb-3 border-b border-slate-800">
          <div className="flex items-center gap-2">
            <Calculator className="w-5 h-5 text-emerald-400" />
            <h2 className="text-sm font-bold text-white">Live Inflow Collection & Profit Margin Simulator</h2>
          </div>
          <span className="text-[11px] px-2.5 py-1 rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-medium">
            Competitor Comparison (Paystack / Flutterwave)
          </span>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-12 gap-4 items-center">
          <div className="md:col-span-4 space-y-2">
            <label className="text-xs text-slate-300 font-semibold block">
              Simulate Inbound Payment Amount (₦)
            </label>
            <div className="relative">
              <span className="absolute left-3 top-2.5 text-slate-400 font-mono text-sm">₦</span>
              <input
                type="number"
                step="10000"
                value={simAmount}
                onChange={(e) => setSimAmount(Math.max(1000, Number(e.target.value)))}
                className="w-full pl-8 pr-3 py-2 rounded-xl bg-slate-950 border border-slate-700 text-white font-mono text-sm focus:outline-none focus:border-emerald-500"
              />
            </div>
            <div className="flex gap-1.5 pt-1">
              {[50000, 100000, 500000, 1500000].map(val => (
                <button
                  key={val}
                  type="button"
                  onClick={() => setSimAmount(val)}
                  className="px-2 py-1 text-[10px] rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 transition"
                >
                  ₦{(val / 1000).toFixed(0)}k
                </button>
              ))}
            </div>
          </div>

          <div className="md:col-span-8 grid grid-cols-2 sm:grid-cols-4 gap-3 text-center">
            <div className="p-3 rounded-xl bg-slate-950 border border-slate-800">
              <span className="text-[10px] text-slate-400 uppercase font-semibold block">Rentilly Fee</span>
              <span className="text-base font-bold text-emerald-400 font-mono">
                ₦{simClientFee.toLocaleString()}
              </span>
              <span className="text-[9px] text-slate-500 block mt-0.5">
                {fees.inflowPricingMode === 'tiered_flat' ? 'Flat Tariff' : `${fees.inflowFeePct}% (max ₦${fees.inflowFeeCap})`}
              </span>
            </div>

            <div className="p-3 rounded-xl bg-slate-950 border border-slate-800">
              <span className="text-[10px] text-slate-400 uppercase font-semibold block">Paystack Fee</span>
              <span className="text-base font-bold text-rose-400 font-mono">
                ₦{simCompetitorFee.toLocaleString()}
              </span>
              <span className="text-[9px] text-slate-500 block mt-0.5">1.5% (max ₦2,000)</span>
            </div>

            <div className="p-3 rounded-xl bg-slate-950 border border-slate-800">
              <span className="text-[10px] text-slate-400 uppercase font-semibold block">Client Savings</span>
              <span className="text-base font-bold text-blue-400 font-mono">
                ₦{simSavings.toLocaleString()}
              </span>
              <span className="text-[9px] text-blue-300/80 block mt-0.5">Saves {simSavingsPct}% vs Paystack</span>
            </div>

            <div className="p-3 rounded-xl bg-emerald-950/40 border border-emerald-500/40">
              <span className="text-[10px] text-emerald-300 uppercase font-semibold block">Rentilly Profit</span>
              <span className={`text-base font-bold font-mono ${simNetProfit >= 0 ? 'text-emerald-400' : 'text-rose-400'}`}>
                {simNetProfit >= 0 ? `+₦${simNetProfit.toLocaleString()}` : `-₦${Math.abs(simNetProfit).toLocaleString()}`}
              </span>
              <span className="text-[9px] text-emerald-500/90 block mt-0.5">
                After ₦{fees.fincraBaseInflowCost} Fincra cost
              </span>
            </div>
          </div>
        </div>
      </div>

      <form onSubmit={handleSubmit} className="space-y-6">
        {/* INFLOW (COLLECTION) CONFIGURATION */}
        <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 space-y-4">
          <div className="flex items-center justify-between pb-3 border-b border-slate-800">
            <div className="flex items-center gap-2">
              <ArrowDownLeft className="w-5 h-5 text-emerald-400" />
              <div>
                <h2 className="text-sm font-bold text-white">Inflow & Virtual Account Collection Tariffs</h2>
                <p className="text-[11px] text-slate-400">Set what tenants, clients, and partner merchants are charged on inbound bank settlements.</p>
              </div>
            </div>
            <span className="text-[10px] text-emerald-400 font-mono bg-emerald-500/10 px-2 py-0.5 rounded border border-emerald-500/20">
              Provider Cost: ₦{fees.fincraBaseInflowCost ?? 300}
            </span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 text-xs">
            <div className="space-y-1.5">
              <label className="text-slate-300 font-semibold block">
                Inflow Pricing Strategy
              </label>
              <select
                value={fees.inflowPricingMode ?? 'percentage_capped'}
                onChange={(e) => setFees({ ...fees, inflowPricingMode: e.target.value as any })}
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white font-semibold focus:outline-none focus:border-emerald-500"
              >
                <option value="percentage_capped">Percentage with Cap (e.g. 0.75% max ₦750)</option>
                <option value="tiered_flat">Tiered Flat Fee (₦100 / ₦250 / ₦600)</option>
                <option value="hybrid">Hybrid (Percentage below ₦100k, Flat above)</option>
              </select>
              <p className="text-[10px] text-slate-500">Determines how collection fees are computed on incoming bank transfers.</p>
            </div>

            <div className="space-y-1.5">
              <label className="text-slate-300 font-semibold flex items-center justify-between">
                <span>Inflow Percentage Fee (%)</span>
                <span className="text-emerald-400 font-mono font-bold">{fees.inflowFeePct ?? 0.75}%</span>
              </label>
              <input
                type="number"
                step="0.05"
                min="0.1"
                max="5.0"
                value={fees.inflowFeePct ?? 0.75}
                onChange={(e) => setFees({ ...fees, inflowFeePct: Number(e.target.value) })}
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white font-mono focus:outline-none focus:border-emerald-500"
              />
              <p className="text-[10px] text-slate-500">Recommended: 0.75% (Half of Paystack's 1.5%).</p>
            </div>

            <div className="space-y-1.5">
              <label className="text-slate-300 font-semibold block">
                Inflow Maximum Fee Cap (₦)
              </label>
              <input
                type="number"
                step="50"
                value={fees.inflowFeeCap ?? 750}
                onChange={(e) => setFees({ ...fees, inflowFeeCap: Number(e.target.value) })}
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white font-mono focus:outline-none focus:border-emerald-500"
              />
              <p className="text-[10px] text-slate-500">Maximum fee charged regardless of millions transferred (Recommended: ₦750).</p>
            </div>

            <div className="space-y-1.5">
              <label className="text-slate-300 font-semibold block">
                High-Ticket / Rent Flat Fee (₦)
              </label>
              <input
                type="number"
                step="50"
                value={fees.inflowFlatFeeHighTicket ?? 600}
                onChange={(e) => setFees({ ...fees, inflowFlatFeeHighTicket: Number(e.target.value) })}
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white font-mono focus:outline-none focus:border-emerald-500"
              />
              <p className="text-[10px] text-slate-500">Special flat rate for rent payments over threshold (Recommended: ₦600).</p>
            </div>

            <div className="space-y-1.5">
              <label className="text-slate-300 font-semibold block">
                High-Ticket Threshold (₦)
              </label>
              <input
                type="number"
                step="10000"
                value={fees.highTicketThreshold ?? 100000}
                onChange={(e) => setFees({ ...fees, highTicketThreshold: Number(e.target.value) })}
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white font-mono focus:outline-none focus:border-emerald-500"
              />
              <p className="text-[10px] text-slate-500">Amounts above this activate high-ticket flat pricing (default ₦100,000).</p>
            </div>

            <div className="space-y-1.5">
              <label className="text-slate-300 font-semibold block">
                Inbound FGN EMTL Stamp Duty (₦)
              </label>
              <input
                type="number"
                value={fees.depositStampDuty}
                onChange={(e) => setFees({ ...fees, depositStampDuty: Number(e.target.value) })}
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white font-mono focus:outline-none focus:border-emerald-500"
              />
              <p className="text-[10px] text-slate-500">Federal Government electronic money transfer levy on deposits ≥ ₦10,000.</p>
            </div>
          </div>
        </div>

        {/* OUTFLOW (PAYOUT / DISBURSEMENT) CONFIGURATION */}
        <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 space-y-4">
          <div className="flex items-center justify-between pb-3 border-b border-slate-800">
            <div className="flex items-center gap-2">
              <ArrowUpRight className="w-5 h-5 text-blue-400" />
              <div>
                <h2 className="text-sm font-bold text-white">Outflow & Payout Disbursement Tariffs</h2>
                <p className="text-[11px] text-slate-400">Charges applied when users or agencies withdraw funds to commercial bank accounts.</p>
              </div>
            </div>
            <span className="text-[10px] text-blue-400 font-mono bg-blue-500/10 px-2 py-0.5 rounded border border-blue-500/20">
              Provider Cost: ₦{fees.fincraBaseOutflowCost ?? 50}
            </span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 text-xs">
            <div className="space-y-1.5">
              <label className="text-slate-300 font-semibold block">
                Retail Bank Withdrawal Fee (₦)
              </label>
              <input
                type="number"
                value={fees.withdrawalFee}
                onChange={(e) => setFees({ ...fees, withdrawalFee: Number(e.target.value) })}
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white font-mono focus:outline-none focus:border-emerald-500"
              />
              <p className="text-[10px] text-slate-500">
                In-app tenant & landlord withdrawal fee (Recommended: ₦65. Margin: +₦15).
              </p>
            </div>

            <div className="space-y-1.5">
              <label className="text-slate-300 font-semibold block">
                Corporate / Agency Payout Fee (₦)
              </label>
              <input
                type="number"
                value={fees.corporatePayoutFee ?? 100}
                onChange={(e) => setFees({ ...fees, corporatePayoutFee: Number(e.target.value) })}
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white font-mono focus:outline-none focus:border-emerald-500"
              />
              <p className="text-[10px] text-slate-500">
                Bulk / corporate disbursements to vendor & partner banks (Recommended: ₦100. Margin: +₦50).
              </p>
            </div>

            <div className="space-y-1.5">
              <label className="text-slate-300 font-semibold flex items-center justify-between">
                <span>USDT On-Chain Fee (%)</span>
                <span className="text-emerald-400 font-mono font-bold">{fees.usdtWithdrawalFeePct ?? 2.0}%</span>
              </label>
              <input
                type="number"
                step="0.1"
                min="0"
                max="50"
                value={fees.usdtWithdrawalFeePct ?? 2.0}
                onChange={(e) => setFees({ ...fees, usdtWithdrawalFeePct: Number(e.target.value) })}
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white font-mono focus:outline-none focus:border-emerald-500"
              />
              <p className="text-[10px] text-slate-500">Deducted on on-chain USDT (TRC20) withdrawals (default 2.0%).</p>
            </div>

            <div className="space-y-1.5">
              <label className="text-slate-300 font-semibold block">
                Minimum Withdrawal (₦)
              </label>
              <input
                type="number"
                value={fees.minWithdrawal}
                onChange={(e) => setFees({ ...fees, minWithdrawal: Number(e.target.value) })}
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white font-mono focus:outline-none focus:border-emerald-500"
              />
            </div>

            <div className="space-y-1.5">
              <label className="text-slate-300 font-semibold block">
                Maximum Daily Withdrawal (₦)
              </label>
              <input
                type="number"
                value={fees.maxWithdrawal}
                onChange={(e) => setFees({ ...fees, maxWithdrawal: Number(e.target.value) })}
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white font-mono focus:outline-none focus:border-emerald-500"
              />
            </div>

            <div className="space-y-1.5">
              <label className="text-slate-300 font-semibold block">
                Provider Base Costs (Fincra)
              </label>
              <div className="grid grid-cols-2 gap-2">
                <input
                  type="number"
                  title="Fincra Inflow Cost"
                  value={fees.fincraBaseInflowCost ?? 300}
                  onChange={(e) => setFees({ ...fees, fincraBaseInflowCost: Number(e.target.value) })}
                  className="w-full px-2 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-400 font-mono text-[11px]"
                />
                <input
                  type="number"
                  title="Fincra Outflow Cost"
                  value={fees.fincraBaseOutflowCost ?? 50}
                  onChange={(e) => setFees({ ...fees, fincraBaseOutflowCost: Number(e.target.value) })}
                  className="w-full px-2 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-400 font-mono text-[11px]"
                />
              </div>
              <p className="text-[10px] text-slate-500">Inflow cost (₦300) / Payout cost (₦50) benchmarks.</p>
            </div>
          </div>
        </div>

        {/* Real Estate Marketplace Tariffs */}
        <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 space-y-4">
          <div className="flex items-center gap-2 pb-3 border-b border-slate-800">
            <Building2 className="w-4 h-4 text-purple-400" />
            <h2 className="text-sm font-bold text-white">Real Estate Marketplace & Escrow Tariffs</h2>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs">
            <div className="space-y-1.5">
              <label className="text-slate-300 font-semibold block">
                Rent Legal Documentation Fee (%)
              </label>
              <input
                type="number"
                step="0.5"
                value={fees.rentLegalFeePct}
                onChange={(e) => setFees({ ...fees, rentLegalFeePct: Number(e.target.value) })}
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white font-mono focus:outline-none focus:border-emerald-500"
              />
              <p className="text-[10px] text-slate-500">Flat legal agreement documentation tariff (standard 10%).</p>
            </div>

            <div className="space-y-1.5">
              <label className="text-slate-300 font-semibold block">
                Outright Sale Escrow & Title Audit Fee (%)
              </label>
              <input
                type="number"
                step="0.5"
                value={fees.saleEscrowFeePct}
                onChange={(e) => setFees({ ...fees, saleEscrowFeePct: Number(e.target.value) })}
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white font-mono focus:outline-none focus:border-emerald-500"
              />
              <p className="text-[10px] text-slate-500">Charged on outright property purchases (standard 5%).</p>
            </div>

            <div className="space-y-1.5">
              <label className="text-slate-300 font-semibold block">
                Partner Mandate Commission — Rent (%)
              </label>
              <input
                type="number"
                step="0.1"
                value={fees.partnerCommissionRentPct}
                onChange={(e) => setFees({ ...fees, partnerCommissionRentPct: Number(e.target.value) })}
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white font-mono focus:outline-none focus:border-emerald-500"
              />
              <p className="text-[10px] text-slate-500">Automatically credited to partner's wallet on escrow release.</p>
            </div>

            <div className="space-y-1.5">
              <label className="text-slate-300 font-semibold block">
                Partner Mandate Commission — Sale (%)
              </label>
              <input
                type="number"
                step="0.1"
                value={fees.partnerCommissionSalePct}
                onChange={(e) => setFees({ ...fees, partnerCommissionSalePct: Number(e.target.value) })}
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white font-mono focus:outline-none focus:border-emerald-500"
              />
              <p className="text-[10px] text-slate-500">Automatically credited to partner's wallet on sale completion.</p>
            </div>
          </div>
        </div>

        {/* Utility Bills Surcharges */}
        <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 space-y-4">
          <div className="flex items-center gap-2 pb-3 border-b border-slate-800">
            <Zap className="w-4 h-4 text-amber-400" />
            <h2 className="text-sm font-bold text-white">Utility Bills & Telecom Margins</h2>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs">
            <div className="space-y-1.5">
              <label className="text-slate-300 font-semibold block">
                Electricity Disco Convenience Surcharge (₦)
              </label>
              <input
                type="number"
                value={fees.electricityFee}
                onChange={(e) => setFees({ ...fees, electricityFee: Number(e.target.value) })}
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white font-mono focus:outline-none focus:border-emerald-500"
              />
              <p className="text-[10px] text-slate-500">Platform convenience fee added to IKEDC / EKEDC meter tokens.</p>
            </div>

            <div className="space-y-1.5">
              <label className="text-slate-300 font-semibold block">
                Airtime & Data Wholesale Margin (%)
              </label>
              <input
                type="number"
                step="0.1"
                value={fees.airtimeDataMarginPct}
                onChange={(e) => setFees({ ...fees, airtimeDataMarginPct: Number(e.target.value) })}
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white font-mono focus:outline-none focus:border-emerald-500"
              />
              <p className="text-[10px] text-slate-500">Wholesale telecom discount retained as revenue.</p>
            </div>
          </div>
        </div>

        {/* Save Button */}
        <div className="flex items-center justify-between pt-2">
          <button
            type="submit"
            disabled={saving}
            className="px-6 py-3 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs shadow-lg shadow-emerald-950/60 transition flex items-center gap-2 disabled:opacity-50"
          >
            <Save className="w-4 h-4" />
            <span>{saving ? 'Saving Changes...' : 'Save & Deploy Platform Tariffs'}</span>
          </button>

          <span className="text-[11px] text-slate-500 flex items-center gap-1.5">
            <ShieldCheck className="w-4 h-4 text-emerald-400" />
            Synced directly to Supabase & runtime cache
          </span>
        </div>
      </form>
    </div>
  );
};
