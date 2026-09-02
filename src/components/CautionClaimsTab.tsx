import React, { useState, useEffect } from 'react';
import { 
  ShieldAlert, 
  Search, 
  CheckCircle2, 
  AlertCircle, 
  X, 
  RefreshCw
} from 'lucide-react';

interface CautionItem {
  id: string;
  transactionId: string;
  propertyTitle: string;
  tenantName: string;
  tenantEmail: string;
  landlordName: string;
  landlordEmail: string;
  cautionAmount: number;
  status: 'held_in_escrow' | 'claim_filed' | 'refunded_to_tenant' | 'partially_deducted' | 'forfeited_to_landlord';
  damageClaim?: {
    id: string;
    claimedAmount: number;
    description: string;
    evidencePhotos?: string[];
    filedAt: string;
    resolution?: string;
  };
  refundedAmount?: number;
  deductedAmount?: number;
  resolvedAt?: string;
}

export const CautionClaimsTab: React.FC = () => {
  const [deposits, setDeposits] = useState<CautionItem[]>([]);
  const [search, setSearch] = useState('');
  const [filterStatus, setFilterStatus] = useState('all');
  const [selectedItem, setSelectedItem] = useState<CautionItem | null>(null);
  const [arbitrateModal, setArbitrateModal] = useState<CautionItem | null>(null);

  // Form states
  const [landlordShare, setLandlordShare] = useState<number>(0);
  const [tenantShare, setTenantShare] = useState<number>(0);
  const [notes, setNotes] = useState('');
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);
  const [loading, setLoading] = useState(true);

  const fetchDeposits = async () => {
    try {
      const res = await fetch('/api/caution/deposits');
      if (res.ok) {
        const d = await res.json();
        setDeposits(d.deposits || []);
      }
    } catch (_) {}
    setLoading(false);
  };

  useEffect(() => {
    fetchDeposits();
  }, []);

  const handleFullRefund = async (depositId: string) => {
    setSaving(true);
    try {
      const res = await fetch('/api/caution/resolve', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ depositId, action: 'full_refund' })
      });
      const data = await res.json();
      if (res.ok && data.success) {
        setMessage({ type: 'success', text: '100% Caution Fee Refund released to tenant wallet.' });
        fetchDeposits();
        setArbitrateModal(null);
      }
    } catch (err: any) {
      setMessage({ type: 'error', text: err.message || 'Refund execution failed.' });
    } finally {
      setSaving(false);
    }
  };

  const handleCustomResolution = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!arbitrateModal) return;
    setSaving(true);

    try {
      const res = await fetch('/api/caution/resolve', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          depositId: arbitrateModal.id,
          action: 'partial_split',
          landlordShare,
          tenantShare,
          arbitrationNotes: notes
        })
      });
      const data = await res.json();
      if (res.ok && data.success) {
        setMessage({ type: 'success', text: `Arbitration executed: ₦${tenantShare} refunded to tenant, ₦${landlordShare} released to landlord.` });
        fetchDeposits();
        setArbitrateModal(null);
      }
    } catch (err: any) {
      setMessage({ type: 'error', text: err.message || 'Arbitration execution failed.' });
    } finally {
      setSaving(false);
    }
  };

  const filtered = deposits.filter((d) => {
    const matchesStatus = filterStatus === 'all' || d.status === filterStatus;
    const matchesSearch = 
      d.propertyTitle.toLowerCase().includes(search.toLowerCase()) ||
      d.tenantName.toLowerCase().includes(search.toLowerCase()) ||
      d.landlordName.toLowerCase().includes(search.toLowerCase()) ||
      d.id.toLowerCase().includes(search.toLowerCase());

    return matchesStatus && matchesSearch;
  });

  const totalHeld = deposits.filter(d => d.status === 'held_in_escrow' || d.status === 'claim_filed').reduce((a, b) => a + b.cautionAmount, 0);
  const activeClaimsCount = deposits.filter(d => d.status === 'claim_filed').length;

  return (
    <div className="space-y-6 font-sans">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold text-white flex items-center gap-2">
            <ShieldAlert className="w-6 h-6 text-amber-400" />
            <span>Caution Deposits & Move-Out Damage Claims</span>
          </h1>
          <p className="text-xs text-slate-400 mt-0.5">
            Safeguard tenant caution fees in escrow, arbitrate landlord move-out repairs, and authorize wallet refunds.
          </p>
        </div>

        <button
          onClick={fetchDeposits}
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

      {/* KPI Stats */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Caution Funds in Escrow</span>
          <div className="text-2xl font-bold text-white mt-1">₦{totalHeld.toLocaleString()}</div>
          <span className="text-[10px] text-slate-400">100% safeguarded move-out deposits</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <span className="text-xs font-semibold text-amber-400 uppercase tracking-wider">Active Damage Claims</span>
          <div className="text-2xl font-bold text-amber-400 mt-1">{activeClaimsCount}</div>
          <span className="text-[10px] text-amber-400/80">Landlord deduction filings pending</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <span className="text-xs font-semibold text-emerald-400 uppercase tracking-wider">Settled & Refunded</span>
          <div className="text-2xl font-bold text-emerald-400 mt-1">
            {deposits.filter(d => d.status === 'refunded_to_tenant' || d.status === 'partially_deducted').length}
          </div>
          <span className="text-[10px] text-emerald-400/80">Move-out handovers mediated</span>
        </div>
      </div>

      {/* Search & Filters */}
      <div className="flex flex-col md:flex-row gap-3 items-center justify-between bg-slate-900/60 p-3.5 rounded-2xl border border-slate-800">
        <div className="relative w-full md:w-80">
          <Search className="w-4 h-4 text-slate-500 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by property, tenant, landlord..."
            className="w-full pl-9 pr-4 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-200 focus:outline-none focus:border-amber-500"
          />
        </div>

        <select
          value={filterStatus}
          onChange={(e) => setFilterStatus(e.target.value)}
          className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-300 focus:outline-none focus:border-amber-500 w-full md:w-auto"
        >
          <option value="all">All Caution Statuses</option>
          <option value="held_in_escrow">Held in Escrow</option>
          <option value="claim_filed">Damage Claim Filed</option>
          <option value="refunded_to_tenant">100% Refunded</option>
          <option value="partially_deducted">Arbitrated Split</option>
        </select>
      </div>

      {/* Table */}
      {filtered.length === 0 ? (
        <div className="p-12 text-center rounded-3xl bg-slate-900/40 border border-slate-800/80 space-y-3">
          <div className="w-12 h-12 rounded-2xl bg-slate-800/80 flex items-center justify-center mx-auto text-slate-500">
            <ShieldAlert className="w-6 h-6" />
          </div>
          <div className="space-y-1">
            <h3 className="text-sm font-bold text-white">No Caution Deposit Records</h3>
            <p className="text-xs text-slate-400">
              When tenants rent verified properties, their caution fees and move-out claims will be arbitrated here.
            </p>
          </div>
        </div>
      ) : (
        <div className="rounded-2xl bg-slate-900 border border-slate-800 overflow-hidden shadow-sm">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="border-b border-slate-800 text-slate-400 uppercase font-semibold text-[10px] tracking-wider bg-slate-950/40">
                <tr>
                  <th className="py-3.5 px-4 font-semibold">Property & Lease</th>
                  <th className="py-3.5 font-semibold">Tenant</th>
                  <th className="py-3.5 font-semibold">Landlord</th>
                  <th className="py-3.5 font-semibold">Caution Fee Held</th>
                  <th className="py-3.5 font-semibold">Status</th>
                  <th className="py-3.5 px-4 font-semibold text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60">
                {filtered.map((d) => (
                  <tr key={d.id} className="hover:bg-slate-850/50 transition">
                    <td className="py-3 px-4">
                      <div className="font-bold text-white">{d.propertyTitle}</div>
                      <div className="text-[10px] text-slate-500 font-mono">ID: {d.id}</div>
                    </td>
                    <td className="py-3">
                      <div className="font-medium text-white">{d.tenantName}</div>
                      <div className="text-[10px] text-slate-400">{d.tenantEmail}</div>
                    </td>
                    <td className="py-3">
                      <div className="font-medium text-white">{d.landlordName}</div>
                      <div className="text-[10px] text-slate-400">{d.landlordEmail}</div>
                    </td>
                    <td className="py-3 font-mono font-bold text-white">
                      ₦{d.cautionAmount.toLocaleString()}
                    </td>
                    <td className="py-3">
                      <span className={`px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase ${
                        d.status === 'held_in_escrow'
                          ? 'bg-blue-500/10 text-blue-400 border border-blue-500/30'
                          : d.status === 'claim_filed'
                          ? 'bg-amber-500/10 text-amber-400 border border-amber-500/30 animate-pulse'
                          : 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/30'
                      }`}>
                        {d.status.replace(/_/g, ' ')}
                      </span>
                    </td>
                    <td className="py-3 px-4 text-right">
                      <div className="flex items-center justify-end gap-1.5">
                        <button
                          onClick={() => setSelectedItem(d)}
                          className="px-2.5 py-1 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 text-[11px] font-semibold"
                        >
                          Inspect
                        </button>
                        {(d.status === 'held_in_escrow' || d.status === 'claim_filed') && (
                          <button
                            onClick={() => {
                              setArbitrateModal(d);
                              setTenantShare(d.cautionAmount);
                              setLandlordShare(0);
                            }}
                            className="px-2.5 py-1 rounded-lg bg-amber-600 hover:bg-amber-500 text-white text-[11px] font-bold shadow"
                          >
                            Arbitrate
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Arbitrate / Resolve Modal */}
      {arbitrateModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm">
          <div className="bg-slate-900 border border-slate-700 rounded-2xl w-full max-w-lg shadow-2xl overflow-hidden">
            <div className="px-6 py-4 border-b border-slate-800 flex items-center justify-between bg-slate-950/60">
              <h2 className="text-base font-bold text-white flex items-center gap-2">
                <ShieldAlert className="w-5 h-5 text-amber-400" />
                <span>Arbitrate Caution Deposit Settlement</span>
              </h2>
              <button 
                onClick={() => setArbitrateModal(null)}
                className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-6 space-y-4 text-xs">
              <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 flex items-center justify-between">
                <div>
                  <span className="text-slate-400 text-[11px]">Total Caution Fee Held:</span>
                  <div className="text-lg font-bold text-white font-mono">₦{arbitrateModal.cautionAmount.toLocaleString()}</div>
                </div>
                <button
                  type="button"
                  disabled={saving}
                  onClick={() => handleFullRefund(arbitrateModal.id)}
                  className="px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs"
                >
                  100% Refund to Tenant
                </button>
              </div>

              {arbitrateModal.damageClaim && (
                <div className="p-3.5 rounded-xl bg-amber-950/30 border border-amber-800/40 space-y-1">
                  <span className="font-bold text-amber-400">Landlord Damage Claim:</span>
                  <div className="text-white font-bold">₦{arbitrateModal.damageClaim.claimedAmount.toLocaleString()}</div>
                  <p className="text-slate-300">{arbitrateModal.damageClaim.description}</p>
                </div>
              )}

              <form onSubmit={handleCustomResolution} className="space-y-3 pt-2 border-t border-slate-800">
                <span className="font-bold text-white block">Custom Arbitration Split:</span>
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="text-slate-300 block mb-1">Tenant Refund (₦)</label>
                    <input
                      type="number"
                      required
                      value={tenantShare}
                      onChange={(e) => {
                        const val = Number(e.target.value);
                        setTenantShare(val);
                        setLandlordShare(Math.max(0, arbitrateModal.cautionAmount - val));
                      }}
                      className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-emerald-400 font-mono font-bold"
                    />
                  </div>
                  <div>
                    <label className="text-slate-300 block mb-1">Landlord Repair (₦)</label>
                    <input
                      type="number"
                      required
                      value={landlordShare}
                      onChange={(e) => {
                        const val = Number(e.target.value);
                        setLandlordShare(val);
                        setTenantShare(Math.max(0, arbitrateModal.cautionAmount - val));
                      }}
                      className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-red-400 font-mono font-bold"
                    />
                  </div>
                </div>

                <div>
                  <label className="text-slate-300 block mb-1">Arbitration Notes</label>
                  <textarea
                    rows={2}
                    value={notes}
                    onChange={(e) => setNotes(e.target.value)}
                    placeholder="Document legal reason for split (e.g. repainting deduction approved, sanitary ware dismissed)..."
                    className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200 resize-none"
                  />
                </div>

                <div className="flex justify-end gap-2 pt-2">
                  <button
                    type="button"
                    onClick={() => setArbitrateModal(null)}
                    className="px-4 py-2 rounded-xl bg-slate-800 text-slate-300 font-semibold"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={saving}
                    className="px-5 py-2 rounded-xl bg-amber-600 hover:bg-amber-500 text-white font-bold"
                  >
                    {saving ? 'Executing...' : 'Execute Payout Split'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}

      {/* Inspect Modal */}
      {selectedItem && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm">
          <div className="bg-slate-900 border border-slate-700 rounded-2xl w-full max-w-md shadow-2xl p-6 space-y-3 text-xs">
            <div className="flex justify-between items-center border-b border-slate-800 pb-2">
              <h3 className="font-bold text-white text-sm">{selectedItem.propertyTitle}</h3>
              <button onClick={() => setSelectedItem(null)} className="text-slate-400 hover:text-white"><X className="w-4 h-4" /></button>
            </div>
            <div className="space-y-1.5 text-slate-300">
              <div><span className="text-slate-500">Tenant:</span> {selectedItem.tenantName} ({selectedItem.tenantEmail})</div>
              <div><span className="text-slate-500">Landlord:</span> {selectedItem.landlordName} ({selectedItem.landlordEmail})</div>
              <div><span className="text-slate-500">Held Deposit:</span> ₦{selectedItem.cautionAmount.toLocaleString()}</div>
              <div><span className="text-slate-500">Status:</span> {selectedItem.status}</div>
              {selectedItem.damageClaim && (
                <div className="p-2.5 rounded-lg bg-slate-950 border border-slate-800 space-y-1 mt-2">
                  <span className="font-bold text-amber-400">Claim Details:</span>
                  <div>Claimed: ₦{selectedItem.damageClaim.claimedAmount.toLocaleString()}</div>
                  <div className="text-slate-400">{selectedItem.damageClaim.description}</div>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
