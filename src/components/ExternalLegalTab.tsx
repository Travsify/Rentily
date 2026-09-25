import React, { useState, useEffect } from 'react';
import {
  Scale,
  Search,
  CheckCircle,
  Clock,
  FileText,
  DollarSign,
  Shield,
  Eye,
  ExternalLink,
  User,
  MapPin,
  RefreshCw,
  XCircle,
  Award
} from 'lucide-react';

interface ExternalLegalOrder {
  id: string;
  userId: string;
  userEmail: string;
  userName: string;
  userPhone?: string;
  serviceType: 'single_doc_50k' | 'multi_doc_100k' | 'doc_preparation_3pct';
  serviceTitle: string;
  propertyTitle: string;
  propertyAddress: string;
  propertyState: string;
  propertyLga?: string;
  propertyValue?: number;
  feeAmount: number;
  documentType?: string;
  documentUrls: string[];
  additionalNotes?: string;
  status: 'pending_review' | 'in_progress' | 'completed' | 'rejected';
  assignedCounselName?: string;
  assignedCounselNba?: string;
  reportSummary?: string;
  reportPdfUrl?: string;
  certificateHash?: string;
  rejectionReason?: string;
  createdAt: string;
  updatedAt: string;
  completedAt?: string;
}

export const ExternalLegalTab: React.FC = () => {
  const [orders, setOrders] = useState<ExternalLegalOrder[]>([]);
  const [stats, setStats] = useState({
    totalOrders: 0,
    totalRevenue: 0,
    pendingCount: 0,
    inProgressCount: 0,
    completedCount: 0,
  });
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedOrder, setSelectedOrder] = useState<ExternalLegalOrder | null>(null);
  const [isUpdating, setIsUpdating] = useState(false);

  // Form State for update modal
  const [modalStatus, setModalStatus] = useState<string>('in_progress');
  const [counselName, setCounselName] = useState('Barr. Chijioke Okonkwo, SAN');
  const [counselNba, setCounselNba] = useState('SCN/NBA/2008/049182');
  const [reportSummary, setReportSummary] = useState('');
  const [reportPdfUrl, setReportPdfUrl] = useState('');
  const [rejectionReason, setRejectionReason] = useState('');

  const fetchOrders = async () => {
    try {
      setLoading(true);
      const token = localStorage.getItem('rentilly_admin_token') || 'admin-token-default';
      const res = await fetch(`/api/external-legal/admin/orders?status=${statusFilter}&q=${encodeURIComponent(searchQuery)}`, {
        headers: {
          'Authorization': `Bearer ${token}`,
          'x-actor-role': 'admin'
        }
      });
      const data = await res.json();
      if (data.status && data.data) {
        setOrders(data.data);
        if (data.stats) setStats(data.stats);
      }
    } catch (err) {
      console.error('Failed to fetch legal orders:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchOrders();
  }, [statusFilter, searchQuery]);

  const openManageModal = (order: ExternalLegalOrder) => {
    setSelectedOrder(order);
    setModalStatus(order.status === 'pending_review' ? 'in_progress' : order.status);
    setCounselName(order.assignedCounselName || 'Barr. Chijioke Okonkwo, SAN');
    setCounselNba(order.assignedCounselNba || 'SCN/NBA/2008/049182');
    setReportSummary(order.reportSummary || '');
    setReportPdfUrl(order.reportPdfUrl || '');
    setRejectionReason(order.rejectionReason || '');
  };

  const handleUpdateOrder = async () => {
    if (!selectedOrder) return;
    try {
      setIsUpdating(true);
      const token = localStorage.getItem('rentilly_admin_token') || 'admin-token-default';
      const res = await fetch(`/api/external-legal/admin/orders/${selectedOrder.id}/update`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
          'x-actor-role': 'admin'
        },
        body: JSON.stringify({
          status: modalStatus,
          assignedCounselName: counselName,
          assignedCounselNba: counselNba,
          reportSummary,
          reportPdfUrl,
          rejectionReason
        })
      });
      const data = await res.json();
      if (data.status && data.order) {
        setSelectedOrder(null);
        fetchOrders();
      } else {
        alert(data.error || 'Failed to update order');
      }
    } catch (err: any) {
      alert(err.message || 'Error updating order');
    } finally {
      setIsUpdating(false);
    }
  };

  const formatNaira = (val?: number) => {
    return '₦' + (val || 0).toLocaleString('en-US');
  };

  const getServiceBadge = (type: string) => {
    switch (type) {
      case 'single_doc_50k':
        return (
          <span className="px-2.5 py-1 bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 rounded-lg text-xs font-bold flex items-center gap-1.5">
            <FileText className="w-3.5 h-3.5" /> Single Doc (₦50k)
          </span>
        );
      case 'multi_doc_100k':
        return (
          <span className="px-2.5 py-1 bg-amber-500/10 text-amber-400 border border-amber-500/20 rounded-lg text-xs font-bold flex items-center gap-1.5">
            <Scale className="w-3.5 h-3.5" /> Registry Search (₦100k)
          </span>
        );
      case 'doc_preparation_3pct':
        return (
          <span className="px-2.5 py-1 bg-blue-500/10 text-blue-400 border border-blue-500/20 rounded-lg text-xs font-bold flex items-center gap-1.5">
            <Award className="w-3.5 h-3.5" /> 3% Legal Drafting
          </span>
        );
      default:
        return <span className="px-2 py-0.5 bg-gray-800 text-gray-300 rounded text-xs">{type}</span>;
    }
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'pending_review':
        return (
          <span className="px-2.5 py-1 bg-amber-500/10 text-amber-400 border border-amber-500/20 rounded-full text-xs font-semibold flex items-center gap-1">
            <Clock className="w-3 h-3" /> Pending Review
          </span>
        );
      case 'in_progress':
        return (
          <span className="px-2.5 py-1 bg-blue-500/10 text-blue-400 border border-blue-500/20 rounded-full text-xs font-semibold flex items-center gap-1">
            <RefreshCw className="w-3 h-3 animate-spin" /> In Progress
          </span>
        );
      case 'completed':
        return (
          <span className="px-2.5 py-1 bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 rounded-full text-xs font-semibold flex items-center gap-1">
            <CheckCircle className="w-3 h-3" /> Completed
          </span>
        );
      case 'rejected':
        return (
          <span className="px-2.5 py-1 bg-rose-500/10 text-rose-400 border border-rose-500/20 rounded-full text-xs font-semibold flex items-center gap-1">
            <XCircle className="w-3 h-3" /> Rejected
          </span>
        );
      default:
        return <span className="px-2 py-0.5 bg-gray-800 text-gray-400 rounded text-xs">{status}</span>;
    }
  };

  return (
    <div className="space-y-6">
      {/* Header Banner */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-gradient-to-r from-emerald-950/60 via-slate-900 to-slate-900 border border-emerald-500/20 rounded-2xl p-6">
        <div>
          <div className="flex items-center gap-2 text-emerald-400 text-xs font-bold uppercase tracking-wider mb-1">
            <Scale className="w-4 h-4" /> Legal & Due Diligence Operations
          </div>
          <h1 className="text-2xl font-black text-white">External Legal & Title Verification Desk</h1>
          <p className="text-sm text-slate-400 mt-1">
            Manage standalone external title searches, registry charting (₦50k/₦100k), and 3% conveyancing instrument drafting.
          </p>
        </div>
        <button
          onClick={fetchOrders}
          className="flex items-center gap-2 px-4 py-2.5 bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 rounded-xl text-xs font-bold transition-all"
        >
          <RefreshCw className="w-3.5 h-3.5" /> Refresh Desk
        </button>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-slate-900/70 border border-slate-800/80 rounded-2xl p-5">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400">Total Legal Revenue</span>
            <div className="p-2 bg-emerald-500/10 rounded-xl text-emerald-400">
              <DollarSign className="w-4 h-4" />
            </div>
          </div>
          <div className="text-2xl font-black text-white mt-3">{formatNaira(stats.totalRevenue)}</div>
          <div className="text-xs text-emerald-400 mt-1">100% wallet settled</div>
        </div>

        <div className="bg-slate-900/70 border border-slate-800/80 rounded-2xl p-5">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400">Pending Review</span>
            <div className="p-2 bg-amber-500/10 rounded-xl text-amber-400">
              <Clock className="w-4 h-4" />
            </div>
          </div>
          <div className="text-2xl font-black text-white mt-3">{stats.pendingCount}</div>
          <div className="text-xs text-amber-400 mt-1">Awaiting counsel assignment</div>
        </div>

        <div className="bg-slate-900/70 border border-slate-800/80 rounded-2xl p-5">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400">Active Searches / Drafting</span>
            <div className="p-2 bg-blue-500/10 rounded-xl text-blue-400">
              <Scale className="w-4 h-4" />
            </div>
          </div>
          <div className="text-2xl font-black text-white mt-3">{stats.inProgressCount}</div>
          <div className="text-xs text-blue-400 mt-1">Under registry investigation</div>
        </div>

        <div className="bg-slate-900/70 border border-slate-800/80 rounded-2xl p-5">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400">Completed & Certified</span>
            <div className="p-2 bg-teal-500/10 rounded-xl text-teal-400">
              <Shield className="w-4 h-4" />
            </div>
          </div>
          <div className="text-2xl font-black text-white mt-3">{stats.completedCount}</div>
          <div className="text-xs text-teal-400 mt-1">SHA-256 sealed reports</div>
        </div>
      </div>

      {/* Filter & Search Bar */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-3 bg-slate-900/60 border border-slate-800 rounded-2xl p-4">
        <div className="flex items-center gap-2 w-full sm:w-auto overflow-x-auto pb-1 sm:pb-0">
          {['all', 'pending_review', 'in_progress', 'completed', 'rejected'].map((st) => (
            <button
              key={st}
              onClick={() => setStatusFilter(st)}
              className={`px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all whitespace-nowrap ${
                statusFilter === st
                  ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-600/20'
                  : 'bg-slate-800 text-slate-400 hover:text-white'
              }`}
            >
              {st === 'all' ? 'All Orders' : st.replace('_', ' ').toUpperCase()}
            </button>
          ))}
        </div>

        <div className="relative w-full sm:w-72">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search client, property, ID..."
            className="w-full pl-10 pr-4 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500"
          />
        </div>
      </div>

      {/* Orders Table */}
      <div className="bg-slate-900/70 border border-slate-800 rounded-2xl overflow-hidden">
        {loading ? (
          <div className="p-12 text-center text-slate-400">
            <RefreshCw className="w-6 h-6 animate-spin mx-auto mb-2 text-emerald-400" />
            Loading legal requests...
          </div>
        ) : orders.length === 0 ? (
          <div className="p-12 text-center text-slate-500">
            <Scale className="w-8 h-8 mx-auto mb-2 opacity-30" />
            No external legal requests found matching your filter.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="bg-slate-950 text-slate-400 font-semibold border-b border-slate-800">
                <tr>
                  <th className="py-3.5 px-4">Order ID & Date</th>
                  <th className="py-3.5 px-4">Client Details</th>
                  <th className="py-3.5 px-4">Service Type</th>
                  <th className="py-3.5 px-4">External Property</th>
                  <th className="py-3.5 px-4">Fee Paid</th>
                  <th className="py-3.5 px-4">Status</th>
                  <th className="py-3.5 px-4 text-right">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60">
                {orders.map((o) => (
                  <tr key={o.id} className="hover:bg-slate-800/30 transition-colors">
                    <td className="py-3.5 px-4">
                      <div className="font-mono font-bold text-white">{o.id}</div>
                      <div className="text-slate-500 text-[11px] mt-0.5">
                        {new Date(o.createdAt).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' })}
                      </div>
                    </td>
                    <td className="py-3.5 px-4">
                      <div className="font-semibold text-white flex items-center gap-1.5">
                        <User className="w-3.5 h-3.5 text-slate-400" /> {o.userName}
                      </div>
                      <div className="text-slate-400 text-[11px]">{o.userEmail}</div>
                      {o.userPhone && <div className="text-slate-500 text-[10px]">{o.userPhone}</div>}
                    </td>
                    <td className="py-3.5 px-4">{getServiceBadge(o.serviceType)}</td>
                    <td className="py-3.5 px-4 max-w-xs">
                      <div className="font-bold text-white truncate">{o.propertyTitle}</div>
                      <div className="text-slate-400 text-[11px] truncate flex items-center gap-1 mt-0.5">
                        <MapPin className="w-3 h-3 text-emerald-400 flex-shrink-0" />
                        {o.propertyAddress}, {o.propertyState}
                      </div>
                      {o.propertyValue && (
                        <div className="text-emerald-400 font-semibold text-[10px] mt-0.5">
                          Valuation: {formatNaira(o.propertyValue)}
                        </div>
                      )}
                    </td>
                    <td className="py-3.5 px-4">
                      <div className="font-black text-emerald-400 text-sm">{formatNaira(o.feeAmount)}</div>
                      <div className="text-[10px] text-slate-500 font-semibold">Wallet Settled</div>
                    </td>
                    <td className="py-3.5 px-4">{getStatusBadge(o.status)}</td>
                    <td className="py-3.5 px-4 text-right">
                      <button
                        onClick={() => openManageModal(o)}
                        className="px-3 py-1.5 bg-emerald-600/10 hover:bg-emerald-600/20 text-emerald-400 border border-emerald-500/20 rounded-lg font-bold text-xs transition-all inline-flex items-center gap-1"
                      >
                        <Eye className="w-3.5 h-3.5" /> Manage
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Modal: Manage Order / Assign Counsel / Deliver Verdict */}
      {selectedOrder && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-2xl w-full p-6 space-y-5 shadow-2xl my-8">
            <div className="flex items-center justify-between pb-3 border-b border-slate-800">
              <div>
                <span className="text-xs font-bold text-emerald-400 uppercase tracking-wider">Legal Desk Docket</span>
                <h3 className="text-lg font-black text-white mt-0.5">Order #{selectedOrder.id}</h3>
              </div>
              <button
                onClick={() => setSelectedOrder(null)}
                className="text-slate-400 hover:text-white p-1 rounded-lg hover:bg-slate-800"
              >
                ✕
              </button>
            </div>

            {/* Service & Property Overview */}
            <div className="grid grid-cols-2 gap-4 bg-slate-950/70 p-4 rounded-xl border border-slate-800/80 text-xs">
              <div>
                <span className="text-slate-500 font-semibold">Service Requested</span>
                <div className="mt-1">{getServiceBadge(selectedOrder.serviceType)}</div>
              </div>
              <div>
                <span className="text-slate-500 font-semibold">Fee Paid from Wallet</span>
                <div className="font-bold text-emerald-400 text-sm mt-1">{formatNaira(selectedOrder.feeAmount)}</div>
              </div>
              <div className="col-span-2">
                <span className="text-slate-500 font-semibold">External Property Title & Location</span>
                <div className="font-bold text-white mt-0.5">{selectedOrder.propertyTitle}</div>
                <div className="text-slate-400 text-[11px]">{selectedOrder.propertyAddress}, {selectedOrder.propertyState}</div>
                {selectedOrder.propertyValue && (
                  <div className="text-emerald-400 text-[11px] font-semibold mt-0.5">
                    Stated Valuation: {formatNaira(selectedOrder.propertyValue)} (3% Fee: {formatNaira(selectedOrder.feeAmount)})
                  </div>
                )}
              </div>
            </div>

            {/* Uploaded Documents */}
            <div>
              <label className="block text-xs font-bold text-slate-300 mb-2">Client Uploaded Documents</label>
              {selectedOrder.documentUrls && selectedOrder.documentUrls.length > 0 ? (
                <div className="flex flex-wrap gap-2">
                  {selectedOrder.documentUrls.map((url, idx) => (
                    <a
                      key={idx}
                      href={url}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="px-3 py-1.5 bg-slate-800 hover:bg-slate-700 text-emerald-400 border border-slate-700 rounded-lg text-xs font-semibold flex items-center gap-1.5"
                    >
                      <FileText className="w-3.5 h-3.5" /> Document #{idx + 1} <ExternalLink className="w-3 h-3" />
                    </a>
                  ))}
                </div>
              ) : (
                <div className="text-xs text-slate-500 italic bg-slate-950/50 p-3 rounded-xl border border-slate-800">
                  No direct file uploads attached. Client requested physical investigation based on provided address.
                </div>
              )}
            </div>

            {/* Client Notes */}
            {selectedOrder.additionalNotes && (
              <div>
                <label className="block text-xs font-bold text-slate-400 mb-1">Client Special Instructions</label>
                <div className="text-xs text-slate-300 bg-slate-950 p-3 rounded-xl border border-slate-800/80">
                  {selectedOrder.additionalNotes}
                </div>
              </div>
            )}

            {/* Legal Operations Management Form */}
            <div className="space-y-4 pt-3 border-t border-slate-800">
              <h4 className="text-xs font-bold uppercase tracking-wider text-emerald-400 flex items-center gap-1.5">
                <Shield className="w-4 h-4" /> Legal Officer Action & Docket Assignment
              </h4>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-semibold text-slate-400 mb-1">Status</label>
                  <select
                    value={modalStatus}
                    onChange={(e) => setModalStatus(e.target.value)}
                    className="w-full px-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white focus:border-emerald-500"
                  >
                    <option value="pending_review">Pending Review</option>
                    <option value="in_progress">In Progress (Registry Search / Drafting)</option>
                    <option value="completed">Completed & Certified</option>
                    <option value="rejected">Rejected / Invalid Info</option>
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-400 mb-1">Assigned Counsel Name</label>
                  <input
                    type="text"
                    value={counselName}
                    onChange={(e) => setCounselName(e.target.value)}
                    className="w-full px-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white focus:border-emerald-500"
                    placeholder="e.g. Barr. Chijioke Okonkwo, SAN"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-400 mb-1">Counsel NBA Enrollment / Seal Number</label>
                <input
                  type="text"
                  value={counselNba}
                  onChange={(e) => setCounselNba(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white focus:border-emerald-500"
                  placeholder="SCN/NBA/2008/049182"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-400 mb-1">Legal Opinion / Due Diligence Report Summary</label>
                <textarea
                  value={reportSummary}
                  onChange={(e) => setReportSummary(e.target.value)}
                  rows={3}
                  className="w-full px-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white focus:border-emerald-500"
                  placeholder="e.g. Search conducted at Lagos State Lands Bureau. C of O No. 45/45/2012 is authentic, unencumbered by court litigation or government acquisition. Title is clean for acquisition."
                />
              </div>

              {modalStatus === 'completed' && (
                <div>
                  <label className="block text-xs font-semibold text-slate-400 mb-1">Certified PDF Report / Deed URL</label>
                  <input
                    type="text"
                    value={reportPdfUrl}
                    onChange={(e) => setReportPdfUrl(e.target.value)}
                    className="w-full px-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white focus:border-emerald-500"
                    placeholder="https://cdn.myrentilly.com/legal/reports/rep_2026_092.pdf"
                  />
                  <span className="text-[10px] text-emerald-400 mt-1 block">
                    * On completion, a SHA-256 cryptographic seal will be stamped and dispatched to user.
                  </span>
                </div>
              )}

              {modalStatus === 'rejected' && (
                <div>
                  <label className="block text-xs font-semibold text-rose-400 mb-1">Rejection / Defect Reason</label>
                  <textarea
                    value={rejectionReason}
                    onChange={(e) => setRejectionReason(e.target.value)}
                    rows={2}
                    className="w-full px-3 py-2 bg-slate-950 border border-rose-500/30 rounded-xl text-xs text-white focus:border-rose-500"
                    placeholder="Provide reason for rejecting request or flagging defective title..."
                  />
                </div>
              )}
            </div>

            {/* Modal Actions */}
            <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-800">
              <button
                type="button"
                onClick={() => setSelectedOrder(null)}
                className="px-4 py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded-xl text-xs font-bold transition-all"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleUpdateOrder}
                disabled={isUpdating}
                className="px-5 py-2 bg-emerald-600 hover:bg-emerald-500 text-white rounded-xl text-xs font-bold transition-all shadow-lg shadow-emerald-600/30 disabled:opacity-50"
              >
                {isUpdating ? 'Saving...' : 'Save & Update Docket ➔'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
