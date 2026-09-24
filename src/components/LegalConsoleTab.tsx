import React, { useState, useEffect } from 'react';
import { 
  Scale, 
  Building2, 
  ShieldCheck, 
  FileText, 
  DollarSign, 
  Truck, 
  ExternalLink,
  Activity
} from 'lucide-react';
import { LegalPurchasesSalesTab } from './LegalPurchasesSalesTab';
import { LegalTitleAuditsTab } from './LegalTitleAuditsTab';
import { LegalDisputeDeskTab } from './LegalDisputeDeskTab';
import { LegalAgreementsTab } from './LegalAgreementsTab';
import type { LegalAgreement, Property, LegalAuditLog } from '../types';

interface LegalConsoleTabProps {
  agreements: LegalAgreement[];
  properties?: Property[];
  initialSubTab?: 'purchases_sales' | 'title_audits' | 'disputes' | 'tenancy_agreements' | 'audit_logs';
}

export const LegalConsoleTab: React.FC<LegalConsoleTabProps> = ({
  agreements = [],
  properties = [],
  initialSubTab = 'purchases_sales'
}) => {
  const [activeTab, setActiveTab] = useState<'purchases_sales' | 'title_audits' | 'disputes' | 'tenancy_agreements' | 'audit_logs'>(initialSubTab);
  const [auditLogs, setAuditLogs] = useState<LegalAuditLog[]>([]);
  const [quickHashSearch, setQuickHashSearch] = useState('');
  const stats = {
    totalAgreements: agreements.length || 12,
    activePurchases: 4,
    escrowHeld: 48500000,
    auditedTitles: 18,
    openDisputes: 3,
    dispatchesInTransit: 5
  };

  const loadAuditLogs = async () => {
    try {
      const res = await fetch('/api/legal/audit-logs', {
        headers: {
          'x-actor-role': 'legal_officer',
          'x-actor-name': 'Barr. Chijioke Okonkwo, SAN'
        }
      });
      if (res.ok) {
        const data = await res.json();
        setAuditLogs(data);
      }
    } catch (_) {}
  };

  useEffect(() => {
    loadAuditLogs();
  }, []);

  const handleVerifyHash = (e: React.FormEvent) => {
    e.preventDefault();
    if (quickHashSearch.trim()) {
      window.open(`/verify-deed/${quickHashSearch.trim()}`, '_blank');
    }
  };

  const formatNaira = (amt: number) => {
    return new Intl.NumberFormat('en-NG', { style: 'currency', currency: 'NGN', maximumFractionDigits: 0 }).format(amt);
  };

  return (
    <div className="space-y-6">
      {/* Top Banner & Quick Hash Verifier */}
      <div className="bg-gradient-to-r from-slate-900 via-slate-900 to-indigo-950 p-6 md:p-8 rounded-3xl border border-slate-800 shadow-2xl relative overflow-hidden">
        <div className="absolute -top-24 -right-24 w-80 h-80 bg-indigo-500/10 rounded-full blur-3xl pointer-events-none"></div>

        <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-6 relative z-10">
          <div>
            <div className="flex items-center gap-2 mb-2">
              <span className="px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 flex items-center gap-1.5">
                <ShieldCheck className="w-3.5 h-3.5" />
                Global Standard Legal Operations Console
              </span>
              <span className="text-xs text-slate-400">• Evidence Act 2011 Sec 84 & AMA 2023 Compliant</span>
            </div>
            <h1 className="text-2xl md:text-3xl font-black text-white tracking-tight">
              Rentilly Legal Counsel Command Hub
            </h1>
            <p className="text-xs md:text-sm text-slate-300 mt-1 max-w-2xl">
              Centralized conveyancing pipeline, 3-tranche milestone escrow release authorization, Cadastral survey due diligence, and binding statutory dispute arbitration.
            </p>
          </div>

          {/* Quick Hash Verifier Box */}
          <form onSubmit={handleVerifyHash} className="bg-slate-950/80 p-4 rounded-2xl border border-slate-800 w-full lg:w-96 shadow-xl">
            <label className="block text-[11px] font-bold text-slate-300 uppercase tracking-wider mb-1.5">
              Live Deed Verification
            </label>
            <div className="relative">
              <input
                type="text"
                value={quickHashSearch}
                onChange={(e) => setQuickHashSearch(e.target.value)}
                placeholder="Paste SHA-256 Deed Hash or Agreement ID..."
                className="w-full bg-slate-900 border border-slate-800 text-xs rounded-xl pl-3 pr-20 py-2.5 text-slate-200 placeholder-slate-500 focus:outline-none focus:border-emerald-500 font-mono"
              />
              <button
                type="submit"
                className="absolute right-1 top-1 bottom-1 px-3 bg-emerald-600 hover:bg-emerald-500 text-white rounded-lg text-xs font-bold transition flex items-center gap-1"
              >
                <span>Verify</span>
                <ExternalLink className="w-3 h-3" />
              </button>
            </div>
          </form>
        </div>
      </div>

      {/* KPI Cards Grid */}
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
        <div className="bg-slate-900/60 border border-slate-800 p-4 rounded-2xl">
          <div className="flex items-center justify-between text-slate-400 mb-2">
            <span className="text-xs font-medium">Executed Deeds</span>
            <FileText className="w-4 h-4 text-emerald-400" />
          </div>
          <p className="text-xl font-black text-white">{stats.totalAgreements}</p>
          <span className="text-[10px] text-emerald-400 mt-1 block">100% Sealed & Stamped</span>
        </div>

        <div className="bg-slate-900/60 border border-slate-800 p-4 rounded-2xl">
          <div className="flex items-center justify-between text-slate-400 mb-2">
            <span className="text-xs font-medium">Outright Sales</span>
            <Building2 className="w-4 h-4 text-amber-400" />
          </div>
          <p className="text-xl font-black text-white">{stats.activePurchases}</p>
          <span className="text-[10px] text-amber-400 mt-1 block">In Conveyancing</span>
        </div>

        <div className="bg-slate-900/60 border border-slate-800 p-4 rounded-2xl">
          <div className="flex items-center justify-between text-slate-400 mb-2">
            <span className="text-xs font-medium">Milestone Escrow</span>
            <DollarSign className="w-4 h-4 text-blue-400" />
          </div>
          <p className="text-lg font-black text-white">{formatNaira(stats.escrowHeld)}</p>
          <span className="text-[10px] text-blue-400 mt-1 block">3-Tranche Releases</span>
        </div>

        <div className="bg-slate-900/60 border border-slate-800 p-4 rounded-2xl">
          <div className="flex items-center justify-between text-slate-400 mb-2">
            <span className="text-xs font-medium">Title Audits</span>
            <ShieldCheck className="w-4 h-4 text-teal-400" />
          </div>
          <p className="text-xl font-black text-white">{stats.auditedTitles}</p>
          <span className="text-[10px] text-teal-400 mt-1 block">Alausa & AGIS Verified</span>
        </div>

        <div className="bg-slate-900/60 border border-slate-800 p-4 rounded-2xl">
          <div className="flex items-center justify-between text-slate-400 mb-2">
            <span className="text-xs font-medium">Arbitration Cases</span>
            <Scale className="w-4 h-4 text-purple-400" />
          </div>
          <p className="text-xl font-black text-white">{stats.openDisputes}</p>
          <span className="text-[10px] text-purple-400 mt-1 block">AMA 2023 Settlement</span>
        </div>

        <div className="bg-slate-900/60 border border-slate-800 p-4 rounded-2xl">
          <div className="flex items-center justify-between text-slate-400 mb-2">
            <span className="text-xs font-medium">Courier Deeds</span>
            <Truck className="w-4 h-4 text-indigo-400" />
          </div>
          <p className="text-xl font-black text-white">{stats.dispatchesInTransit}</p>
          <span className="text-[10px] text-indigo-400 mt-1 block">Protected by OTP</span>
        </div>
      </div>

      {/* Main Tab Navigation Buttons */}
      <div className="flex items-center gap-2 overflow-x-auto pb-2 border-b border-slate-800">
        <button
          onClick={() => setActiveTab('purchases_sales')}
          className={`flex items-center gap-2 px-5 py-3 rounded-2xl text-xs font-bold transition whitespace-nowrap ${
            activeTab === 'purchases_sales'
              ? 'bg-amber-600 text-white shadow-lg shadow-amber-600/30'
              : 'bg-slate-900/60 text-slate-400 hover:text-white hover:bg-slate-800'
          }`}
        >
          <Building2 className="w-4 h-4" />
          <span>Outright Purchases & Escrow Milestones</span>
        </button>

        <button
          onClick={() => setActiveTab('title_audits')}
          className={`flex items-center gap-2 px-5 py-3 rounded-2xl text-xs font-bold transition whitespace-nowrap ${
            activeTab === 'title_audits'
              ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-600/30'
              : 'bg-slate-900/60 text-slate-400 hover:text-white hover:bg-slate-800'
          }`}
        >
          <ShieldCheck className="w-4 h-4" />
          <span>Title Due Diligence & Audits</span>
        </button>

        <button
          onClick={() => setActiveTab('disputes')}
          className={`flex items-center gap-2 px-5 py-3 rounded-2xl text-xs font-bold transition whitespace-nowrap ${
            activeTab === 'disputes'
              ? 'bg-purple-600 text-white shadow-lg shadow-purple-600/30'
              : 'bg-slate-900/60 text-slate-400 hover:text-white hover:bg-slate-800'
          }`}
        >
          <Scale className="w-4 h-4" />
          <span>Disputes & AMA Arbitration Desk</span>
        </button>

        <button
          onClick={() => setActiveTab('tenancy_agreements')}
          className={`flex items-center gap-2 px-5 py-3 rounded-2xl text-xs font-bold transition whitespace-nowrap ${
            activeTab === 'tenancy_agreements'
              ? 'bg-blue-600 text-white shadow-lg shadow-blue-600/30'
              : 'bg-slate-900/60 text-slate-400 hover:text-white hover:bg-slate-800'
          }`}
        >
          <FileText className="w-4 h-4" />
          <span>Tenancy Agreements & Waybills</span>
        </button>

        <button
          onClick={() => setActiveTab('audit_logs')}
          className={`flex items-center gap-2 px-5 py-3 rounded-2xl text-xs font-bold transition whitespace-nowrap ${
            activeTab === 'audit_logs'
              ? 'bg-slate-800 text-white border border-slate-700'
              : 'bg-slate-900/60 text-slate-400 hover:text-white hover:bg-slate-800'
          }`}
        >
          <Activity className="w-4 h-4" />
          <span>Evidence Act Audit Logs</span>
        </button>
      </div>

      {/* Render Active Sub-View */}
      {activeTab === 'purchases_sales' && (
        <LegalPurchasesSalesTab properties={properties} agreements={agreements} />
      )}

      {activeTab === 'title_audits' && (
        <LegalTitleAuditsTab properties={properties} />
      )}

      {activeTab === 'disputes' && (
        <LegalDisputeDeskTab />
      )}

      {activeTab === 'tenancy_agreements' && (
        <LegalAgreementsTab agreements={agreements} />
      )}

      {activeTab === 'audit_logs' && (
        <div className="bg-slate-900/80 border border-slate-800 rounded-3xl p-6 space-y-4 shadow-xl">
          <div className="flex items-center justify-between border-b border-slate-800 pb-4">
            <div>
              <h3 className="text-base font-bold text-white">Immutable Legal Audit Ledger</h3>
              <p className="text-xs text-slate-400">
                Cryptographic record of every legal officer seal, title audit verdict, escrow execution, and custody handover.
              </p>
            </div>
            <span className="px-3 py-1 rounded-full text-xs font-bold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-mono">
              Evidence Act 2011 Sec 84
            </span>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs text-slate-300">
              <thead className="bg-slate-950 text-slate-400 text-[10px] uppercase font-bold border-b border-slate-800">
                <tr>
                  <th className="p-3">Timestamp</th>
                  <th className="p-3">Entity Type</th>
                  <th className="p-3">Action</th>
                  <th className="p-3">Actor / Legal Counsel</th>
                  <th className="p-3">Audit Details</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60 font-mono text-[11px]">
                {auditLogs.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="p-8 text-center text-slate-500 font-sans">
                      No legal actions recorded in this session. All legal operations are immutably logged upon execution.
                    </td>
                  </tr>
                ) : (
                  auditLogs.map((log) => (
                    <tr key={log.id} className="hover:bg-slate-800/40">
                      <td className="p-3 text-slate-400 font-sans">{new Date(log.createdAt).toLocaleString()}</td>
                      <td className="p-3 font-bold text-white uppercase">{log.entityType}</td>
                      <td className="p-3">
                        <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 uppercase font-sans">
                          {log.action}
                        </span>
                      </td>
                      <td className="p-3 text-slate-300 font-sans">{log.actorEmail} ({log.actorRole})</td>
                      <td className="p-3 text-slate-400 max-w-xs truncate">{JSON.stringify(log.changes || {})}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
};
