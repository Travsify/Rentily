import React, { useState, useEffect } from 'react';
import { 
  ShieldAlert, 
  Search, 
  Trash2, 
  UserX, 
  AlertTriangle, 
  Phone, 
  CreditCard, 
  ShieldCheck
} from 'lucide-react';
import type { FraudBlacklistEntry } from '../types';

export const FraudBlacklistTab: React.FC = () => {
  const [blacklist, setBlacklist] = useState<FraudBlacklistEntry[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [showAddModal, setShowAddModal] = useState(false);

  // Form State
  const [newEntry, setNewEntry] = useState({
    fullName: '',
    phoneNumber: '',
    bvn: '',
    nin: '',
    bankAccountNumber: '',
    bankName: 'Guaranty Trust Bank (GTBank)',
    flagReason: '',
    severity: 'high' as FraudBlacklistEntry['severity']
  });

  const loadBlacklist = async () => {
    try {
      const res = await fetch('/api/fraud/blacklist');
      if (res.ok) {
        const data = await res.json();
        const list = Array.isArray(data)
          ? data
          : (Array.isArray(data?.blacklist)
              ? data.blacklist
              : (Array.isArray(data?.data) ? data.data : []));
        setBlacklist(list);
      }
    } catch (e) {
      console.error('Error fetching blacklist:', e);
      setBlacklist([]);
    }
  };

  useEffect(() => {
    loadBlacklist();
  }, []);

  const handleAddBlacklist = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newEntry.fullName || !newEntry.flagReason) return;

    try {
      const res = await fetch('/api/fraud/blacklist', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newEntry)
      });

      if (res.ok) {
        setShowAddModal(false);
        setNewEntry({
          fullName: '',
          phoneNumber: '',
          bvn: '',
          nin: '',
          bankAccountNumber: '',
          bankName: 'Guaranty Trust Bank (GTBank)',
          flagReason: '',
          severity: 'high'
        });
        await loadBlacklist();
      }
    } catch (e) {
      console.error('Error adding blacklist entry:', e);
    }
  };

  const handleDeleteEntry = async (id: string) => {
    try {
      const res = await fetch(`/api/fraud/blacklist/${id}`, {
        method: 'DELETE'
      });
      if (res.ok) {
        await loadBlacklist();
      }
    } catch (e) {
      console.error('Error removing entry:', e);
    }
  };

  const safeList = Array.isArray(blacklist) ? blacklist : [];
  const filtered = safeList.filter((b) => {
    if (!b) return false;
    const q = (searchQuery || '').toLowerCase();
    const name = (b.fullName || '').toLowerCase();
    const phone = (b.phoneNumber || '');
    const bvn = (b.bvn || '');
    const nin = (b.nin || '');
    const reason = (b.flagReason || '').toLowerCase();
    return (
      name.includes(q) ||
      phone.includes(q) ||
      bvn.includes(q) ||
      nin.includes(q) ||
      reason.includes(q)
    );
  });

  return (
    <div className="space-y-6 font-sans">
      {/* Top Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-lg font-bold text-white flex items-center gap-2">
            <ShieldAlert className="w-5 h-5 text-red-400" />
            <span>Fraud & Rogue Agent Blacklist Desk</span>
          </h1>
          <p className="text-xs text-slate-400 mt-0.5">
            Central registry of flagged fake landlords, double-letting scammers, and rogue agents prohibited from listing properties on Rentilly.
          </p>
        </div>

        <button
          onClick={() => setShowAddModal(true)}
          className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-red-600 hover:bg-red-500 text-white text-xs font-semibold shadow-md shadow-red-950/40 transition transform active:scale-95 self-start sm:self-auto"
        >
          <UserX className="w-3.5 h-3.5" />
          <span>Flag & Blacklist Scammer</span>
        </button>
      </div>

      {/* Add Modal */}
      {showAddModal && (
        <div className="p-5 rounded-2xl bg-slate-900 border border-red-500/30 shadow-2xl space-y-4">
          <div className="flex items-center justify-between pb-2 border-b border-slate-800">
            <h2 className="text-xs font-bold text-white flex items-center gap-2">
              <AlertTriangle className="w-4 h-4 text-red-400" />
              <span>Blacklist Rogue Agent / Fraudulent Individual</span>
            </h2>
            <button
              onClick={() => setShowAddModal(false)}
              className="text-xs text-slate-400 hover:text-white"
            >
              ✕
            </button>
          </div>

          <form onSubmit={handleAddBlacklist} className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3.5 text-xs">
            <div>
              <label className="block text-slate-300 font-semibold text-[11px] mb-1">Full Name *</label>
              <input
                type="text"
                required
                value={newEntry.fullName}
                onChange={(e) => setNewEntry({ ...newEntry, fullName: e.target.value })}
                placeholder="e.g. Chief 'Alhaji' Impersonator"
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200 focus:outline-none focus:border-red-500 text-xs"
              />
            </div>

            <div>
              <label className="block text-slate-300 font-semibold text-[11px] mb-1">Phone Number</label>
              <input
                type="text"
                value={newEntry.phoneNumber}
                onChange={(e) => setNewEntry({ ...newEntry, phoneNumber: e.target.value })}
                placeholder="+2348000000000"
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200 focus:outline-none focus:border-red-500 text-xs font-mono"
              />
            </div>

            <div>
              <label className="block text-slate-300 font-semibold text-[11px] mb-1">NIN Number</label>
              <input
                type="text"
                value={newEntry.nin}
                onChange={(e) => setNewEntry({ ...newEntry, nin: e.target.value })}
                placeholder="11-digit NIN"
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200 focus:outline-none focus:border-red-500 text-xs font-mono"
              />
            </div>

            <div>
              <label className="block text-slate-300 font-semibold text-[11px] mb-1">Bank Account Number</label>
              <input
                type="text"
                value={newEntry.bankAccountNumber}
                onChange={(e) => setNewEntry({ ...newEntry, bankAccountNumber: e.target.value })}
                placeholder="10-digit NUBAN"
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200 focus:outline-none focus:border-red-500 text-xs font-mono"
              />
            </div>

            <div>
              <label className="block text-slate-300 font-semibold text-[11px] mb-1">Severity Risk Level</label>
              <select
                value={newEntry.severity}
                onChange={(e) => setNewEntry({ ...newEntry, severity: e.target.value as any })}
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200 text-xs"
              >
                <option value="critical">Critical (Confirmed Land Scammer / Impersonator)</option>
                <option value="high">High (Rogue Middleman Agent)</option>
                <option value="medium">Medium (Fake Document Submitter)</option>
                <option value="low">Low (Flagged for Review)</option>
              </select>
            </div>

            <div className="sm:col-span-2 lg:col-span-3">
              <label className="block text-slate-300 font-semibold text-[11px] mb-1">Flag Reason & Incident Report *</label>
              <textarea
                required
                rows={2}
                value={newEntry.flagReason}
                onChange={(e) => setNewEntry({ ...newEntry, flagReason: e.target.value })}
                placeholder="Detailed reason e.g. Attempted to collect 20% mobilization fee on a Lekki property they do not own; submitted forged Governor's Consent deed."
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200 focus:outline-none focus:border-red-500 text-xs"
              />
            </div>

            <div className="sm:col-span-2 lg:col-span-3 flex justify-end gap-2 pt-2 border-t border-slate-800">
              <button
                type="button"
                onClick={() => setShowAddModal(false)}
                className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold"
              >
                Cancel
              </button>
              <button
                type="submit"
                className="px-4 py-2 rounded-xl bg-red-600 hover:bg-red-500 text-white text-xs font-bold shadow-md"
              >
                Save Changes & Submit to Blacklist
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Search Bar */}
      <div className="flex items-center gap-2 p-3 rounded-2xl bg-slate-900/70 border border-slate-800">
        <Search className="w-4 h-4 text-slate-500 ml-1" />
        <input
          type="text"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          placeholder="Search blacklist by name, phone, NIN, BVN, or incident details..."
          className="w-full bg-transparent text-xs text-slate-200 placeholder-slate-500 focus:outline-none"
        />
      </div>

      {/* Blacklist Table or Empty State */}
      {filtered.length === 0 ? (
        <div className="p-12 text-center rounded-3xl bg-slate-900/40 border border-slate-800/80 space-y-3">
          <div className="w-14 h-14 rounded-2xl bg-slate-800/80 flex items-center justify-center mx-auto text-emerald-400">
            <ShieldCheck className="w-7 h-7" />
          </div>
          <div className="space-y-1 max-w-sm mx-auto">
            <h3 className="text-base font-bold text-white">No Flagged Entities in Blacklist</h3>
            <p className="text-xs text-slate-400">
              Rogue agents, fake landlords, or defaulting accounts flagged by automated Prembly identity cross-checks or admin reviews will be isolated here.
            </p>
          </div>
        </div>
      ) : (
        <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 overflow-x-auto shadow-sm">
          <table className="w-full text-left text-xs">
            <thead className="border-b border-slate-800 text-slate-400 uppercase font-semibold text-[10px] tracking-wider">
              <tr>
                <th className="pb-3">Individual / Rogue Agent</th>
                <th className="pb-3">Identifiers (Phone / NIN / BVN)</th>
                <th className="pb-3">Incident Reason</th>
                <th className="pb-3">Severity</th>
                <th className="pb-3">Flagged At</th>
                <th className="pb-3 text-right">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60">
              {filtered.map((entry) => (
                <tr key={entry.id || Math.random()} className="hover:bg-slate-850/50 transition">
                  <td className="py-3 font-semibold text-white">
                    <div>{entry.fullName || 'Unnamed Subject'}</div>
                    <span className="text-[10px] text-slate-500 font-mono">ID: {(entry.id || '').toString().slice(0, 8)}</span>
                  </td>

                  <td className="py-3 text-slate-300 font-mono text-[11px] space-y-0.5">
                    {entry.phoneNumber && <div className="flex items-center gap-1"><Phone className="w-3 h-3 text-slate-500" /> {entry.phoneNumber}</div>}
                    {entry.nin && <div>NIN: {entry.nin}</div>}
                    {entry.bankAccountNumber && <div className="flex items-center gap-1"><CreditCard className="w-3 h-3 text-slate-500" /> {entry.bankAccountNumber}</div>}
                  </td>

                  <td className="py-3 text-slate-300 max-w-xs leading-relaxed">
                    {entry.flagReason || 'Flagged for suspicious activity'}
                  </td>

                  <td className="py-3">
                    <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full uppercase border ${
                      entry.severity === 'critical'
                        ? 'bg-red-500/20 text-red-300 border-red-500/40'
                        : entry.severity === 'high'
                        ? 'bg-amber-500/20 text-amber-300 border-amber-500/40'
                        : 'bg-slate-800 text-slate-300 border-slate-700'
                    }`}>
                      {entry.severity || 'high'}
                    </span>
                  </td>

                  <td className="py-3 text-slate-400 text-[11px]">
                    {entry.createdAt ? new Date(entry.createdAt).toLocaleDateString() : 'Active'}
                  </td>

                  <td className="py-3 text-right">
                    <button
                      onClick={() => handleDeleteEntry(entry.id)}
                      className="p-1.5 rounded-lg bg-slate-800 hover:bg-red-500/20 text-slate-400 hover:text-red-400 transition"
                      title="Unban / Remove from Blacklist"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
};
