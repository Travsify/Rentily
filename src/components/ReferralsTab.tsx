import React, { useState, useEffect } from 'react';
import { 
  Gift, 
  Users, 
  CheckCircle, 
  Clock, 
  DollarSign, 
  Save, 
  RefreshCw, 
  Search, 
  ShieldCheck, 
  AlertCircle,
  ToggleLeft,
  ToggleRight,
  Award
} from 'lucide-react';
import type { ReferralConfig, ReferralRecord } from '../types';

export const ReferralsTab: React.FC = () => {
  const [config, setConfig] = useState<ReferralConfig>({
    enabled: true,
    instantEarning: true,
    signupBonusAmount: 1000,
    referrerBonusAmount: 500,
    requireKycForPayout: true,
  });

  const [referrals, setReferrals] = useState<ReferralRecord[]>([]);
  const [stats, setStats] = useState({
    totalReferrals: 0,
    totalDisbursed: 0,
    pendingVerification: 0,
    activeReferrers: 0
  });

  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [saveSuccess, setSaveSuccess] = useState(false);
  const [errorMessage, setErrorMessage] = useState('');
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState<'all' | 'paid' | 'pending_kyc'>('all');

  const fetchData = async () => {
    setIsLoading(true);
    setErrorMessage('');
    try {
      // 1. Fetch Config
      const cfgRes = await fetch('/api/admin/referrals/config');
      if (cfgRes.ok) {
        const cfgData = await cfgRes.json();
        const loadedConfig = cfgData.data || cfgData.config || cfgData;
        if (loadedConfig && typeof loadedConfig.enabled === 'boolean') {
          setConfig(loadedConfig);
        }
      }

      // 2. Fetch Referrals List & Stats
      const listRes = await fetch('/api/admin/referrals/list');
      if (listRes.ok) {
        const listData = await listRes.json();
        const logs: ReferralRecord[] = listData.logs || listData.data || [];
        setReferrals(logs);
        
        if (listData.stats) {
          setStats(listData.stats);
        } else {
          setStats({
            totalReferrals: listData.totalReferralsCount ?? logs.length,
            totalDisbursed: listData.totalPayoutAmount ?? 0,
            pendingVerification: listData.pendingPayoutCount ?? logs.filter((r) => r.refereeRewardStatus === 'pending_kyc' || r.referrerRewardStatus === 'pending_kyc').length,
            activeReferrers: new Set(logs.map((r) => r.referrerId).filter(Boolean)).size
          });
        }
      }
    } catch (err: any) {
      setErrorMessage(err.message || 'Failed to load referral data');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  const handleSaveConfig = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSaving(true);
    setSaveSuccess(false);
    setErrorMessage('');
    try {
      const res = await fetch('/api/admin/referrals/config', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(config)
      });
      if (res.ok) {
        const data = await res.json();
        const updatedConfig = data.data || data.config;
        if (updatedConfig) {
          setConfig(updatedConfig);
        }
        setSaveSuccess(true);
        setTimeout(() => setSaveSuccess(false), 4000);
      } else {
        const err = await res.json();
        setErrorMessage(err.error || 'Failed to update referral configuration');
      }
    } catch (err: any) {
      setErrorMessage(err.message || 'Network error saving settings');
    } finally {
      setIsSaving(false);
    }
  };

  const filteredReferrals = referrals.filter(r => {
    const term = searchTerm.toLowerCase().trim();
    const matchSearch = 
      (r.refereeEmail || '').toLowerCase().includes(term) ||
      (r.refereeName || '').toLowerCase().includes(term) ||
      (r.referrerName || '').toLowerCase().includes(term) ||
      (r.referrerCode || '').toLowerCase().includes(term);
    
    if (!matchSearch) return false;
    if (statusFilter === 'all') return true;
    return r.refereeRewardStatus === statusFilter || r.referrerRewardStatus === statusFilter;
  });

  return (
    <div className="space-y-6">
      {/* Top Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-white p-6 rounded-2xl border border-slate-200/80 shadow-sm">
        <div className="flex items-center space-x-3">
          <div className="p-3 bg-emerald-50 rounded-xl border border-emerald-200">
            <Gift className="w-6 h-6 text-emerald-600" />
          </div>
          <div>
            <h1 className="text-xl font-bold text-slate-900 tracking-tight">Referral & Rewards Engine</h1>
            <p className="text-xs text-slate-500 mt-0.5">
              Live automated ₦1,000 Signup / ₦500 Referral Bounty ledger & anti-fraud governance
            </p>
          </div>
        </div>

        <button
          onClick={fetchData}
          disabled={isLoading}
          className="flex items-center space-x-2 px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-semibold rounded-xl transition"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${isLoading ? 'animate-spin' : ''}`} />
          <span>Sync Ledger</span>
        </button>
      </div>

      {/* KPI Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-sm">
          <div className="flex justify-between items-start">
            <div>
              <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Total Disbursed</p>
              <h3 className="text-2xl font-black text-slate-900 mt-1">
                ₦{stats.totalDisbursed.toLocaleString()}
              </h3>
            </div>
            <div className="p-2.5 bg-emerald-50 rounded-xl text-emerald-600">
              <DollarSign className="w-5 h-5" />
            </div>
          </div>
          <p className="text-[11px] text-emerald-600 font-medium mt-3 flex items-center gap-1">
            <CheckCircle className="w-3 h-3" /> Live wallet credits settled
          </p>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-sm">
          <div className="flex justify-between items-start">
            <div>
              <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Total Referrals</p>
              <h3 className="text-2xl font-black text-slate-900 mt-1">
                {stats.totalReferrals.toLocaleString()}
              </h3>
            </div>
            <div className="p-2.5 bg-blue-50 rounded-xl text-blue-600">
              <Users className="w-5 h-5" />
            </div>
          </div>
          <p className="text-[11px] text-slate-500 font-medium mt-3">
            Registered with invite codes
          </p>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-sm">
          <div className="flex justify-between items-start">
            <div>
              <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Pending KYC</p>
              <h3 className="text-2xl font-black text-amber-600 mt-1">
                {stats.pendingVerification.toLocaleString()}
              </h3>
            </div>
            <div className="p-2.5 bg-amber-50 rounded-xl text-amber-600">
              <Clock className="w-5 h-5" />
            </div>
          </div>
          <p className="text-[11px] text-amber-600 font-medium mt-3 flex items-center gap-1">
            <ShieldCheck className="w-3 h-3" /> Awaiting NIN / BVN check
          </p>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-sm">
          <div className="flex justify-between items-start">
            <div>
              <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Active Advocates</p>
              <h3 className="text-2xl font-black text-purple-600 mt-1">
                {stats.activeReferrers.toLocaleString()}
              </h3>
            </div>
            <div className="p-2.5 bg-purple-50 rounded-xl text-purple-600">
              <Award className="w-5 h-5" />
            </div>
          </div>
          <p className="text-[11px] text-purple-600 font-medium mt-3">
            Sharing referral codes
          </p>
        </div>
      </div>

      {/* Admin Controls Configuration Panel */}
      <div className="bg-white p-6 rounded-2xl border border-slate-200/80 shadow-sm">
        <div className="flex items-center justify-between border-b border-slate-100 pb-4 mb-5">
          <div>
            <h2 className="text-base font-bold text-slate-900">Program Rules & Immediate Earnings Policy</h2>
            <p className="text-xs text-slate-500">Configure real-time reward amounts and anti-fraud instant payout toggles</p>
          </div>
          <span className={`px-3 py-1 text-xs font-bold rounded-full ${config.enabled ? 'bg-emerald-100 text-emerald-800' : 'bg-rose-100 text-rose-800'}`}>
            {config.enabled ? 'SYSTEM ACTIVE' : 'PROGRAM PAUSED'}
          </span>
        </div>

        {saveSuccess && (
          <div className="mb-4 p-3 bg-emerald-50 border border-emerald-200 rounded-xl text-emerald-800 text-xs font-semibold flex items-center gap-2">
            <CheckCircle className="w-4 h-4 text-emerald-600" />
            Referral settings saved and propagated to mobile & database instantly.
          </div>
        )}

        {errorMessage && (
          <div className="mb-4 p-3 bg-rose-50 border border-rose-200 rounded-xl text-rose-800 text-xs font-semibold flex items-center gap-2">
            <AlertCircle className="w-4 h-4 text-rose-600" />
            {errorMessage}
          </div>
        )}

        <form onSubmit={handleSaveConfig} className="space-y-5">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
            {/* Master Enable Toggle */}
            <div className="p-4 rounded-xl border border-slate-200 bg-slate-50/50 flex items-center justify-between">
              <div>
                <p className="text-xs font-bold text-slate-800">Master Referral System</p>
                <p className="text-[11px] text-slate-500">Enable signup bonus & referral rewards</p>
              </div>
              <button
                type="button"
                onClick={() => setConfig({ ...config, enabled: !config.enabled })}
                className="text-slate-700 hover:text-slate-900 focus:outline-none"
              >
                {config.enabled ? (
                  <ToggleRight className="w-8 h-8 text-emerald-600" />
                ) : (
                  <ToggleLeft className="w-8 h-8 text-slate-400" />
                )}
              </button>
            </div>

            {/* Instant Payout Toggle */}
            <div className="p-4 rounded-xl border border-slate-200 bg-slate-50/50 flex items-center justify-between">
              <div>
                <p className="text-xs font-bold text-slate-800">Instant Earnings Mode</p>
                <p className="text-[11px] text-slate-500">Automatic wallet credit upon verification</p>
              </div>
              <button
                type="button"
                onClick={() => setConfig({ ...config, instantEarning: !config.instantEarning })}
                className="text-slate-700 hover:text-slate-900 focus:outline-none"
              >
                {config.instantEarning ? (
                  <ToggleRight className="w-8 h-8 text-emerald-600" />
                ) : (
                  <ToggleLeft className="w-8 h-8 text-slate-400" />
                )}
              </button>
            </div>

            {/* Require KYC Toggle */}
            <div className="p-4 rounded-xl border border-slate-200 bg-slate-50/50 flex items-center justify-between">
              <div>
                <p className="text-xs font-bold text-slate-800">Enforce KYC / KYB</p>
                <p className="text-[11px] text-slate-500">Anti-fraud NIN/BVN completion gate</p>
              </div>
              <button
                type="button"
                onClick={() => setConfig({ ...config, requireKycForPayout: !config.requireKycForPayout })}
                className="text-slate-700 hover:text-slate-900 focus:outline-none"
              >
                {config.requireKycForPayout ? (
                  <ToggleRight className="w-8 h-8 text-emerald-600" />
                ) : (
                  <ToggleLeft className="w-8 h-8 text-slate-400" />
                )}
              </button>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-5 pt-2">
            <div>
              <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                New User Welcome Bonus (₦ NGN)
              </label>
              <div className="relative">
                <span className="absolute inset-y-0 left-0 pl-3.5 flex items-center text-slate-400 font-bold text-xs">₦</span>
                <input
                  type="number"
                  min="0"
                  step="100"
                  value={config.signupBonusAmount}
                  onChange={(e) => setConfig({ ...config, signupBonusAmount: Number(e.target.value) })}
                  className="w-full pl-8 pr-4 py-2.5 bg-white border border-slate-200 rounded-xl text-xs font-bold text-slate-900 focus:outline-none focus:ring-2 focus:ring-emerald-500"
                  placeholder="1000"
                />
              </div>
              <p className="text-[10.5px] text-slate-400 mt-1">Disbursed to referee upon verified signup</p>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                Referrer Bounty Reward (₦ NGN)
              </label>
              <div className="relative">
                <span className="absolute inset-y-0 left-0 pl-3.5 flex items-center text-slate-400 font-bold text-xs">₦</span>
                <input
                  type="number"
                  min="0"
                  step="50"
                  value={config.referrerBonusAmount}
                  onChange={(e) => setConfig({ ...config, referrerBonusAmount: Number(e.target.value) })}
                  className="w-full pl-8 pr-4 py-2.5 bg-white border border-slate-200 rounded-xl text-xs font-bold text-slate-900 focus:outline-none focus:ring-2 focus:ring-emerald-500"
                  placeholder="500"
                />
              </div>
              <p className="text-[10.5px] text-slate-400 mt-1">Disbursed to code owner when referee verifies</p>
            </div>
          </div>

          <div className="flex justify-end pt-3">
            <button
              type="submit"
              disabled={isSaving}
              className="flex items-center space-x-2 px-6 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold rounded-xl shadow-sm transition disabled:opacity-50"
            >
              <Save className="w-4 h-4" />
              <span>{isSaving ? 'Saving Changes...' : 'Save Configuration'}</span>
            </button>
          </div>
        </form>
      </div>

      {/* Referrals Activity Ledger */}
      <div className="bg-white rounded-2xl border border-slate-200/80 shadow-sm overflow-hidden">
        <div className="p-5 border-b border-slate-100 flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3">
          <div>
            <h2 className="text-base font-bold text-slate-900">Referral Audit & Activity Logs</h2>
            <p className="text-xs text-slate-500">Live stream of all referee registrations, code linkages, and wallet reward credits</p>
          </div>

          <div className="flex flex-wrap items-center gap-2 w-full sm:w-auto">
            {/* Search */}
            <div className="relative flex-1 sm:w-64">
              <Search className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-1/2 transform -translate-y-1/2" />
              <input
                type="text"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                placeholder="Search user, email, code..."
                className="w-full pl-8 pr-3 py-1.5 bg-slate-50 border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-emerald-500"
              />
            </div>

            {/* Status Filter */}
            <select
              value={statusFilter}
              onChange={(e: any) => setStatusFilter(e.target.value)}
              className="px-3 py-1.5 bg-slate-50 border border-slate-200 rounded-xl text-xs font-medium text-slate-700 focus:outline-none"
            >
              <option value="all">All Statuses</option>
              <option value="paid">Paid & Verified</option>
              <option value="pending_kyc">Pending KYC</option>
            </select>
          </div>
        </div>

        {/* Table */}
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-50/75 text-slate-500 font-semibold uppercase text-[10px] tracking-wider border-b border-slate-100">
              <tr>
                <th className="px-5 py-3.5">Referee (New User)</th>
                <th className="px-5 py-3.5">Referrer & Code</th>
                <th className="px-5 py-3.5">Type</th>
                <th className="px-5 py-3.5">Signup Reward (₦1,000)</th>
                <th className="px-5 py-3.5">Referrer Bounty (₦500)</th>
                <th className="px-5 py-3.5">KYC Status</th>
                <th className="px-5 py-3.5">Registered Date</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {isLoading ? (
                <tr>
                  <td colSpan={7} className="px-5 py-12 text-center text-slate-400">
                    <RefreshCw className="w-6 h-6 animate-spin mx-auto mb-2 text-emerald-600" />
                    Loading live referral logs...
                  </td>
                </tr>
              ) : filteredReferrals.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-5 py-12 text-center text-slate-400">
                    <Gift className="w-8 h-8 mx-auto mb-2 text-slate-300" />
                    No referral transactions found matching your filter.
                  </td>
                </tr>
              ) : (
                filteredReferrals.map((r) => {
                  const isRefereePaid = r.refereeRewardStatus === 'paid';
                  const isReferrerPaid = r.referrerRewardStatus === 'paid';

                  return (
                    <tr key={r.id} className="hover:bg-slate-50/50 transition">
                      <td className="px-5 py-3.5">
                        <div className="font-bold text-slate-900">{r.refereeName}</div>
                        <div className="text-[11px] text-slate-500 font-mono">{r.refereeEmail}</div>
                      </td>

                      <td className="px-5 py-3.5">
                        <div className="font-semibold text-slate-800">{r.referrerName}</div>
                        {r.referrerCode ? (
                          <span className="inline-block font-mono font-bold text-[10px] bg-slate-100 text-slate-700 px-2 py-0.5 rounded-md mt-0.5">
                            {r.referrerCode}
                          </span>
                        ) : (
                          <span className="text-slate-400 italic text-[11px]">Direct / Organic</span>
                        )}
                      </td>

                      <td className="px-5 py-3.5">
                        <span className={`px-2 py-0.5 text-[10px] font-bold rounded-md uppercase ${
                          r.refereeBuyerType === 'corporate' 
                            ? 'bg-purple-100 text-purple-800' 
                            : 'bg-blue-100 text-blue-800'
                        }`}>
                          {r.refereeBuyerType || 'Personal'}
                        </span>
                      </td>

                      <td className="px-5 py-3.5">
                        <span className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[10.5px] font-bold ${
                          isRefereePaid 
                            ? 'bg-emerald-100 text-emerald-800' 
                            : 'bg-amber-100 text-amber-800'
                        }`}>
                          {isRefereePaid ? <CheckCircle className="w-3 h-3 text-emerald-600" /> : <Clock className="w-3 h-3 text-amber-600" />}
                          ₦{r.refereeRewardAmount?.toLocaleString() || '1,000'} {isRefereePaid ? 'PAID' : 'PENDING'}
                        </span>
                      </td>

                      <td className="px-5 py-3.5">
                        {r.referrerId || r.referrerCode ? (
                          <span className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[10.5px] font-bold ${
                            isReferrerPaid 
                              ? 'bg-emerald-100 text-emerald-800' 
                              : 'bg-amber-100 text-amber-800'
                          }`}>
                            {isReferrerPaid ? <CheckCircle className="w-3 h-3 text-emerald-600" /> : <Clock className="w-3 h-3 text-amber-600" />}
                            ₦{r.referrerRewardAmount?.toLocaleString() || '500'} {isReferrerPaid ? 'PAID' : 'PENDING'}
                          </span>
                        ) : (
                          <span className="text-slate-400 italic text-[11px]">N/A (No Referrer)</span>
                        )}
                      </td>

                      <td className="px-5 py-3.5">
                        {r.kycCompleted ? (
                          <span className="inline-flex items-center gap-1 text-emerald-700 font-bold text-[11px]">
                            <ShieldCheck className="w-3.5 h-3.5 text-emerald-600" /> Verified
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1 text-amber-600 font-semibold text-[11px]">
                            <Clock className="w-3.5 h-3.5 text-amber-500" /> Unverified
                          </span>
                        )}
                      </td>

                      <td className="px-5 py-3.5 text-slate-500 text-[11px]">
                        {new Date(r.createdAt).toLocaleDateString('en-GB', {
                          day: 'numeric',
                          month: 'short',
                          year: 'numeric'
                        })}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};
