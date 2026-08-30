import React from 'react';
import { ShieldCheck, Database, Server, Plus, AlertCircle, RefreshCw, LogOut, UserCheck } from 'lucide-react';
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
    <header className="sticky top-0 z-40 bg-slate-900/95 backdrop-blur border-b border-slate-800 px-5 py-2.5 flex items-center justify-between shadow-sm">
      {/* Brand & Market Identity */}
      <div className="flex items-center gap-2.5">
        <div className="w-8 h-8 rounded-xl bg-gradient-to-tr from-emerald-600 to-teal-400 flex items-center justify-center shadow-md shadow-emerald-900/30">
          <ShieldCheck className="w-4.5 h-4.5 text-white" />
        </div>
        <div>
          <div className="flex items-center gap-1.5">
            <span className="font-bold text-base tracking-tight text-white">Rentilly</span>
            <span className="text-[9px] uppercase font-bold tracking-wider px-1.5 py-0.5 rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
              Admin Ops
            </span>
          </div>
          <p className="text-[10px] text-slate-400 leading-none mt-0.5">Zero-Agent Real Estate • Nigerian Operations Hub</p>
        </div>
      </div>

      {/* Center Status Indicators */}
      <div className="hidden md:flex items-center gap-2 text-[11px]">
        {/* Live Render API Backend Status */}
        <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-slate-800/80 border border-slate-700/60">
          <Server className="w-3 h-3 text-emerald-400" />
          <span className="text-slate-400">Server:</span>
          <span className="flex items-center gap-1 font-semibold text-emerald-400">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse"></span>
            Online
          </span>
        </div>

        {/* Supabase Status */}
        <button 
          onClick={() => setCurrentTab('supabase_config')}
          className="flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-slate-800/80 hover:bg-slate-800 border border-slate-700/60 transition group"
        >
          <Database className="w-3 h-3 text-emerald-400 group-hover:scale-110 transition-transform" />
          <span className="text-slate-400">Database:</span>
          {serverStatus.supabase ? (
            <span className="text-emerald-400 font-semibold flex items-center gap-1">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-400"></span>
              Supabase Live
            </span>
          ) : (
            <span className="text-emerald-400 font-semibold flex items-center gap-1">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-400"></span>
              Connected
            </span>
          )}
        </button>
      </div>

      {/* Right Controls & Profile */}
      <div className="flex items-center gap-2">
        <button
          onClick={onRefreshData}
          title="Refresh Data"
          className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 transition"
        >
          <RefreshCw className="w-3.5 h-3.5" />
        </button>

        {pendingKypCount > 0 && (
          <button
            onClick={() => setCurrentTab('kyp')}
            className="hidden sm:flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-amber-500/10 hover:bg-amber-500/20 text-amber-300 border border-amber-500/30 text-[11px] font-semibold animate-pulse transition"
          >
            <AlertCircle className="w-3 h-3" />
            <span>{pendingKypCount} KYP Audit</span>
          </button>
        )}

        <button
          onClick={onOpenAddProperty}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white text-[11px] font-semibold shadow-sm transition transform active:scale-95"
        >
          <Plus className="w-3.5 h-3.5" />
          <span>Add Property</span>
        </button>

        {/* Authenticated Admin Profile & Logout */}
        <div className="flex items-center gap-2 pl-2 border-l border-slate-800">
          <div className="w-7 h-7 rounded-full bg-gradient-to-tr from-emerald-600 to-teal-500 flex items-center justify-center text-white ring-1 ring-emerald-500/40">
            <UserCheck className="w-4 h-4 text-white" />
          </div>
          <div className="hidden lg:block text-left">
            <p className="text-[11px] font-semibold text-white leading-tight">
              {currentUser?.fullName || 'Rentilly Super Admin'}
            </p>
            <p className="text-[9px] text-emerald-400 font-medium">
              Platform Administrator
            </p>
          </div>

          <button
            onClick={onLogout}
            title="Sign Out"
            className="p-1.5 rounded-lg bg-slate-800 hover:bg-red-500/20 text-slate-400 hover:text-red-400 transition ml-0.5"
          >
            <LogOut className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>
    </header>
  );
};
