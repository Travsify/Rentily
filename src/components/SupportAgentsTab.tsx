import React, { useState, useEffect, useCallback } from 'react';
import {
  Users,
  UserPlus,
  CheckCircle2,
  XCircle,
  Clock,
  Wifi,
  WifiOff,
  MessageSquare,
  X,
  AlertCircle,
  ChevronDown,
  Shield,
  ShieldCheck,
  RefreshCw,
} from 'lucide-react';

interface SupportAgent {
  id: string;
  name: string;
  email: string;
  role: 'customer_support' | 'senior_agent';
  is_active: boolean;
  is_online: boolean;
  last_seen: string | null;
  active_chats: number;
  created_at: string;
}

interface AddAgentForm {
  name: string;
  email: string;
  password: string;
  role: 'customer_support' | 'senior_agent';
}

function timeAgo(iso: string | null): string {
  if (!iso) return 'Never';
  const diff = Date.now() - new Date(iso).getTime();
  const m = Math.floor(diff / 60000);
  if (m < 1) return 'Just now';
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  return `${Math.floor(h / 24)}d ago`;
}

export const SupportAgentsTab: React.FC = () => {
  const [agents, setAgents] = useState<SupportAgent[]>([]);
  const [loading, setLoading] = useState(true);
  const [showAddModal, setShowAddModal] = useState(false);
  const [addForm, setAddForm] = useState<AddAgentForm>({
    name: '',
    email: '',
    password: '',
    role: 'customer_support',
  });
  const [addLoading, setAddLoading] = useState(false);
  const [addError, setAddError] = useState<string | null>(null);
  const [addSuccess, setAddSuccess] = useState(false);
  const [deactivatingId, setDeactivatingId] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const fetchAgents = useCallback(async () => {
    try {
      const res = await fetch('/api/support/agents', {
        headers: { 'Content-Type': 'application/json' },
      });
      if (res.ok) {
        const data = await res.json();
        setAgents(data.agents || data);
      }
    } catch (e) {
      console.error('Failed to fetch agents', e);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchAgents();
    const interval = setInterval(fetchAgents, 10000);
    return () => clearInterval(interval);
  }, [fetchAgents]);

  const handleAddAgent = async (e: React.FormEvent) => {
    e.preventDefault();
    setAddLoading(true);
    setAddError(null);
    try {
      const res = await fetch('/api/support/agents', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: addForm.name.trim(),
          email: addForm.email.trim().toLowerCase(),
          password: addForm.password,
          role: addForm.role,
          createdBy: 'admin@myrentilly.com',
        }),
      });
      if (!res.ok) {
        const err = await res.json().catch(() => ({ message: 'Failed to create agent' }));
        throw new Error(err.message || 'Failed to create agent');
      }
      setAddSuccess(true);
      setAddForm({ name: '', email: '', password: '', role: 'customer_support' });
      await fetchAgents();
      setTimeout(() => {
        setAddSuccess(false);
        setShowAddModal(false);
      }, 1500);
    } catch (err: any) {
      setAddError(err.message || 'Something went wrong.');
    } finally {
      setAddLoading(false);
    }
  };

  const handleDeactivate = async (agent: SupportAgent) => {
    if (!window.confirm(`Deactivate ${agent.name}? They will no longer be able to log in.`)) return;
    setDeactivatingId(agent.id);
    setActionError(null);
    try {
      const res = await fetch(`/api/support/agents/${agent.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isActive: false }),
      });
      if (!res.ok) throw new Error('Failed to deactivate agent');
      await fetchAgents();
    } catch (err: any) {
      setActionError(err.message || 'Failed to deactivate agent');
    } finally {
      setDeactivatingId(null);
    }
  };

  const handleActivate = async (agent: SupportAgent) => {
    setDeactivatingId(agent.id);
    setActionError(null);
    try {
      const res = await fetch(`/api/support/agents/${agent.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isActive: true }),
      });
      if (!res.ok) throw new Error('Failed to activate agent');
      await fetchAgents();
    } catch (err: any) {
      setActionError(err.message || 'Failed to activate agent');
    } finally {
      setDeactivatingId(null);
    }
  };

  const totalAgents = agents.length;
  const onlineAgents = agents.filter((a) => a.is_online && a.is_active).length;
  const totalActiveChats = agents.reduce((sum, a) => sum + (a.active_chats || 0), 0);
  const activeAgents = agents.filter((a) => a.is_active).length;

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-extrabold text-white tracking-tight">Support Team Management</h1>
          <p className="text-xs text-slate-400 mt-0.5">Manage customer support agents, monitor online status and assign workloads</p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={fetchAgents}
            className="p-2 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 transition"
            title="Refresh"
          >
            <RefreshCw className="w-4 h-4" />
          </button>
          <button
            onClick={() => { setShowAddModal(true); setAddError(null); setAddSuccess(false); }}
            className="flex items-center gap-2 px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-sm font-bold shadow-lg shadow-emerald-950/40 transition"
          >
            <UserPlus className="w-4 h-4" />
            Add Agent
          </button>
        </div>
      </div>

      {/* Stats Row */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800 space-y-1">
          <div className="flex items-center gap-2 text-slate-400 text-xs font-semibold">
            <Users className="w-4 h-4" />
            <span>Total Agents</span>
          </div>
          <p className="text-2xl font-extrabold text-white">{totalAgents}</p>
          <p className="text-[11px] text-slate-500">{activeAgents} active</p>
        </div>
        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800 space-y-1">
          <div className="flex items-center gap-2 text-emerald-400 text-xs font-semibold">
            <Wifi className="w-4 h-4" />
            <span>Online Now</span>
          </div>
          <p className="text-2xl font-extrabold text-white">{onlineAgents}</p>
          <p className="text-[11px] text-slate-500">of {activeAgents} active</p>
        </div>
        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800 space-y-1">
          <div className="flex items-center gap-2 text-blue-400 text-xs font-semibold">
            <MessageSquare className="w-4 h-4" />
            <span>Active Chats</span>
          </div>
          <p className="text-2xl font-extrabold text-white">{totalActiveChats}</p>
          <p className="text-[11px] text-slate-500">across all agents</p>
        </div>
        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800 space-y-1">
          <div className="flex items-center gap-2 text-amber-400 text-xs font-semibold">
            <WifiOff className="w-4 h-4" />
            <span>Offline</span>
          </div>
          <p className="text-2xl font-extrabold text-white">{activeAgents - onlineAgents}</p>
          <p className="text-[11px] text-slate-500">active agents offline</p>
        </div>
      </div>

      {/* Action Error */}
      {actionError && (
        <div className="p-3 rounded-xl bg-red-500/10 border border-red-500/30 text-red-300 text-xs flex items-center gap-2">
          <AlertCircle className="w-4 h-4 shrink-0" />
          {actionError}
        </div>
      )}

      {/* Agents Table */}
      <div className="rounded-2xl bg-slate-900 border border-slate-800 overflow-hidden">
        <div className="px-5 py-3.5 border-b border-slate-800 flex items-center justify-between">
          <h2 className="text-sm font-bold text-white">Agent Roster</h2>
          <span className="text-[11px] text-slate-500">Auto-refreshes every 10s</span>
        </div>

        {loading ? (
          <div className="flex items-center justify-center py-16 gap-3 text-slate-400">
            <div className="w-5 h-5 border-2 border-emerald-500/20 border-t-emerald-500 rounded-full animate-spin" />
            <span className="text-sm">Loading agents...</span>
          </div>
        ) : agents.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-16 text-slate-500 gap-3">
            <Users className="w-10 h-10 opacity-30" />
            <p className="text-sm font-semibold">No agents yet</p>
            <p className="text-xs text-slate-600">Click "Add Agent" to create your first support agent</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-slate-800 text-xs text-slate-500 uppercase tracking-wider">
                  <th className="px-5 py-3 text-left font-semibold">Name</th>
                  <th className="px-4 py-3 text-left font-semibold">Email</th>
                  <th className="px-4 py-3 text-left font-semibold">Role</th>
                  <th className="px-4 py-3 text-left font-semibold">Status</th>
                  <th className="px-4 py-3 text-center font-semibold">Active Chats</th>
                  <th className="px-4 py-3 text-left font-semibold">Last Seen</th>
                  <th className="px-4 py-3 text-right font-semibold">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60">
                {agents.map((agent) => (
                  <tr
                    key={agent.id}
                    className={`hover:bg-slate-800/30 transition-colors ${!agent.is_active ? 'opacity-50' : ''}`}
                  >
                    {/* Name */}
                    <td className="px-5 py-3.5">
                      <div className="flex items-center gap-3">
                        <div className="relative">
                          <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-slate-700 to-slate-600 flex items-center justify-center text-white text-xs font-bold shrink-0">
                            {agent.name.charAt(0).toUpperCase()}
                          </div>
                          {agent.is_online && agent.is_active && (
                            <span className="absolute -bottom-0.5 -right-0.5 w-2.5 h-2.5 bg-emerald-500 rounded-full border-2 border-slate-900" />
                          )}
                        </div>
                        <span className="font-semibold text-slate-200 text-xs">{agent.name}</span>
                      </div>
                    </td>

                    {/* Email */}
                    <td className="px-4 py-3.5 text-xs text-slate-400">{agent.email}</td>

                    {/* Role Badge */}
                    <td className="px-4 py-3.5">
                      {agent.role === 'senior_agent' ? (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-blue-500/15 text-blue-400 border border-blue-500/30 text-[10px] font-bold">
                          <ShieldCheck className="w-3 h-3" />
                          Senior Agent
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-emerald-500/15 text-emerald-400 border border-emerald-500/30 text-[10px] font-bold">
                          <Shield className="w-3 h-3" />
                          Support
                        </span>
                      )}
                    </td>

                    {/* Online Status */}
                    <td className="px-4 py-3.5">
                      {!agent.is_active ? (
                        <span className="inline-flex items-center gap-1.5 text-[10px] font-semibold text-slate-500">
                          <XCircle className="w-3.5 h-3.5" />
                          Deactivated
                        </span>
                      ) : agent.is_online ? (
                        <span className="inline-flex items-center gap-1.5 text-[10px] font-semibold text-emerald-400">
                          <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
                          Online
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1.5 text-[10px] font-semibold text-slate-500">
                          <span className="w-2 h-2 rounded-full bg-slate-600" />
                          Offline
                        </span>
                      )}
                    </td>

                    {/* Active Chats */}
                    <td className="px-4 py-3.5 text-center">
                      <span className={`text-sm font-bold ${agent.active_chats > 0 ? 'text-amber-400' : 'text-slate-500'}`}>
                        {agent.active_chats || 0}
                      </span>
                    </td>

                    {/* Last Seen */}
                    <td className="px-4 py-3.5">
                      <span className="inline-flex items-center gap-1.5 text-[11px] text-slate-500">
                        <Clock className="w-3 h-3" />
                        {timeAgo(agent.last_seen)}
                      </span>
                    </td>

                    {/* Actions */}
                    <td className="px-4 py-3.5 text-right">
                      {deactivatingId === agent.id ? (
                        <div className="inline-flex items-center justify-end">
                          <div className="w-4 h-4 border-2 border-slate-600 border-t-slate-300 rounded-full animate-spin" />
                        </div>
                      ) : agent.is_active ? (
                        <button
                          onClick={() => handleDeactivate(agent)}
                          className="px-3 py-1 rounded-lg bg-red-500/10 hover:bg-red-500/20 text-red-400 border border-red-500/20 text-[11px] font-semibold transition"
                        >
                          Deactivate
                        </button>
                      ) : (
                        <button
                          onClick={() => handleActivate(agent)}
                          className="px-3 py-1 rounded-lg bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-400 border border-emerald-500/20 text-[11px] font-semibold transition"
                        >
                          Reactivate
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Add Agent Modal */}
      {showAddModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          {/* Backdrop */}
          <div
            className="absolute inset-0 bg-black/70 backdrop-blur-sm"
            onClick={() => setShowAddModal(false)}
          />

          {/* Panel */}
          <div className="relative w-full max-w-md bg-[#0f172a] border border-slate-700 rounded-2xl shadow-2xl z-10 overflow-hidden">
            {/* Modal Header */}
            <div className="flex items-center justify-between px-6 py-4 border-b border-slate-800">
              <div className="flex items-center gap-2.5">
                <div className="p-1.5 rounded-lg bg-emerald-500/15 border border-emerald-500/20">
                  <UserPlus className="w-4 h-4 text-emerald-400" />
                </div>
                <div>
                  <h3 className="text-sm font-bold text-white">Add Support Agent</h3>
                  <p className="text-[10px] text-slate-500">Create a new customer support team member</p>
                </div>
              </div>
              <button
                onClick={() => setShowAddModal(false)}
                className="p-1.5 rounded-lg hover:bg-slate-800 text-slate-500 hover:text-slate-300 transition"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {/* Modal Body */}
            <form onSubmit={handleAddAgent} className="px-6 py-5 space-y-4">
              {addError && (
                <div className="p-3 rounded-xl bg-red-500/10 border border-red-500/30 text-red-300 text-xs flex items-center gap-2">
                  <AlertCircle className="w-4 h-4 shrink-0" />
                  {addError}
                </div>
              )}

              {addSuccess && (
                <div className="p-3 rounded-xl bg-emerald-500/10 border border-emerald-500/30 text-emerald-300 text-xs flex items-center gap-2">
                  <CheckCircle2 className="w-4 h-4 shrink-0" />
                  Agent created successfully!
                </div>
              )}

              {/* Full Name */}
              <div className="space-y-1.5">
                <label className="text-xs font-semibold text-slate-300">Full Name</label>
                <input
                  type="text"
                  required
                  value={addForm.name}
                  onChange={(e) => setAddForm((f) => ({ ...f, name: e.target.value }))}
                  placeholder="e.g. Chioma Okafor"
                  className="w-full px-3.5 py-2.5 rounded-xl bg-slate-950 border border-slate-700 text-slate-200 text-xs focus:outline-none focus:border-emerald-500 transition placeholder-slate-600"
                />
              </div>

              {/* Email */}
              <div className="space-y-1.5">
                <label className="text-xs font-semibold text-slate-300">Email Address</label>
                <input
                  type="email"
                  required
                  value={addForm.email}
                  onChange={(e) => setAddForm((f) => ({ ...f, email: e.target.value }))}
                  placeholder="agent@myrentilly.com"
                  className="w-full px-3.5 py-2.5 rounded-xl bg-slate-950 border border-slate-700 text-slate-200 text-xs focus:outline-none focus:border-emerald-500 transition placeholder-slate-600"
                />
              </div>

              {/* Password */}
              <div className="space-y-1.5">
                <label className="text-xs font-semibold text-slate-300">Initial Password</label>
                <input
                  type="password"
                  required
                  minLength={8}
                  value={addForm.password}
                  onChange={(e) => setAddForm((f) => ({ ...f, password: e.target.value }))}
                  placeholder="Min. 8 characters"
                  className="w-full px-3.5 py-2.5 rounded-xl bg-slate-950 border border-slate-700 text-slate-200 text-xs focus:outline-none focus:border-emerald-500 transition placeholder-slate-600"
                />
              </div>

              {/* Role */}
              <div className="space-y-1.5">
                <label className="text-xs font-semibold text-slate-300">Role</label>
                <div className="relative">
                  <select
                    value={addForm.role}
                    onChange={(e) => setAddForm((f) => ({ ...f, role: e.target.value as AddAgentForm['role'] }))}
                    className="w-full appearance-none px-3.5 py-2.5 rounded-xl bg-slate-950 border border-slate-700 text-slate-200 text-xs focus:outline-none focus:border-emerald-500 transition pr-8"
                  >
                    <option value="customer_support">Customer Support</option>
                    <option value="senior_agent">Senior Agent</option>
                  </select>
                  <ChevronDown className="w-3.5 h-3.5 text-slate-500 absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none" />
                </div>
                <p className="text-[10px] text-slate-600">
                  {addForm.role === 'senior_agent'
                    ? 'Senior agents can escalate and handle priority tickets'
                    : 'Standard support agent with chat inbox access'}
                </p>
              </div>

              {/* Actions */}
              <div className="flex gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => setShowAddModal(false)}
                  className="flex-1 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={addLoading || addSuccess}
                  className="flex-1 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-white text-xs font-bold transition flex items-center justify-center gap-2"
                >
                  {addLoading ? (
                    <div className="w-4 h-4 border-2 border-white/20 border-t-white rounded-full animate-spin" />
                  ) : addSuccess ? (
                    <>
                      <CheckCircle2 className="w-4 h-4" />
                      Created!
                    </>
                  ) : (
                    <>
                      <UserPlus className="w-4 h-4" />
                      Create Agent
                    </>
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
