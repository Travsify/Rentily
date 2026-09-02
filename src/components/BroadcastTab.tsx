import React, { useState, useEffect } from 'react';
import { 
  Send, 
  Megaphone, 
  CheckCircle2, 
  AlertCircle, 
  Clock 
} from 'lucide-react';

interface BroadcastLog {
  id: string;
  targetGroup: string;
  title: string;
  message: string;
  channel: string;
  recipientCount: number;
  sentBy: string;
  createdAt: string;
}

export const BroadcastTab: React.FC = () => {
  const [targetGroup, setTargetGroup] = useState<'all' | 'renters' | 'owners' | 'partners' | 'specific'>('all');
  const [specificEmail, setSpecificEmail] = useState('');
  const [title, setTitle] = useState('');
  const [message, setMessage] = useState('');
  const [channel, setChannel] = useState<'push' | 'sms' | 'both'>('push');
  const [sending, setSending] = useState(false);
  const [statusMessage, setStatusMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);
  const [history, setHistory] = useState<BroadcastLog[]>([]);

  const fetchHistory = async () => {
    try {
      const res = await fetch('/api/broadcast/history');
      if (res.ok) {
        const d = await res.json();
        setHistory(d.history || []);
      }
    } catch (_) {}
  };

  useEffect(() => {
    fetchHistory();
  }, []);

  const handleSend = async (e: React.FormEvent) => {
    e.preventDefault();
    setSending(true);
    setStatusMessage(null);

    try {
      const res = await fetch('/api/broadcast/send', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          targetGroup,
          specificEmail: targetGroup === 'specific' ? specificEmail : undefined,
          title,
          message,
          channel
        })
      });

      const data = await res.json();
      if (res.ok && data.success) {
        setStatusMessage({ type: 'success', text: data.message });
        setTitle('');
        setMessage('');
        fetchHistory();
      } else {
        throw new Error(data.error || 'Failed to dispatch broadcast');
      }
    } catch (err: any) {
      setStatusMessage({ type: 'error', text: err.message || 'Error sending broadcast.' });
    } finally {
      setSending(false);
    }
  };

  return (
    <div className="space-y-6 font-sans max-w-4xl">
      {/* Header */}
      <div>
        <h1 className="text-xl font-bold text-white flex items-center gap-2">
          <Megaphone className="w-6 h-6 text-emerald-400" />
          <span>Broadcast & Push Communications Desk</span>
        </h1>
        <p className="text-xs text-slate-400 mt-0.5">
          Dispatch real-time push announcements and SMS alerts to Tenants, Landlords, and Corporate Partners across Nigeria.
        </p>
      </div>

      {statusMessage && (
        <div className={`p-4 rounded-xl text-xs flex items-center gap-2 ${
          statusMessage.type === 'success'
            ? 'bg-emerald-500/10 border border-emerald-500/30 text-emerald-300'
            : 'bg-red-500/10 border border-red-500/30 text-red-300'
        }`}>
          {statusMessage.type === 'success' ? <CheckCircle2 className="w-4 h-4 text-emerald-400" /> : <AlertCircle className="w-4 h-4 text-red-400" />}
          <span>{statusMessage.text}</span>
        </div>
      )}

      {/* Broadcast Form */}
      <div className="p-6 rounded-2xl bg-slate-900 border border-slate-800 space-y-4">
        <h2 className="text-sm font-bold text-white flex items-center gap-2">
          <Send className="w-4 h-4 text-emerald-400" />
          <span>Compose New Announcement</span>
        </h2>

        <form onSubmit={handleSend} className="space-y-4 text-xs">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-slate-300 font-semibold block">Target Audience</label>
              <select
                value={targetGroup}
                onChange={(e) => setTargetGroup(e.target.value as any)}
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white focus:outline-none focus:border-emerald-500"
              >
                <option value="all">📢 All Users (Tenants, Landlords, Partners)</option>
                <option value="renters">🏠 All Renters & Tenants</option>
                <option value="owners">🏢 All Property Owners / Landlords</option>
                <option value="partners">🤝 All Accredited Corporate Partners</option>
                <option value="specific">👤 Specific User by Email</option>
              </select>
            </div>

            <div className="space-y-1.5">
              <label className="text-slate-300 font-semibold block">Dispatch Channel</label>
              <select
                value={channel}
                onChange={(e) => setChannel(e.target.value as any)}
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white focus:outline-none focus:border-emerald-500"
              >
                <option value="push">📱 In-App Push Notification</option>
                <option value="sms">💬 SMS Alert (Twilio / Africa's Talking)</option>
                <option value="both">🔔 Both Push & SMS Alert</option>
              </select>
            </div>
          </div>

          {targetGroup === 'specific' && (
            <div className="space-y-1.5">
              <label className="text-slate-300 font-semibold block">Recipient Email</label>
              <input
                type="email"
                required
                value={specificEmail}
                onChange={(e) => setSpecificEmail(e.target.value)}
                placeholder="user@example.com"
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white focus:outline-none focus:border-emerald-500"
              />
            </div>
          )}

          <div className="space-y-1.5">
            <label className="text-slate-300 font-semibold block">Announcement Title</label>
            <input
              type="text"
              required
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="e.g. New Tenancy Law Regulations & Escrow Release Update"
              className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-white font-medium focus:outline-none focus:border-emerald-500"
            />
          </div>

          <div className="space-y-1.5">
            <label className="text-slate-300 font-semibold block">Message Content</label>
            <textarea
              required
              rows={4}
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              placeholder="Draft your platform notification message..."
              className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200 focus:outline-none focus:border-emerald-500 resize-none leading-relaxed"
            />
          </div>

          <button
            type="submit"
            disabled={sending}
            className="px-6 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs shadow-lg shadow-emerald-950/60 transition flex items-center gap-2 disabled:opacity-50"
          >
            <Send className="w-4 h-4" />
            <span>{sending ? 'Dispatching Broadcast...' : 'Dispatch Announcement Now'}</span>
          </button>
        </form>
      </div>

      {/* Broadcast History */}
      {history.length > 0 && (
        <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 space-y-3">
          <h2 className="text-sm font-bold text-white flex items-center gap-2">
            <Clock className="w-4 h-4 text-slate-400" />
            <span>Recent Broadcast History</span>
          </h2>

          <div className="divide-y divide-slate-800/60 text-xs">
            {history.map((log) => (
              <div key={log.id} className="py-3 flex items-start justify-between gap-4">
                <div className="space-y-1">
                  <div className="font-bold text-white flex items-center gap-2">
                    <span>{log.title}</span>
                    <span className="text-[10px] uppercase font-mono px-1.5 py-0.5 rounded bg-slate-800 text-slate-300">
                      {log.targetGroup}
                    </span>
                  </div>
                  <p className="text-slate-400 leading-relaxed">{log.message}</p>
                  <span className="text-[10px] text-slate-500 font-mono">
                    {new Date(log.createdAt).toLocaleString()}
                  </span>
                </div>
                <div className="text-right shrink-0">
                  <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                    {log.recipientCount} Recipients
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};
