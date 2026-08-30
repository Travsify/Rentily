import React from 'react';
import { 
  Building2, 
  ShieldCheck, 
  Wallet, 
  Calendar, 
  TrendingUp, 
  CheckCircle2, 
  Clock, 
  AlertTriangle,
  ArrowRight,
  Plus
} from 'lucide-react';
import type { Property, KYPRecord, Inspection, Transaction, AdminTab } from '../types';

interface OverviewTabProps {
  properties: Property[];
  kypRecords: KYPRecord[];
  inspections: Inspection[];
  transactions: Transaction[];
  setCurrentTab: (tab: AdminTab) => void;
  onOpenKYPModal: (kyp: KYPRecord) => void;
}

export const OverviewTab: React.FC<OverviewTabProps> = ({
  properties,
  kypRecords,
  inspections,
  transactions,
  setCurrentTab,
  onOpenKYPModal
}) => {
  // Financial metrics
  const totalVolume = transactions.reduce((acc, t) => acc + t.totalAmount, 0);
  const totalLegalCommissions = transactions.reduce((acc, t) => acc + t.rentillyLegalFee, 0);
  const activeEscrowHeld = transactions
    .filter(t => t.escrowStatus === 'held_in_escrow')
    .reduce((acc, t) => acc + t.totalAmount, 0);
  
  // Calculate traditional agent fee that Nigerians would have paid (approx 20% on rent or 10% on sales)
  const traditionalAgentFeesEstimated = transactions.reduce((acc, t) => {
    const rate = t.transactionType === 'rent' ? 0.20 : 0.10;
    return acc + ((t.baseAmount || 0) * rate);
  }, 0);
  const totalNairaSavedByUsers = Math.max(0, traditionalAgentFeesEstimated - totalLegalCommissions);

  const pendingKYP = kypRecords.filter(k => k.status === 'pending');
  const verifiedProperties = properties.filter(p => p.status === 'verified');
  const upcomingInspections = inspections.filter(i => i.status === 'confirmed');

  return (
    <div className="space-y-5 font-sans">
      {/* Top Banner: Real Estate Impact Metrics */}
      <div className="p-5 rounded-2xl bg-gradient-to-r from-emerald-950/60 via-slate-900 to-slate-900 border border-emerald-500/30 shadow-md relative overflow-hidden">
        <div className="absolute right-0 top-0 bottom-0 w-1/3 bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-emerald-500/10 via-transparent to-transparent pointer-events-none"></div>
        <div className="relative z-10 flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div className="space-y-1.5">
            <div className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 text-[10px] font-semibold">
              <ShieldCheck className="w-3.5 h-3.5" />
              <span>Nigerian Agent-Free Marketplace Model</span>
            </div>
            <h1 className="text-lg font-bold text-white tracking-tight">
              Executive Operations & Title Verification Hub
            </h1>
            <p className="text-xs text-slate-400 max-w-xl leading-relaxed">
              Eliminating 20% agent scam commissions. Rentilly connects vetted direct property owners with tenants and buyers, charging a flat 10% (rent) or 5% (sale) legal documentation fee.
            </p>
          </div>

          {/* Real-time Anti-Agent Savings Counter */}
          <div className="p-3.5 rounded-xl bg-slate-950/90 border border-emerald-500/40 shadow-inner flex flex-col justify-center min-w-[210px]">
            <div className="flex items-center gap-1.5 text-emerald-400 text-[10px] uppercase font-bold tracking-wider mb-0.5">
              <TrendingUp className="w-3.5 h-3.5" />
              <span>Anti-Agent Savings</span>
            </div>
            <div className="text-xl font-extrabold text-white tracking-tight font-mono">
              ₦{totalNairaSavedByUsers.toLocaleString()}
            </div>
            <span className="text-[9px] text-slate-400">Total Naira saved by platform users</span>
          </div>
        </div>
      </div>

      {/* 4 Core Financial & Volume KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3.5">
        {/* Gross Volume */}
        <div className="p-4 rounded-2xl bg-slate-900/90 border border-slate-800 space-y-1.5">
          <div className="flex items-center justify-between text-slate-400 text-xs">
            <span className="text-[11px] font-semibold text-slate-300">Total GMV</span>
            <Wallet className="w-4 h-4 text-emerald-400" />
          </div>
          <div className="text-xl font-extrabold text-white font-mono">
            ₦{totalVolume.toLocaleString()}
          </div>
          <p className="text-[10px] text-slate-400">Across verified rent & sale transactions</p>
        </div>

        {/* Rentilly Legal Fee Revenue */}
        <div className="p-4 rounded-2xl bg-slate-900/90 border border-slate-800 space-y-1.5">
          <div className="flex items-center justify-between text-slate-400 text-xs">
            <span className="text-[11px] font-semibold text-slate-300">Rentilly Revenue</span>
            <span className="text-[9px] font-bold text-emerald-400 bg-emerald-500/10 px-1.5 py-0.5 rounded border border-emerald-500/20">
              10% / 5%
            </span>
          </div>
          <div className="text-xl font-extrabold text-emerald-400 font-mono">
            ₦{totalLegalCommissions.toLocaleString()}
          </div>
          <p className="text-[10px] text-slate-400">Legal due diligence & contract fees</p>
        </div>

        {/* Active Escrow Balance */}
        <div className="p-4 rounded-2xl bg-slate-900/90 border border-slate-800 space-y-1.5">
          <div className="flex items-center justify-between text-slate-400 text-xs">
            <span className="text-[11px] font-semibold text-slate-300">Escrow Held</span>
            <span className="w-2 h-2 rounded-full bg-blue-400 animate-pulse"></span>
          </div>
          <div className="text-xl font-extrabold text-blue-400 font-mono">
            ₦{activeEscrowHeld.toLocaleString()}
          </div>
          <p className="text-[10px] text-slate-400">Pending physical key handover</p>
        </div>

        {/* Verified Property Count */}
        <div className="p-4 rounded-2xl bg-slate-900/90 border border-slate-800 space-y-1.5">
          <div className="flex items-center justify-between text-slate-400 text-xs">
            <span className="text-[11px] font-semibold text-slate-300">Verified Titles</span>
            <Building2 className="w-4 h-4 text-emerald-400" />
          </div>
          <div className="text-xl font-extrabold text-white font-mono">
            {verifiedProperties.length} <span className="text-xs text-slate-400 font-normal">/ {properties.length}</span>
          </div>
          <p className="text-[10px] text-slate-400">C of O & Governor's Consent audited</p>
        </div>
      </div>

      {/* Two Columns: Actionable KYP Review Queue & Quick Operational Feeds */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-5">
        {/* Left Column: Pending KYP Review Desk (7 cols) */}
        <div className="lg:col-span-7 rounded-2xl bg-slate-900/90 border border-slate-800 p-5 space-y-3.5">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <AlertTriangle className="w-4 h-4 text-amber-400" />
              <h2 className="font-bold text-xs text-white">KYP Land Title Review Queue</h2>
              <span className="text-[10px] font-semibold px-2 py-0.5 rounded-full bg-amber-500/10 text-amber-300 border border-amber-500/30">
                {pendingKYP.length} Pending
              </span>
            </div>
            <button
              onClick={() => setCurrentTab('kyp')}
              className="text-[11px] text-emerald-400 hover:text-emerald-300 flex items-center gap-1 font-semibold transition"
            >
              <span>Full Desk</span>
              <ArrowRight className="w-3 h-3" />
            </button>
          </div>

          {pendingKYP.length === 0 ? (
            <div className="p-8 text-center rounded-xl bg-slate-950/60 border border-slate-800 space-y-2">
              <CheckCircle2 className="w-8 h-8 text-emerald-400 mx-auto" />
              <p className="text-xs font-semibold text-white">All Ownership Titles Audited</p>
              <p className="text-[11px] text-slate-400">New landlord listings will appear here for title verification.</p>
            </div>
          ) : (
            <div className="space-y-2.5">
              {pendingKYP.slice(0, 3).map((kyp) => (
                <div
                  key={kyp.id}
                  className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 hover:border-slate-700 transition flex items-center justify-between gap-3 text-xs"
                >
                  <div className="space-y-0.5 max-w-[65%]">
                    <div className="flex items-center gap-1.5">
                      <span className="text-[9px] font-bold uppercase px-1.5 py-0.5 rounded bg-amber-500/10 text-amber-400 border border-amber-500/20">
                        {kyp.titleDocumentType.replace(/_/g, ' ')}
                      </span>
                      <span className="text-[10px] text-slate-500 font-mono">Ref: {kyp.titleDocumentNumber}</span>
                    </div>
                    <h3 className="font-semibold text-white truncate">{kyp.propertyTitle}</h3>
                    <p className="text-[10px] text-slate-400 truncate">
                      Owner: {kyp.ownerName} • {kyp.propertyNeighborhood}
                    </p>
                  </div>

                  <button
                    onClick={() => onOpenKYPModal(kyp)}
                    className="px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-[11px] transition shrink-0"
                  >
                    Audit Title
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Right Column: Upcoming Inspections (5 cols) */}
        <div className="lg:col-span-5 rounded-2xl bg-slate-900/90 border border-slate-800 p-5 space-y-3.5">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Calendar className="w-4 h-4 text-emerald-400" />
              <h2 className="font-bold text-xs text-white">Upcoming Physical Inspections</h2>
            </div>
            <button
              onClick={() => setCurrentTab('inspections')}
              className="text-[11px] text-emerald-400 hover:text-emerald-300 flex items-center gap-1 font-semibold transition"
            >
              <span>View All</span>
              <ArrowRight className="w-3 h-3" />
            </button>
          </div>

          {upcomingInspections.length === 0 ? (
            <div className="p-8 text-center rounded-xl bg-slate-950/60 border border-slate-800 space-y-2">
              <Clock className="w-8 h-8 text-slate-600 mx-auto" />
              <p className="text-xs font-semibold text-white">No Confirmed Inspections</p>
              <p className="text-[11px] text-slate-400">Scheduled appointments and gate passes will show here.</p>
              <button
                onClick={() => setCurrentTab('inspections')}
                className="mt-1 px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-emerald-400 text-[11px] font-semibold inline-flex items-center gap-1"
              >
                <Plus className="w-3 h-3" />
                <span>Book Slot</span>
              </button>
            </div>
          ) : (
            <div className="space-y-2.5">
              {upcomingInspections.slice(0, 3).map((insp) => (
                <div
                  key={insp.id}
                  className="p-3 rounded-xl bg-slate-950 border border-slate-800 text-xs space-y-1"
                >
                  <div className="flex items-center justify-between">
                    <span className="font-semibold text-white truncate max-w-[180px]">{insp.propertyTitle}</span>
                    <span className="text-[10px] font-mono text-amber-300 font-bold bg-amber-500/10 px-1.5 py-0.5 rounded border border-amber-500/20">
                      PASS: {insp.inspectionPassCode}
                    </span>
                  </div>
                  <div className="flex items-center justify-between text-[10px] text-slate-400">
                    <span>{insp.scheduledDate} ({insp.scheduledTimeSlot})</span>
                    <span className="text-slate-300">{insp.prospectName}</span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
