import React, { useState, useEffect } from 'react';
import { 
  FileText, 
  Scale, 
  Copy, 
  Check, 
  Clock 
} from 'lucide-react';

interface StatutoryNoticeRecord {
  id: string;
  noticeType: string;
  jurisdiction: string;
  landlordName: string;
  tenantName: string;
  propertyAddress: string;
  annualRent: number;
  serviceDate: string;
  expiryDate: string;
  legalCitation: string;
  documentBody: string;
  createdAt: string;
}

export const StatutoryNoticesTab: React.FC = () => {
  const [noticeType, setNoticeType] = useState<'notice_to_quit_yearly' | 'notice_to_quit_monthly' | 'seven_days_owners_intention' | 'rent_arrears_demand'>('notice_to_quit_yearly');
  const [jurisdiction, setJurisdiction] = useState<'lagos' | 'abuja_fct' | 'general_nigeria'>('lagos');
  const [landlordName, setLandlordName] = useState('');
  const [tenantName, setTenantName] = useState('');
  const [propertyAddress, setPropertyAddress] = useState('');
  const [annualRent, setAnnualRent] = useState('');
  const [serviceDate, setServiceDate] = useState(new Date().toISOString().slice(0, 10));
  const [legalGrounds, setLegalGrounds] = useState('');

  const [generatedDoc, setGeneratedDoc] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);
  const [saving, setSaving] = useState(false);
  const [history, setHistory] = useState<StatutoryNoticeRecord[]>([]);

  const fetchHistory = async () => {
    try {
      const res = await fetch('/api/legal/statutory-notices');
      if (res.ok) {
        const d = await res.json();
        setHistory(d.notices || []);
      }
    } catch (_) {}
  };

  useEffect(() => {
    fetchHistory();
  }, []);

  const handleGenerate = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);

    try {
      const res = await fetch('/api/legal/statutory-notice', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          noticeType,
          jurisdiction,
          landlordName,
          tenantName,
          propertyAddress,
          annualRent: Number(annualRent),
          serviceDate,
          legalGrounds
        })
      });

      const data = await res.json();
      if (res.ok && data.success) {
        setGeneratedDoc(data.notice.documentBody);
        fetchHistory();
      }
    } catch (_) {}
    setSaving(false);
  };

  const handleCopy = () => {
    if (!generatedDoc) return;
    navigator.clipboard.writeText(generatedDoc);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="space-y-6 font-sans max-w-5xl">
      {/* Header */}
      <div>
        <h1 className="text-xl font-bold text-white flex items-center gap-2">
          <Scale className="w-6 h-6 text-emerald-400" />
          <span>Statutory Tenancy Legal Notice Generator</span>
        </h1>
        <p className="text-xs text-slate-400 mt-0.5">
          Generate legally unchallengeable Notices to Quit (6-Month/1-Month) and 7-Day Notices of Owner's Intention under Lagos State Tenancy Law 2011 & FCT Recovery of Premises Act.
        </p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Generator Form */}
        <div className="lg:col-span-6 p-5 rounded-2xl bg-slate-900 border border-slate-800 space-y-4 text-xs">
          <h2 className="text-sm font-bold text-white flex items-center gap-2">
            <FileText className="w-4 h-4 text-emerald-400" />
            <span>Notice Parameters</span>
          </h2>

          <form onSubmit={handleGenerate} className="space-y-3">
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-slate-300 font-semibold block mb-1">Notice Type</label>
                <select
                  value={noticeType}
                  onChange={(e) => setNoticeType(e.target.value as any)}
                  className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white font-medium"
                >
                  <option value="notice_to_quit_yearly">Notice to Quit (6-Month Annual)</option>
                  <option value="notice_to_quit_monthly">Notice to Quit (1-Month Monthly)</option>
                  <option value="seven_days_owners_intention">7-Day Notice of Owner's Intention (Form E)</option>
                  <option value="rent_arrears_demand">Demand for Rent Arrears</option>
                </select>
              </div>

              <div>
                <label className="text-slate-300 font-semibold block mb-1">Statutory Jurisdiction</label>
                <select
                  value={jurisdiction}
                  onChange={(e) => setJurisdiction(e.target.value as any)}
                  className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white font-medium"
                >
                  <option value="lagos">Lagos State (Tenancy Law 2011)</option>
                  <option value="abuja_fct">Abuja FCT (Recovery of Premises Act)</option>
                  <option value="general_nigeria">General Nigerian Tenancy Law</option>
                </select>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-slate-300 font-semibold block mb-1">Landlord Name</label>
                <input
                  type="text"
                  required
                  value={landlordName}
                  onChange={(e) => setLandlordName(e.target.value)}
                  placeholder="Chief Adebayo Falana"
                  className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white"
                />
              </div>

              <div>
                <label className="text-slate-300 font-semibold block mb-1">Tenant in Possession</label>
                <input
                  type="text"
                  required
                  value={tenantName}
                  onChange={(e) => setTenantName(e.target.value)}
                  placeholder="Emeka Okonkwo"
                  className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white"
                />
              </div>
            </div>

            <div>
              <label className="text-slate-300 font-semibold block mb-1">Premises Address</label>
              <input
                type="text"
                required
                value={propertyAddress}
                onChange={(e) => setPropertyAddress(e.target.value)}
                placeholder="Flat 4B, 14 Admiralty Way, Lekki Phase 1, Lagos"
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white"
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-slate-300 font-semibold block mb-1">Annual Reserved Rent (₦)</label>
                <input
                  type="number"
                  required
                  value={annualRent}
                  onChange={(e) => setAnnualRent(e.target.value)}
                  placeholder="4500000"
                  className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white font-mono"
                />
              </div>

              <div>
                <label className="text-slate-300 font-semibold block mb-1">Service Date</label>
                <input
                  type="date"
                  required
                  value={serviceDate}
                  onChange={(e) => setServiceDate(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white font-mono"
                />
              </div>
            </div>

            <div>
              <label className="text-slate-300 font-semibold block mb-1">Specific Legal Grounds</label>
              <textarea
                rows={2}
                value={legalGrounds}
                onChange={(e) => setLegalGrounds(e.target.value)}
                placeholder="e.g. Substantial personal renovation; determination by statutory effluxion of term..."
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200 resize-none"
              />
            </div>

            <button
              type="submit"
              disabled={saving}
              className="w-full py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs shadow-lg shadow-emerald-950/60 transition"
            >
              {saving ? 'Drafting Statutory Document...' : 'Generate Enforceable Legal Notice'}
            </button>
          </form>
        </div>

        {/* Live Document Preview */}
        <div className="lg:col-span-6 flex flex-col p-5 rounded-2xl bg-slate-900 border border-slate-800 space-y-3">
          <div className="flex items-center justify-between pb-2 border-b border-slate-800">
            <span className="text-xs font-bold text-white uppercase tracking-wider">Statutory Notice Document</span>
            {generatedDoc && (
              <button
                onClick={handleCopy}
                className="flex items-center gap-1.5 px-3 py-1 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold"
              >
                {copied ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
                <span>{copied ? 'Copied' : 'Copy Notice'}</span>
              </button>
            )}
          </div>

          <div className="flex-1 bg-slate-950 rounded-xl p-4 border border-slate-800/80 overflow-y-auto max-h-[460px] font-mono text-[11px] text-slate-300 whitespace-pre-wrap leading-relaxed">
            {generatedDoc || (
              <div className="h-full flex flex-col items-center justify-center text-center text-slate-500 space-y-2 py-12">
                <Scale className="w-8 h-8 text-slate-600" />
                <p>Fill in parameters on the left to draft a statutory Nigerian tenancy notice.</p>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* History of Served Statutory Notices */}
      {history.length > 0 && (
        <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 space-y-3 text-xs">
          <h2 className="text-sm font-bold text-white flex items-center gap-2">
            <Clock className="w-4 h-4 text-emerald-400" />
            <span>Served Statutory Notices Register</span>
          </h2>
          <div className="divide-y divide-slate-800/60">
            {history.map((h) => (
              <div key={h.id} className="py-2.5 flex items-center justify-between gap-4">
                <div>
                  <div className="font-bold text-white flex items-center gap-2">
                    <span>{h.tenantName}</span>
                    <span className="text-[10px] text-slate-400">({h.propertyAddress})</span>
                  </div>
                  <div className="text-[10px] text-emerald-400 mt-0.5">{h.legalCitation}</div>
                </div>
                <div className="text-right">
                  <span className="font-mono text-[10px] text-slate-400">
                    Expiry: {new Date(h.expiryDate).toLocaleDateString()}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};
