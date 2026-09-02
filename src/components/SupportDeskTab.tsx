import React, { useState, useEffect } from 'react';
import { 
  Headphones, 
  Search, 
  AlertTriangle, 
  CheckCircle2, 
  Clock, 
  Download, 
  X
} from 'lucide-react';

export interface SupportTicket {
  id: string;
  userId: string;
  userEmail: string;
  userName: string;
  businessName?: string;
  role: string;
  category: string;
  subject: string;
  message: string;
  urgency: 'normal' | 'urgent' | 'critical';
  status: 'open' | 'in_review' | 'resolved' | 'closed';
  createdAt: string;
}

export const SupportDeskTab: React.FC = () => {
  const [tickets, setTickets] = useState<SupportTicket[]>([]);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [urgencyFilter, setUrgencyFilter] = useState('all');
  const [selectedTicket, setSelectedTicket] = useState<SupportTicket | null>(null);

  const fetchTickets = async () => {
    try {
      const res = await fetch('/api/support/tickets');
      if (res.ok) {
        const data = await res.json();
        setTickets(data);
      }
    } catch (_) {}
  };

  useEffect(() => {
    fetchTickets();
    const interval = setInterval(fetchTickets, 15000);
    return () => clearInterval(interval);
  }, []);

  const handleUpdateStatus = (ticketId: string, newStatus: SupportTicket['status']) => {
    setTickets(prev => prev.map(t => t.id === ticketId ? { ...t, status: newStatus } : t));
    if (selectedTicket && selectedTicket.id === ticketId) {
      setSelectedTicket(prev => prev ? { ...prev, status: newStatus } : null);
    }
  };

  const filteredTickets = tickets.filter(t => {
    const matchesSearch = 
      t.id.toLowerCase().includes(search.toLowerCase()) ||
      t.subject.toLowerCase().includes(search.toLowerCase()) ||
      t.userEmail.toLowerCase().includes(search.toLowerCase()) ||
      (t.businessName || '').toLowerCase().includes(search.toLowerCase()) ||
      t.userName.toLowerCase().includes(search.toLowerCase());

    const matchesStatus = statusFilter === 'all' || t.status === statusFilter;
    const matchesUrgency = urgencyFilter === 'all' || t.urgency === urgencyFilter;

    return matchesSearch && matchesStatus && matchesUrgency;
  });

  const openCount = tickets.filter(t => t.status === 'open').length;
  const inReviewCount = tickets.filter(t => t.status === 'in_review').length;
  const resolvedCount = tickets.filter(t => t.status === 'resolved').length;
  const criticalCount = tickets.filter(t => t.urgency === 'critical' && t.status !== 'resolved').length;

  const exportToCSV = () => {
    if (tickets.length === 0) return;
    const headers = ['Ticket ID', 'Role', 'Entity / Name', 'Email', 'Category', 'Subject', 'Urgency', 'Status', 'Date'];
    const rows = tickets.map(t => [
      t.id,
      t.role,
      `"${(t.businessName || t.userName || '').replace(/"/g, '""')}"`,
      t.userEmail,
      t.category,
      `"${(t.subject || '').replace(/"/g, '""')}"`,
      t.urgency,
      t.status,
      t.createdAt
    ]);
    const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map(e => e.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `rentilly_support_tickets_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="space-y-6 font-sans">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold text-white flex items-center gap-2">
            <Headphones className="w-6 h-6 text-emerald-400" />
            <span>Support & Partner Arbitration Desk</span>
          </h1>
          <p className="text-xs text-slate-400 mt-0.5">
            Audit partner inquiries, commission claims, tenancy disputes, and legal desk submissions.
          </p>
        </div>

        {tickets.length > 0 && (
          <button
            onClick={exportToCSV}
            className="flex items-center gap-2 px-4 py-2 rounded-xl bg-slate-900 border border-slate-700 hover:border-slate-600 text-xs font-semibold text-white shadow-sm transition self-start sm:self-auto"
          >
            <Download className="w-4 h-4 text-emerald-400" />
            <span>Export Tickets (CSV)</span>
          </button>
        )}
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Open Tickets</span>
          <div className="text-2xl font-bold text-white mt-1">{openCount}</div>
          <span className="text-[10px] text-slate-400">Awaiting Legal Desk response</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">In Review / Mediation</span>
          <div className="text-2xl font-bold text-blue-400 mt-1">{inReviewCount}</div>
          <span className="text-[10px] text-blue-300/80">Active legal review in progress</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Critical Escalations</span>
          <div className="text-2xl font-bold text-red-400 mt-1">{criticalCount}</div>
          <span className="text-[10px] text-red-400/80">Urgent SLA (&lt; 24h)</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Resolved</span>
          <div className="text-2xl font-bold text-emerald-400 mt-1">{resolvedCount}</div>
          <span className="text-[10px] text-emerald-400/80">Closed & mediated</span>
        </div>
      </div>

      {/* Search and Filters */}
      <div className="flex flex-col md:flex-row gap-3 items-center justify-between bg-slate-900/60 p-3.5 rounded-2xl border border-slate-800">
        <div className="relative w-full md:w-80">
          <Search className="w-4 h-4 text-slate-500 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by ticket ID, firm, email or subject..."
            className="w-full pl-9 pr-4 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-200 focus:outline-none focus:border-emerald-500"
          />
        </div>

        <div className="flex items-center gap-2 w-full md:w-auto">
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-300 focus:outline-none focus:border-emerald-500"
          >
            <option value="all">All Statuses</option>
            <option value="open">Open</option>
            <option value="in_review">In Review</option>
            <option value="resolved">Resolved</option>
          </select>

          <select
            value={urgencyFilter}
            onChange={(e) => setUrgencyFilter(e.target.value)}
            className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-300 focus:outline-none focus:border-emerald-500"
          >
            <option value="all">All Urgency</option>
            <option value="critical">Critical</option>
            <option value="urgent">Urgent</option>
            <option value="normal">Normal</option>
          </select>
        </div>
      </div>

      {/* Table */}
      {filteredTickets.length === 0 ? (
        <div className="p-12 text-center rounded-3xl bg-slate-900/40 border border-slate-800/80 space-y-3">
          <div className="w-12 h-12 rounded-2xl bg-slate-800/80 flex items-center justify-center mx-auto text-slate-500">
            <Headphones className="w-6 h-6" />
          </div>
          <div className="space-y-1">
            <h3 className="text-sm font-bold text-white">No Tickets Found</h3>
            <p className="text-xs text-slate-400">
              {search || statusFilter !== 'all' || urgencyFilter !== 'all'
                ? 'Try adjusting your filters.'
                : 'Partner complaints, dispute filings, and support tickets will appear here.'}
            </p>
          </div>
        </div>
      ) : (
        <div className="rounded-2xl bg-slate-900 border border-slate-800 overflow-hidden shadow-sm">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="border-b border-slate-800 text-slate-400 uppercase font-semibold text-[10px] tracking-wider bg-slate-950/40">
                <tr>
                  <th className="py-3.5 px-4 font-semibold">Ticket ID & Date</th>
                  <th className="py-3.5 font-semibold">Entity / Sender</th>
                  <th className="py-3.5 font-semibold">Category</th>
                  <th className="py-3.5 font-semibold">Subject & Message</th>
                  <th className="py-3.5 font-semibold">Urgency</th>
                  <th className="py-3.5 font-semibold">Status</th>
                  <th className="py-3.5 px-4 font-semibold text-right">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60">
                {filteredTickets.map((t) => (
                  <tr key={t.id} className="hover:bg-slate-850/50 transition">
                    <td className="py-3 px-4 font-mono text-[11px] text-slate-300">
                      <div className="font-bold text-white">{t.id}</div>
                      <div className="text-[10px] text-slate-500">{new Date(t.createdAt).toLocaleDateString()}</div>
                    </td>
                    <td className="py-3">
                      <div className="font-semibold text-white">{t.businessName || t.userName}</div>
                      <div className="text-[11px] text-slate-400">{t.userEmail}</div>
                      <span className="text-[9px] uppercase tracking-wider px-1.5 py-0.5 rounded bg-slate-800 text-slate-400">
                        {t.role}
                      </span>
                    </td>
                    <td className="py-3 text-slate-300 font-medium capitalize">
                      {t.category.replace(/_/g, ' ')}
                    </td>
                    <td className="py-3 max-w-[260px]">
                      <div className="font-semibold text-white truncate">{t.subject}</div>
                      <div className="text-[11px] text-slate-400 truncate">{t.message}</div>
                    </td>
                    <td className="py-3">
                      <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold uppercase ${
                        t.urgency === 'critical'
                          ? 'bg-red-500/10 text-red-400 border border-red-500/30'
                          : t.urgency === 'urgent'
                          ? 'bg-amber-500/10 text-amber-400 border border-amber-500/30'
                          : 'bg-slate-800 text-slate-400 border border-slate-700'
                      }`}>
                        {t.urgency}
                      </span>
                    </td>
                    <td className="py-3">
                      <span className={`inline-flex items-center gap-1 text-[10px] font-bold px-2 py-0.5 rounded-full ${
                        t.status === 'resolved'
                          ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/30'
                          : t.status === 'in_review'
                          ? 'bg-blue-500/10 text-blue-400 border border-blue-500/30'
                          : 'bg-amber-500/10 text-amber-400 border border-amber-500/30'
                      }`}>
                        {t.status === 'resolved' && <CheckCircle2 className="w-3 h-3" />}
                        {t.status === 'in_review' && <Clock className="w-3 h-3" />}
                        {t.status === 'open' && <AlertTriangle className="w-3 h-3" />}
                        <span className="capitalize">{t.status.replace(/_/g, ' ')}</span>
                      </span>
                    </td>
                    <td className="py-3 px-4 text-right">
                      <button
                        onClick={() => setSelectedTicket(t)}
                        className="px-3 py-1 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs shadow transition"
                      >
                        Inspect
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Ticket Details Modal */}
      {selectedTicket && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm overflow-y-auto">
          <div className="bg-slate-900 border border-slate-700 rounded-2xl w-full max-w-xl shadow-2xl overflow-hidden">
            <div className="px-6 py-4 border-b border-slate-800 flex items-center justify-between bg-slate-950/60">
              <div className="flex items-center gap-3">
                <div className="w-9 h-9 rounded-xl bg-emerald-500/20 text-emerald-400 flex items-center justify-center">
                  <Headphones className="w-5 h-5" />
                </div>
                <div>
                  <h2 className="text-base font-bold text-white flex items-center gap-2">
                    <span>{selectedTicket.id}</span>
                    <span className="text-[10px] uppercase px-2 py-0.5 rounded bg-slate-800 text-slate-300">
                      {selectedTicket.category}
                    </span>
                  </h2>
                  <p className="text-xs text-slate-400">{selectedTicket.businessName || selectedTicket.userName} ({selectedTicket.userEmail})</p>
                </div>
              </div>
              <button 
                onClick={() => setSelectedTicket(null)}
                className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-6 space-y-4 text-xs">
              <div className="p-3 rounded-xl bg-slate-950 border border-slate-800 space-y-1">
                <span className="text-slate-400 font-medium">Subject</span>
                <p className="text-white font-bold text-sm">{selectedTicket.subject}</p>
              </div>

              <div className="p-3 rounded-xl bg-slate-950 border border-slate-800 space-y-1">
                <span className="text-slate-400 font-medium">Message Body</span>
                <p className="text-slate-200 leading-relaxed whitespace-pre-wrap">{selectedTicket.message}</p>
              </div>

              <div className="flex items-center gap-2 pt-2 border-t border-slate-800">
                <span className="text-slate-400 font-medium">Save Status:</span>
                <button
                  onClick={() => handleUpdateStatus(selectedTicket.id, 'in_review')}
                  className="px-3.5 py-2 rounded-lg bg-blue-600 hover:bg-blue-500 text-white font-bold text-xs shadow transition"
                >
                  Save Changes (In Review)
                </button>
                <button
                  onClick={() => handleUpdateStatus(selectedTicket.id, 'resolved')}
                  className="px-3.5 py-2 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs shadow transition"
                >
                  Save Changes & Resolve ✓
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
