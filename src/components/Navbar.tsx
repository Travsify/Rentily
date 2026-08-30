import React from 'react';
import { ShieldCheck, Database, Server, Plus, AlertCircle, RefreshCw, LogOut } from 'lucide-react';
import type { AdminTab, UserProfile } from '../types';

interface NavbarProps {
  currentTab: AdminTab;
  setCurrentTab: (tab: AdminTab) => void;
  pendingKypCount: number;
  serverStatus: { connected: boolean; supabase: boolean };
  currentUser: UserProfile | null;
  onOpenAddProperty: () => void;
  onRefreshData: () => void;
  onLogout: () => void;
}

export const Navbar: React.FC<NavbarProps> = ({
  setCurrentTab,
  pendingKypCount,
  serverStatus,
  currentUser,
  onOpenAddProperty,
  onRefreshData,
  onLogout
}) => {
  return (
    <header className="sticky top-0 z-40 bg-slate-900/95 backdrop-blur border-b border-slate-800 px-6 py-3 flex items-center justify-between shadow-sm">
      {/* Brand & Market Identity */}
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-emerald-600 to-teal-400 flex items-center justify-center shadow-lg shadow-emerald-900/30">
          <ShieldCheck className="w-6 h-6 text-white" />
        </div>
        <div>
          <div className="flex items-center gap-2">
            <span className="font-bold text-xl tracking-tight text-white">Rentilly</span>
            <span className="text-[10px] uppercase font-bold tracking-wider px-2 py-0.5 rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
              Admin & Legal Vault
            </span>
          </div>
          <p className="text-xs text-slate-400">Zero-Agent Real Estate Platform • Nigerian KYP Protocol</p>
        </div>
      </div>

      {/* Center Status Indicators */}
      <div className="hidden md:flex items-center gap-3">
        {/* Live Render API Backend Status */}
        <div className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-slate-800/80 border border-slate-700/60 text-xs">
          <Server className="w-3.5 h-3.5 text-emerald-400" />
          <span className="text-slate-300">Render API:</span>
          <span className="flex items-center gap-1 font-semibold text-emerald-400">
            <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
            Online
          </span>
        </div>

        {/* Supabase Status */}
        <button 
          onClick={() => setCurrentTab('supabase_config')}
          className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-slate-800/80 hover:bg-slate-800 border border-slate-700/60 text-xs transition group"
        >
          <Database className="w-3.5 h-3.5 text-emerald-400 group-hover:scale-110 transition-transform" />
          <span className="text-slate-300">Database:</span>
          {serverStatus.supabase ? (
            <span className="text-emerald-400 font-semibold flex items-center gap-1">
              <span className="w-2 h-2 rounded-full bg-emerald-400"></span>
              Supabase Connected
            </span>
          ) : (
            <span className="text-amber-400 font-semibold flex items-center gap-1">
              <span className="w-2 h-2 rounded-full bg-amber-400"></span>
              In-Memory Mode
            </span>
          )}
        </button>
      </div>

      {/* Right Controls & Profile */}
      <div className="flex items-center gap-3">
        <button
          onClick={onRefreshData}
          title="Refresh Data"
          className="p-2 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 transition"
        >
          <RefreshCw className="w-4 h-4" />
        </button>

        {pendingKypCount > 0 && (
          <button
            onClick={() => setCurrentTab('kyp')}
            className="hidden sm:flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-amber-500/10 hover:bg-amber-500/20 text-amber-300 border border-amber-500/30 text-xs font-semibold animate-pulse transition"
          >
            <AlertCircle className="w-3.5 h-3.5" />
            <span>{pendingKypCount} KYP Needs Review</span>
          </button>
        )}

        <button
          onClick={onOpenAddProperty}
          className="flex items-center gap-2 px-3.5 py-2 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold shadow-md shadow-emerald-900/30 transition transform active:scale-95"
        >
          <Plus className="w-4 h-4" />
          <span>Add Direct Property</span>
        </button>

        {/* Authenticated Admin Profile & Logout */}
        <div className="flex items-center gap-2.5 pl-2 border-l border-slate-800">
          <img
            src={currentUser?.avatarUrl || "https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=120&q=80"}
            alt="Admin Profile"
            className="w-8 h-8 rounded-full object-cover ring-2 ring-emerald-500/40"
          />
          <div className="hidden lg:block text-left">
            <p className="text-xs font-semibold text-white leading-tight">
              {currentUser?.fullName || 'Barr. Chijioke Okonkwo'}
            </p>
            <p className="text-[10px] text-emerald-400">
              {currentUser?.role === 'admin' ? 'Head of Legal & Title Audit' : 'Verified Admin'}
            </p>
          </div>

          <button
            onClick={onLogout}
            title="Sign Out"
            className="p-1.5 rounded-lg bg-slate-800 hover:bg-red-500/20 text-slate-400 hover:text-red-400 transition ml-1"
          >
            <LogOut className="w-4 h-4" />
          </button>
        </div>
      </div>
    </header>
  );
};
