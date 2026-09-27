import React, { useState, useEffect } from 'react';
import { 
  Sliders, 
  CreditCard, 
  Globe, 
  Zap, 
  Scale, 
  ShieldAlert, 
  AlertTriangle, 
  Save, 
  CheckCircle2, 
  RefreshCw,
  Eye,
  EyeOff,
  Package,
  GraduationCap,
  Truck,
  DollarSign,
  Coins
} from 'lucide-react';

interface FeatureFlags {
  enableVirtualCards: boolean;
  enableVirtualNgnCards: boolean;
  enablePhysicalNgnCards: boolean;
  enableVirtualUsdCards: boolean;
  enableTuitionPayments: boolean;
  enableSupplierPayouts: boolean;
  physicalCardIssuanceFeeNgn: number;
  physicalCardDeliveryFeeNgn: number;
  virtualCardIssuanceFeeNgn: number;
  virtualCardIssuanceFeeUsd: number;
  enableMultiCurrencyVault: boolean;
  enableUtilityBills: boolean;
  enableStatutoryNotices: boolean;
  enableCautionClaims: boolean;
  maintenanceMode: boolean;
  updatedAt?: string;
}

export const FeatureFlagsTab: React.FC = () => {
  const [flags, setFlags] = useState<FeatureFlags>({
    enableVirtualCards: true,
    enableVirtualNgnCards: true,
    enablePhysicalNgnCards: true,
    enableVirtualUsdCards: true,
    enableTuitionPayments: true,
    enableSupplierPayouts: true,
    physicalCardIssuanceFeeNgn: 4500,
    physicalCardDeliveryFeeNgn: 2000,
    virtualCardIssuanceFeeNgn: 1500,
    virtualCardIssuanceFeeUsd: 3.00,
    enableMultiCurrencyVault: false,
    enableUtilityBills: true,
    enableStatutoryNotices: true,
    enableCautionClaims: true,
    maintenanceMode: false
  });

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [statusMessage, setStatusMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

  const fetchFlags = async () => {
    setLoading(true);
    try {
      const res = await fetch('/api/config/features');
      if (res.ok) {
        const data = await res.json();
        if (data.flags) {
          setFlags(prev => ({ ...prev, ...data.flags }));
        }
      }
    } catch (_) {}
    setLoading(false);
  };

  useEffect(() => {
    fetchFlags();
  }, []);

  const handleToggle = (key: keyof FeatureFlags) => {
    setFlags(prev => ({
      ...prev,
      [key]: !prev[key]
    }));
  };

  const handleFeeChange = (key: keyof FeatureFlags, value: string) => {
    const num = parseFloat(value);
    setFlags(prev => ({
      ...prev,
      [key]: isNaN(num) ? 0 : num
    }));
  };

  const handleSave = async () => {
    setSaving(true);
    setStatusMessage(null);
    try {
      const res = await fetch('/api/config/features', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(flags)
      });

      if (res.ok) {
        setStatusMessage({
          type: 'success',
          text: 'Feature flags saved! Mobile apps and web dashboards will reflect these changes dynamically.'
        });
      } else {
        throw new Error('Failed to update feature flags.');
      }
    } catch (err: any) {
      setStatusMessage({ type: 'error', text: err.message || 'Error updating feature flags.' });
    } finally {
      setSaving(false);
    }
  };

  const items = [
    {
      key: 'enableVirtualCards' as keyof FeatureFlags,
      title: 'Cards Desk Master Switch',
      description: 'Master toggle for multi-currency cards across all mobile wallets and drawer menus.',
      impact: 'When OFF, completely hides the Cards Desk entry point across all dashboards.',
      icon: CreditCard,
      color: 'emerald',
      isCaution: false
    },
    {
      key: 'enableVirtualNgnCards' as keyof FeatureFlags,
      title: 'Virtual NGN Cards (Mastercard / Verve)',
      description: 'Instant Nigerian Naira virtual debit cards for domestic subscriptions and POS checkouts.',
      impact: 'When OFF, hides the Virtual NGN tab on the cards desk and prevents new NGN issuance.',
      icon: Coins,
      color: 'emerald',
      isCaution: false
    },
    {
      key: 'enablePhysicalNgnCards' as keyof FeatureFlags,
      title: 'Physical NGN Cards (EMV Chip & Courier Delivery)',
      description: 'Physical contactless debit cards with nationwide courier dispatch, ATM/POS PIN, and delivery tracking.',
      impact: 'When OFF, hides the Physical NGN tab and disables the doorstep order modal on mobile.',
      icon: Package,
      color: 'blue',
      isCaution: false
    },
    {
      key: 'enableVirtualUsdCards' as keyof FeatureFlags,
      title: 'Virtual USD Cards (Visa Platinum)',
      description: 'Institutional USD Visa cards for international subscriptions, travel, and global software billing.',
      impact: 'When OFF, hides the Virtual USD tab and disables USD card issuance.',
      icon: DollarSign,
      color: 'purple',
      isCaution: false
    },
    {
      key: 'enableTuitionPayments' as keyof FeatureFlags,
      title: 'Global Pay — Tuition & University Payments',
      description: 'Direct foreign student tuition settlement to accredited UK, US, EU, and Canadian universities.',
      impact: 'When OFF, disables the Tuition quick-action pod on home screens and halts new tuition orders.',
      icon: GraduationCap,
      color: 'amber',
      isCaution: false
    },
    {
      key: 'enableSupplierPayouts' as keyof FeatureFlags,
      title: 'Global Pay — International Supplier Invoices',
      description: 'Overseas wholesale manufacturer and commercial vendor payouts via SWIFT, SEPA, and FPS rails.',
      impact: 'When OFF, disables the Supplier quick-action pod on home screens and halts supplier wires.',
      icon: Truck,
      color: 'teal',
      isCaution: false
    },
    {
      key: 'enableMultiCurrencyVault' as keyof FeatureFlags,
      title: 'Multi-Currency Bank Vault (USD, GBP, EUR)',
      description: 'Dedicated foreign collection bank accounts, IBANs, and Fedwire routing numbers for international collections.',
      impact: 'When OFF, limits user wallets to Nigerian Naira (NGN), hiding foreign account coordinates.',
      icon: Globe,
      color: 'teal',
      isCaution: false
    },
    {
      key: 'enableUtilityBills' as keyof FeatureFlags,
      title: 'Utility Bills & Disco Electricity Desk',
      description: 'Prepaid/postpaid electricity token vending across all Nigerian Discos and airtime/data top-ups.',
      impact: 'When OFF, hides utility quick-pay and electricity meter verification buttons.',
      icon: Zap,
      color: 'amber',
      isCaution: false
    },
    {
      key: 'enableStatutoryNotices' as keyof FeatureFlags,
      title: 'Statutory Legal Notices & Quit Notices',
      description: 'Standard 7-day owner intentions, notice to quit, and formal tenancy termination documents.',
      impact: 'When OFF, disables legal notice serving tools on landlord and partner dashboards.',
      icon: Scale,
      color: 'blue',
      isCaution: false
    },
    {
      key: 'enableCautionClaims' as keyof FeatureFlags,
      title: 'Caution Deposit Claims & Damage Disputes',
      description: 'Move-out damage inspection photo uploads and formal caution fee retention claims.',
      impact: 'When OFF, restricts deposit payouts to standard automated refund protocols.',
      icon: ShieldAlert,
      color: 'purple',
      isCaution: false
    },
    {
      key: 'maintenanceMode' as keyof FeatureFlags,
      title: 'System-Wide Maintenance Mode',
      description: 'Displays a maintenance notice banner across mobile and web during major infrastructure upgrades.',
      impact: 'When ON, pauses new financial transactions and prompts users to check back shortly.',
      icon: AlertTriangle,
      color: 'red',
      isCaution: true
    }
  ];

  return (
    <div className="space-y-6 font-sans max-w-4xl">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold text-white flex items-center gap-2">
            <Sliders className="w-6 h-6 text-emerald-400" />
            <span>Remote Feature Flags & Dynamic App Rollout</span>
          </h1>
          <p className="text-xs text-slate-400 mt-0.5">
            Dynamically toggle features ON or OFF in real-time. Changes propagate instantly to mobile apps nationwide without requiring an app store update.
          </p>
        </div>

        <div className="flex items-center gap-2.5">
          <button
            onClick={fetchFlags}
            disabled={loading}
            className="p-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 transition"
            title="Refresh Flags"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
          </button>

          <button
            onClick={handleSave}
            disabled={saving}
            className="flex items-center gap-2 px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold shadow-lg shadow-emerald-900/30 transition transform active:scale-95 disabled:opacity-50"
          >
            <Save className="w-4 h-4" />
            <span>{saving ? 'Publishing...' : 'Save & Publish Live'}</span>
          </button>
        </div>
      </div>

      {statusMessage && (
        <div className={`p-4 rounded-xl text-xs flex items-center gap-2 ${
          statusMessage.type === 'success' 
            ? 'bg-emerald-950/60 border border-emerald-800 text-emerald-300' 
            : 'bg-red-950/60 border border-red-800 text-red-300'
        }`}>
          <CheckCircle2 className="w-4 h-4 shrink-0" />
          <span>{statusMessage.text}</span>
        </div>
      )}

      {/* Card Pricing & Courier Delivery Fees Section */}
      <div className="bg-slate-900/90 border border-slate-800 rounded-2xl p-5 space-y-4">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-sm font-bold text-white flex items-center gap-2">
              <CreditCard className="w-4 h-4 text-emerald-400" />
              <span>Card Issuance & Nationwide Courier Fee Matrix</span>
            </h2>
            <p className="text-xs text-slate-400 mt-0.5">
              Live fees deducted from user wallets upon card creation or physical card courier dispatch.
            </p>
          </div>
          <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-emerald-950 text-emerald-400 border border-emerald-800/50">
            AUTO-SYNCED TO CLIENTS
          </span>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="p-3.5 rounded-xl bg-slate-950/70 border border-slate-800">
            <label className="text-[11px] font-bold text-slate-300 block mb-1">
              Virtual NGN Issuance (₦)
            </label>
            <div className="relative">
              <span className="absolute left-3 top-2 text-xs font-bold text-slate-400">₦</span>
              <input
                type="number"
                value={flags.virtualCardIssuanceFeeNgn || 0}
                onChange={(e) => handleFeeChange('virtualCardIssuanceFeeNgn', e.target.value)}
                className="w-full pl-7 pr-3 py-1.5 rounded-lg bg-slate-900 border border-slate-700 text-white text-xs font-bold focus:outline-none focus:border-emerald-500"
              />
            </div>
            <p className="text-[10px] text-slate-500 mt-1">Default: ₦1,500</p>
          </div>

          <div className="p-3.5 rounded-xl bg-slate-950/70 border border-slate-800">
            <label className="text-[11px] font-bold text-slate-300 block mb-1">
              Physical NGN Card Fee (₦)
            </label>
            <div className="relative">
              <span className="absolute left-3 top-2 text-xs font-bold text-slate-400">₦</span>
              <input
                type="number"
                value={flags.physicalCardIssuanceFeeNgn || 0}
                onChange={(e) => handleFeeChange('physicalCardIssuanceFeeNgn', e.target.value)}
                className="w-full pl-7 pr-3 py-1.5 rounded-lg bg-slate-900 border border-slate-700 text-white text-xs font-bold focus:outline-none focus:border-emerald-500"
              />
            </div>
            <p className="text-[10px] text-slate-500 mt-1">Default: ₦4,500</p>
          </div>

          <div className="p-3.5 rounded-xl bg-slate-950/70 border border-slate-800">
            <label className="text-[11px] font-bold text-slate-300 block mb-1">
              Physical Courier Delivery (₦)
            </label>
            <div className="relative">
              <span className="absolute left-3 top-2 text-xs font-bold text-slate-400">₦</span>
              <input
                type="number"
                value={flags.physicalCardDeliveryFeeNgn || 0}
                onChange={(e) => handleFeeChange('physicalCardDeliveryFeeNgn', e.target.value)}
                className="w-full pl-7 pr-3 py-1.5 rounded-lg bg-slate-900 border border-slate-700 text-white text-xs font-bold focus:outline-none focus:border-emerald-500"
              />
            </div>
            <p className="text-[10px] text-slate-500 mt-1">Default: ₦2,000</p>
          </div>

          <div className="p-3.5 rounded-xl bg-slate-950/70 border border-slate-800">
            <label className="text-[11px] font-bold text-slate-300 block mb-1">
              Virtual USD Issuance ($)
            </label>
            <div className="relative">
              <span className="absolute left-3 top-2 text-xs font-bold text-slate-400">$</span>
              <input
                type="number"
                step="0.5"
                value={flags.virtualCardIssuanceFeeUsd || 0}
                onChange={(e) => handleFeeChange('virtualCardIssuanceFeeUsd', e.target.value)}
                className="w-full pl-7 pr-3 py-1.5 rounded-lg bg-slate-900 border border-slate-700 text-white text-xs font-bold focus:outline-none focus:border-emerald-500"
              />
            </div>
            <p className="text-[10px] text-slate-500 mt-1">Default: $3.00</p>
          </div>
        </div>
      </div>

      {/* Feature Toggles List */}
      <div className="grid grid-cols-1 gap-4">
        {items.map((item) => {
          const isEnabled = flags[item.key] === true;
          const Icon = item.icon;

          return (
            <div
              key={item.key}
              className={`p-5 rounded-2xl border transition ${
                item.isCaution && isEnabled
                  ? 'bg-red-950/30 border-red-800/80 shadow-lg shadow-red-950/20'
                  : isEnabled
                    ? 'bg-slate-900/80 border-slate-800 hover:border-emerald-500/40'
                    : 'bg-slate-950/50 border-slate-900/80 opacity-80'
              }`}
            >
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                <div className="flex items-start gap-3.5">
                  <div className={`p-2.5 rounded-xl border mt-0.5 ${
                    isEnabled
                      ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-400'
                      : 'bg-slate-800 border-slate-700 text-slate-500'
                  }`}>
                    <Icon className="w-5 h-5" />
                  </div>

                  <div className="space-y-1">
                    <div className="flex items-center gap-2 flex-wrap">
                      <h3 className="text-sm font-bold text-white tracking-wide">{item.title}</h3>
                      <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold border ${
                        isEnabled
                          ? 'bg-emerald-950 text-emerald-400 border-emerald-800/50'
                          : 'bg-slate-900 text-slate-400 border-slate-800'
                      }`}>
                        {isEnabled ? (
                          <>
                            <Eye className="w-3 h-3" /> LIVE ON MOBILE
                          </>
                        ) : (
                          <>
                            <EyeOff className="w-3 h-3" /> HIDDEN FROM USERS
                          </>
                        )}
                      </span>
                    </div>

                    <p className="text-xs text-slate-400 leading-relaxed">
                      {item.description}
                    </p>

                    <p className="text-[11px] text-slate-500 italic">
                      {item.impact}
                    </p>
                  </div>
                </div>

                {/* Switch Toggle */}
                <div className="flex items-center self-end sm:self-center">
                  <button
                    type="button"
                    onClick={() => handleToggle(item.key)}
                    className={`relative inline-flex h-7 w-13 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none ${
                      isEnabled ? (item.isCaution ? 'bg-red-600' : 'bg-emerald-500') : 'bg-slate-800'
                    }`}
                  >
                    <span
                      className={`pointer-events-none inline-block h-6 w-6 transform rounded-full bg-white shadow-lg ring-0 transition duration-200 ease-in-out ${
                        isEnabled ? 'translate-x-6' : 'translate-x-0'
                      }`}
                    />
                  </button>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};
