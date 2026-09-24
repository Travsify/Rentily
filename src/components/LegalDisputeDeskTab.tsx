import React, { useState, useEffect } from 'react';
import { 
  Scale, 
  CheckCircle, 
  Gavel, 
  Plus, 
  ShieldAlert, 
  Clock, 
  X 
} from 'lucide-react';
import type { LegalDispute, DisputeCategory, DisputeStatus } from '../types';

export const LegalDisputeDeskTab: React.FC = () => {
  const [disputes, setDisputes] = useState<LegalDispute[]>([]);
  const [selectedDispute, setSelectedDispute] = useState<LegalDispute | null>(null);
  const [filterCategory, setFilterCategory] = useState<string>('all');
  const [filterStatus, setFilterStatus] = useState<string>('all');
  const [isResolveModalOpen, setIsResolveModalOpen] = useState(false);
  const [isNewDisputeModalOpen, setIsNewDisputeModalOpen] = useState(false);
  const [resolutionOutcome, setResolutionOutcome] = useState('');
  const [arbitrationAward, setArbitrationAward] = useState('');
  const [actionSuccessMsg, setActionSuccessMsg] = useState<string | null>(null);

  // New Dispute Form State
  const [formData, setFormData] = useState({
    propertyTitle: '',
    complainantName: '',
    complainantEmail: '',
    complainantRole: 'tenant',
    respondentName: '',
    respondentEmail: '',
    respondentRole: 'landlord',
    disputeCategory: 'breach_of_covenant' as DisputeCategory,
    disputeTitle: '',
    claimAmount: 0,
    description: '',
    statutoryNoticeType: 'Form_TL1'
  });

  const loadDisputes = async () => {
    try {
      const res = await fetch('/api/legal/disputes');
      if (res.ok) {
        const data = await res.json();
        setDisputes(data);
        if (data.length > 0 && !selectedDispute) {
          setSelectedDispute(data[0]);
        }
      }
    } catch (_) {}
  };

  useEffect(() => {
    loadDisputes();
  }, []);

  const handleCreateDispute = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const res = await fetch('/api/legal/disputes', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData)
      });
      if (res.ok) {
        setIsNewDisputeModalOpen(false);
        setActionSuccessMsg('Dispute claim successfully docketed on the Rentilly Arbitration Desk.');
        loadDisputes();
        setTimeout(() => setActionSuccessMsg(null), 4000);
      }
    } catch (_) {}
  };

  const handleResolveDispute = async () => {
    if (!selectedDispute) return;
    try {
      const res = await fetch(`/api/legal/disputes/${selectedDispute.id}/resolve`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-actor-role': 'legal_officer',
          'x-actor-name': 'Barr. Chijioke Okonkwo, SAN'
        },
        body: JSON.stringify({
          resolutionOutcome: resolutionOutcome || 'Arbitral settlement award granted in accordance with AMA 2023 principles.',
          arbitrationAwardSummary: arbitrationAward,
          status: 'resolved'
        })
      });
      if (res.ok) {
        setIsResolveModalOpen(false);
        setActionSuccessMsg('Arbitration Ruling & AMA 2023 Consent Judgment issued.');
        loadDisputes();
        setTimeout(() => setActionSuccessMsg(null), 4000);
      }
    } catch (_) {}
  };

  const filteredDisputes = disputes.filter(d => {
    const matchCat = filterCategory === 'all' || d.disputeCategory === filterCategory;
    const matchStat = filterStatus === 'all' || d.status === filterStatus;
    return matchCat && matchStat;
  });

  const getCategoryBadge = (cat: DisputeCategory) => {
    switch (cat) {
      case 'unlawful_eviction':
        return <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-rose-500/10 text-rose-400 border border-rose-500/30 flex items-center gap-1"><ShieldAlert className="w-3 h-3" /> Anti-Self-Help (Emergency)</span>;
      case 'caution_deposit_retention':
        return <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-amber-500/10 text-amber-400 border border-amber-500/30">Caution Retention</span>;
      case 'title_defect':
        return <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-purple-500/10 text-purple-400 border border-purple-500/30">Title Defect</span>;
      default:
        return <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-blue-500/10 text-blue-400 border border-blue-500/30">Breach of Covenant</span>;
    }
  };

  const getStatusBadge = (status: DisputeStatus) => {
    switch (status) {
      case 'resolved':
        return <span className="px-2.5 py-1 rounded-full text-xs font-bold bg-emerald-500/10 text-emerald-400 border border-emerald-500/30 flex items-center gap-1"><CheckCircle className="w-3.5 h-3.5" /> Resolved (AMA Award)</span>;
      case 'mediation':
        return <span className="px-2.5 py-1 rounded-full text-xs font-bold bg-amber-500/10 text-amber-400 border border-amber-500/30 flex items-center gap-1"><Clock className="w-3.5 h-3.5" /> In Mediation</span>;
      case 'arbitration':
        return <span className="px-2.5 py-1 rounded-full text-xs font-bold bg-purple-500/10 text-purple-400 border border-purple-500/30 flex items-center gap-1"><Gavel className="w-3.5 h-3.5" /> Arbitration Tribunal</span>;
      default:
        return <span className="px-2.5 py-1 rounded-full text-xs font-bold bg-slate-500/10 text-slate-400 border border-slate-500/30">Filed (Docketed)</span>;
    }
  };

  const formatNaira = (amt: number) => {
    return new Intl.NumberFormat('en-NG', { style: 'currency', currency: 'NGN', maximumFractionDigits: 0 }).format(amt);
  };

  return (
    <div className="space-y-6">
      {/* Banner */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-slate-900/60 p-6 rounded-3xl border border-slate-800 shadow-xl">
        <div className="flex items-center gap-4">
          <div className="w-14 h-14 rounded-2xl bg-gradient-to-tr from-purple-600 to-indigo-500 flex items-center justify-center shadow-lg shadow-purple-600/30">
            <Scale className="w-7 h-7 text-white" />
          </div>
          <div>
            <h2 className="text-xl font-bold text-white tracking-tight">Statutory Dispute & Arbitration Desk</h2>
            <p className="text-xs text-slate-400 mt-0.5">
              Arbitration & Mediation Act (AMA) 2023 Tribunal, Lagos LSTL 2011 Anti-Self-Help Interventions, and Form TL1-TL5 Notices.
            </p>
          </div>
        </div>

        <button
          onClick={() => setIsNewDisputeModalOpen(true)}
          className="inline-flex items-center gap-2 px-5 py-3 rounded-2xl bg-purple-600 hover:bg-purple-500 text-white text-xs font-bold shadow-lg shadow-purple-600/30 transition transform hover:-translate-y-0.5"
        >
          <Plus className="w-4 h-4" />
          <span>Docket New Dispute Claim</span>
        </button>
      </div>

      {actionSuccessMsg && (
        <div className="p-4 rounded-2xl bg-emerald-950/60 border border-emerald-500/40 text-xs text-emerald-300 flex items-center gap-3 animate-fade-in">
          <CheckCircle className="w-5 h-5 text-emerald-400 flex-shrink-0" />
          <span>{actionSuccessMsg}</span>
        </div>
      )}

      {/* Grid: Dispute List + Detailed Tribunal Dossier */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Left: Disputes Docket List (5 Cols) */}
        <div className="lg:col-span-5 space-y-4">
          {/* Filters */}
          <div className="flex items-center gap-2 bg-slate-900/80 p-3 rounded-2xl border border-slate-800 text-xs">
            <select
              value={filterCategory}
              onChange={(e) => setFilterCategory(e.target.value)}
              className="bg-slate-950 border border-slate-800 rounded-xl px-2.5 py-1.5 text-slate-300 focus:outline-none focus:border-purple-500 flex-1"
            >
              <option value="all">All Categories</option>
              <option value="unlawful_eviction">Unlawful Eviction (Anti-Self-Help)</option>
              <option value="caution_deposit_retention">Caution Deposit Retention</option>
              <option value="breach_of_covenant">Breach of Covenant</option>
              <option value="title_defect">Title Defect</option>
            </select>
            <select
              value={filterStatus}
              onChange={(e) => setFilterStatus(e.target.value)}
              className="bg-slate-950 border border-slate-800 rounded-xl px-2.5 py-1.5 text-slate-300 focus:outline-none focus:border-purple-500"
            >
              <option value="all">All Statuses</option>
              <option value="filed">Filed</option>
              <option value="mediation">Mediation</option>
              <option value="arbitration">Arbitration</option>
              <option value="resolved">Resolved</option>
            </select>
          </div>

          <div className="space-y-3 max-h-[750px] overflow-y-auto pr-1">
            {filteredDisputes.length === 0 ? (
              <div className="p-8 text-center bg-slate-900/40 rounded-2xl border border-slate-800 text-slate-500 text-xs">
                No legal disputes match the current filters.
              </div>
            ) : (
              filteredDisputes.map((disp) => {
                const isSelected = selectedDispute?.id === disp.id;
                return (
                  <div
                    key={disp.id}
                    onClick={() => setSelectedDispute(disp)}
                    className={`p-4 rounded-2xl border transition-all cursor-pointer ${
                      isSelected
                        ? 'bg-slate-800/90 border-purple-500/50 shadow-lg shadow-purple-950/30'
                        : 'bg-slate-900/60 border-slate-800/80 hover:bg-slate-800/40'
                    }`}
                  >
                    <div className="flex items-start justify-between gap-2 mb-2">
                      <span className="text-xs font-bold text-white line-clamp-1">{disp.disputeTitle}</span>
                      {getCategoryBadge(disp.disputeCategory)}
                    </div>
                    <p className="text-[11px] text-slate-400">Property: {disp.propertyTitle}</p>
                    <div className="flex items-center justify-between mt-3 pt-3 border-t border-slate-800/60 text-xs">
                      <span className="text-slate-400">Claim: <strong className="text-purple-400">{formatNaira(disp.claimAmount)}</strong></span>
                      {getStatusBadge(disp.status)}
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>

        {/* Right: Dispute Tribunal Dossier (7 Cols) */}
        <div className="lg:col-span-7">
          {selectedDispute ? (
            <div className="bg-slate-900/80 border border-slate-800 rounded-3xl p-6 space-y-6 shadow-xl">
              {/* Header */}
              <div className="flex items-start justify-between border-b border-slate-800 pb-5">
                <div>
                  <div className="flex items-center gap-2 mb-1">
                    <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider bg-purple-500/10 text-purple-400 border border-purple-500/20">
                      Docket #{selectedDispute.id.slice(-6)}
                    </span>
                    <span className="text-xs text-slate-500">• {new Date(selectedDispute.createdAt).toLocaleDateString()}</span>
                  </div>
                  <h3 className="text-lg font-bold text-white">{selectedDispute.disputeTitle}</h3>
                  <p className="text-xs text-slate-400 mt-0.5">{selectedDispute.propertyTitle}</p>
                </div>
                {getStatusBadge(selectedDispute.status)}
              </div>

              {/* Parties Grid */}
              <div className="grid grid-cols-2 gap-4 text-xs">
                <div className="bg-slate-950 p-4 rounded-2xl border border-slate-800">
                  <span className="text-slate-500 block uppercase text-[10px] font-bold tracking-wider mb-1">Complainant ({selectedDispute.complainantRole})</span>
                  <span className="text-slate-200 font-bold">{selectedDispute.complainantName}</span>
                  <span className="text-slate-400 block text-[11px] mt-0.5">{selectedDispute.complainantEmail}</span>
                </div>
                <div className="bg-slate-950 p-4 rounded-2xl border border-slate-800">
                  <span className="text-slate-500 block uppercase text-[10px] font-bold tracking-wider mb-1">Respondent ({selectedDispute.respondentRole})</span>
                  <span className="text-slate-200 font-bold">{selectedDispute.respondentName}</span>
                  <span className="text-slate-400 block text-[11px] mt-0.5">{selectedDispute.respondentEmail}</span>
                </div>
              </div>

              {/* Claim Statement */}
              <div className="bg-slate-950 p-4 rounded-2xl border border-slate-800 space-y-2 text-xs">
                <div className="flex items-center justify-between">
                  <span className="text-slate-400 uppercase text-[10px] font-bold tracking-wider">Dispute Claim Statement</span>
                  <span className="text-purple-400 font-bold">Claimed Amount: {formatNaira(selectedDispute.claimAmount)}</span>
                </div>
                <p className="text-slate-200 leading-relaxed">{selectedDispute.description}</p>
              </div>

              {/* Statutory Notice & Anti-Self-Help Details */}
              <div className="bg-slate-950 p-4 rounded-2xl border border-slate-800 text-xs space-y-2">
                <span className="text-slate-400 uppercase text-[10px] font-bold tracking-wider block">
                  Statutory Notice & Jurisdiction Compliance
                </span>
                <div className="flex items-center justify-between text-[11px]">
                  <span className="text-slate-300">Served Notice Type:</span>
                  <span className="font-mono text-purple-400 font-semibold">{selectedDispute.statutoryNoticeType || 'Form TL1 (Notice of Breach)'}</span>
                </div>
                <div className="flex items-center justify-between text-[11px]">
                  <span className="text-slate-300">Governing Statutory Framework:</span>
                  <span className="text-slate-200 font-semibold">Arbitration & Mediation Act (AMA) 2023</span>
                </div>
              </div>

              {/* Resolved Award Banner if Resolved */}
              {selectedDispute.status === 'resolved' && (
                <div className="p-4 rounded-2xl bg-emerald-950/40 border border-emerald-500/40 text-xs space-y-2">
                  <div className="flex items-center gap-2 text-emerald-400 font-bold">
                    <CheckCircle className="w-4 h-4" />
                    <span>Binding Arbitration Award Issued</span>
                  </div>
                  <p className="text-slate-200 leading-relaxed">{selectedDispute.arbitrationAwardSummary || selectedDispute.mediationNotes}</p>
                  <p className="text-[10px] text-emerald-400">
                    Consent Judgment Registered at State High Court Multi-Door Courthouse.
                  </p>
                </div>
              )}

              {/* Action Controls */}
              <div className="flex items-center justify-between pt-4 border-t border-slate-800">
                <div className="text-xs text-slate-400">
                  <span>Assigned Arbitrator: </span>
                  <span className="font-bold text-white">{selectedDispute.assignedLegalOfficerName || 'Barr. Chijioke Okonkwo, SAN'}</span>
                </div>

                {selectedDispute.status !== 'resolved' && (
                  <button
                    onClick={() => setIsResolveModalOpen(true)}
                    className="px-4 py-2 rounded-xl bg-purple-600 hover:bg-purple-500 text-white text-xs font-bold shadow-lg shadow-purple-600/30 transition flex items-center gap-2"
                  >
                    <Gavel className="w-4 h-4" />
                    <span>Issue Arbitral Ruling & Award</span>
                  </button>
                )}
              </div>
            </div>
          ) : (
            <div className="bg-slate-900/60 border border-slate-800 rounded-3xl p-12 text-center text-slate-500">
              Select a dispute docket from the left list to review claims, evidence, and issue arbitral awards.
            </div>
          )}
        </div>
      </div>

      {/* Modal: Resolve Dispute */}
      {isResolveModalOpen && selectedDispute && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-3xl max-w-lg w-full p-6 space-y-5 shadow-2xl">
            <div className="flex items-center gap-3 border-b border-slate-800 pb-4">
              <div className="w-12 h-12 rounded-2xl bg-purple-500/10 border border-purple-500/30 flex items-center justify-center text-purple-400">
                <Gavel className="w-6 h-6" />
              </div>
              <div>
                <h3 className="text-base font-bold text-white">Issue Arbitral Award & Settlement</h3>
                <p className="text-xs text-slate-400">Under Arbitration & Mediation Act 2023</p>
              </div>
            </div>

            <div className="space-y-4 text-xs">
              <div>
                <label className="block text-slate-400 font-semibold mb-1">Arbitration Settlement Summary & Notes</label>
                <input
                  type="text"
                  value={resolutionOutcome}
                  onChange={(e) => setResolutionOutcome(e.target.value)}
                  placeholder="e.g. Mutual release agreed; 100% caution fee refund."
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl p-2.5 text-white focus:outline-none focus:border-purple-500 mb-3"
                />
              </div>

              <div>
                <label className="block text-slate-400 font-semibold mb-1">Binding Tribunal Award Terms</label>
                <textarea
                  rows={4}
                  required
                  value={arbitrationAward}
                  onChange={(e) => setArbitrationAward(e.target.value)}
                  placeholder="The Arbitral Tribunal orders full refund of caution fee with interest, and 14 days compliance period..."
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl p-2.5 text-white focus:outline-none focus:border-purple-500"
                ></textarea>
              </div>
            </div>

            <div className="flex justify-end gap-3 pt-3 border-t border-slate-800">
              <button
                type="button"
                onClick={() => setIsResolveModalOpen(false)}
                className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleResolveDispute}
                className="px-5 py-2 rounded-xl bg-purple-600 hover:bg-purple-500 text-white text-xs font-bold shadow-lg shadow-purple-600/30"
              >
                Sign & Issue Binding Award
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Modal: New Dispute Claim */}
      {isNewDisputeModalOpen && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-slate-900 border border-slate-800 rounded-3xl max-w-xl w-full p-6 space-y-5 shadow-2xl">
            <div className="flex items-center justify-between border-b border-slate-800 pb-4">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-purple-500/10 border border-purple-500/20 flex items-center justify-center text-purple-400">
                  <Scale className="w-5 h-5" />
                </div>
                <h3 className="text-base font-bold text-white">Docket New Dispute Claim</h3>
              </div>
              <button onClick={() => setIsNewDisputeModalOpen(false)} className="text-slate-400 hover:text-white">
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleCreateDispute} className="space-y-4 text-xs">
              <div>
                <label className="block text-slate-400 font-semibold mb-1">Dispute Title</label>
                <input
                  type="text"
                  required
                  value={formData.disputeTitle}
                  onChange={(e) => setFormData({ ...formData, disputeTitle: e.target.value })}
                  placeholder="e.g. Unlawful Lockout & Caution Retention Claim"
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl p-2.5 text-white focus:outline-none focus:border-purple-500"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-slate-400 font-semibold mb-1">Dispute Category</label>
                  <select
                    value={formData.disputeCategory}
                    onChange={(e) => setFormData({ ...formData, disputeCategory: e.target.value as DisputeCategory })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl p-2.5 text-slate-200 focus:outline-none focus:border-purple-500"
                  >
                    <option value="breach_of_covenant">Breach of Covenant</option>
                    <option value="unlawful_eviction">Unlawful Eviction (Anti-Self-Help)</option>
                    <option value="caution_deposit_retention">Caution Deposit Retention</option>
                    <option value="title_defect">Title Defect</option>
                    <option value="rent_default">Rent Default</option>
                    <option value="damage_claim">Damage Claim</option>
                  </select>
                </div>
                <div>
                  <label className="block text-slate-400 font-semibold mb-1">Claim Amount (₦)</label>
                  <input
                    type="number"
                    value={formData.claimAmount}
                    onChange={(e) => setFormData({ ...formData, claimAmount: Number(e.target.value) })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl p-2.5 text-white focus:outline-none focus:border-purple-500 font-bold"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-slate-400 font-semibold mb-1">Complainant Name</label>
                  <input
                    type="text"
                    required
                    value={formData.complainantName}
                    onChange={(e) => setFormData({ ...formData, complainantName: e.target.value })}
                    placeholder="Full legal name"
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl p-2.5 text-white focus:outline-none focus:border-purple-500"
                  />
                </div>
                <div>
                  <label className="block text-slate-400 font-semibold mb-1">Complainant Email</label>
                  <input
                    type="email"
                    required
                    value={formData.complainantEmail}
                    onChange={(e) => setFormData({ ...formData, complainantEmail: e.target.value })}
                    placeholder="email@example.com"
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl p-2.5 text-white focus:outline-none focus:border-purple-500"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-slate-400 font-semibold mb-1">Respondent Name</label>
                  <input
                    type="text"
                    required
                    value={formData.respondentName}
                    onChange={(e) => setFormData({ ...formData, respondentName: e.target.value })}
                    placeholder="Full legal name"
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl p-2.5 text-white focus:outline-none focus:border-purple-500"
                  />
                </div>
                <div>
                  <label className="block text-slate-400 font-semibold mb-1">Respondent Email</label>
                  <input
                    type="email"
                    required
                    value={formData.respondentEmail}
                    onChange={(e) => setFormData({ ...formData, respondentEmail: e.target.value })}
                    placeholder="respondent@example.com"
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl p-2.5 text-white focus:outline-none focus:border-purple-500"
                  />
                </div>
              </div>

              <div>
                <label className="block text-slate-400 font-semibold mb-1">Detailed Description of Breach</label>
                <textarea
                  rows={3}
                  required
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  placeholder="Provide chronological events and evidence citations..."
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl p-2.5 text-white focus:outline-none focus:border-purple-500"
                ></textarea>
              </div>

              <div className="flex justify-end gap-3 pt-3 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setIsNewDisputeModalOpen(false)}
                  className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 font-semibold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-5 py-2 rounded-xl bg-purple-600 hover:bg-purple-500 text-white font-bold shadow-lg shadow-purple-600/30"
                >
                  Docket Claim
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
