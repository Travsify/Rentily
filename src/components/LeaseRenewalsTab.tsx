import React, { useState, useEffect } from 'react';
import { 
  Calendar, 
  Search, 
  Send, 
  Clock, 
  CheckCircle2, 
  AlertCircle, 
  RefreshCw 
} from 'lucide-react';

interface RenewalItem {
  id: string;
  propertyTitle: string;
  tenantName: string;
  tenantEmail: string;
  landlordName: string;
  landlordEmail: string;
  currentAnnualRent: number;
  leaseStartDate: string;
  leaseEndDate: string;
  daysRemaining: number;
  renewalStatus: string;
}

export const LeaseRenewalsTab: React.FC = () => {
  const [renewals, setRenewals] = useState<RenewalItem[]>([]);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

  const fetchRenewals = async () => {
    try {
      const res = await fetch('/api/renewals/upcoming');
      if (res.ok) {
        const d = await res.json();
        setRenewals(d.renewals || []);
      }
    } catch (_) {}
    setLoading(false);
  };

  useEffect(() => {
    fetchRenewals();
  }, []);

  const handleSendReminder = async (item: RenewalItem) => {
    try {
      const res = await fetch('/api/renewals/dispatch-reminder', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          renewalId: item.id,
          tenantEmail: item.tenantEmail,
          tenantName: item.tenantName,
          propertyTitle: item.propertyTitle,
          annualRent: item.currentAnnualRent,
          daysRemaining: item.daysRemaining
        })
      });

      const data = await res.json();
      if (res.ok && data.success) {
        setMessage({ type: 'success', text: `Renewal notice & escrow link sent to ${item.tenantName}!` });
      }
    } catch (err: any) {
      setMessage({ type: 'error', text: err.message || 'Error dispatching reminder.' });
    }
  };

  const filtered = renewals.filter(r => 
    r.propertyTitle.toLowerCase().includes(search.toLowerCase()) ||
    r.tenantName.toLowerCase().includes(search.toLowerCase()) ||
    r.landlordName.toLowerCase().includes(search.toLowerCase())
  );

  const expiringSoonCount = renewals.filter(r => r.daysRemaining <= 60).length;

  return (
    <div className="space-y-6 font-sans">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold text-white flex items-center gap-2">
            <Calendar className="w-6 h-6 text-emerald-400" />
            <span>Annual Lease Expiry & Renewal Protocol</span>
          </h1>
          <p className="text-xs text-slate-400 mt-0.5">
            Track annual tenancies approaching expiration, automate renewal reminders, and route Year-2/Year-3 rents into Rentilly Escrow.
          </p>
        </div>

        <button
          onClick={fetchRenewals}
          title="Refresh"
          className="p-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-400 hover:text-white transition self-start sm:self-auto"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
        </button>
      </div>

      {message && (
        <div className={`p-3.5 rounded-xl text-xs flex items-center gap-2 ${
          message.type === 'success'
            ? 'bg-emerald-500/10 border border-emerald-500/30 text-emerald-300'
            : 'bg-red-500/10 border border-red-500/30 text-red-300'
        }`}>
          {message.type === 'success' ? <CheckCircle2 className="w-4 h-4 text-emerald-400" /> : <AlertCircle className="w-4 h-4 text-red-400" />}
          <span>{message.text}</span>
        </div>
      )}

      {/* KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Active Annual Leases</span>
          <div className="text-2xl font-bold text-white mt-1">{renewals.length}</div>
          <span className="text-[10px] text-slate-400">Total verified tenancies</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <span className="text-xs font-semibold text-amber-400 uppercase tracking-wider">Expiring Within 60 Days</span>
          <div className="text-2xl font-bold text-amber-400 mt-1">{expiringSoonCount}</div>
          <span className="text-[10px] text-amber-400/80">Action required to retain GMV</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <span className="text-xs font-semibold text-emerald-400 uppercase tracking-wider">Annual Renewal Pipeline</span>
          <div className="text-2xl font-bold text-emerald-400 mt-1">
            ₦{renewals.reduce((a, b) => a + Number(b.currentAnnualRent || 0), 0).toLocaleString()}
          </div>
          <span className="text-[10px] text-emerald-400/80">Potential Year-2 renewal GMV</span>
        </div>
      </div>

      {/* Search */}
      <div className="flex items-center bg-slate-900/60 p-3.5 rounded-2xl border border-slate-800">
        <div className="relative w-full max-w-sm">
          <Search className="w-4 h-4 text-slate-500 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by property, tenant, landlord..."
            className="w-full pl-9 pr-4 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-200 focus:outline-none focus:border-emerald-500"
          />
        </div>
      </div>

      {/* Table */}
      {filtered.length === 0 ? (
        <div className="p-12 text-center rounded-3xl bg-slate-900/40 border border-slate-800/80 space-y-3">
          <div className="w-12 h-12 rounded-2xl bg-slate-800/80 flex items-center justify-center mx-auto text-slate-500">
            <Calendar className="w-6 h-6" />
          </div>
          <div className="space-y-1">
            <h3 className="text-sm font-bold text-white">No Active Annual Leases</h3>
            <p className="text-xs text-slate-400">
              When tenants sign tenancy agreements, their annual renewal schedule will appear here.
            </p>
          </div>
        </div>
      ) : (
        <div className="rounded-2xl bg-slate-900 border border-slate-800 overflow-hidden shadow-sm">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="border-b border-slate-800 text-slate-400 uppercase font-semibold text-[10px] tracking-wider bg-slate-950/40">
                <tr>
                  <th className="py-3.5 px-4 font-semibold">Property & Tenant</th>
                  <th className="py-3.5 font-semibold">Landlord</th>
                  <th className="py-3.5 font-semibold">Annual Rent</th>
                  <th className="py-3.5 font-semibold">Lease Term</th>
                  <th className="py-3.5 font-semibold">Countdown</th>
                  <th className="py-3.5 px-4 font-semibold text-right">Renewal Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60">
                {filtered.map((r) => (
                  <tr key={r.id} className="hover:bg-slate-850/50 transition">
                    <td className="py-3 px-4">
                      <div className="font-bold text-white">{r.propertyTitle}</div>
                      <div className="text-[11px] text-slate-400">Tenant: {r.tenantName}</div>
                    </td>
                    <td className="py-3">
                      <div className="font-medium text-white">{r.landlordName}</div>
                      <div className="text-[10px] text-slate-500">{r.landlordEmail}</div>
                    </td>
                    <td className="py-3 font-mono font-bold text-white">
                      ₦{r.currentAnnualRent.toLocaleString()}
                    </td>
                    <td className="py-3 font-mono text-[10px] text-slate-400">
                      {new Date(r.leaseStartDate).toLocaleDateString()} — {new Date(r.leaseEndDate).toLocaleDateString()}
                    </td>
                    <td className="py-3">
                      <span className={`inline-flex items-center gap-1 text-[10px] font-bold px-2 py-0.5 rounded-full ${
                        r.daysRemaining <= 30
                          ? 'bg-red-500/10 text-red-400 border border-red-500/30 animate-pulse'
                          : r.daysRemaining <= 60
                          ? 'bg-amber-500/10 text-amber-400 border border-amber-500/30'
                          : 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/30'
                      }`}>
                        <Clock className="w-3 h-3" />
                        <span>{r.daysRemaining > 0 ? `${r.daysRemaining} days left` : 'Expired'}</span>
                      </span>
                    </td>
                    <td className="py-3 px-4 text-right">
                      <button
                        onClick={() => handleSendReminder(r)}
                        className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-[11px] shadow transition"
                      >
                        <Send className="w-3 h-3" />
                        <span>Send Renewal Notice</span>
                      </button>
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
