import React, { useState, useEffect } from 'react';
import { 
  Zap, 
  DollarSign, 
  TrendingUp, 
  Users, 
  Globe 
} from 'lucide-react';
import { CreatorBountyService } from '../services/creatorBountyService';
import type { CreatorSubmission, BountyStatus } from '../types/creatorBounty';

export const CreatorBountiesAdminTab: React.FC<{ onOpenPublicPortal: () => void }> = ({ onOpenPublicPortal }) => {
  const [submissions, setSubmissions] = useState<CreatorSubmission[]>([]);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editViews, setEditViews] = useState<number>(0);
  const [editStatus, setEditStatus] = useState<BountyStatus>('under_review');
  const [editTxRef, setEditTxRef] = useState<string>('');

  const loadData = () => {
    setSubmissions(CreatorBountyService.getSubmissions());
  };

  useEffect(() => {
    loadData();
  }, []);

  const handleStartEdit = (sub: CreatorSubmission) => {
    setEditingId(sub.id);
    setEditViews(sub.verifiedViews || sub.claimedViews);
    setEditStatus(sub.bountyStatus);
    setEditTxRef(sub.payoutTxRef || '');
  };

  const handleSaveEdit = (id: string) => {
    let payout = 0;
    if (editStatus === 'qualified_500k') payout = 150000;
    else if (editStatus === 'qualified_100k') payout = 50000;
    else if (editStatus === 'qualified_25k') payout = 15000;
    else if (editStatus === 'grand_prize') payout = 300000;
    else if (editStatus === 'paid') {
      const existing = submissions.find((s) => s.id === id);
      payout = existing?.payoutAmount || 15000;
    }

    CreatorBountyService.updateSubmission(id, {
      verifiedViews: editViews,
      bountyStatus: editStatus,
      payoutAmount: payout,
      payoutTxRef: editTxRef,
      paidAt: editStatus === 'paid' ? new Date().toISOString() : undefined,
    });

    setEditingId(null);
    loadData();
  };

  const handleDelete = (id: string) => {
    if (window.confirm('Are you sure you want to remove this creator submission?')) {
      CreatorBountyService.deleteSubmission(id);
      loadData();
    }
  };

  const stats = CreatorBountyService.getStats();

  return (
    <div className="space-y-6">
      {/* Top Action Bar */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-slate-900 border border-slate-800 p-6 rounded-2xl">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-2xl font-black text-white">Creator Bounties &amp; Viral Swarm</h1>
            <span className="px-2.5 py-0.5 rounded-full text-xs font-bold bg-amber-500/20 text-amber-300 border border-amber-500/40">
              Cluely Playbook Desk
            </span>
          </div>
          <p className="text-xs text-slate-400 mt-1">
            Manage 50+ creator drops, verify view milestones, and approve instant bank payouts.
          </p>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={onOpenPublicPortal}
            className="px-4 py-2.5 rounded-xl bg-gradient-to-r from-emerald-500 to-emerald-600 text-slate-950 font-bold text-xs shadow-lg shadow-emerald-500/20 flex items-center gap-2 hover:from-emerald-400 hover:to-emerald-500 transition"
          >
            <Globe className="w-4 h-4" />
            <span>View Public Live Leaderboard</span>
          </button>
        </div>
      </div>

      {/* Metrics Row */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="bg-slate-900 border border-slate-800 p-4 rounded-xl">
          <div className="flex items-center justify-between">
            <span className="text-xs text-slate-400 uppercase font-bold">Total Swarm Views</span>
            <TrendingUp className="w-4 h-4 text-emerald-400" />
          </div>
          <div className="text-2xl font-black text-emerald-400 mt-1">{stats.totalViews.toLocaleString()}</div>
        </div>
        <div className="bg-slate-900 border border-slate-800 p-4 rounded-xl">
          <div className="flex items-center justify-between">
            <span className="text-xs text-slate-400 uppercase font-bold">Submissions</span>
            <Users className="w-4 h-4 text-slate-400" />
          </div>
          <div className="text-2xl font-black text-white mt-1">{stats.totalSubmissions}</div>
        </div>
        <div className="bg-slate-900 border border-slate-800 p-4 rounded-xl">
          <div className="flex items-center justify-between">
            <span className="text-xs text-slate-400 uppercase font-bold">Milestones Qualified</span>
            <Zap className="w-4 h-4 text-amber-400" />
          </div>
          <div className="text-2xl font-black text-amber-400 mt-1">{stats.qualifiedCount}</div>
        </div>
        <div className="bg-slate-900 border border-slate-800 p-4 rounded-xl">
          <div className="flex items-center justify-between">
            <span className="text-xs text-slate-400 uppercase font-bold">Total Paid Out</span>
            <DollarSign className="w-4 h-4 text-purple-400" />
          </div>
          <div className="text-2xl font-black text-purple-400 mt-1">₦{stats.totalPaidOut.toLocaleString()}</div>
        </div>
      </div>

      {/* Submissions Admin Table */}
      <div className="bg-slate-900 border border-slate-800 rounded-2xl overflow-hidden shadow-xl">
        <div className="p-4 border-b border-slate-800 flex items-center justify-between">
          <h2 className="text-sm font-bold text-white uppercase tracking-wider">All Creator Video Submissions</h2>
          <span className="text-xs text-slate-400">{submissions.length} Total Drops</span>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-950/80 text-slate-400 uppercase tracking-wider border-b border-slate-800">
              <tr>
                <th className="py-3 px-4">Creator</th>
                <th className="py-3 px-4">Platform &amp; URL</th>
                <th className="py-3 px-4">Views</th>
                <th className="py-3 px-4">Bank Details</th>
                <th className="py-3 px-4">Bounty Status</th>
                <th className="py-3 px-4 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60">
              {submissions.map((sub) => {
                const isEditing = editingId === sub.id;
                return (
                  <tr key={sub.id} className="hover:bg-slate-800/40 transition">
                    <td className="py-3 px-4">
                      <div className="font-bold text-white">{sub.creatorName}</div>
                      <div className="text-emerald-400 font-semibold">{sub.handle}</div>
                      <div className="text-[11px] text-slate-400">{sub.phone}</div>
                    </td>
                    <td className="py-3 px-4">
                      <span className="uppercase font-bold text-[10px] px-2 py-0.5 rounded bg-slate-800 text-slate-300 block w-max mb-1">
                        {sub.platform}
                      </span>
                      <a
                        href={sub.videoUrl}
                        target="_blank"
                        rel="noreferrer"
                        className="text-emerald-400 hover:underline max-w-[200px] truncate block text-[11px]"
                      >
                        {sub.videoUrl}
                      </a>
                    </td>
                    <td className="py-3 px-4">
                      {isEditing ? (
                        <input
                          type="number"
                          value={editViews}
                          onChange={(e) => setEditViews(Number(e.target.value))}
                          className="w-24 px-2 py-1 bg-slate-950 border border-emerald-500 rounded text-xs text-white"
                        />
                      ) : (
                        <div>
                          <div className="font-black text-white text-sm">
                            {(sub.verifiedViews || sub.claimedViews).toLocaleString()}
                          </div>
                          <span className="text-[10px] text-slate-500">
                            {sub.verifiedViews ? 'Verified' : 'Claimed'}
                          </span>
                        </div>
                      )}
                    </td>
                    <td className="py-3 px-4">
                      {sub.bankName ? (
                        <div>
                          <span className="text-white font-semibold block">{sub.bankName}</span>
                          <span className="font-mono text-slate-300">{sub.accountNumber}</span>
                          <span className="text-slate-400 block text-[10px]">{sub.accountName}</span>
                        </div>
                      ) : (
                        <span className="text-slate-500 italic">Not provided</span>
                      )}
                    </td>
                    <td className="py-3 px-4">
                      {isEditing ? (
                        <select
                          value={editStatus}
                          onChange={(e) => setEditStatus(e.target.value as BountyStatus)}
                          className="px-2 py-1 bg-slate-950 border border-emerald-500 rounded text-xs text-white"
                        >
                          <option value="under_review">Under Review</option>
                          <option value="qualified_25k">Qualified ₦15k (25k views)</option>
                          <option value="qualified_100k">Qualified ₦50k (100k views)</option>
                          <option value="qualified_500k">Qualified ₦150k (500k views)</option>
                          <option value="grand_prize">Grand Champion ₦300k</option>
                          <option value="paid">PAID OUT</option>
                        </select>
                      ) : (
                        <div>
                          <span className="font-bold capitalize block text-white">
                            {sub.bountyStatus.replace('_', ' ')}
                          </span>
                          {sub.payoutAmount > 0 && (
                            <span className="text-emerald-400 font-bold text-[11px]">
                              ₦{sub.payoutAmount.toLocaleString()} Bonus
                            </span>
                          )}
                        </div>
                      )}
                    </td>
                    <td className="py-3 px-4 text-right space-x-2">
                      {isEditing ? (
                        <>
                          <button
                            onClick={() => handleSaveEdit(sub.id)}
                            className="px-2.5 py-1 rounded bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-[11px]"
                          >
                            Save
                          </button>
                          <button
                            onClick={() => setEditingId(null)}
                            className="px-2 py-1 rounded bg-slate-800 text-slate-400 hover:text-white text-[11px]"
                          >
                            Cancel
                          </button>
                        </>
                      ) : (
                        <>
                          <button
                            onClick={() => handleStartEdit(sub)}
                            className="px-2.5 py-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-300 font-bold text-[11px]"
                          >
                            Edit
                          </button>
                          <button
                            onClick={() => handleDelete(sub.id)}
                            className="px-2 py-1 rounded bg-red-950/40 hover:bg-red-900/60 text-red-400 font-bold text-[11px]"
                          >
                            Delete
                          </button>
                        </>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};
