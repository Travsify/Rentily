import React, { useState } from 'react';
import { 
  Database, 
  Server, 
  Key, 
  Check, 
  Copy, 
  ExternalLink, 
  FileCode,
  Layers,
  Loader2
} from 'lucide-react';
import { RentillyApiService } from '../services/api';

interface SupabaseConfigTabProps {
  onTestConnection?: () => void;
}

export const SupabaseConfigTab: React.FC<SupabaseConfigTabProps> = () => {
  const [copiedIndex, setCopiedIndex] = useState<number | null>(null);
  const [supabaseUrl, setSupabaseUrl] = useState('');
  const [supabaseAnonKey, setSupabaseAnonKey] = useState('');
  const [supabaseServiceRoleKey, setSupabaseServiceRoleKey] = useState('');
  const [saveSuccess, setSaveSuccess] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [feedbackMessage, setFeedbackMessage] = useState<string | null>(null);

  const copyToClipboard = (text: string, index: number) => {
    navigator.clipboard.writeText(text);
    setCopiedIndex(index);
    setTimeout(() => setCopiedIndex(null), 2000);
  };

  const handleSaveCredentials = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!supabaseUrl.trim() || (!supabaseAnonKey.trim() && !supabaseServiceRoleKey.trim())) {
      setFeedbackMessage('Please provide your Supabase URL and at least one API Key.');
      return;
    }
    setIsSaving(true);
    setFeedbackMessage(null);
    try {
      const res = await RentillyApiService.configureSupabase({
        url: supabaseUrl.trim(),
        anonKey: supabaseAnonKey.trim(),
        serviceRoleKey: supabaseServiceRoleKey.trim()
      });
      setSaveSuccess(res.success && res.connected);
      setFeedbackMessage(res.message);
    } catch (err: any) {
      setSaveSuccess(false);
      setFeedbackMessage(err.message || 'Failed to connect to Supabase.');
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-xl font-bold text-white flex items-center gap-2">
          <Database className="w-6 h-6 text-emerald-400" />
          <span>Supabase & Render Infrastructure Hub</span>
        </h1>
        <p className="text-xs text-slate-400 mt-0.5">
          Connect your live Supabase PostgreSQL database and manage your Render cloud deployment for Rentilly.
        </p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Left Column: Credentials & Connection Form (6 cols) */}
        <div className="lg:col-span-6 space-y-4">
          <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 space-y-4 shadow-xl">
            <div className="flex items-center justify-between pb-3 border-b border-slate-800">
              <h2 className="text-sm font-bold text-white flex items-center gap-2">
                <Key className="w-4 h-4 text-emerald-400" />
                <span>Supabase API Credentials</span>
              </h2>
              <span className="text-[11px] text-slate-400">Settings &gt; API</span>
            </div>

            <form onSubmit={handleSaveCredentials} className="space-y-3 text-xs">
              <div>
                <label className="block text-slate-300 font-semibold mb-1">Project URL (SUPABASE_URL)</label>
                <input
                  type="text"
                  value={supabaseUrl}
                  onChange={(e) => setSupabaseUrl(e.target.value)}
                  placeholder="https://your-project-ref.supabase.co"
                  className="w-full px-3.5 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200 focus:outline-none focus:border-emerald-500 font-mono"
                />
              </div>

              <div>
                <label className="block text-slate-300 font-semibold mb-1">Anon / Public Key (SUPABASE_ANON_KEY)</label>
                <textarea
                  rows={2}
                  value={supabaseAnonKey}
                  onChange={(e) => setSupabaseAnonKey(e.target.value)}
                  placeholder="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
                  className="w-full px-3.5 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200 focus:outline-none focus:border-emerald-500 font-mono text-[11px]"
                />
              </div>

              <div>
                <label className="block text-slate-300 font-semibold mb-1">Service Role Key (SUPABASE_SERVICE_ROLE_KEY)</label>
                <textarea
                  rows={2}
                  value={supabaseServiceRoleKey}
                  onChange={(e) => setSupabaseServiceRoleKey(e.target.value)}
                  placeholder="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
                  className="w-full px-3.5 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200 focus:outline-none focus:border-emerald-500 font-mono text-[11px]"
                />
              </div>

              <div className="pt-2 flex flex-col gap-2">
                <div className="flex items-center justify-between">
                  <button
                    type="submit"
                    disabled={isSaving}
                    className="px-5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-white font-bold text-xs shadow-md transition flex items-center gap-1.5"
                  >
                    {isSaving && <Loader2 className="w-3.5 h-3.5 animate-spin" />}
                    <span>{isSaving ? 'Validating Connection...' : 'Save & Validate Connection'}</span>
                  </button>

                  {saveSuccess && (
                    <span className="text-emerald-400 font-semibold flex items-center gap-1">
                      <Check className="w-4 h-4" />
                      <span>Connected!</span>
                    </span>
                  )}
                </div>

                {feedbackMessage && (
                  <div className={`p-2.5 rounded-lg text-[11px] font-mono ${
                    saveSuccess 
                      ? 'bg-emerald-500/10 text-emerald-300 border border-emerald-500/30' 
                      : 'bg-amber-500/10 text-amber-300 border border-amber-500/30'
                  }`}>
                    {feedbackMessage}
                  </div>
                )}
              </div>
            </form>
          </div>

          {/* Render Cloud Deployment Card */}
          <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 space-y-3">
            <div className="flex items-center justify-between pb-3 border-b border-slate-800">
              <h2 className="text-sm font-bold text-white flex items-center gap-2">
                <Server className="w-4 h-4 text-emerald-400" />
                <span>Render Web Service Config</span>
              </h2>
              <span className="text-[11px] text-emerald-400 font-semibold">render.yaml Ready</span>
            </div>

            <div className="p-3 bg-slate-950 rounded-xl border border-slate-800 font-mono text-[11px] text-slate-300 space-y-1">
              <p><span className="text-slate-500">Service:</span> Web Service (Node.js)</p>
              <p><span className="text-slate-500">Build:</span> npm install && npm run build</p>
              <p><span className="text-slate-500">Start:</span> npx tsx server/index.ts</p>
              <p><span className="text-slate-500">Health Check:</span> /api/health</p>
            </div>

            <a
              href="https://render.com"
              target="_blank"
              rel="noreferrer"
              className="inline-flex items-center gap-1.5 text-xs text-emerald-400 hover:text-emerald-300 font-semibold"
            >
              <span>Open Render Dashboard</span>
              <ExternalLink className="w-3.5 h-3.5" />
            </a>
          </div>
        </div>

        {/* Right Column: SQL Schema Migrations & Storage Setup (6 cols) */}
        <div className="lg:col-span-6 space-y-4">
          <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 space-y-3">
            <div className="flex items-center justify-between pb-3 border-b border-slate-800">
              <h2 className="text-sm font-bold text-white flex items-center gap-2">
                <FileCode className="w-4 h-4 text-emerald-400" />
                <span>Supabase SQL Migration Scripts</span>
              </h2>
              <span className="text-[11px] text-slate-400">Run in SQL Editor</span>
            </div>

            <div className="space-y-3 text-xs">
              <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 flex items-center justify-between">
                <div>
                  <span className="font-bold text-white block">1. Table Schema & RLS Policies</span>
                  <span className="text-[11px] text-slate-400">20260830000001_create_rentilly_tables.sql</span>
                </div>
                <button
                  onClick={() => copyToClipboard('supabase/migrations/20260830000001_create_rentilly_tables.sql', 1)}
                  className="px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 font-semibold flex items-center gap-1"
                >
                  {copiedIndex === 1 ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
                  <span>{copiedIndex === 1 ? 'Copied' : 'Copy Path'}</span>
                </button>
              </div>

              <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 flex items-center justify-between">
                <div>
                  <span className="font-bold text-white block">2. Authentic Nigerian Seed Data</span>
                  <span className="text-[11px] text-slate-400">20260830000002_seed_nigerian_data.sql</span>
                </div>
                <button
                  onClick={() => copyToClipboard('supabase/migrations/20260830000002_seed_nigerian_data.sql', 2)}
                  className="px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 font-semibold flex items-center gap-1"
                >
                  {copiedIndex === 2 ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
                  <span>{copiedIndex === 2 ? 'Copied' : 'Copy Path'}</span>
                </button>
              </div>
            </div>
          </div>

          {/* Storage Buckets Guidelines */}
          <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 space-y-3 text-xs">
            <h3 className="text-sm font-bold text-white flex items-center gap-2">
              <Layers className="w-4 h-4 text-emerald-400" />
              <span>Recommended Supabase Storage Buckets</span>
            </h3>
            <ul className="space-y-2 text-slate-300 text-[11px]">
              <li className="p-2 rounded-lg bg-slate-950 border border-slate-800">
                <code className="text-emerald-400 font-bold">kyp-documents</code> (Private): For C of O, Deed of Assignment, NIN, and utility bills.
              </li>
              <li className="p-2 rounded-lg bg-slate-950 border border-slate-800">
                <code className="text-emerald-400 font-bold">property-media</code> (Public): For property photos and video walkthroughs.
              </li>
              <li className="p-2 rounded-lg bg-slate-950 border border-slate-800">
                <code className="text-emerald-400 font-bold">legal-contracts</code> (Private): For executed PDF Tenancy Agreements and Contracts of Sale.
              </li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  );
};
