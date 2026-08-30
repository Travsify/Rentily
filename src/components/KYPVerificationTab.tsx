import React, { useState } from 'react';
import { 
  ShieldAlert, 
  Search, 
  Filter, 
  CheckCircle2, 
  XCircle, 
  Clock, 
  FileText, 
  MapPin, 
  Zap,
  ShieldCheck
} from 'lucide-react';
import type { KYPRecord } from '../types';

interface KYPVerificationTabProps {
  kypRecords: KYPRecord[];
  onOpenKYPModal: (kyp: KYPRecord) => void;
}

export const KYPVerificationTab: React.FC<KYPVerificationTabProps> = ({
  kypRecords,
  onOpenKYPModal
}) => {
  const [filterStatus, setFilterStatus] = useState<string>('all');
  const [searchQuery, setSearchQuery] = useState<string>('');

  const filtered = kypRecords.filter((kyp) => {
    const matchesStatus = filterStatus === 'all' ? true : kyp.status === filterStatus;
    const matchesSearch = 
      kyp.propertyTitle.toLowerCase().includes(searchQuery.toLowerCase()) ||
      kyp.ownerName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      kyp.propertyNeighborhood.toLowerCase().includes(searchQuery.toLowerCase()) ||
      kyp.titleDocumentNumber.toLowerCase().includes(searchQuery.toLowerCase());
    return matchesStatus && matchesSearch;
  });

  const pendingCount = kypRecords.filter(k => k.status === 'pending').length;
  const approvedCount = kypRecords.filter(k => k.status === 'approved').length;
  const rejectedCount = kypRecords.filter(k => k.status === 'rejected').length;

  return (
    <div className="space-y-6">
      {/* Top Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold text-white flex items-center gap-2">
            <ShieldAlert className="w-6 h-6 text-amber-400" />
            <span>KYP (Know Your Property) Verification Desk</span>
          </h1>
          <p className="text-xs text-slate-400 mt-0.5">
            Audit Nigerian land titles, verify Governor's Consent / C of O, and eliminate fake landlord scams.
          </p>
        </div>

        {/* Status Count Pills */}
        <div className="flex items-center gap-2 text-xs">
          <span className="px-3 py-1 rounded-lg bg-amber-500/10 text-amber-300 border border-amber-500/20 font-semibold">
            {pendingCount} Pending Audit
          </span>
          <span className="px-3 py-1 rounded-lg bg-emerald-500/10 text-emerald-300 border border-emerald-500/20 font-semibold">
            {approvedCount} Verified Titles
          </span>
          <span className="px-3 py-1 rounded-lg bg-red-500/10 text-red-300 border border-red-500/20 font-semibold">
            {rejectedCount} Rejected
          </span>
        </div>
      </div>

      {/* Filter and Search Bar */}
      <div className="flex flex-col md:flex-row gap-3 items-center justify-between bg-slate-900/60 p-3.5 rounded-2xl border border-slate-800">
        <div className="relative w-full md:w-80">
          <Search className="w-4 h-4 text-slate-500 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search by title, owner, document ref..."
            className="w-full pl-9 pr-4 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-200 focus:outline-none focus:border-emerald-500"
          />
        </div>

        <div className="flex items-center gap-2 w-full md:w-auto">
          <Filter className="w-4 h-4 text-slate-500 hidden sm:block" />
          <div className="flex items-center bg-slate-950 p-1 rounded-xl border border-slate-800 text-xs w-full sm:w-auto justify-between sm:justify-start">
            <button
              onClick={() => setFilterStatus('all')}
              className={`px-3 py-1 rounded-lg font-medium transition ${
                filterStatus === 'all' ? 'bg-emerald-600 text-white shadow-sm' : 'text-slate-400 hover:text-white'
              }`}
            >
              All ({kypRecords.length})
            </button>
            <button
              onClick={() => setFilterStatus('pending')}
              className={`px-3 py-1 rounded-lg font-medium transition ${
                filterStatus === 'pending' ? 'bg-amber-600 text-white shadow-sm' : 'text-slate-400 hover:text-white'
              }`}
            >
              Pending ({pendingCount})
            </button>
            <button
              onClick={() => setFilterStatus('approved')}
              className={`px-3 py-1 rounded-lg font-medium transition ${
                filterStatus === 'approved' ? 'bg-emerald-600 text-white shadow-sm' : 'text-slate-400 hover:text-white'
              }`}
            >
              Verified
            </button>
            <button
              onClick={() => setFilterStatus('rejected')}
              className={`px-3 py-1 rounded-lg font-medium transition ${
                filterStatus === 'rejected' ? 'bg-red-600 text-white shadow-sm' : 'text-slate-400 hover:text-white'
              }`}
            >
              Rejected
            </button>
          </div>
        </div>
      </div>

      {/* Grid or Empty State */}
      {filtered.length === 0 ? (
        <div className="p-12 text-center rounded-3xl bg-slate-900/40 border border-slate-800/80 space-y-3">
          <div className="w-14 h-14 rounded-2xl bg-slate-800/80 flex items-center justify-center mx-auto text-emerald-400">
            <ShieldCheck className="w-7 h-7" />
          </div>
          <div className="space-y-1 max-w-sm mx-auto">
            <h3 className="text-base font-bold text-white">No KYP Verification Requests</h3>
            <p className="text-xs text-slate-400">
              When direct landlords list properties and upload ownership documents (C of O, Governor's Consent, NIN, Disco bills), they will appear here for title audit.
            </p>
          </div>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
          {filtered.map((kyp) => {
            const isPending = kyp.status === 'pending';
            const isApproved = kyp.status === 'approved';
            const isRejected = kyp.status === 'rejected';

            return (
              <div
                key={kyp.id}
                className="rounded-2xl bg-slate-900 border border-slate-800 p-5 flex flex-col justify-between hover:border-slate-700 transition space-y-4"
              >
                <div className="space-y-3">
                  {/* Top Status and Date */}
                  <div className="flex items-center justify-between">
                    <span className="text-[11px] font-mono text-slate-500">
                      Submitted: {new Date(kyp.submittedAt).toLocaleDateString()}
                    </span>
                    {isPending && (
                      <span className="flex items-center gap-1 text-[10px] font-bold px-2.5 py-1 rounded-full bg-amber-500/10 text-amber-300 border border-amber-500/30 animate-pulse">
                        <Clock className="w-3 h-3" />
                        <span>Needs Legal Review</span>
                      </span>
                    )}
                    {isApproved && (
                      <span className="flex items-center gap-1 text-[10px] font-bold px-2.5 py-1 rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                        <CheckCircle2 className="w-3 h-3" />
                        <span>Title Verified</span>
                      </span>
                    )}
                    {isRejected && (
                      <span className="flex items-center gap-1 text-[10px] font-bold px-2.5 py-1 rounded-full bg-red-500/10 text-red-400 border border-red-500/30">
                        <XCircle className="w-3 h-3" />
                        <span>Rejected</span>
                      </span>
                    )}
                  </div>

                  {/* Property Info */}
                  <div>
                    <h3 className="text-sm font-bold text-white line-clamp-1">{kyp.propertyTitle}</h3>
                    <p className="text-xs text-slate-400 flex items-center gap-1 mt-0.5">
                      <MapPin className="w-3.5 h-3.5 text-slate-500 shrink-0" />
                      <span>{kyp.propertyNeighborhood}</span>
                    </p>
                  </div>

                  {/* Land Title & Documents Snapshot */}
                  <div className="grid grid-cols-2 gap-2 p-3 rounded-xl bg-slate-950/70 border border-slate-800/80 text-xs">
                    <div>
                      <span className="text-[10px] text-slate-500 uppercase block font-semibold">Title Deed</span>
                      <span className="text-slate-200 font-medium block truncate">
                        {kyp.titleDocumentType.replace(/_/g, ' ').toUpperCase()}
                      </span>
                      <span className="text-[10px] text-emerald-400 font-mono block truncate">
                        Ref: {kyp.titleDocumentNumber}
                      </span>
                    </div>

                    <div>
                      <span className="text-[10px] text-slate-500 uppercase block font-semibold">Owner Verified ID</span>
                      <span className="text-slate-200 font-medium block truncate">{kyp.ownerName}</span>
                      <span className="text-[10px] text-slate-400 block truncate">
                        {kyp.ownerIdType}: {kyp.ownerIdNumber}
                      </span>
                    </div>
                  </div>

                  {/* Disco Utility Meter */}
                  <div className="flex items-center justify-between text-xs px-3 py-2 rounded-lg bg-slate-950/40 border border-slate-800/40">
                    <div className="flex items-center gap-1.5 text-slate-300">
                      <Zap className="w-3.5 h-3.5 text-amber-400" />
                      <span>Disco Meter: {kyp.discoProvider} ({kyp.discoMeterNumber || 'N/A'})</span>
                    </div>
                    <span className="text-[10px] text-emerald-400 font-bold">
                      {kyp.landRegistrySearchStatus.replace(/_/g, ' ').toUpperCase()}
                    </span>
                  </div>

                  {/* Registry Search Notes if Available */}
                  {kyp.landRegistrySearchNotes && (
                    <p className="text-[11px] text-slate-400 bg-slate-950 p-2.5 rounded-lg border border-slate-800/60 line-clamp-2">
                      <strong className="text-slate-300">Audit Notes: </strong>{kyp.landRegistrySearchNotes}
                    </p>
                  )}
                </div>

                {/* Action Button */}
                <div className="mt-4 pt-3 border-t border-slate-800/80 flex items-center justify-between">
                  <span className="text-xs font-bold text-emerald-400">
                    ₦{kyp.propertyPrice.toLocaleString()} ({kyp.propertyPurpose === 'rent' ? '/yr' : 'Sale'})
                  </span>

                  <button
                    onClick={() => onOpenKYPModal(kyp)}
                    className="px-4 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold shadow-md transition flex items-center gap-1.5"
                  >
                    <FileText className="w-3.5 h-3.5" />
                    <span>Audit Documents & Verify</span>
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};
