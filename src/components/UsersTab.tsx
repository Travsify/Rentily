import React, { useState } from 'react';
import { 
  Users, 
  ShieldCheck, 
  Search, 
  Download, 
  KeyRound, 
  UserPlus, 
  Eye, 
  EyeOff, 
  X, 
  Building2, 
  CheckCircle2, 
  AlertCircle,
  SlidersHorizontal
} from 'lucide-react';
import type { UserProfile } from '../types';
import { formatOpsId } from '../utils/idGenerator';

interface UsersTabProps {
  users: UserProfile[];
}

export const UsersTab: React.FC<UsersTabProps> = ({ users }) => {
  const [search, setSearch] = useState('');
  const [roleFilter, setRoleFilter] = useState('all');
  const [localUsers, setLocalUsers] = useState<UserProfile[]>(users);

  // Modals state
  const [isAddUserModalOpen, setIsAddUserModalOpen] = useState(false);
  const [selectedUserForPassword, setSelectedUserForPassword] = useState<UserProfile | null>(null);
  const [selectedUserForRole, setSelectedUserForRole] = useState<UserProfile | null>(null);

  // Form states
  const [newFullName, setNewFullName] = useState('');
  const [newEmail, setNewEmail] = useState('');
  const [newPhone, setNewPhone] = useState('');
  const [newRole, setNewRole] = useState<'renter' | 'owner' | 'partner' | 'admin' | 'legal_officer'>('renter');
  const [newPassword, setNewPassword] = useState('');
  const [newBusinessName, setNewBusinessName] = useState('');
  const [newCacNumber, setNewCacNumber] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [resetPasswordVal, setResetPasswordVal] = useState('');
  const [showResetPassword, setShowResetPassword] = useState(false);
  const [selectedRoleVal, setSelectedRoleVal] = useState<string>('renter');

  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

  // Synchronize incoming users prop if updated
  React.useEffect(() => {
    if (users && users.length > 0) {
      setLocalUsers(users);
    }
  }, [users]);

  const filteredUsers = localUsers.filter(u => {
    const matchesSearch = 
      (u.fullName || '').toLowerCase().includes(search.toLowerCase()) ||
      (u.email || '').toLowerCase().includes(search.toLowerCase()) ||
      (u.phoneNumber || '').includes(search) ||
      ((u as any).businessName || '').toLowerCase().includes(search.toLowerCase()) ||
      ((u as any).accountNumber || '').includes(search);

    const matchesRole = roleFilter === 'all' || u.role === roleFilter;

    return matchesSearch && matchesRole;
  });

  const totalUsers = localUsers.length;
  const verifiedCount = localUsers.filter(u => u.isVerified).length;
  const partnerCount = localUsers.filter(u => u.role === ('partner' as any)).length;
  const landlordCount = localUsers.filter(u => u.role === 'owner').length;

  const handleCreateUser = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setMessage(null);

    try {
      const res = await fetch('/api/users/create', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          fullName: newFullName,
          email: newEmail,
          phoneNumber: newPhone,
          role: newRole,
          password: newPassword,
          businessName: newRole === 'partner' ? newBusinessName : undefined,
          cacNumber: newRole === 'partner' ? newCacNumber : undefined
        })
      });

      const data = await res.json();
      if (res.ok && data.success) {
        setMessage({ type: 'success', text: `Account created for ${newFullName} (${newRole})!` });
        setLocalUsers(prev => [data.user, ...prev]);
        setIsAddUserModalOpen(false);
        setNewFullName('');
        setNewEmail('');
        setNewPhone('');
        setNewPassword('');
        setNewBusinessName('');
        setNewCacNumber('');
      } else {
        throw new Error(data.error || 'Failed to create user');
      }
    } catch (err: any) {
      setMessage({ type: 'error', text: err.message || 'Error creating user' });
    } finally {
      setSaving(false);
    }
  };

  const handleResetPassword = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedUserForPassword) return;
    setSaving(true);
    setMessage(null);

    try {
      const res = await fetch(`/api/users/${selectedUserForPassword.id}/reset-password`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ newPassword: resetPasswordVal })
      });

      const data = await res.json();
      if (res.ok && data.success) {
        setMessage({ type: 'success', text: `Password updated for ${selectedUserForPassword.fullName}!` });
        setSelectedUserForPassword(null);
        setResetPasswordVal('');
      } else {
        throw new Error(data.error || 'Failed to reset password');
      }
    } catch (err: any) {
      setMessage({ type: 'error', text: err.message || 'Error resetting password' });
    } finally {
      setSaving(false);
    }
  };

  const handleUpdateRole = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedUserForRole) return;
    setSaving(true);
    setMessage(null);

    try {
      const res = await fetch(`/api/users/${selectedUserForRole.id}/role`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ role: selectedRoleVal })
      });

      const data = await res.json();
      if (res.ok && data.success) {
        setMessage({ type: 'success', text: `Role updated to ${selectedRoleVal} for ${selectedUserForRole.fullName}!` });
        setLocalUsers(prev => prev.map(u => u.id === selectedUserForRole.id ? { ...u, role: selectedRoleVal as any } : u));
        setSelectedUserForRole(null);
      } else {
        throw new Error(data.error || 'Failed to update role');
      }
    } catch (err: any) {
      setMessage({ type: 'error', text: err.message || 'Error updating role' });
    } finally {
      setSaving(false);
    }
  };

  const exportToCSV = () => {
    if (localUsers.length === 0) return;
    const headers = ['User ID', 'Full Name', 'Email', 'Phone', 'Role', 'Verified', 'Account Number', 'Bank', 'Wallet Balance (NGN)', 'Created At'];
    const rows = localUsers.map(u => {
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
            <span>Platform Stakeholders & User Governance</span>
          </h1>
          <p className="text-xs text-slate-400 mt-0.5">
            Create user roles, view/reset passwords, manage corporate partners, landlords, tenants, and system administrators.
          </p>
        </div>

        <div className="flex items-center gap-2 self-start sm:self-auto">
          <button
            onClick={() => setIsAddUserModalOpen(true)}
            className="flex items-center gap-2 px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-xs font-bold text-white shadow-lg shadow-emerald-950/60 transition"
          >
            <UserPlus className="w-4 h-4" />
            <span>Add New Stakeholder</span>
          </button>

          {localUsers.length > 0 && (
            <button
              onClick={exportToCSV}
              className="flex items-center gap-2 px-4 py-2 rounded-xl bg-slate-900 border border-slate-700 hover:border-slate-600 text-xs font-semibold text-white shadow-sm transition"
            >
              <Download className="w-4 h-4 text-emerald-400" />
              <span>Export (CSV)</span>
            </button>
          )}
        </div>
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
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Total Accounts</span>
          <div className="text-2xl font-bold text-white mt-1">{totalUsers}</div>
          <span className="text-[10px] text-slate-400">Direct mobile & web users</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Tier-3 Verified</span>
          <div className="text-2xl font-bold text-emerald-400 mt-1">{verifiedCount}</div>
          <span className="text-[10px] text-emerald-400/80">NIN & BVN matched</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Corporate Partners</span>
          <div className="text-2xl font-bold text-blue-400 mt-1">{partnerCount}</div>
          <span className="text-[10px] text-blue-300/80">Accredited Mandate Firms</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Direct Landlords</span>
          <div className="text-2xl font-bold text-amber-400 mt-1">{landlordCount}</div>
          <span className="text-[10px] text-amber-300/80">Property owners</span>
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
            placeholder="Search by name, email, phone, firm, NUBAN..."
            className="w-full pl-9 pr-4 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-200 focus:outline-none focus:border-emerald-500"
          />
        </div>

        <div className="flex items-center gap-2 w-full md:w-auto">
          <select
            value={roleFilter}
            onChange={(e) => setRoleFilter(e.target.value)}
            className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-300 focus:outline-none focus:border-emerald-500"
          >
            <option value="all">All Roles</option>
            <option value="renter">Renters / Tenants</option>
            <option value="owner">Direct Landlords</option>
            <option value="partner">Corporate Partners</option>
            <option value="admin">Administrators</option>
            <option value="legal_officer">Legal Officers</option>
          </select>
        </div>
      </div>

      {/* Table */}
      {filteredUsers.length === 0 ? (
        <div className="p-12 text-center rounded-3xl bg-slate-900/40 border border-slate-800/80 space-y-3">
          <div className="w-12 h-12 rounded-2xl bg-slate-800/80 flex items-center justify-center mx-auto text-slate-500">
            <Users className="w-6 h-6" />
          </div>
          <div className="space-y-1">
            <h3 className="text-sm font-bold text-white">No Users Found</h3>
            <p className="text-xs text-slate-400">
              {search || roleFilter !== 'all' ? 'Try adjusting your filters.' : 'Registered users will appear here.'}
            </p>
          </div>
        </div>
      ) : (
        <div className="rounded-2xl bg-slate-900 border border-slate-800 overflow-hidden shadow-sm">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="border-b border-slate-800 text-slate-400 uppercase font-semibold text-[10px] tracking-wider bg-slate-950/40">
                <tr>
                  <th className="py-3.5 px-4 font-semibold">User Details</th>
                  <th className="py-3.5 font-semibold">Role</th>
                  <th className="py-3.5 font-semibold">KYC / Verification</th>
                  <th className="py-3.5 font-semibold">Dedicated NUBAN Vault</th>
                  <th className="py-3.5 font-semibold">Wallet Balance</th>
                  <th className="py-3.5 px-4 font-semibold text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60">
                {filteredUsers.map((u) => {
                  const anyU = u as any;
                  return (
                    <tr key={u.id} className="hover:bg-slate-850/50 transition">
                      <td className="py-3 px-4">
                        <div className="font-bold text-white flex items-center gap-1.5 flex-wrap">
                          <span>{u.fullName || 'Unnamed User'}</span>
                          <span className="text-[10px] font-mono px-1.5 py-0.5 rounded bg-slate-800 text-slate-300 border border-slate-700">
                            {formatOpsId(u.id, u.role === ('partner' as any))}
                          </span>
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
                          <span className="inline-flex items-center gap-1 text-[10px] font-bold text-emerald-400 bg-emerald-500/10 border border-emerald-500/30 px-2 py-0.5 rounded-full">
                            <ShieldCheck className="w-3 h-3" />
                            <span>Tier-3 Verified</span>
                          </span>
                        ) : (
                          <span className="text-[10px] font-semibold text-slate-500 bg-slate-800 px-2 py-0.5 rounded-full">
                            Unverified
                          </span>
                        )}
                      </td>
                      <td className="py-3">
                        {anyU.accountNumber ? (
                          <div className="font-mono">
                            <span className="font-bold text-white text-xs">{anyU.accountNumber}</span>
                            <span className="text-[10px] text-slate-400 block">{anyU.bankName || 'Flutterwave MFB'}</span>
                          </div>
                        ) : (
                          <span className="text-slate-500 text-[10px] italic">Not Assigned</span>
                        )}
                      </td>
                      <td className="py-3 font-mono font-bold text-white text-xs">
                        ₦{(anyU.walletBalance || 0).toLocaleString()}
                      </td>
                      <td className="py-3 px-4 text-right">
                        <div className="flex items-center justify-end gap-1.5">
                          <button
                            onClick={() => {
                              setSelectedUserForPassword(u);
                              setResetPasswordVal('');
                            }}
                            title="Reset / Set Password"
                            className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition flex items-center gap-1 text-[11px]"
                          >
                            <KeyRound className="w-3.5 h-3.5 text-amber-400" />
                            <span className="hidden lg:inline">Password</span>
                          </button>

                          <button
                            onClick={() => {
                              setSelectedUserForRole(u);
                              setSelectedRoleVal(u.role);
                            }}
                            title="Change Role"
                            className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition flex items-center gap-1 text-[11px]"
                          >
                            <SlidersHorizontal className="w-3.5 h-3.5 text-blue-400" />
                            <span className="hidden lg:inline">Role</span>
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Add New Stakeholder Modal */}
      {isAddUserModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm overflow-y-auto">
          <div className="bg-slate-900 border border-slate-700 rounded-2xl w-full max-w-lg shadow-2xl overflow-hidden">
            <div className="px-6 py-4 border-b border-slate-800 flex items-center justify-between bg-slate-950/60">
              <h2 className="text-base font-bold text-white flex items-center gap-2">
                <UserPlus className="w-5 h-5 text-emerald-400" />
                <span>Create New User / Partner / Admin</span>
              </h2>
              <button 
                onClick={() => setIsAddUserModalOpen(false)}
                className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleCreateUser} className="p-6 space-y-4 text-xs">
              <div className="space-y-1">
                <label className="text-slate-300 font-semibold block">Full Name</label>
                <input
                  type="text"
                  required
                  value={newFullName}
                  onChange={(e) => setNewFullName(e.target.value)}
                  placeholder="e.g. Oladipo Adeleke"
                  className="w-full px-3 py-2.5 rounded-xl bg-slate-950 border border-slate-800 text-white focus:outline-none focus:border-emerald-500"
                />
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div className="space-y-1">
                  <label className="text-slate-300 font-semibold block">Email Address</label>
                  <input
                    type="email"
                    required
                    value={newEmail}
                    onChange={(e) => setNewEmail(e.target.value)}
                    placeholder="user@example.com"
                    className="w-full px-3 py-2.5 rounded-xl bg-slate-950 border border-slate-800 text-white focus:outline-none focus:border-emerald-500"
                  />
                </div>

                <div className="space-y-1">
                  <label className="text-slate-300 font-semibold block">Phone Number</label>
                  <input
                    type="tel"
                    required
                    value={newPhone}
                    onChange={(e) => setNewPhone(e.target.value)}
                    placeholder="+234 801 234 5678"
                    className="w-full px-3 py-2.5 rounded-xl bg-slate-950 border border-slate-800 text-white focus:outline-none focus:border-emerald-500"
                  />
                </div>
              </div>

              <div className="space-y-1">
                <label className="text-slate-300 font-semibold block">Assign Stakeholder Role</label>
                <select
                  value={newRole}
                  onChange={(e) => setNewRole(e.target.value as any)}
                  className="w-full px-3 py-2.5 rounded-xl bg-slate-950 border border-slate-800 text-white focus:outline-none focus:border-emerald-500 font-semibold"
                >
                  <option value="renter">🏠 Renter / Prospective Tenant</option>
                  <option value="owner">🏢 Direct Property Owner (Landlord)</option>
                  <option value="partner">🤝 Accredited Corporate Partner (Mandate Broker)</option>
                  <option value="legal_officer">⚖️ Legal Officer (Title Auditor)</option>
                  <option value="admin">🛡️ Platform Administrator</option>
                </select>
              </div>

              {newRole === 'partner' && (
                <div className="p-3 rounded-xl bg-blue-950/30 border border-blue-800/40 space-y-3">
                  <div className="text-[11px] font-bold text-blue-300 flex items-center gap-1.5">
                    <Building2 className="w-3.5 h-3.5" />
                    <span>Corporate Firm Credentials</span>
                  </div>
                  <div className="grid grid-cols-2 gap-2">
                    <div>
                      <label className="text-slate-400 block mb-1">Business Name</label>
                      <input
                        type="text"
                        required
                        value={newBusinessName}
                        onChange={(e) => setNewBusinessName(e.target.value)}
                        placeholder="Apex Realty Ltd"
                        className="w-full px-3 py-2 rounded-lg bg-slate-950 border border-slate-800 text-white"
                      />
                    </div>
                    <div>
                      <label className="text-slate-400 block mb-1">CAC Registration (RC/BN)</label>
                      <input
                        type="text"
                        required
                        value={newCacNumber}
                        onChange={(e) => setNewCacNumber(e.target.value)}
                        placeholder="RC-1849204"
                        className="w-full px-3 py-2 rounded-lg bg-slate-950 border border-slate-800 text-white"
                      />
                    </div>
                  </div>
                </div>
              )}

              <div className="space-y-1">
                <label className="text-slate-300 font-semibold block">Set Account Password</label>
                <div className="relative">
                  <input
                    type={showPassword ? 'text' : 'password'}
                    required
                    value={newPassword}
                    onChange={(e) => setNewPassword(e.target.value)}
                    placeholder="Enter password..."
                    className="w-full pl-3 pr-10 py-2.5 rounded-xl bg-slate-950 border border-slate-800 text-white font-mono focus:outline-none focus:border-emerald-500"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="p-1.5 text-slate-400 hover:text-white absolute right-2 top-1/2 -translate-y-1/2"
                  >
                    {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
              </div>

              <div className="pt-2 flex justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setIsAddUserModalOpen(false)}
                  className="px-4 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 font-semibold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={saving}
                  className="px-5 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold disabled:opacity-50"
                >
                  {saving ? 'Creating Account...' : 'Create Stakeholder Account'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Reset Password Modal */}
      {selectedUserForPassword && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm">
          <div className="bg-slate-900 border border-slate-700 rounded-2xl w-full max-w-md shadow-2xl overflow-hidden">
            <div className="px-6 py-4 border-b border-slate-800 flex items-center justify-between bg-slate-950/60">
              <h2 className="text-base font-bold text-white flex items-center gap-2">
                <KeyRound className="w-5 h-5 text-amber-400" />
                <span>Reset User Password</span>
              </h2>
              <button 
                onClick={() => setSelectedUserForPassword(null)}
                className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleResetPassword} className="p-6 space-y-4 text-xs">
              <div className="p-3 rounded-xl bg-slate-950 border border-slate-800 space-y-0.5">
                <span className="text-slate-400">Target User:</span>
                <p className="text-white font-bold text-sm">{selectedUserForPassword.fullName}</p>
                <p className="text-slate-400 font-mono text-[11px]">{selectedUserForPassword.email}</p>
              </div>

              <div className="space-y-1">
                <label className="text-slate-300 font-semibold block">New Password</label>
                <div className="relative">
                  <input
                    type={showResetPassword ? 'text' : 'password'}
                    required
                    value={resetPasswordVal}
                    onChange={(e) => setResetPasswordVal(e.target.value)}
                    placeholder="Enter new password..."
                    className="w-full pl-3 pr-10 py-2.5 rounded-xl bg-slate-950 border border-slate-800 text-white font-mono focus:outline-none focus:border-amber-500"
                  />
                  <button
                    type="button"
                    onClick={() => setShowResetPassword(!showResetPassword)}
                    className="p-1.5 text-slate-400 hover:text-white absolute right-2 top-1/2 -translate-y-1/2"
                  >
                    {showResetPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
              </div>

              <div className="pt-2 flex justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setSelectedUserForPassword(null)}
                  className="px-4 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 font-semibold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={saving}
                  className="px-5 py-2.5 rounded-xl bg-amber-600 hover:bg-amber-500 text-white font-bold disabled:opacity-50"
                >
                  {saving ? 'Updating...' : 'Set New Password'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Change Role Modal */}
      {selectedUserForRole && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm">
          <div className="bg-slate-900 border border-slate-700 rounded-2xl w-full max-w-md shadow-2xl overflow-hidden">
            <div className="px-6 py-4 border-b border-slate-800 flex items-center justify-between bg-slate-950/60">
              <h2 className="text-base font-bold text-white flex items-center gap-2">
                <SlidersHorizontal className="w-5 h-5 text-blue-400" />
                <span>Modify User Role</span>
              </h2>
              <button 
                onClick={() => setSelectedUserForRole(null)}
                className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleUpdateRole} className="p-6 space-y-4 text-xs">
              <div className="p-3 rounded-xl bg-slate-950 border border-slate-800 space-y-0.5">
                <span className="text-slate-400">Target User:</span>
                <p className="text-white font-bold text-sm">{selectedUserForRole.fullName}</p>
                <p className="text-slate-400 font-mono text-[11px]">{selectedUserForRole.email}</p>
              </div>

              <div className="space-y-1">
                <label className="text-slate-300 font-semibold block">Select New Role</label>
                <select
                  value={selectedRoleVal}
                  onChange={(e) => setSelectedRoleVal(e.target.value)}
                  className="w-full px-3 py-2.5 rounded-xl bg-slate-950 border border-slate-800 text-white font-semibold focus:outline-none focus:border-blue-500"
                >
                  <option value="renter">🏠 Renter / Prospective Tenant</option>
                  <option value="owner">🏢 Direct Property Owner (Landlord)</option>
                  <option value="partner">🤝 Accredited Corporate Partner</option>
                  <option value="legal_officer">⚖️ Legal Officer (Title Auditor)</option>
                  <option value="admin">🛡️ Platform Administrator</option>
                </select>
              </div>

              <div className="pt-2 flex justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setSelectedUserForRole(null)}
                  className="px-4 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 font-semibold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={saving}
                  className="px-5 py-2.5 rounded-xl bg-blue-600 hover:bg-blue-500 text-white font-bold disabled:opacity-50"
                >
                  {saving ? 'Updating...' : 'Update Role'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
