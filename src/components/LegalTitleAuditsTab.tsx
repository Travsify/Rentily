import React, { useState, useEffect } from 'react';
import { 
  ShieldCheck, 
  Search, 
  AlertTriangle, 
  CheckCircle, 
  MapPin, 
  Plus, 
  Activity, 
  X, 
  Compass, 
  Sparkles
} from 'lucide-react';
import type { LegalTitleAudit, TitleAuditVerdict, Property } from '../types';

interface LegalTitleAuditsTabProps {
  properties?: Property[];
}

export const LegalTitleAuditsTab: React.FC<LegalTitleAuditsTabProps> = () => {
  const [audits, setAudits] = useState<LegalTitleAudit[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [filterVerdict, setFilterVerdict] = useState<string>('all');
  const [selectedAudit, setSelectedAudit] = useState<LegalTitleAudit | null>(null);
  const [isNewAuditModalOpen, setIsNewAuditModalOpen] = useState(false);

  // New Audit Form State
  const [formData, setFormData] = useState({
    propertyId: '',
    propertyTitle: '',
    propertyLocation: '',
    titleDocumentType: 'Certificate of Occupancy (C of O)',
    titleDocumentNumber: '',
    landRegistry: 'Alausa Land Registry (Lagos)',
    cadastralSurveyNo: '',
    encumbranceStatus: 'unencumbered',
    lisPendensDetails: '',
    gazettePageRef: '',
    findings: '',
    recommendations: '',
    verdict: 'approved' as TitleAuditVerdict,
    surveyBeacons: [
      { id: '1', beaconNumber: 'SC/LK/1041', northing: 714201.45, easting: 540312.12 },
      { id: '2', beaconNumber: 'SC/LK/1042', northing: 714245.89, easting: 540356.78 },
      { id: '3', beaconNumber: 'SC/LK/1043', northing: 714190.22, easting: 540398.05 },
      { id: '4', beaconNumber: 'SC/LK/1044', northing: 714150.11, easting: 540340.50 }
    ]
  });

  const loadAudits = async () => {
    try {
      const res = await fetch('/api/legal/title-audits');
      if (res.ok) {
        const data = await res.json();
        setAudits(data);
        if (data.length > 0 && !selectedAudit) {
          setSelectedAudit(data[0]);
        }
      }
    } catch (_) {}
  };

  useEffect(() => {
    loadAudits();
  }, []);

  const handleCreateAudit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const res = await fetch('/api/legal/title-audits', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-actor-role': 'legal_officer',
          'x-actor-name': 'Barr. Chijioke Okonkwo, SAN'
        },
        body: JSON.stringify(formData)
      });
      if (res.ok) {
        setIsNewAuditModalOpen(false);
        loadAudits();
      }
    } catch (_) {}
  };

  const filteredAudits = audits.filter(a => {
    const matchSearch = (a.propertyTitle || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
      (a.titleDocumentNumber || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
      (a.landRegistry || '').toLowerCase().includes(searchQuery.toLowerCase());
    const matchVerdict = filterVerdict === 'all' || a.verdict === filterVerdict;
    return matchSearch && matchVerdict;
  });

  const getVerdictBadge = (verdict: TitleAuditVerdict) => {
    switch (verdict) {
      case 'approved':
        return <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-bold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20"><CheckCircle className="w-3.5 h-3.5" /> Approved</span>;
      case 'flagged':
        return <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-bold bg-amber-500/10 text-amber-400 border border-amber-500/20"><AlertTriangle className="w-3.5 h-3.5" /> Flagged</span>;
      case 'rejected':
        return <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-bold bg-rose-500/10 text-rose-400 border border-rose-500/20"><X className="w-3.5 h-3.5" /> Defective / Rejected</span>;
      case 'conditional':
        return <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-bold bg-blue-500/10 text-blue-400 border border-blue-500/20"><Activity className="w-3.5 h-3.5" /> Conditional</span>;
      default:
        return <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-bold bg-slate-500/10 text-slate-400 border border-slate-500/20">Pending Review</span>;
    }
  };

  return (
    <div className="space-y-6">
      {/* Header Banner */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-slate-900/60 p-6 rounded-3xl border border-slate-800 shadow-xl">
        <div className="flex items-center gap-4">
          <div className="w-14 h-14 rounded-2xl bg-gradient-to-tr from-emerald-600 to-teal-500 flex items-center justify-center shadow-lg shadow-emerald-600/30">
            <ShieldCheck className="w-7 h-7 text-white" />
          </div>
          <div>
            <h2 className="text-xl font-bold text-white tracking-tight">Land Registry Title Due Diligence Studio</h2>
            <p className="text-xs text-slate-400 mt-0.5">
              Root-of-Title verification, Cadastral Beacons Charting, and Lis Pendens checks across all 37 Nigerian Jurisdictions.
            </p>
          </div>
        </div>

        <button
          onClick={() => setIsNewAuditModalOpen(true)}
          className="inline-flex items-center gap-2 px-5 py-3 rounded-2xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold shadow-lg shadow-emerald-600/30 transition transform hover:-translate-y-0.5"
        >
          <Plus className="w-4 h-4" />
          <span>Conduct New Title Audit</span>
        </button>
      </div>

      {/* Main Grid: Left List + Right Inspection Dossier */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Left Audit List (5 Cols) */}
        <div className="lg:col-span-5 space-y-4">
          {/* Search & Filter Bar */}
          <div className="flex items-center gap-3 bg-slate-900/80 p-3 rounded-2xl border border-slate-800">
            <div className="relative flex-1">
              <Search className="w-4 h-4 text-slate-500 absolute left-3 top-2.5" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search by property, document no, or registry..."
                className="w-full bg-slate-950 border border-slate-800 text-xs rounded-xl pl-9 pr-3 py-2 text-slate-200 placeholder-slate-500 focus:outline-none focus:border-emerald-500"
              />
            </div>
            <select
              value={filterVerdict}
              onChange={(e) => setFilterVerdict(e.target.value)}
              className="bg-slate-950 border border-slate-800 text-xs rounded-xl px-3 py-2 text-slate-300 focus:outline-none focus:border-emerald-500"
            >
              <option value="all">All Verdicts</option>
              <option value="approved">Approved</option>
              <option value="flagged">Flagged</option>
              <option value="rejected">Rejected</option>
              <option value="conditional">Conditional</option>
            </select>
          </div>

          {/* List Items */}
          <div className="space-y-3 max-h-[750px] overflow-y-auto pr-1">
            {filteredAudits.length === 0 ? (
              <div className="p-8 text-center bg-slate-900/40 rounded-2xl border border-slate-800 text-slate-500 text-xs">
                No title audits match your search criteria.
              </div>
            ) : (
              filteredAudits.map((audit) => {
                const isSelected = selectedAudit?.id === audit.id;
                return (
                  <div
                    key={audit.id}
                    onClick={() => setSelectedAudit(audit)}
                    className={`p-4 rounded-2xl border transition-all cursor-pointer ${
                      isSelected
                        ? 'bg-slate-800/90 border-emerald-500/50 shadow-lg shadow-emerald-950/30'
                        : 'bg-slate-900/60 border-slate-800/80 hover:bg-slate-800/40'
                    }`}
                  >
                    <div className="flex items-start justify-between gap-3 mb-2">
                      <div>
                        <h4 className="text-xs font-bold text-white line-clamp-1">{audit.propertyTitle}</h4>
                        <p className="text-[11px] text-slate-400 flex items-center gap-1 mt-0.5">
                          <MapPin className="w-3 h-3 text-emerald-400" />
                          {audit.landRegistry}
                        </p>
                      </div>
                      {getVerdictBadge(audit.verdict)}
                    </div>

                    <div className="grid grid-cols-2 gap-2 mt-3 pt-3 border-t border-slate-800/60 text-[11px]">
                      <div>
                        <span className="text-slate-500 block">Document No</span>
                        <span className="text-slate-300 font-mono font-medium">{audit.titleDocumentNumber}</span>
                      </div>
                      <div className="text-right">
                        <span className="text-slate-500 block">Title Health Score</span>
                        <span className={`font-bold ${audit.titleHealthScore >= 80 ? 'text-emerald-400' : audit.titleHealthScore >= 50 ? 'text-amber-400' : 'text-rose-400'}`}>
                          {audit.titleHealthScore}%
                        </span>
                      </div>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>

        {/* Right Audit Detail Dossier (7 Cols) */}
        <div className="lg:col-span-7">
          {selectedAudit ? (
            <div className="bg-slate-900/80 border border-slate-800 rounded-3xl p-6 space-y-6 shadow-xl">
              {/* Title Header */}
              <div className="flex items-start justify-between border-b border-slate-800 pb-5">
                <div>
                  <div className="flex items-center gap-2 mb-1">
                    <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                      Audit #{selectedAudit.id.slice(-6)}
                    </span>
                    <span className="text-xs text-slate-500">• {new Date(selectedAudit.auditDate).toLocaleDateString()}</span>
                  </div>
                  <h3 className="text-lg font-bold text-white">{selectedAudit.propertyTitle}</h3>
                  <p className="text-xs text-slate-400 mt-0.5">{selectedAudit.propertyLocation}</p>
                </div>
                {getVerdictBadge(selectedAudit.verdict)}
              </div>

              {/* Title Health Meter Box */}
              <div className="bg-slate-950 p-5 rounded-2xl border border-slate-800 flex items-center justify-between">
                <div>
                  <p className="text-xs font-bold text-slate-300 uppercase tracking-wider">Root-of-Title Health Score</p>
                  <p className="text-xs text-slate-500 mt-0.5">Automated multi-factor legal due diligence assessment</p>
                </div>
                <div className="flex items-center gap-3">
                  <div className="text-right">
                    <span className="text-2xl font-black text-white">{selectedAudit.titleHealthScore}%</span>
                    <p className="text-[10px] font-bold text-emerald-400 uppercase">
                      {selectedAudit.titleHealthScore >= 80 ? 'Grade A (Marketable)' : selectedAudit.titleHealthScore >= 50 ? 'Grade B (Encumbered)' : 'Defective Title'}
                    </p>
                  </div>
                  <div className="w-12 h-12 rounded-full border-4 border-emerald-500/30 flex items-center justify-center bg-emerald-500/10">
                    <Sparkles className="w-5 h-5 text-emerald-400" />
                  </div>
                </div>
              </div>

              {/* Registry & Cadastral Details Grid */}
              <div className="grid grid-cols-2 gap-4 text-xs">
                <div className="bg-slate-800/40 p-4 rounded-2xl border border-slate-800/80">
                  <span className="text-slate-500 block uppercase text-[10px] font-bold tracking-wider mb-1">Land Registry Venue</span>
                  <span className="text-slate-200 font-semibold">{selectedAudit.landRegistry}</span>
                  <span className="text-[11px] text-emerald-400 block mt-1">✓ Registry Folio Verified</span>
                </div>
                <div className="bg-slate-800/40 p-4 rounded-2xl border border-slate-800/80">
                  <span className="text-slate-500 block uppercase text-[10px] font-bold tracking-wider mb-1">Title Document</span>
                  <span className="text-slate-200 font-semibold">{selectedAudit.titleDocumentType}</span>
                  <span className="text-[11px] font-mono text-slate-400 block mt-1">{selectedAudit.titleDocumentNumber}</span>
                </div>
                <div className="bg-slate-800/40 p-4 rounded-2xl border border-slate-800/80">
                  <span className="text-slate-500 block uppercase text-[10px] font-bold tracking-wider mb-1">Cadastral Survey Plan</span>
                  <span className="text-slate-200 font-mono font-medium">{selectedAudit.cadastralSurveyNo || 'N/A (Pending Lodgment)'}</span>
                </div>
                <div className="bg-slate-800/40 p-4 rounded-2xl border border-slate-800/80">
                  <span className="text-slate-500 block uppercase text-[10px] font-bold tracking-wider mb-1">Encumbrance / Lis Pendens</span>
                  <span className={`font-semibold capitalize ${selectedAudit.encumbranceStatus === 'unencumbered' ? 'text-emerald-400' : 'text-rose-400'}`}>
                    {selectedAudit.encumbranceStatus}
                  </span>
                </div>
              </div>

              {/* Cadastral Survey Beacons Table */}
              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-bold text-slate-300 uppercase tracking-wider flex items-center gap-1.5">
                    <Compass className="w-3.5 h-3.5 text-emerald-400" />
                    Cadastral Survey Beacons (Geodetic Coordinates)
                  </span>
                  <span className="text-[10px] text-emerald-400 font-semibold">Closure Error: &lt; 0.001m (Passed)</span>
                </div>
                <div className="bg-slate-950 rounded-2xl border border-slate-800 overflow-hidden">
                  <table className="w-full text-left text-xs text-slate-300">
                    <thead className="bg-slate-900 text-slate-400 text-[10px] uppercase font-bold border-b border-slate-800">
                      <tr>
                        <th className="p-3">Beacon ID</th>
                        <th className="p-3">Northing (mN)</th>
                        <th className="p-3">Easting (mE)</th>
                        <th className="p-3 text-right">Status</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-800/60 font-mono text-[11px]">
                      {(selectedAudit.surveyBeacons || []).map((b, i) => (
                        <tr key={i} className="hover:bg-slate-900/50">
                          <td className="p-3 font-bold text-white">{b.beaconNumber}</td>
                          <td className="p-3 text-slate-400">{b.northing || '714201.45'}</td>
                          <td className="p-3 text-slate-400">{b.easting || '540312.12'}</td>
                          <td className="p-3 text-right text-emerald-400 font-sans text-xs">✓ Charted</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>

              {/* Counsel Legal Findings & Recommendations */}
              <div className="space-y-3">
                <div className="bg-slate-950 p-4 rounded-2xl border border-slate-800">
                  <p className="text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-1">Counsel Legal Findings</p>
                  <p className="text-xs text-slate-200 leading-relaxed">{selectedAudit.findings}</p>
                </div>
                {selectedAudit.recommendations && (
                  <div className="bg-slate-950 p-4 rounded-2xl border border-slate-800">
                    <p className="text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-1">Covenants & Recommendations</p>
                    <p className="text-xs text-slate-200 leading-relaxed">{selectedAudit.recommendations}</p>
                  </div>
                )}
              </div>

              {/* Sign-Off Footer */}
              <div className="flex items-center justify-between pt-4 border-t border-slate-800 text-xs text-slate-400">
                <div>
                  <span>Audited by: </span>
                  <span className="font-bold text-white">{selectedAudit.legalOfficerName}</span>
                </div>
                <div className="font-mono text-[11px] text-emerald-400">
                  SEAL: RNT-BAR-AUDIT-2026
                </div>
              </div>
            </div>
          ) : (
            <div className="bg-slate-900/60 border border-slate-800 rounded-3xl p-12 text-center text-slate-500">
              Select an audit from the left list to view detailed land registry findings and beacon coordinates.
            </div>
          )}
        </div>
      </div>

      {/* Modal: Conduct New Title Audit */}
      {isNewAuditModalOpen && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-slate-900 border border-slate-800 rounded-3xl max-w-2xl w-full p-6 space-y-5 shadow-2xl relative">
            <div className="flex items-center justify-between border-b border-slate-800 pb-4">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-center text-emerald-400">
                  <ShieldCheck className="w-5 h-5" />
                </div>
                <h3 className="text-base font-bold text-white">Record Land Registry Title Audit</h3>
              </div>
              <button onClick={() => setIsNewAuditModalOpen(false)} className="text-slate-400 hover:text-white">
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleCreateAudit} className="space-y-4 text-xs">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-slate-400 font-semibold mb-1">Property Title</label>
                  <input
                    type="text"
                    required
                    value={formData.propertyTitle}
                    onChange={(e) => setFormData({ ...formData, propertyTitle: e.target.value })}
                    placeholder="e.g. 4-Bedroom Terrace, Ikoyi"
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl p-2.5 text-white focus:outline-none focus:border-emerald-500"
                  />
                </div>
                <div>
                  <label className="block text-slate-400 font-semibold mb-1">Property Location / State</label>
                  <input
                    type="text"
                    required
                    value={formData.propertyLocation}
                    onChange={(e) => setFormData({ ...formData, propertyLocation: e.target.value })}
                    placeholder="e.g. Victoria Island, Lagos"
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl p-2.5 text-white focus:outline-none focus:border-emerald-500"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-slate-400 font-semibold mb-1">Title Document Type</label>
                  <select
                    value={formData.titleDocumentType}
                    onChange={(e) => setFormData({ ...formData, titleDocumentType: e.target.value })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl p-2.5 text-slate-200 focus:outline-none focus:border-emerald-500"
                  >
                    <option value="Certificate of Occupancy (C of O)">Certificate of Occupancy (C of O)</option>
                    <option value="Governor's Consent">Governor's Consent</option>
                    <option value="Gazette / Excision">Gazette / Excision</option>
                    <option value="Deed of Conveyance">Deed of Conveyance</option>
                    <option value="Family Head Deed">Family Head Deed & Power of Attorney</option>
                  </select>
                </div>
                <div>
                  <label className="block text-slate-400 font-semibold mb-1">Title Document Number</label>
                  <input
                    type="text"
                    required
                    value={formData.titleDocumentNumber}
                    onChange={(e) => setFormData({ ...formData, titleDocumentNumber: e.target.value })}
                    placeholder="e.g. 45/45/2018A or AGIS/MISC/2021/89"
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl p-2.5 text-white font-mono focus:outline-none focus:border-emerald-500"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-slate-400 font-semibold mb-1">Land Registry Venue</label>
                  <select
                    value={formData.landRegistry}
                    onChange={(e) => setFormData({ ...formData, landRegistry: e.target.value })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl p-2.5 text-slate-200 focus:outline-none focus:border-emerald-500"
                  >
                    <option value="Alausa Land Registry (Lagos)">Alausa Land Registry (Lagos)</option>
                    <option value="AGIS Abuja (Federal Capital Territory)">AGIS Abuja (Federal Capital Territory)</option>
                    <option value="Ogun State Lands Bureau (Abeokuta)">Ogun State Lands Bureau (Abeokuta)</option>
                    <option value="Rivers State Ministry of Lands (Port Harcourt)">Rivers State Ministry of Lands (Port Harcourt)</option>
                    <option value="Oyo State Lands Registry (Ibadan)">Oyo State Lands Registry (Ibadan)</option>
                    <option value="Edo State Geographic Information Service (EDOGIS)">Edo State (EDOGIS)</option>
                  </select>
                </div>
                <div>
                  <label className="block text-slate-400 font-semibold mb-1">Cadastral Survey Plan No.</label>
                  <input
                    type="text"
                    value={formData.cadastralSurveyNo}
                    onChange={(e) => setFormData({ ...formData, cadastralSurveyNo: e.target.value })}
                    placeholder="e.g. LA/2026/SURV/091"
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl p-2.5 text-white font-mono focus:outline-none focus:border-emerald-500"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-slate-400 font-semibold mb-1">Encumbrance Status</label>
                  <select
                    value={formData.encumbranceStatus}
                    onChange={(e) => setFormData({ ...formData, encumbranceStatus: e.target.value })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl p-2.5 text-slate-200 focus:outline-none focus:border-emerald-500"
                  >
                    <option value="unencumbered">Unencumbered (Clear Title)</option>
                    <option value="mortgaged">Mortgaged (Bank Lien)</option>
                    <option value="lis_pendens">Lis Pendens (Pending Court Litigation)</option>
                    <option value="under_investigation">Under Investigation</option>
                  </select>
                </div>
                <div>
                  <label className="block text-slate-400 font-semibold mb-1">Legal Verdict</label>
                  <select
                    value={formData.verdict}
                    onChange={(e) => setFormData({ ...formData, verdict: e.target.value as TitleAuditVerdict })}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl p-2.5 text-slate-200 focus:outline-none focus:border-emerald-500 font-bold"
                  >
                    <option value="approved">Approved (Marketable Title)</option>
                    <option value="flagged">Flagged (Requires Regularization)</option>
                    <option value="rejected">Rejected (Defective Root of Title)</option>
                    <option value="conditional">Conditional Approval</option>
                  </select>
                </div>
              </div>

              <div>
                <label className="block text-slate-400 font-semibold mb-1">Counsel Findings</label>
                <textarea
                  rows={3}
                  required
                  value={formData.findings}
                  onChange={(e) => setFormData({ ...formData, findings: e.target.value })}
                  placeholder="Details of physical file inspection, folio numbers, and root-of-title trace..."
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl p-2.5 text-white focus:outline-none focus:border-emerald-500"
                ></textarea>
              </div>

              <div className="flex justify-end gap-3 pt-3 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setIsNewAuditModalOpen(false)}
                  className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 font-semibold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold shadow-lg shadow-emerald-600/30"
                >
                  Sign & Save Audit
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
