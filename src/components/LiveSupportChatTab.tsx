import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  MessageSquare, Send, Search, RefreshCw, X,
  ChevronDown, Users, Inbox, LogOut, Circle,
} from 'lucide-react';

const SUPABASE_URL = 'https://zuxvxuqxomsxgiljykzj.supabase.co';
const SUPABASE_KEY = 'sb_publishable_LiVL01tqjp7jQQZwxFTayQ_TrhSswA_';

const sbHeaders = {
  apikey: SUPABASE_KEY,
  Authorization: `Bearer ${SUPABASE_KEY}`,
  'Content-Type': 'application/json',
  Prefer: 'return=representation',
};

interface AgentSession { id: string; name: string; email: string; role: string; }
interface SupportAgent { id: string; name: string; email: string; role: string; is_online: boolean; is_active: boolean; }

interface Conversation {
  id: string; user_email: string; user_name: string; user_role: string;
  subject: string; status: 'open' | 'pending' | 'resolved' | 'closed';
  priority: 'low' | 'normal' | 'high' | 'urgent';
  last_message: string; last_message_at: string; unread_by_agent: number;
  assigned_agent_id?: string | null; assigned_agent_name?: string | null;
  assigned_agent_email?: string | null; created_at: string;
}

interface Message {
  id: string; conversation_id: string; sender: 'user' | 'agent' | 'bot';
  sender_name: string; message: string; created_at: string; is_read: boolean;
}

function timeAgo(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  const m = Math.floor(diff / 60000);
  if (m < 1) return 'Just now';
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  return `${Math.floor(h / 24)}d ago`;
}

const statusColors: Record<string, string> = {
  open: 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30',
  pending: 'bg-amber-500/20 text-amber-400 border-amber-500/30',
  resolved: 'bg-blue-500/20 text-blue-400 border-blue-500/30',
  closed: 'bg-slate-700/50 text-slate-500 border-slate-700',
};

const priorityColors: Record<string, string> = {
  low: 'bg-slate-700/50 text-slate-500',
  normal: 'bg-blue-500/15 text-blue-400',
  high: 'bg-orange-500/20 text-orange-400',
  urgent: 'bg-red-500/20 text-red-400',
};

// ─── Conversation List Item ────────────────────────────────────────────────────

const ConvItem: React.FC<{ conv: Conversation; isActive: boolean; onClick: () => void }> = ({ conv, isActive, onClick }) => (
  <button
    onClick={onClick}
    className={`w-full text-left px-4 py-3 border-b border-slate-800/60 hover:bg-slate-800/40 transition-colors ${isActive ? 'bg-slate-800/70 border-l-2 border-l-emerald-500' : ''} ${!conv.assigned_agent_id ? 'border-l-2 border-l-amber-500/40' : ''}`}
  >
    <div className="flex items-start justify-between gap-2">
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-1.5 mb-0.5">
          <span className="text-xs font-bold text-slate-200 truncate">{conv.user_name || conv.user_email}</span>
          {conv.unread_by_agent > 0 && (
            <span className="flex-shrink-0 w-4 h-4 bg-red-500 rounded-full text-white text-[9px] flex items-center justify-center font-bold">{conv.unread_by_agent}</span>
          )}
        </div>
        <p className="text-[10px] text-slate-400 font-medium truncate">{conv.subject}</p>
        <p className="text-[10px] text-slate-600 truncate mt-0.5">{conv.last_message || 'No messages yet'}</p>
      </div>
      <div className="flex flex-col items-end gap-1 flex-shrink-0">
        <span className="text-[9px] text-slate-600">{timeAgo(conv.last_message_at)}</span>
        <span className={`px-1.5 py-0.5 rounded text-[9px] font-semibold border ${statusColors[conv.status]}`}>{conv.status}</span>
      </div>
    </div>
  </button>
);

// ─── Chat Panel ────────────────────────────────────────────────────────────────

interface ChatPanelProps {
  selected: Conversation; messages: Message[]; agents: SupportAgent[];
  isAdmin: boolean; agentSession: AgentSession | null;
  onClose: () => void; onStatusChange: (id: string, s: string) => void;
  onAssign: (id: string, agent: SupportAgent | null) => void;
  onSend: (text: string) => void; sending: boolean;
  bottomRef: React.RefObject<HTMLDivElement | null>;
}

const ChatPanel: React.FC<ChatPanelProps> = ({ selected, messages, agents, isAdmin, agentSession, onClose, onStatusChange, onAssign, onSend, sending, bottomRef }) => {
  const [reply, setReply] = useState('');
  const senderName = agentSession?.name || 'Rentilly Support';

  const handleSend = () => { if (!reply.trim()) return; onSend(reply.trim()); setReply(''); };

  return (
    <div className="flex-1 flex flex-col min-h-0 bg-slate-950">
      {/* Header */}
      <div className="flex items-center justify-between px-5 py-3 bg-[#090d16] border-b border-slate-800 shrink-0">
        <div className="flex items-center gap-3 min-w-0">
          <div className="w-9 h-9 rounded-full bg-gradient-to-tr from-blue-600 to-indigo-600 flex items-center justify-center text-white text-sm font-bold shrink-0">
            {(selected.user_name || selected.user_email).charAt(0).toUpperCase()}
          </div>
          <div className="min-w-0">
            <p className="text-sm font-bold text-white truncate">{selected.user_name || selected.user_email}</p>
            <p className="text-[10px] text-slate-500 truncate">{selected.user_email} · {selected.subject}</p>
          </div>
        </div>
        <div className="flex items-center gap-2 shrink-0">
          <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${priorityColors[selected.priority]}`}>{selected.priority}</span>
          <div className="relative">
            <select value={selected.status} onChange={(e) => onStatusChange(selected.id, e.target.value)} className="appearance-none text-xs bg-slate-800 border border-slate-700 text-slate-300 rounded-lg px-2.5 py-1 pr-6 focus:outline-none focus:border-emerald-500 transition">
              <option value="open">Open</option>
              <option value="pending">Pending</option>
              <option value="resolved">Resolved</option>
              <option value="closed">Closed</option>
            </select>
            <ChevronDown className="w-3 h-3 text-slate-500 absolute right-2 top-1/2 -translate-y-1/2 pointer-events-none" />
          </div>
          {isAdmin && (
            <div className="relative">
              <select
                value={selected.assigned_agent_email || ''}
                onChange={(e) => { const agent = agents.find((a) => a.email === e.target.value) || null; onAssign(selected.id, agent); }}
                className="appearance-none text-xs bg-slate-800 border border-slate-700 text-slate-300 rounded-lg px-2.5 py-1 pr-6 focus:outline-none focus:border-emerald-500 transition max-w-[160px]"
              >
                <option value="">🔴 Unassigned</option>
                {agents.filter((a) => a.is_active).map((a) => (
                  <option key={a.id} value={a.email}>{a.is_online ? '🟢' : '⚫'} {a.name}</option>
                ))}
              </select>
              <ChevronDown className="w-3 h-3 text-slate-500 absolute right-2 top-1/2 -translate-y-1/2 pointer-events-none" />
            </div>
          )}
          <button onClick={onClose} className="p-1.5 hover:bg-slate-800 rounded-lg text-slate-500 hover:text-slate-300 transition"><X className="w-4 h-4" /></button>
        </div>
      </div>

      {/* Assigned agent banner */}
      {isAdmin && selected.assigned_agent_name && (
        <div className="px-5 py-1.5 bg-slate-900/50 border-b border-slate-800/60 text-[10px] text-slate-500 flex items-center gap-1.5">
          <Users className="w-3 h-3" />
          Assigned to <span className="text-emerald-400 font-semibold">{selected.assigned_agent_name}</span>
          <span className="text-slate-600">({selected.assigned_agent_email})</span>
        </div>
      )}

      {/* Messages */}
      <div className="flex-1 overflow-y-auto px-5 py-4 space-y-3">
        {messages.length === 0 && (
          <div className="flex flex-col items-center justify-center h-full text-slate-600 gap-2">
            <MessageSquare className="w-8 h-8 opacity-30" />
            <p className="text-xs">No messages yet in this conversation</p>
          </div>
        )}
        {messages.map((msg) => {
          const isAgentMsg = msg.sender === 'agent';
          const isBot = msg.sender === 'bot';
          return (
            <div key={msg.id} className={`flex ${isAgentMsg ? 'justify-end' : 'justify-start'}`}>
              {!isAgentMsg && (
                <div className={`w-7 h-7 rounded-full flex items-center justify-center text-white text-[10px] font-bold mr-2 flex-shrink-0 mt-1 ${isBot ? 'bg-emerald-600' : 'bg-blue-600'}`}>
                  {isBot ? 'RS' : (selected.user_name || 'U').charAt(0).toUpperCase()}
                </div>
              )}
              <div className={`max-w-xs lg:max-w-md xl:max-w-lg px-4 py-2.5 rounded-2xl text-xs leading-relaxed ${isAgentMsg ? 'bg-emerald-600 text-white rounded-br-sm' : 'bg-slate-800 text-slate-200 border border-slate-700 rounded-bl-sm'}`}>
                {!isAgentMsg && <p className={`text-[9px] font-bold mb-1 ${isBot ? 'text-emerald-400' : 'text-blue-400'}`}>{msg.sender_name}</p>}
                <p className="whitespace-pre-wrap">{msg.message}</p>
                <p className={`text-[9px] mt-1 ${isAgentMsg ? 'text-emerald-200 text-right' : 'text-slate-500'}`}>
                  {new Date(msg.created_at).toLocaleTimeString('en-NG', { hour: '2-digit', minute: '2-digit' })}
                </p>
              </div>
            </div>
          );
        })}
        <div ref={bottomRef} />
      </div>

      {/* Reply */}
      {selected.status !== 'resolved' && selected.status !== 'closed' ? (
        <div className="px-5 py-3 bg-[#090d16] border-t border-slate-800 shrink-0">
          <div className="flex items-end gap-3">
            <textarea
              value={reply}
              onChange={(e) => setReply(e.target.value)}
              onKeyDown={(e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); handleSend(); } }}
              placeholder="Type reply... (Enter to send, Shift+Enter for newline)"
              rows={2}
              className="flex-1 text-xs bg-slate-800 border border-slate-700 text-slate-200 rounded-xl px-4 py-2.5 focus:outline-none focus:border-emerald-500 resize-none placeholder-slate-600 transition"
            />
            <button onClick={handleSend} disabled={!reply.trim() || sending} className="flex-shrink-0 p-3 bg-emerald-600 text-white rounded-xl hover:bg-emerald-500 disabled:opacity-50 disabled:cursor-not-allowed transition">
              {sending ? <RefreshCw className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
            </button>
          </div>
          <p className="text-[10px] text-slate-600 mt-1.5">Replying as <span className="font-semibold text-emerald-500">{senderName}</span> · User notified via push</p>
        </div>
      ) : (
        <div className="px-5 py-3 bg-slate-900 border-t border-slate-800 text-center shrink-0">
          <p className="text-xs text-slate-500">Conversation is <span className="font-semibold text-slate-400">{selected.status}</span>. Change status to reply.</p>
        </div>
      )}
    </div>
  );
};

// ─── Main Component ────────────────────────────────────────────────────────────

export const LiveSupportChatTab: React.FC = () => {
  const agentSession: AgentSession | null = (() => {
    try { const s = localStorage.getItem('rentilly_agent_session'); return s ? JSON.parse(s) : null; }
    catch { return null; }
  })();
  const isAdmin = !agentSession;

  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [agents, setAgents] = useState<SupportAgent[]>([]);
  const [selected, setSelected] = useState<Conversation | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [search, setSearch] = useState('');
  const [sending, setSending] = useState(false);
  const [loading, setLoading] = useState(true);
  const bottomRef = useRef<HTMLDivElement>(null);
  const msgPollRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const fetchConversations = useCallback(async () => {
    try {
      if (isAdmin) {
        const res = await fetch(`${SUPABASE_URL}/rest/v1/support_conversations?order=last_message_at.desc&select=*`, { headers: sbHeaders });
        if (res.ok) setConversations(await res.json());
      } else {
        const res = await fetch(`/api/support/conversations/agent/${encodeURIComponent(agentSession!.email)}`, {
          headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${localStorage.getItem('rentilly_agent_token') || ''}` },
        });
        if (res.ok) { const d = await res.json(); setConversations(d.conversations || d); }
      }
    } catch (e) { console.error(e); }
    finally { setLoading(false); }
  }, [isAdmin, agentSession]);

  const fetchAgents = useCallback(async () => {
    if (!isAdmin) return;
    try { const res = await fetch('/api/support/agents'); if (res.ok) { const d = await res.json(); setAgents(d.agents || d); } }
    catch (_) {}
  }, [isAdmin]);

  const fetchMessages = useCallback(async (convId: string) => {
    try {
      const res = await fetch(`${SUPABASE_URL}/rest/v1/support_messages?conversation_id=eq.${convId}&order=created_at.asc&select=*`, { headers: sbHeaders });
      if (res.ok) { setMessages(await res.json()); setTimeout(() => bottomRef.current?.scrollIntoView({ behavior: 'smooth' }), 100); }
    } catch (_) {}
  }, []);

  const markRead = useCallback(async (convId: string) => {
    await fetch(`${SUPABASE_URL}/rest/v1/support_conversations?id=eq.${convId}`, { method: 'PATCH', headers: sbHeaders, body: JSON.stringify({ unread_by_agent: 0 }) });
    setConversations((prev) => prev.map((c) => c.id === convId ? { ...c, unread_by_agent: 0 } : c));
  }, []);

  useEffect(() => {
    fetchConversations(); fetchAgents();
    const iv = setInterval(() => { fetchConversations(); fetchAgents(); }, 5000);
    return () => clearInterval(iv);
  }, [fetchConversations, fetchAgents]);

  useEffect(() => {
    if (msgPollRef.current) clearInterval(msgPollRef.current);
    if (!selected) return;
    fetchMessages(selected.id); markRead(selected.id);
    msgPollRef.current = setInterval(() => fetchMessages(selected.id), 3000);
    return () => { if (msgPollRef.current) clearInterval(msgPollRef.current); };
  }, [selected?.id]);

  useEffect(() => { bottomRef.current?.scrollIntoView({ behavior: 'smooth' }); }, [messages.length]);

  useEffect(() => {
    if (!agentSession) return;
    const beat = async () => {
      try {
        await fetch(`/api/support/agents/${agentSession.id}/heartbeat`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${localStorage.getItem('rentilly_agent_token') || ''}` } });
      } catch (_) {}
    };
    beat(); const iv = setInterval(beat, 30000); return () => clearInterval(iv);
  }, [agentSession?.id]);

  const handleSelect = (conv: Conversation) => { setSelected(conv); setMessages([]); };

  const handleSend = async (text: string) => {
    if (!selected || sending) return;
    setSending(true);
    try {
      await fetch(`/api/support/conversations/${selected.id}/messages`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ conversationId: selected.id, message: text, sender: 'agent', senderName: agentSession?.name || 'Rentilly Support' }) });
      await fetchMessages(selected.id); await fetchConversations();
    } catch (_) {} finally { setSending(false); }
  };

  const handleStatusChange = async (convId: string, status: string) => {
    await fetch(`${SUPABASE_URL}/rest/v1/support_conversations?id=eq.${convId}`, { method: 'PATCH', headers: sbHeaders, body: JSON.stringify({ status }) });
    setConversations((p) => p.map((c) => c.id === convId ? { ...c, status: status as Conversation['status'] } : c));
    if (selected?.id === convId) setSelected((p) => p ? { ...p, status: status as Conversation['status'] } : null);
  };

  const handleAssign = async (convId: string, agent: SupportAgent | null) => {
    const patch = agent ? { assigned_agent_id: agent.id, assigned_agent_name: agent.name, assigned_agent_email: agent.email } : { assigned_agent_id: null, assigned_agent_name: null, assigned_agent_email: null };
    await fetch(`${SUPABASE_URL}/rest/v1/support_conversations?id=eq.${convId}`, { method: 'PATCH', headers: sbHeaders, body: JSON.stringify(patch) });
    setConversations((p) => p.map((c) => c.id === convId ? { ...c, ...patch } : c));
    if (selected?.id === convId) setSelected((p) => p ? { ...p, ...patch } : null);
  };

  const handleAgentLogout = () => {
    localStorage.removeItem('rentilly_agent_token'); localStorage.removeItem('rentilly_agent_session'); window.location.reload();
  };

  const filtered = conversations.filter((c) => {
    if (!search) return true;
    const q = search.toLowerCase();
    return c.user_email.toLowerCase().includes(q) || (c.user_name || '').toLowerCase().includes(q) || c.subject.toLowerCase().includes(q);
  });

  const unassigned = filtered.filter((c) => !c.assigned_agent_id);
  const assigned = filtered.filter((c) => !!c.assigned_agent_id);
  const byAgent: Record<string, { agentName: string; convs: Conversation[] }> = {};
  assigned.forEach((c) => {
    const key = c.assigned_agent_email!;
    if (!byAgent[key]) byAgent[key] = { agentName: c.assigned_agent_name!, convs: [] };
    byAgent[key].convs.push(c);
  });

  const openCount = conversations.filter((c) => c.status === 'open').length;
  const unassignedCount = conversations.filter((c) => !c.assigned_agent_id && c.status === 'open').length;
  const onlineAgents = agents.filter((a) => a.is_online && a.is_active).length;

  return (
    <div className="flex flex-col h-full min-h-0 bg-slate-950 text-slate-100">
      {/* Top bar */}
      <div className="flex items-center justify-between px-5 py-3 bg-[#090d16] border-b border-slate-800 shrink-0">
        <div className="flex items-center gap-3">
          <div className="p-2 rounded-xl bg-emerald-500/15 border border-emerald-500/20">
            <MessageSquare className="w-4 h-4 text-emerald-400" />
          </div>
          <div>
            {isAdmin ? (
              <>
                <h2 className="text-sm font-bold text-white">Live Chat Inbox</h2>
                <p className="text-[10px] text-slate-500">Admin oversight — all conversations</p>
              </>
            ) : (
              <>
                <h2 className="text-sm font-bold text-white">My Chat Inbox</h2>
                <div className="flex items-center gap-1.5">
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
                  <span className="text-[10px] text-emerald-400 font-semibold">{agentSession?.name} — Online</span>
                </div>
              </>
            )}
          </div>
        </div>
        <div className="flex items-center gap-2">
          {isAdmin && (
            <>
              <span className="px-2.5 py-1 rounded-full bg-emerald-500/15 text-emerald-400 border border-emerald-500/20 text-[10px] font-bold">{openCount} open</span>
              {unassignedCount > 0 && <span className="px-2.5 py-1 rounded-full bg-amber-500/15 text-amber-400 border border-amber-500/20 text-[10px] font-bold animate-pulse">{unassignedCount} unassigned</span>}
              <span className="px-2.5 py-1 rounded-full bg-slate-800 text-slate-400 border border-slate-700 text-[10px] font-bold">{onlineAgents} agents online</span>
            </>
          )}
          {!isAdmin && (
            <button onClick={handleAgentLogout} className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-red-500/20 text-slate-400 hover:text-red-400 border border-slate-700 text-[11px] font-semibold transition">
              <LogOut className="w-3.5 h-3.5" /> Sign Out
            </button>
          )}
          <button onClick={() => { fetchConversations(); fetchAgents(); }} className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-400 transition">
            <RefreshCw className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>

      <div className="flex flex-1 min-h-0 overflow-hidden">
        {/* Left panel */}
        <div className="w-72 xl:w-80 flex-shrink-0 border-r border-slate-800 flex flex-col min-h-0 bg-[#090d16]">
          <div className="px-4 py-3 border-b border-slate-800">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-slate-600" />
              <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search conversations..." className="w-full pl-9 pr-3 py-2 text-xs bg-slate-900 border border-slate-800 text-slate-300 rounded-lg focus:outline-none focus:border-emerald-500 placeholder-slate-600 transition" />
            </div>
          </div>

          <div className="flex-1 overflow-y-auto">
            {loading ? (
              <div className="flex items-center justify-center h-32 gap-2 text-slate-500">
                <div className="w-4 h-4 border-2 border-slate-700 border-t-slate-400 rounded-full animate-spin" />
                <span className="text-xs">Loading...</span>
              </div>
            ) : filtered.length === 0 ? (
              <div className="flex flex-col items-center justify-center h-40 text-slate-600 gap-2">
                <Inbox className="w-8 h-8 opacity-30" />
                <p className="text-xs">{isAdmin ? 'No conversations' : 'No assigned conversations'}</p>
              </div>
            ) : isAdmin ? (
              <>
                {unassigned.length > 0 && (
                  <div>
                    <div className="px-4 py-2">
                      <span className="text-[9px] font-extrabold uppercase tracking-wider text-amber-500">🔴 Unassigned ({unassigned.length})</span>
                    </div>
                    {unassigned.map((c) => <ConvItem key={c.id} conv={c} isActive={selected?.id === c.id} onClick={() => handleSelect(c)} />)}
                  </div>
                )}
                {Object.entries(byAgent).map(([email, { agentName, convs }]) => {
                  const agentData = agents.find((a) => a.email === email);
                  return (
                    <div key={email}>
                      <div className="px-4 py-2 flex items-center gap-1.5">
                        <Circle className={`w-1.5 h-1.5 fill-current ${agentData?.is_online ? 'text-emerald-500' : 'text-slate-600'}`} />
                        <span className="text-[9px] font-extrabold uppercase tracking-wider text-slate-500 truncate">{agentName} ({convs.length})</span>
                      </div>
                      {convs.map((c) => <ConvItem key={c.id} conv={c} isActive={selected?.id === c.id} onClick={() => handleSelect(c)} />)}
                    </div>
                  );
                })}
              </>
            ) : (
              filtered.map((c) => <ConvItem key={c.id} conv={c} isActive={selected?.id === c.id} onClick={() => handleSelect(c)} />)
            )}
          </div>
        </div>

        {/* Right panel */}
        {selected ? (
          <ChatPanel
            selected={selected} messages={messages} agents={agents}
            isAdmin={isAdmin} agentSession={agentSession}
            onClose={() => { setSelected(null); setMessages([]); }}
            onStatusChange={handleStatusChange} onAssign={handleAssign}
            onSend={handleSend} sending={sending} bottomRef={bottomRef}
          />
        ) : (
          <div className="flex-1 flex flex-col items-center justify-center bg-slate-950 text-slate-600 gap-3">
            <div className="p-6 bg-slate-900 rounded-2xl border border-slate-800">
              <MessageSquare className="w-12 h-12 text-slate-700 mx-auto mb-3" />
              <p className="text-sm font-semibold text-slate-500 text-center">Select a conversation</p>
              <p className="text-xs text-slate-600 text-center mt-1">{isAdmin ? 'Pick any conversation from the left panel' : 'Select one of your assigned chats'}</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};