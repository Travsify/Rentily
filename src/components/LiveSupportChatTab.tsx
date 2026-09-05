import React, { useState, useEffect, useRef } from 'react';
import { MessageSquare, Send, CheckCircle2, Clock, AlertCircle, Search, RefreshCw, User, X, ChevronRight } from 'lucide-react';

const SUPABASE_URL = 'https://zuxvxuqxomsxgiljykzj.supabase.co';
const SUPABASE_KEY = 'sb_publishable_LiVL01tqjp7jQQZwxFTayQ_TrhSswA_';

interface Conversation {
  id: string;
  user_email: string;
  user_name: string;
  user_role: string;
  subject: string;
  status: 'open' | 'pending' | 'resolved' | 'closed';
  priority: 'low' | 'normal' | 'high' | 'urgent';
  last_message: string;
  last_message_at: string;
  unread_by_agent: number;
  assigned_to?: string;
  created_at: string;
}

interface Message {
  id: string;
  conversation_id: string;
  sender: 'user' | 'agent' | 'bot';
  sender_name: string;
  message: string;
  created_at: string;
  is_read: boolean;
}

const sbHeaders = {
  apikey: SUPABASE_KEY,
  Authorization: `Bearer ${SUPABASE_KEY}`,
  'Content-Type': 'application/json',
  Prefer: 'return=representation',
};

const statusColor: Record<string, string> = {
  open: 'bg-green-100 text-green-700',
  pending: 'bg-yellow-100 text-yellow-700',
  resolved: 'bg-blue-100 text-blue-700',
  closed: 'bg-gray-100 text-gray-500',
};

const priorityColor: Record<string, string> = {
  low: 'bg-gray-100 text-gray-500',
  normal: 'bg-blue-50 text-blue-600',
  high: 'bg-orange-100 text-orange-600',
  urgent: 'bg-red-100 text-red-600',
};

function timeAgo(iso: string) {
  const diff = Date.now() - new Date(iso).getTime();
  const m = Math.floor(diff / 60000);
  if (m < 1) return 'Just now';
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  return `${Math.floor(h / 24)}d ago`;
}

export const LiveSupportChatTab: React.FC = () => {
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [selected, setSelected] = useState<Conversation | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [reply, setReply] = useState('');
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [sending, setSending] = useState(false);
  const [loading, setLoading] = useState(true);
  const bottomRef = useRef<HTMLDivElement>(null);
  const pollRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const fetchConversations = async () => {
    try {
      const res = await fetch(`${SUPABASE_URL}/rest/v1/support_conversations?order=last_message_at.desc&select=*`, { headers: sbHeaders });
      if (res.ok) setConversations(await res.json());
    } catch (_) {}
    setLoading(false);
  };

  const fetchMessages = async (convId: string) => {
    try {
      const res = await fetch(`${SUPABASE_URL}/rest/v1/support_messages?conversation_id=eq.${convId}&order=created_at.asc&select=*`, { headers: sbHeaders });
      if (res.ok) {
        const data: Message[] = await res.json();
        setMessages(data);
        setTimeout(() => bottomRef.current?.scrollIntoView({ behavior: 'smooth' }), 100);
      }
    } catch (_) {}
  };

  useEffect(() => {
    fetchConversations();
    const iv = setInterval(fetchConversations, 8000);
    return () => clearInterval(iv);
  }, []);

  useEffect(() => {
    if (pollRef.current) clearInterval(pollRef.current);
    if (!selected) return;
    fetchMessages(selected.id);
    markAgentRead(selected.id);
    pollRef.current = setInterval(() => fetchMessages(selected.id), 3000);
    return () => { if (pollRef.current) clearInterval(pollRef.current); };
  }, [selected?.id]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages.length]);

  const markAgentRead = async (convId: string) => {
    await fetch(`${SUPABASE_URL}/rest/v1/support_conversations?id=eq.${convId}`, {
      method: 'PATCH', headers: sbHeaders, body: JSON.stringify({ unread_by_agent: 0 }),
    });
    setConversations(prev => prev.map(c => c.id === convId ? { ...c, unread_by_agent: 0 } : c));
  };

  const sendReply = async () => {
    if (!reply.trim() || !selected || sending) return;
    setSending(true);
    const text = reply.trim();
    setReply('');
    try {
      await fetch('/api/support/conversations/' + selected.id + '/messages', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ conversationId: selected.id, message: text, sender: 'agent', senderName: 'Rentilly Support' }),
      });
      await fetchMessages(selected.id);
      await fetchConversations();
    } catch (_) {} finally { setSending(false); }
  };

  const updateStatus = async (convId: string, status: string) => {
    await fetch(`${SUPABASE_URL}/rest/v1/support_conversations?id=eq.${convId}`, {
      method: 'PATCH', headers: sbHeaders, body: JSON.stringify({ status }),
    });
    setConversations(prev => prev.map(c => c.id === convId ? { ...c, status: status as any } : c));
    if (selected?.id === convId) setSelected(prev => prev ? { ...prev, status: status as any } : null);
  };

  const filtered = conversations.filter(c => {
    const q = search.toLowerCase();
    const matchSearch = !q || c.user_email.includes(q) || c.user_name.toLowerCase().includes(q) || c.subject.toLowerCase().includes(q);
    const matchStatus = statusFilter === 'all' || c.status === statusFilter;
    return matchSearch && matchStatus;
  });

  const openCount = conversations.filter(c => c.status === 'open').length;
  const pendingCount = conversations.filter(c => c.status === 'pending').length;
  const totalUnread = conversations.reduce((sum, c) => sum + (c.unread_by_agent || 0), 0);

  return (
    <div className="flex flex-col h-full min-h-0">
      {/* Header */}
      <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100 bg-white">
        <div className="flex items-center gap-3">
          <div className="p-2 bg-blue-50 rounded-xl"><MessageSquare className="w-5 h-5 text-blue-600" /></div>
          <div>
            <h2 className="text-base font-bold text-gray-900">Live Support Chat</h2>
            <p className="text-xs text-gray-500">Real-time in-app user conversations</p>
          </div>
        </div>
        <div className="flex items-center gap-3">
          {totalUnread > 0 && <span className="px-2.5 py-1 bg-red-100 text-red-600 text-xs font-bold rounded-full">{totalUnread} unread</span>}
          <span className="px-2.5 py-1 bg-green-100 text-green-700 text-xs font-semibold rounded-full">{openCount} open</span>
          <span className="px-2.5 py-1 bg-yellow-100 text-yellow-700 text-xs font-semibold rounded-full">{pendingCount} pending</span>
          <button onClick={fetchConversations} className="p-2 hover:bg-gray-100 rounded-lg transition-colors"><RefreshCw className="w-4 h-4 text-gray-500" /></button>
        </div>
      </div>

      <div className="flex flex-1 min-h-0 overflow-hidden">
        {/* Left — conversation list */}
        <div className="w-80 flex-shrink-0 border-r border-gray-100 flex flex-col min-h-0 bg-white">
          {/* Filters */}
          <div className="px-4 py-3 border-b border-gray-100 space-y-2">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-gray-400" />
              <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Search users..." className="w-full pl-9 pr-3 py-2 text-xs border border-gray-200 rounded-lg focus:outline-none focus:ring-1 focus:ring-blue-500" />
            </div>
            <div className="flex gap-1">
              {['all','open','pending','resolved','closed'].map(s => (
                <button key={s} onClick={() => setStatusFilter(s)} className={`px-2 py-1 rounded text-[10px] font-semibold capitalize transition-colors ${statusFilter === s ? 'bg-blue-600 text-white' : 'bg-gray-100 text-gray-500 hover:bg-gray-200'}`}>{s}</button>
              ))}
            </div>
          </div>

          {/* List */}
          <div className="flex-1 overflow-y-auto">
            {loading ? (
              <div className="flex items-center justify-center h-32 text-gray-400 text-sm">Loading...</div>
            ) : filtered.length === 0 ? (
              <div className="flex flex-col items-center justify-center h-40 text-gray-400 gap-2">
                <MessageSquare className="w-8 h-8 opacity-30" />
                <p className="text-xs">No conversations yet</p>
              </div>
            ) : filtered.map(conv => (
              <button key={conv.id} onClick={() => setSelected(conv)} className={`w-full text-left px-4 py-3 border-b border-gray-50 hover:bg-blue-50/50 transition-colors ${selected?.id === conv.id ? 'bg-blue-50 border-l-2 border-l-blue-500' : ''}`}>
                <div className="flex items-start justify-between gap-2">
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-1.5 mb-0.5">
                      <span className="text-xs font-bold text-gray-900 truncate">{conv.user_name || conv.user_email}</span>
                      {conv.unread_by_agent > 0 && <span className="flex-shrink-0 w-4 h-4 bg-red-500 rounded-full text-white text-[9px] flex items-center justify-center font-bold">{conv.unread_by_agent}</span>}
                    </div>
                    <p className="text-[10px] text-blue-600 font-medium truncate">{conv.subject}</p>
                    <p className="text-[10px] text-gray-500 truncate mt-0.5">{conv.last_message || 'No messages yet'}</p>
                  </div>
                  <div className="flex flex-col items-end gap-1 flex-shrink-0">
                    <span className="text-[9px] text-gray-400">{timeAgo(conv.last_message_at)}</span>
                    <span className={`px-1.5 py-0.5 rounded text-[9px] font-semibold ${statusColor[conv.status]}`}>{conv.status}</span>
                  </div>
                </div>
              </button>
            ))}
          </div>
        </div>

        {/* Right — chat panel */}
        {selected ? (
          <div className="flex-1 flex flex-col min-h-0 bg-gray-50">
            {/* Chat header */}
            <div className="flex items-center justify-between px-5 py-3 bg-white border-b border-gray-100">
              <div className="flex items-center gap-3">
                <div className="w-9 h-9 rounded-full bg-blue-600 flex items-center justify-center text-white text-sm font-bold">
                  {(selected.user_name || selected.user_email).charAt(0).toUpperCase()}
                </div>
                <div>
                  <p className="text-sm font-bold text-gray-900">{selected.user_name || selected.user_email}</p>
                  <p className="text-[10px] text-gray-500">{selected.user_email} · {selected.user_role} · {selected.subject}</p>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <span className={`px-2 py-1 rounded-full text-[10px] font-bold ${priorityColor[selected.priority]}`}>{selected.priority}</span>
                <select value={selected.status} onChange={e => updateStatus(selected.id, e.target.value)} className="text-xs border border-gray-200 rounded-lg px-2 py-1 focus:outline-none focus:ring-1 focus:ring-blue-500 bg-white">
                  <option value="open">Open</option>
                  <option value="pending">Pending</option>
                  <option value="resolved">Resolved</option>
                  <option value="closed">Closed</option>
                </select>
                <button onClick={() => setSelected(null)} className="p-1.5 hover:bg-gray-100 rounded-lg"><X className="w-4 h-4 text-gray-400" /></button>
              </div>
            </div>

            {/* Messages */}
            <div className="flex-1 overflow-y-auto px-5 py-4 space-y-3">
              {messages.map(msg => {
                const isAgent = msg.sender === 'agent';
                const isBot = msg.sender === 'bot';
                return (
                  <div key={msg.id} className={`flex ${isAgent ? 'justify-end' : 'justify-start'}`}>
                    {!isAgent && (
                      <div className={`w-7 h-7 rounded-full flex items-center justify-center text-white text-xs font-bold mr-2 flex-shrink-0 mt-1 ${isBot ? 'bg-green-500' : 'bg-gray-400'}`}>
                        {isBot ? 'RS' : (selected.user_name || 'U').charAt(0).toUpperCase()}
                      </div>
                    )}
                    <div className={`max-w-xs lg:max-w-md xl:max-w-lg px-4 py-2.5 rounded-2xl ${isAgent ? 'bg-blue-600 text-white rounded-br-sm' : 'bg-white text-gray-900 border border-gray-100 rounded-bl-sm shadow-sm'}`}>
                      {!isAgent && <p className={`text-[9px] font-bold mb-1 ${isBot ? 'text-green-600' : 'text-gray-400'}`}>{msg.sender_name}</p>}
                      <p className={`text-xs leading-relaxed whitespace-pre-wrap ${isAgent ? 'text-white' : 'text-gray-800'}`}>{msg.message}</p>
                      <p className={`text-[9px] mt-1 ${isAgent ? 'text-blue-200 text-right' : 'text-gray-400'}`}>{new Date(msg.created_at).toLocaleTimeString('en-NG', { hour: '2-digit', minute: '2-digit' })}</p>
                    </div>
                  </div>
                );
              })}
              <div ref={bottomRef} />
            </div>

            {/* Reply input */}
            {selected.status !== 'resolved' && selected.status !== 'closed' ? (
              <div className="px-5 py-3 bg-white border-t border-gray-100">
                <div className="flex items-end gap-3">
                  <div className="flex-1">
                    <textarea value={reply} onChange={e => setReply(e.target.value)} onKeyDown={e => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendReply(); } }} placeholder="Type your reply... (Enter to send, Shift+Enter for new line)" rows={2} className="w-full text-xs border border-gray-200 rounded-xl px-4 py-2.5 focus:outline-none focus:ring-2 focus:ring-blue-500 resize-none" />
                  </div>
                  <button onClick={sendReply} disabled={!reply.trim() || sending} className="flex-shrink-0 p-3 bg-blue-600 text-white rounded-xl hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors">
                    {sending ? <RefreshCw className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
                  </button>
                </div>
                <p className="text-[10px] text-gray-400 mt-1.5">Replying as <span className="font-semibold text-blue-600">Rentilly Support</span> · User will be notified via push notification</p>
              </div>
            ) : (
              <div className="px-5 py-3 bg-gray-50 border-t border-gray-100 text-center">
                <p className="text-xs text-gray-400">This conversation is {selected.status}. Change status to reply.</p>
              </div>
            )}
          </div>
        ) : (
          <div className="flex-1 flex flex-col items-center justify-center bg-gray-50 text-gray-400 gap-3">
            <div className="p-6 bg-white rounded-2xl shadow-sm border border-gray-100">
              <MessageSquare className="w-12 h-12 text-blue-200 mx-auto mb-3" />
              <p className="text-sm font-semibold text-gray-500 text-center">Select a conversation</p>
              <p className="text-xs text-gray-400 text-center mt-1">Pick a user conversation from the left to start replying</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
