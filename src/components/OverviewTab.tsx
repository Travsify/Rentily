import React from 'react';
import { 
  Building2, 
  ShieldCheck, 
  Wallet, 
  Calendar, 
  TrendingUp, 
  ArrowUpRight, 
  CheckCircle2, 
  Clock, 
  AlertTriangle,
  ArrowRight
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
    return acc + (t.baseAmount * rate);
  }, 0);
  const totalNairaSavedByUsers = Math.max(0, traditionalAgentFeesEstimated - totalLegalCommissions);

  const pendingKYP = kypRecords.filter(k => k.status === 'pending');
  const verifiedProperties = properties.filter(p => p.status === 'verified');
  const upcomingInspections = inspections.filter(i => i.status === 'confirmed');

  return (
    <div className="space-y-6">
      {/* Top Banner: Real Estate Impact Metrics */}
      <div className="p-6 rounded-2xl bg-gradient-to-r from-emerald-900/60 via-slate-900 to-slate-900 border border-emerald-500/30 shadow-xl relative overflow-hidden">
        <div className="absolute right-0 top-0 bottom-0 w-1/3 bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-emerald-500/10 via-transparent to-transparent pointer-events-none"></div>
        <div className="relative z-10 flex flex-col md:flex-row md:items-center justify-between gap-6">
          <div className="space-y-2">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 text-xs font-semibold">
              <ShieldCheck className="w-4 h-4" />
              <span>Nigerian Market Agent-Free Protocol Active</span>
            </div>
            <h1 className="text-2xl lg:text-3xl font-bold text-white tracking-tight">
              Rentilly Central Operations Desk
            </h1>
            <p className="text-sm text-slate-300 max-w-2xl">
              Eliminating rogue agents and property fraud across Lagos and Abuja through strict KYP land registry title verification, automated Nigerian Tenancy Agreements, and secure escrow.
            </p>
          </div>

          {/* User Savings Card */}
          <div className="p-4 rounded-xl bg-slate-950/80 border border-emerald-500/40 text-left min-w-[240px] shadow-lg">
            <span className="text-xs text-slate-400 font-medium">Tenant & Buyer Savings (Anti-Agent)</span>
            <div className="text-2xl font-extrabold text-emerald-400 mt-1">
              ₦{totalNairaSavedByUsers.toLocaleString()}
            </div>
            <p className="text-[11px] text-slate-400 mt-0.5">
              Saved from extortionate 20% agent commission markups
            </p>
          </div>
        </div>
      </div>

      {/* KPI Cards Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Total GMV */}
        <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 hover:border-slate-700 transition">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Total Transaction GMV</span>
            <div className="w-9 h-9 rounded-xl bg-emerald-500/10 text-emerald-400 flex items-center justify-center">
              <Wallet className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-3">
            <span className="text-2xl font-bold text-white">₦{(totalVolume / 1_000_000).toFixed(2)}M</span>
            <div className="flex items-center gap-1.5 mt-1 text-xs text-emerald-400">
              <TrendingUp className="w-3.5 h-3.5" />
              <span>100% Direct Transactions</span>
            </div>
          </div>
        </div>

        {/* Rentilly Legal Fees (10% & 5%) */}
        <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 hover:border-slate-700 transition">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Rentilly Revenue (10%/5%)</span>
            <div className="w-9 h-9 rounded-xl bg-teal-500/10 text-teal-400 flex items-center justify-center">
              <Building2 className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-3">
            <span className="text-2xl font-bold text-teal-300">₦{totalLegalCommissions.toLocaleString()}</span>
            <div className="flex items-center gap-1.5 mt-1 text-xs text-slate-400">
              <span>Legal Drafting & Title Search Fee</span>
            </div>
          </div>
        </div>

        {/* Active Escrow Balance */}
        <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 hover:border-slate-700 transition">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Active Escrow Held</span>
            <div className="w-9 h-9 rounded-xl bg-blue-500/10 text-blue-400 flex items-center justify-center">
              <CheckCircle2 className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-3">
            <span className="text-2xl font-bold text-blue-300">₦{activeEscrowHeld.toLocaleString()}</span>
            <div className="flex items-center gap-1.5 mt-1 text-xs text-slate-400">
              <span>Awaiting Key Handover Payout</span>
            </div>
          </div>
        </div>

        {/* Pending KYP Queue */}
        <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 hover:border-slate-700 transition">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">KYP Queue (Verification)</span>
            <div className="w-9 h-9 rounded-xl bg-amber-500/10 text-amber-400 flex items-center justify-center">
              <ShieldCheck className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-3">
            <span className="text-2xl font-bold text-amber-300">{pendingKYP.length} Pending</span>
            <div className="flex items-center gap-1.5 mt-1 text-xs text-amber-400/80">
              <Clock className="w-3.5 h-3.5" />
              <span>{verifiedProperties.length} Properties Live & Verified</span>
            </div>
          </div>
        </div>
      </div>

      {/* Main Grid: Pending KYP Verification Queue & Upcoming Inspections */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left 2 Cols: Urgent KYP Action Desk */}
        <div className="lg:col-span-2 space-y-4">
          <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800">
            <div className="flex items-center justify-between pb-4 border-b border-slate-800">
              <div>
                <h2 className="text-base font-bold text-white flex items-center gap-2">
                  <ShieldCheck className="w-5 h-5 text-amber-400" />
                  <span>Pending KYP Title Verifications</span>
                </h2>
                <p className="text-xs text-slate-400">Audit land registry deeds before properties become visible on the public feed</p>
              </div>
              <button
                onClick={() => setCurrentTab('kyp')}
                className="text-xs text-emerald-400 hover:text-emerald-300 font-semibold flex items-center gap-1"
              >
                <span>View All ({kypRecords.length})</span>
                <ArrowRight className="w-3.5 h-3.5" />
              </button>
            </div>

            {pendingKYP.length === 0 ? (
              <div className="py-8 text-center text-slate-500 text-xs">
                <CheckCircle2 className="w-8 h-8 text-emerald-500 mx-auto mb-2 opacity-80" />
                All landlord ownership documents are fully audited and verified!
              </div>
            ) : (
              <div className="divide-y divide-slate-800/60 mt-2">
                {pendingKYP.map((kyp) => (
                  <div key={kyp.id} className="py-3.5 flex items-center justify-between gap-4">
                    <div className="space-y-1">
                      <div className="flex items-center gap-2">
                        <span className="text-xs font-bold text-white hover:text-emerald-400 transition">
                          {kyp.propertyTitle}
                        </span>
                        <span className="text-[10px] uppercase font-bold px-2 py-0.5 rounded bg-amber-500/10 text-amber-300 border border-amber-500/30">
                          {kyp.titleDocumentType.replace(/_/g, ' ')}
                        </span>
                      </div>
                      <p className="text-xs text-slate-400">
                        Owner: <span className="text-slate-200 font-medium">{kyp.ownerName}</span> ({kyp.ownerPhone}) • {kyp.propertyNeighborhood}
                      </p>
                    </div>

                    <button
                      onClick={() => onOpenKYPModal(kyp)}
                      className="px-3 py-1.5 rounded-lg bg-emerald-600/20 hover:bg-emerald-600/30 text-emerald-300 border border-emerald-500/30 text-xs font-semibold transition shrink-0"
                    >
                      Audit Documents
                    </button>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Quick Real Estate Market Model Comparison */}
          <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800">
            <h3 className="text-sm font-bold text-white mb-3 flex items-center gap-2">
              <AlertTriangle className="w-4 h-4 text-emerald-400" />
              <span>How Rentilly Protects the Nigerian Market</span>
            </h3>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
              <div className="p-3.5 rounded-xl bg-red-950/30 border border-red-800/40 space-y-1.5">
                <span className="font-bold text-red-400 uppercase tracking-wider text-[10px]">Traditional Nigerian Agent System</span>
                <ul className="text-slate-300 space-y-1 list-disc pl-4 text-[11px]">
                  <li>10% Agent Commission + 10% Legal Agreement Markup = <strong>20%+</strong></li>
                  <li>₦5,000 – ₦10,000 Inspection/Viewing fees</li>
                  <li>Rogue agents posing as landlords without title deeds</li>
                  <li>No move-in warranty or caution fee protection</li>
                </ul>
              </div>

              <div className="p-3.5 rounded-xl bg-emerald-950/40 border border-emerald-700/50 space-y-1.5">
                <span className="font-bold text-emerald-400 uppercase tracking-wider text-[10px]">The Rentilly Zero-Agent Protocol</span>
                <ul className="text-slate-200 space-y-1 list-disc pl-4 text-[11px]">
                  <li>Flat <strong>10% Legal Fee</strong> for Rentals (Zero Agent fee)</li>
                  <li>Flat <strong>5% Due-Diligence & Title Search</strong> for Sales</li>
                  <li>Mandatory KYP (C of O / Governor's Consent / NIN verification)</li>
                  <li>Direct Landlord Inspection Booking + In-App Chat</li>
                </ul>
              </div>
            </div>
          </div>
        </div>

        {/* Right Col: Active Physical Inspections */}
        <div className="space-y-4">
          <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 h-full flex flex-col justify-between">
            <div>
              <div className="flex items-center justify-between pb-3 border-b border-slate-800">
                <h3 className="text-sm font-bold text-white flex items-center gap-2">
                  <Calendar className="w-4 h-4 text-emerald-400" />
                  <span>Scheduled Inspections</span>
                </h3>
                <span className="text-[10px] px-2 py-0.5 rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-bold">
                  {upcomingInspections.length} Active
                </span>
              </div>

              <div className="space-y-3 mt-4">
                {inspections.slice(0, 3).map((insp) => (
                  <div key={insp.id} className="p-3 rounded-xl bg-slate-950/60 border border-slate-800/80 space-y-2">
                    <div className="flex items-center justify-between text-xs">
                      <span className="font-semibold text-white truncate max-w-[150px]">{insp.propertyTitle}</span>
                      <span className="text-[10px] px-2 py-0.5 rounded bg-emerald-500/20 text-emerald-300 font-bold">
                        Pass: {insp.inspectionPassCode}
                      </span>
                    </div>
                    <div className="text-[11px] text-slate-400 space-y-0.5">
                      <p>Prospect: <span className="text-slate-200">{insp.prospectName}</span></p>
                      <p>Owner: <span className="text-slate-200">{insp.ownerName}</span></p>
                      <p className="text-emerald-400 font-medium">{insp.scheduledDate} • {insp.scheduledTimeSlot}</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            <button
              onClick={() => setCurrentTab('inspections')}
              className="w-full mt-4 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold transition flex items-center justify-center gap-1.5"
            >
              <span>Manage Inspection Scheduler</span>
              <ArrowUpRight className="w-3.5 h-3.5" />
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
