import React, { useState } from 'react';
import { 
  Users, 
  ShieldCheck, 
  Search, 
  AlertCircle,
  Download
} from 'lucide-react';
import type { UserProfile } from '../types';

interface UsersTabProps {
  users: UserProfile[];
}

export const UsersTab: React.FC<UsersTabProps> = ({ users }) => {
  const [search, setSearch] = useState('');
  const [roleFilter, setRoleFilter] = useState('all');

  const filteredUsers = users.filter(u => {
    const matchesSearch = 
      (u.fullName || '').toLowerCase().includes(search.toLowerCase()) ||
      (u.email || '').toLowerCase().includes(search.toLowerCase()) ||
      (u.phoneNumber || '').includes(search) ||
      ((u as any).accountNumber || '').includes(search);

    const matchesRole = roleFilter === 'all' || u.role === roleFilter;

    return matchesSearch && matchesRole;
  });

  const totalUsers = users.length;
  const verifiedCount = users.filter(u => u.isVerified).length;
  const partnerCount = users.filter(u => u.role === ('partner' as any)).length;
  const landlordCount = users.filter(u => u.role === 'owner').length;

  const exportToCSV = () => {
    if (users.length === 0) return;
    const headers = ['User ID', 'Full Name', 'Email', 'Phone', 'Role', 'Verified', 'Account Number', 'Bank', 'Wallet Balance (NGN)', 'Created At'];
    const rows = users.map(u => {
      const anyU = u as any;
      return [
        u.id,
        `"${(u.fullName || '').replace(/"/g, '""')}"`,
        u.email,
        u.phoneNumber || '',
        u.role,
        u.isVerified ? 'Yes' : 'No',
        anyU.accountNumber || '',
        `"${(anyU.bankName || '').replace(/"/g, '""')}"`,
        anyU.walletBalance || 0,
        u.createdAt || ''
      ];
    });
    const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map(e => e.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `rentilly_users_${new Date().toISOString().slice(0, 10)}.csv`);
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
            <Users className="w-6 h-6 text-emerald-400" />
            <span>Platform Stakeholders & User Accounts</span>
          </h1>
          <p className="text-xs text-slate-400 mt-0.5">
            Audit registered Nigerian property owners, prospective tenants, institutional partners, and system administrators.
          </p>
        </div>

        {users.length > 0 && (
          <button
            onClick={exportToCSV}
            className="flex items-center gap-2 px-4 py-2 rounded-xl bg-slate-900 border border-slate-700 hover:border-slate-600 text-xs font-semibold text-white shadow-sm transition"
          >
            <Download className="w-4 h-4 text-emerald-400" />
            <span>Export Users (CSV)</span>
          </button>
        )}
      </div>

      {/* KPI Stats */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Total Registered Accounts</span>
          <div className="text-2xl font-bold text-white mt-1">{totalUsers}</div>
          <span className="text-[10px] text-slate-400">Direct mobile & web users</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Tier-3 Verified</span>
          <div className="text-2xl font-bold text-emerald-400 mt-1">{verifiedCount}</div>
          <span className="text-[10px] text-emerald-400/80">NIN & BVN matched</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Verified Landlords</span>
          <div className="text-2xl font-bold text-blue-400 mt-1">{landlordCount}</div>
          <span className="text-[10px] text-blue-300">Direct property title holders</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Corporate Partners</span>
          <div className="text-2xl font-bold text-amber-400 mt-1">{partnerCount}</div>
          <span className="text-[10px] text-amber-300">Vetted brokerage agencies</span>
        </div>
      </div>

      {/* Filter & Search Bar */}
      <div className="flex flex-col sm:flex-row gap-3">
        <div className="relative flex-1">
          <Search className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
          <input
            type="text"
            placeholder="Search by name, email, phone, or NUBAN account number..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pl-9 pr-4 py-2.5 rounded-xl bg-slate-900 border border-slate-800 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500"
          />
        </div>

        <div className="flex gap-2">
          {['all', 'renter', 'owner', 'partner', 'admin'].map((role) => (
            <button
              key={role}
              onClick={() => setRoleFilter(role)}
              className={`px-3.5 py-2 rounded-xl text-xs font-semibold capitalize transition ${
                roleFilter === role
                  ? 'bg-emerald-600 text-white shadow-md shadow-emerald-950/40'
                  : 'bg-slate-900 text-slate-400 border border-slate-800 hover:text-white'
              }`}
            >
              {role === 'owner' ? 'Landlord' : role}
            </button>
          ))}
        </div>
      </div>

      {/* Users Table */}
      {filteredUsers.length === 0 ? (
        <div className="p-12 text-center rounded-3xl bg-slate-900/40 border border-slate-800/80 space-y-3">
          <div className="w-14 h-14 rounded-2xl bg-slate-800/80 flex items-center justify-center mx-auto text-emerald-400">
            <Users className="w-7 h-7" />
          </div>
          <div className="space-y-1 max-w-sm mx-auto">
            <h3 className="text-base font-bold text-white">No Users Found</h3>
            <p className="text-xs text-slate-400">
              No registered user accounts match your current filter or search criteria.
            </p>
          </div>
        </div>
      ) : (
        <div className="p-5 rounded-3xl bg-slate-900 border border-slate-800 space-y-4">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="border-b border-slate-800 text-slate-400 uppercase font-semibold text-[10px] tracking-wider">
                <tr>
                  <th className="pb-3 font-semibold">User Details</th>
                  <th className="pb-3 font-semibold">Role</th>
                  <th className="pb-3 font-semibold">KYC / Verification</th>
                  <th className="pb-3 font-semibold">Dedicated Bank Account</th>
                  <th className="pb-3 font-semibold">Wallet Balance</th>
                  <th className="pb-3 font-semibold">Joined</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60">
                {filteredUsers.map((u) => {
                  const anyU = u as any;
                  return (
                    <tr key={u.id} className="hover:bg-slate-850/50 transition">
                      <td className="py-3">
                        <div className="font-bold text-white flex items-center gap-1.5">
                          <span>{u.fullName || 'Unnamed User'}</span>
                          {anyU.businessName && (
                            <span className="text-[10px] font-semibold px-2 py-0.5 rounded bg-blue-950 text-blue-300 border border-blue-800">
                              {anyU.businessName}
                            </span>
                          )}
                        </div>
                        <div className="text-[11px] text-slate-400 font-mono flex items-center gap-2">
                          <span>{u.email}</span>
                          {anyU.cacNumber && (
                            <span className="text-[10px] text-emerald-400 font-bold">CAC: {anyU.cacNumber}</span>
                          )}
                        </div>
                        {u.phoneNumber && (
                          <div className="text-[10px] text-slate-500">{u.phoneNumber}</div>
                        )}
                      </td>
                      <td className="py-3">
                        <span className={`px-2.5 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider ${
                          u.role === 'admin'
                            ? 'bg-purple-500/10 text-purple-400 border border-purple-500/30'
                            : u.role === ('partner' as any)
                            ? 'bg-blue-500/10 text-blue-400 border border-blue-500/30'
                            : u.role === 'owner'
                            ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/30'
                            : 'bg-amber-500/10 text-amber-400 border border-amber-500/30'
                        }`}>
                          {u.role === 'owner' ? 'Landlord' : u.role}
                        </span>
                      </td>
                      <td className="py-3">
                        {u.isVerified ? (
                          <span className="inline-flex items-center gap-1 text-[10px] font-bold px-2 py-0.5 rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                            <ShieldCheck className="w-3 h-3" />
                            <span>Tier-3 Verified</span>
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1 text-[10px] font-bold px-2 py-0.5 rounded-full bg-slate-800 text-slate-400 border border-slate-700">
                            <AlertCircle className="w-3 h-3" />
                            <span>Unverified</span>
                          </span>
                        )}
                      </td>
                      <td className="py-3">
                        {anyU.accountNumber ? (
                          <div>
                            <div className="font-mono text-emerald-300 font-bold">{anyU.accountNumber}</div>
                            <div className="text-[10px] text-slate-500">{anyU.bankName || 'Flutterwave MFB'}</div>
                          </div>
                        ) : (
                          <span className="text-[10px] text-slate-500 italic">Not provisioned</span>
                        )}
                      </td>
                      <td className="py-3 font-mono font-bold text-white">
                        ₦{(anyU.walletBalance || 0).toLocaleString()}
                      </td>
                      <td className="py-3 text-[11px] text-slate-500">
                        {u.createdAt ? new Date(u.createdAt).toLocaleDateString() : 'N/A'}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
};
