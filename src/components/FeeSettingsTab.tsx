import React, { useState, useEffect } from 'react';
import { 
  BadgePercent, 
  Save, 
  CheckCircle2, 
  AlertCircle, 
  ArrowUpRight, 
  Zap, 
  FileText
} from 'lucide-react';

interface FeeConfig {
  withdrawalFee: number;
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
    withdrawalFee: 50,
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

  useEffect(() => {
    fetch('/api/config/fees')
      .then(res => res.json())
      .then(data => {
        if (data.fees) setFees(data.fees);
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

  return (
    <div className="space-y-6 font-sans max-w-4xl">
      {/* Header */}
      <div>
        <h1 className="text-xl font-bold text-white flex items-center gap-2">
          <BadgePercent className="w-6 h-6 text-emerald-400" />
          <span>Platform Fee & Tariff Configuration</span>
        </h1>
        <p className="text-xs text-slate-400 mt-0.5">
          Configure transaction charges, utility surcharges, legal documentation fees, and partner commissions deducted across mobile and web rails.
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

      <form onSubmit={handleSubmit} className="space-y-6">
        {/* Fintech & Wallet Rail Fees */}
        <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 space-y-4">
          <div className="flex items-center gap-2 pb-3 border-b border-slate-800">
            <ArrowUpRight className="w-4 h-4 text-emerald-400" />
            <h2 className="text-sm font-bold text-white">Wallet & Bank Settlement Charges</h2>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs">
            <div className="space-y-1.5">
              <label className="text-slate-300 font-semibold block">
                Bank Withdrawal Fee (₦)
              </label>
              <input
                type="number"
                value={fees.withdrawalFee}
                onChange={(e) => setFees({ ...fees, withdrawalFee: Number(e.target.value) })}
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white font-mono focus:outline-none focus:border-emerald-500"
              />
              <p className="text-[10px] text-slate-500">Charged on every bank transfer payout (industry standard ₦50).</p>
            </div>

            <div className="space-y-1.5">
              <label className="text-slate-300 font-semibold block">
                Inbound Deposit Stamp Duty (₦)
              </label>
              <input
                type="number"
                value={fees.depositStampDuty}
                onChange={(e) => setFees({ ...fees, depositStampDuty: Number(e.target.value) })}
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white font-mono focus:outline-none focus:border-emerald-500"
              />
              <p className="text-[10px] text-slate-500">Government/Bank stamp duty for deposits ≥ ₦10,000.</p>
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

        {/* Real Estate Marketplace Tariffs */}
        <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 space-y-4">
          <div className="flex items-center gap-2 pb-3 border-b border-slate-800">
            <FileText className="w-4 h-4 text-blue-400" />
            <h2 className="text-sm font-bold text-white">Real Estate Marketplace Tariffs</h2>
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
              <p className="text-[10px] text-slate-500">Replaces traditional 20% agent fees with flat 10% legal fee.</p>
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

        {/* Submit */}
        <button
          type="submit"
          disabled={saving}
          className="px-6 py-3 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs shadow-lg shadow-emerald-950/60 transition flex items-center gap-2 disabled:opacity-50"
        >
          <Save className="w-4 h-4" />
          <span>{saving ? 'Saving Tariffs...' : 'Save & Update Platform Tariffs'}</span>
        </button>
      </form>
    </div>
  );
};
