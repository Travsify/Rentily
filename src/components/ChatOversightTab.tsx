import React, { useState, useEffect } from 'react';
import { 
  ShieldAlert, 
  Search, 
  CheckCircle2, 
  PhoneCall, 
  CreditCard, 
  User, 
  RefreshCw
} from 'lucide-react';

interface FlaggedMessage {
  id: string;
  senderId: string;
  senderName: string;
  senderRole: string;
  recipientId: string;
  propertyTitle?: string;
  content: string;
  violationType: 'phone_number' | 'bank_account' | 'circumvention_keyword';
  flaggedContent: string;
  severity: 'medium' | 'high' | 'critical';
  status: string;
  createdAt: string;
}

export const ChatOversightTab: React.FC = () => {
  const [messages, setMessages] = useState<FlaggedMessage[]>([]);
  const [search, setSearch] = useState('');
  const [severityFilter, setSeverityFilter] = useState('all');
  const [loading, setLoading] = useState(true);

  const fetchData = async () => {
    try {
      const res = await fetch('/api/chat/oversight');
      if (res.ok) {
        const d = await res.json();
        setMessages(d.flaggedMessages || []);
      }
    } catch (_) {}
    setLoading(false);
  };

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 15000);
    return () => clearInterval(interval);
  }, []);

  const filtered = messages.filter((m) => {
    const matchesSeverity = severityFilter === 'all' || m.severity === severityFilter;
    const matchesSearch = 
      m.content.toLowerCase().includes(search.toLowerCase()) ||
      m.senderName.toLowerCase().includes(search.toLowerCase()) ||
      (m.propertyTitle && m.propertyTitle.toLowerCase().includes(search.toLowerCase())) ||
      m.flaggedContent.toLowerCase().includes(search.toLowerCase());

    return matchesSeverity && matchesSearch;
  });

  const criticalCount = messages.filter(m => m.severity === 'critical').length;
  const highCount = messages.filter(m => m.severity === 'high').length;

  return (
    <div className="space-y-6 font-sans">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold text-white flex items-center gap-2">
            <ShieldAlert className="w-6 h-6 text-red-400" />
            <span>Chat Oversight & Anti-Circumvention Desk</span>
          </h1>
          <p className="text-xs text-slate-400 mt-0.5">
            Real-time scanner intercepting direct off-platform payments, phone number sharing, and illegal tenancy fee bypasses.
          </p>
        </div>

        <button
          onClick={fetchData}
          title="Refresh Messages"
          className="p-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-400 hover:text-white transition self-start sm:self-auto"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
        </button>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Total Flagged Interceptions</span>
          <div className="text-2xl font-bold text-white mt-1">{messages.length}</div>
          <span className="text-[10px] text-slate-400">Suspicious messages intercepted</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-red-400 uppercase tracking-wider">Critical Violations</span>
            <CreditCard className="w-4 h-4 text-red-400" />
          </div>
          <div className="text-2xl font-bold text-red-400 mt-1">{criticalCount}</div>
          <span className="text-[10px] text-red-400/80">Direct bank account & bypass attempts</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-amber-400 uppercase tracking-wider">Phone Number Disclosures</span>
            <PhoneCall className="w-4 h-4 text-amber-400" />
          </div>
          <div className="text-2xl font-bold text-amber-400 mt-1">{highCount}</div>
          <span className="text-[10px] text-amber-400/80">Off-app contact attempts</span>
        </div>
      </div>

      {/* Filter and Search Bar */}
      <div className="flex flex-col md:flex-row gap-3 items-center justify-between bg-slate-900/60 p-3.5 rounded-2xl border border-slate-800">
        <div className="relative w-full md:w-80">
          <Search className="w-4 h-4 text-slate-500 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search message text, sender, violation..."
            className="w-full pl-9 pr-4 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-200 focus:outline-none focus:border-red-500"
          />
        </div>

        <div className="flex items-center gap-2 w-full md:w-auto">
          <select
            value={severityFilter}
            onChange={(e) => setSeverityFilter(e.target.value)}
            className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-300 focus:outline-none focus:border-red-500"
          >
            <option value="all">All Severities</option>
            <option value="critical">Critical (Bank & Bypass)</option>
            <option value="high">High (Phone Numbers)</option>
            <option value="medium">Medium (Keywords)</option>
          </select>
        </div>
      </div>

      {/* Messages Table */}
      {filtered.length === 0 ? (
        <div className="p-12 text-center rounded-3xl bg-slate-900/40 border border-slate-800/80 space-y-3">
          <div className="w-12 h-12 rounded-2xl bg-slate-800/80 flex items-center justify-center mx-auto text-emerald-400">
            <CheckCircle2 className="w-6 h-6" />
          </div>
          <div className="space-y-1">
            <h3 className="text-sm font-bold text-white">Clean Communications Rail</h3>
            <p className="text-xs text-slate-400">
              No off-platform circumvention attempts or phone number disclosures detected in tenant-landlord chats.
            </p>
          </div>
        </div>
      ) : (
        <div className="rounded-2xl bg-slate-900 border border-slate-800 overflow-hidden shadow-sm">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="border-b border-slate-800 text-slate-400 uppercase font-semibold text-[10px] tracking-wider bg-slate-950/40">
                <tr>
                  <th className="py-3.5 px-4 font-semibold">Sender & Target Listing</th>
                  <th className="py-3.5 font-semibold">Violation Type</th>
                  <th className="py-3.5 font-semibold">Intercepted Content</th>
                  <th className="py-3.5 font-semibold">Severity</th>
                  <th className="py-3.5 font-semibold">Date</th>
                  <th className="py-3.5 px-4 font-semibold text-right">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60">
                {filtered.map((m) => (
                  <tr key={m.id} className="hover:bg-slate-850/50 transition">
                    <td className="py-3 px-4">
                      <div className="font-bold text-white flex items-center gap-1.5">
                        <User className="w-3.5 h-3.5 text-slate-400" />
                        <span>{m.senderName}</span>
                        <span className="text-[9px] uppercase px-1.5 py-0.2 rounded bg-slate-800 text-slate-400">
                          {m.senderRole}
                        </span>
                      </div>
                      <div className="text-[11px] text-emerald-400/80 mt-0.5">{m.propertyTitle}</div>
                    </td>
                    <td className="py-3 capitalize text-slate-300 font-medium">
                      {m.violationType.replace(/_/g, ' ')}
                    </td>
                    <td className="py-3 max-w-[320px]">
                      <div className="p-2 rounded-lg bg-slate-950 border border-slate-800 text-slate-200 text-[11px]">
                        "{m.content}"
                      </div>
                      <div className="mt-1 font-mono text-[10px] text-red-400 font-bold">
                        Trigger: {m.flaggedContent}
                      </div>
                    </td>
                    <td className="py-3">
                      <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold uppercase ${
                        m.severity === 'critical'
                          ? 'bg-red-500/10 text-red-400 border border-red-500/30'
                          : m.severity === 'high'
                          ? 'bg-amber-500/10 text-amber-400 border border-amber-500/30'
                          : 'bg-slate-800 text-slate-400 border border-slate-700'
                      }`}>
                        {m.severity}
                      </span>
                    </td>
                    <td className="py-3 font-mono text-[11px] text-slate-500">
                      {new Date(m.createdAt).toLocaleDateString()}
                    </td>
                    <td className="py-3 px-4 text-right">
                      <span className="text-[10px] font-bold text-amber-400 uppercase">
                        Flagged
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
};
