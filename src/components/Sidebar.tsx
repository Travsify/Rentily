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
  UserX,
  Headphones,
  ShieldCheck,
  Wallet,
  Zap,
  Sliders,
  Megaphone,
  Eye,
  Calendar,
  Scale,
  Activity,
  Globe
} from 'lucide-react';
import type { AdminTab } from '../types';

interface SidebarProps {
  currentTab: AdminTab;
  setCurrentTab: (tab: AdminTab) => void;
  pendingKypCount: number;
  activeInspectionsCount: number;
  escrowTotalAmount: number;
}

interface NavSection {
  title: string;
  items: {
    id: AdminTab;
    label: string;
    icon: React.ComponentType<{ className?: string }>;
    badge?: string | null;
    badgeColor?: string;
  }[];
}

export const Sidebar: React.FC<SidebarProps> = ({
  currentTab,
  setCurrentTab,
  pendingKypCount,
  activeInspectionsCount,
  escrowTotalAmount
}) => {
  const sections: NavSection[] = [
    {
      title: 'OPERATIONS & PROPERTIES',
      items: [
        {
          id: 'overview',
          label: 'Executive Overview',
          icon: LayoutDashboard,
          badge: null
        },
        {
          id: 'kyp',
          label: 'KYP Title Audits',
          icon: ShieldAlert,
          badge: pendingKypCount > 0 ? `${pendingKypCount} Pending` : null,
          badgeColor: 'bg-amber-500/20 text-amber-300 border-amber-500/30 font-bold'
        },
        {
          id: 'properties',
          label: 'Property Registry',
          icon: Building2,
          badge: null
        },
        {
          id: 'inspections',
          label: 'Field Inspections',
          icon: CalendarCheck,
          badge: activeInspectionsCount > 0 ? `${activeInspectionsCount}` : null,
          badgeColor: 'bg-emerald-500/20 text-emerald-300 border-emerald-500/30'
        },
        {
          id: 'lease_renewals',
          label: 'Lease Expiry & Renewals',
          icon: Calendar,
          badge: 'Annual'
        },
        {
          id: 'statutory_notices',
          label: 'Statutory Notices (Lagos/FCT)',
          icon: Scale,
          badge: 'Legal'
        }
      ]
    },
    {
      title: 'STAKEHOLDERS & GOVERNANCE',
      items: [
        {
          id: 'users',
          label: 'Stakeholders & Users',
          icon: Users,
          badge: null
        },
        {
          id: 'chat_oversight',
          label: 'Chat & Anti-Circumvention',
          icon: Eye,
          badge: 'Anti-Bypass'
        },
        {
          id: 'support_tickets',
          label: 'Support & Disputes',
          icon: Headphones,
          badge: 'Arbitration'
        },
        {
          id: 'fraud_blacklist',
          label: 'Fraud & Scam Shield',
          icon: UserX,
          badge: 'Anti-Scam'
        }
      ]
    },
    {
      title: 'FINANCIALS & REVENUE',
      items: [
        {
          id: 'escrow',
          label: 'Escrow Payout Releases',
          icon: BadgePercent,
          badge: escrowTotalAmount > 0 ? `₦${(escrowTotalAmount / 1_000_000).toFixed(1)}M` : null,
          badgeColor: 'bg-blue-500/20 text-blue-300 border-blue-500/30'
        },
        {
          id: 'caution_claims',
          label: 'Caution Fees & Damage Claims',
          icon: ShieldAlert,
          badge: 'Refunds'
        },
        {
          id: 'master_ledger',
          label: 'Master Financial Ledger',
          icon: Wallet,
          badge: 'Live Flows'
        },
        {
          id: 'reconciliation',
          label: 'Daily Banking Audit',
          icon: Activity,
          badge: 'Settlement'
        },
        {
          id: 'global_cards',
          label: 'Global FX & Virtual Cards',
          icon: Globe,
          badge: 'USD/Cards'
        },
        {
          id: 'bills_operations',
          label: 'Bills & Utilities Desk',
          icon: Zap,
          badge: 'Disco/Data'
        },
        {
          id: 'fee_settings',
          label: 'Platform Tariffs & Fees',
          icon: Sliders,
          badge: '₦50 / ₦100'
        },
        {
          id: 'legal',
          label: 'Tenancy Leases (10%/5%)',
          icon: FileText,
          badge: 'Contracts'
        }
      ]
    },
    {
      title: 'SYSTEM & COMMUNICATIONS',
      items: [
        {
          id: 'broadcast',
          label: 'Push & SMS Broadcasts',
          icon: Megaphone,
          badge: 'Alerts'
        },
        {
          id: 'supabase_config',
          label: 'Cloud DB & Gateways',
          icon: Database,
          badge: 'Live DB'
        },
        {
          id: 'flutter_api',
          label: 'Mobile API Endpoints',
          icon: Smartphone,
          badge: 'REST'
        }
      ]
    }
  ];

  return (
    <aside className="w-64 bg-[#090d16] border-r border-slate-800 flex flex-col justify-between p-4 sticky top-[61px] h-[calc(100vh-61px)] overflow-y-auto overflow-x-hidden font-sans select-none scrollbar-thin scrollbar-thumb-slate-800 hover:scrollbar-thumb-slate-700">
      <div className="space-y-5">
        {/* Zero-Agent Value Proposition Banner */}
        <div className="p-3.5 rounded-2xl bg-gradient-to-br from-emerald-950/60 to-slate-900 border border-emerald-800/40 space-y-1">
          <div className="flex items-center gap-1.5 text-emerald-400 font-bold text-xs">
            <ShieldCheck className="w-4 h-4" />
            <span>Zero-Agent Protocol</span>
          </div>
          <p className="text-[11px] text-slate-300 leading-relaxed">
            Eliminating 20% agent fees with direct title audits, escrow settlements, and automated 2.5% partner yields.
          </p>
        </div>

        {/* Navigation Sections */}
        <nav className="space-y-4">
          {sections.map((section) => (
            <div key={section.title} className="space-y-1">
              <p className="px-3 text-[9px] font-extrabold uppercase tracking-wider text-slate-500">
                {section.title}
              </p>
              <div className="space-y-0.5">
                {section.items.map((item) => {
                  const Icon = item.icon;
                  const isActive = currentTab === item.id;
                  return (
                    <button
                      key={item.id}
                      onClick={() => setCurrentTab(item.id)}
                      className={`w-full flex items-center justify-between px-3 py-2 rounded-xl text-xs font-semibold transition-all ${
                        isActive
                          ? 'bg-emerald-600 text-white shadow-md shadow-emerald-950/50'
                          : 'text-slate-400 hover:text-slate-100 hover:bg-slate-800/60'
                      }`}
                    >
                      <div className="flex items-center gap-2.5">
                        <Icon className={`w-3.5 h-3.5 shrink-0 ${isActive ? 'text-white' : 'text-slate-400'}`} />
                        <span className="truncate">{item.label}</span>
                      </div>
                      {item.badge && (
                        <span
                          className={`text-[9px] px-1.5 py-0.2 rounded-full border whitespace-nowrap ${
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
              </div>
            </div>
          ))}
        </nav>
      </div>

      {/* Footer System Pill */}
      <div className="pt-3 border-t border-slate-800/80">
        <div className="p-2.5 rounded-xl bg-slate-950 border border-slate-800/80 flex items-center justify-between text-xs text-slate-400">
          <div className="flex items-center gap-2">
            <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
            <span className="font-semibold text-slate-300 text-[11px]">Rentilly Protocol</span>
          </div>
          <span className="text-[10px] text-emerald-400 font-mono font-bold bg-emerald-950/80 px-1.5 py-0.5 rounded border border-emerald-800/60">
            Live Ops
          </span>
        </div>
      </div>
    </aside>
  );
};
