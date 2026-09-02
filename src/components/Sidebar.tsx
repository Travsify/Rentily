import React from 'react';
import { 
  LayoutDashboard, 
  Users,
  ShieldAlert, 
  Building2, 
  CalendarCheck, 
  BadgePercent, 
  FileText, 
  Database, 
  Smartphone,
  TrendingDown,
  Key,
  UserX
} from 'lucide-react';
import type { AdminTab } from '../types';

interface SidebarProps {
  currentTab: AdminTab;
  setCurrentTab: (tab: AdminTab) => void;
  pendingKypCount: number;
  activeInspectionsCount: number;
  escrowTotalAmount: number;
}

export const Sidebar: React.FC<SidebarProps> = ({
  currentTab,
  setCurrentTab,
  pendingKypCount,
  activeInspectionsCount,
  escrowTotalAmount
}) => {
  const menuItems = [
    {
      id: 'overview' as AdminTab,
      label: 'Executive Overview',
      icon: LayoutDashboard,
      badge: null
    },
    {
      id: 'users' as AdminTab,
      label: 'Users & Stakeholders',
      icon: Users,
      badge: null
    },
    {
      id: 'kyp' as AdminTab,
      label: 'KYP Verification Desk',
      icon: ShieldAlert,
      badge: pendingKypCount > 0 ? `${pendingKypCount} Pending` : null,
      badgeColor: 'bg-amber-500/20 text-amber-300 border-amber-500/30'
    },
    {
      id: 'properties' as AdminTab,
      label: 'Property Registry',
      icon: Building2,
      badge: null
    },
    {
      id: 'inspections' as AdminTab,
      label: 'Inspection Scheduler',
      icon: CalendarCheck,
      badge: activeInspectionsCount > 0 ? `${activeInspectionsCount}` : null,
      badgeColor: 'bg-emerald-500/20 text-emerald-300 border-emerald-500/30'
    },
    {
      id: 'escrow' as AdminTab,
      label: 'Escrow & Payouts',
      icon: BadgePercent,
      badge: escrowTotalAmount > 0 ? `₦${(escrowTotalAmount / 1_000_000).toFixed(1)}M` : null,
      badgeColor: 'bg-blue-500/20 text-blue-300 border-blue-500/30'
    },
    {
      id: 'legal' as AdminTab,
      label: 'Nigerian Legal Engine',
      icon: FileText,
      badge: '10% / 5%'
    },
    {
      id: 'fraud_blacklist' as AdminTab,
      label: 'Fraud & Rogue Blacklist',
      icon: UserX,
      badge: 'Anti-Scam'
    },
    {
      id: 'integrations' as AdminTab,
      label: 'Identitypass & Flutterwave',
      icon: Key,
      badge: 'Live APIs'
    },
    {
      id: 'supabase_config' as AdminTab,
      label: 'Supabase & Cloud Hub',
      icon: Database,
      badge: null
    },
    {
      id: 'flutter_api' as AdminTab,
      label: 'Flutter Mobile API Docs',
      icon: Smartphone,
      badge: 'Ready'
    }
  ];

  return (
    <aside className="w-60 bg-slate-900/95 border-r border-slate-800 flex flex-col justify-between p-3.5 min-h-[calc(100vh-57px)] font-sans">
      <div className="space-y-4">
        {/* Anti-Agent Mission Banner */}
        <div className="p-3 rounded-xl bg-gradient-to-br from-emerald-950/60 to-slate-900 border border-emerald-800/40">
          <div className="flex items-center gap-1.5 text-emerald-400 font-semibold text-[11px] mb-1">
            <TrendingDown className="w-3.5 h-3.5" />
            <span>Anti-Agent Model</span>
          </div>
          <p className="text-[10px] text-slate-300 leading-relaxed">
            Rentals: <span className="text-emerald-400 font-bold">10% Legal</span> (No 20% agent fee).<br/>
            Sales: <span className="text-emerald-400 font-bold">5% Escrow</span> (Direct titles).
          </p>
        </div>

        {/* Navigation Menu */}
        <nav className="space-y-0.5">
          <p className="px-2.5 text-[9px] font-bold uppercase tracking-wider text-slate-500 mb-1.5">
            Admin Navigation
          </p>
          {menuItems.map((item) => {
            const Icon = item.icon;
            const isActive = currentTab === item.id;
            return (
              <button
                key={item.id}
                onClick={() => setCurrentTab(item.id)}
                className={`w-full flex items-center justify-between px-3 py-2 rounded-xl text-[11px] font-medium transition-all ${
                  isActive
                    ? 'bg-emerald-600 text-white font-semibold shadow-sm'
                    : 'text-slate-400 hover:text-slate-100 hover:bg-slate-800/70'
                }`}
              >
                <div className="flex items-center gap-2.5">
                  <Icon className={`w-3.5 h-3.5 ${isActive ? 'text-white' : 'text-slate-400'}`} />
                  <span>{item.label}</span>
                </div>
                {item.badge && (
                  <span
                    className={`text-[9px] px-1.5 py-0.5 rounded-full border ${
                      isActive
                        ? 'bg-white/20 text-white border-white/30 font-bold'
                        : item.badgeColor || 'bg-slate-800 text-slate-400 border-slate-700'
                    }`}
                  >
                    {item.badge}
                  </span>
                )}
              </button>
            );
          })}
        </nav>
      </div>

      {/* Bottom Info Box */}
      <div className="p-2.5 rounded-xl bg-slate-950/80 border border-slate-800/80 text-[10px] text-slate-400 space-y-0.5">
        <div className="flex justify-between items-center text-slate-300 font-semibold">
          <span>Rentilly Core API</span>
          <span className="text-[9px] text-emerald-400 bg-emerald-950 px-1 py-0.5 rounded border border-emerald-800">
            Online
          </span>
        </div>
        <p className="text-[9px] text-slate-500">Lagos & Abuja Market Disruption</p>
      </div>
    </aside>
  );
};
