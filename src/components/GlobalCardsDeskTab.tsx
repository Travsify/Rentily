import React, { useState, useEffect } from 'react';
import { 
  CreditCard, 
  Globe, 
  DollarSign, 
  ShieldCheck, 
  Lock, 
  Unlock, 
  Plus, 
  RefreshCw, 
  ArrowRightLeft, 
  Copy, 
  Check, 
  CheckCircle, 
  TrendingUp, 
  Building,
  Eye,
  EyeOff,
  Zap
} from 'lucide-react';

interface VirtualAccount {
  currency: 'NGN' | 'USD' | 'GBP' | 'EUR';
  currencySymbol: string;
  currencyName: string;
  flagEmoji: string;
  balance: number;
  bankName: string;
  accountNumber: string;
  accountName: string;
  routingNumber?: string;
  sortCode?: string;
  iban?: string;
  swiftBic?: string;
  status: string;
  railType: string;
}

interface VirtualCard {
  id: string;
  cardholderName: string;
  email: string;
  currency: 'USD' | 'NGN';
  brand: 'VISA' | 'MASTERCARD';
  cardType: string;
  maskedPan: string;
  fullPan?: string;
  expiryMonth: string;
  expiryYear: string;
  cvv?: string;
  balance: number;
  spendingLimit: number;
  isFrozen: boolean;
  status: string;
  createdAt: string;
}

export const GlobalCardsDeskTab: React.FC = () => {
  const [accounts, setAccounts] = useState<VirtualAccount[]>([]);
  const [cards, setCards] = useState<VirtualCard[]>([]);
  const [selectedCurrency, setSelectedCurrency] = useState<'NGN' | 'USD' | 'GBP' | 'EUR'>('USD');
  const [loading, setLoading] = useState(true);
  const [copiedKey, setCopiedKey] = useState<string | null>(null);
  const [showIssueModal, setShowIssueModal] = useState(false);
  const [showFundModal, setShowFundModal] = useState(false);
  const [showFxModal, setShowFxModal] = useState(false);
  const [showCardPricingModal, setShowCardPricingModal] = useState(false);
  const [fxRates, setFxRates] = useState({ USD_NGN: 1510, GBP_NGN: 1980, EUR_NGN: 1660 });
  const [fxUsd, setFxUsd] = useState('1510');
  const [fxGbp, setFxGbp] = useState('1980');
  const [fxEur, setFxEur] = useState('1660');
  const [spreadBase, setSpreadBase] = useState('1430');
  const [spreadBuyRate, setSpreadBuyRate] = useState('1400');
  const [spreadSellRate, setSpreadSellRate] = useState('1460');
  const [savingFx, setSavingFx] = useState(false);
  const [cardPricing, setCardPricing] = useState({
    issuanceFeeUsd: 3.00,
    fundingFeePercent: 1.5,
    monthlyMaintenanceUsd: 1.00,
    minFundingUsd: 5.00,
    liquidationFeePercent: 1.0,
  });
  const [pricingIssuance, setPricingIssuance] = useState('3.00');
  const [pricingFunding, setPricingFunding] = useState('1.5');
  const [pricingMaintenance, setPricingMaintenance] = useState('1.00');
  const [pricingMinFunding, setPricingMinFunding] = useState('5.00');
  const [pricingLiquidation, setPricingLiquidation] = useState('1.0');
  const [savingCardPricing, setSavingCardPricing] = useState(false);
  const [selectedCardForFund, setSelectedCardForFund] = useState<VirtualCard | null>(null);
  const [fundAmount, setFundAmount] = useState('100');
  const [newCardholder, setNewCardholder] = useState('');
  const [newCardCurrency, setNewCardCurrency] = useState<'USD' | 'NGN'>('USD');
  const [newCardBrand, setNewCardBrand] = useState<'VISA' | 'MASTERCARD'>('VISA');
  const [revealedCardId, setRevealedCardId] = useState<string | null>(null);

  const fetchData = async () => {
    try {
      const [accRes, cardRes, fxRes, pricingRes, spreadRes] = await Promise.all([
        fetch('/api/wallet/multi-currency-accounts?email=tonerocool1@gmail.com'),
        fetch('/api/cards/user-cards?email=tonerocool1@gmail.com'),
        fetch('/api/wallet/fx-rates'),
        fetch('/api/cards/pricing'),
        fetch('/api/fx/spread-rates')
      ]);

      if (accRes.ok) {
        const d = await accRes.json();
        setAccounts(d.data || []);
      }
      if (cardRes.ok) {
        const d = await cardRes.json();
        setCards(d.data || []);
      }
      if (fxRes.ok) {
        const d = await fxRes.json();
        if (d.data) {
          setFxRates(d.data);
          setFxUsd((d.data.USD_NGN || 1510).toString());
          setFxGbp((d.data.GBP_NGN || 1980).toString());
          setFxEur((d.data.EUR_NGN || 1660).toString());
        }
      }
      if (spreadRes.ok) {
        const s = await spreadRes.json();
        if (s.success) {
          setSpreadBase((s.baseRate || 1430).toString());
          setSpreadBuyRate((s.buyRate || 1400).toString());
          setSpreadSellRate((s.sellRate || 1460).toString());
        }
      }
      if (pricingRes.ok) {
        const d = await pricingRes.json();
        if (d.data) {
          setCardPricing(d.data);
          setPricingIssuance((d.data.issuanceFeeUsd ?? 3.00).toString());
          setPricingFunding((d.data.fundingFeePercent ?? 1.5).toString());
          setPricingMaintenance((d.data.monthlyMaintenanceUsd ?? 1.00).toString());
          setPricingMinFunding((d.data.minFundingUsd ?? 5.00).toString());
          setPricingLiquidation((d.data.liquidationFeePercent ?? 1.0).toString());
        }
      }
    } catch (_) {}
    setLoading(false);
  };

  useEffect(() => {
    fetchData();
  }, []);

  const handleSaveFxRates = async (e: React.FormEvent) => {
    e.preventDefault();
    setSavingFx(true);
    try {
      await Promise.all([
        fetch('/api/wallet/fx-rates', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            USD_NGN: Number(fxUsd),
            GBP_NGN: Number(fxGbp),
            EUR_NGN: Number(fxEur)
          })
        }),
        fetch('/api/fx/spread-rates', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            baseRate: Number(spreadBase),
            buyRate: Number(spreadBuyRate),
            sellRate: Number(spreadSellRate)
          })
        })
      ]);

      setShowFxModal(false);
      fetchData();
    } catch (_) {}
    setSavingFx(false);
  };

  const handleSaveCardPricing = async (e: React.FormEvent) => {
    e.preventDefault();
    setSavingCardPricing(true);
    try {
      const res = await fetch('/api/cards/pricing', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          issuanceFeeUsd: Number(pricingIssuance),
          fundingFeePercent: Number(pricingFunding),
          monthlyMaintenanceUsd: Number(pricingMaintenance),
          minFundingUsd: Number(pricingMinFunding),
          liquidationFeePercent: Number(pricingLiquidation),
        })
      });
      if (res.ok) {
        const d = await res.json();
        if (d.data) {
          setCardPricing(d.data);
        }
        setShowCardPricingModal(false);
        fetchData();
      }
    } catch (_) {}
    setSavingCardPricing(false);
  };

  const handleCopy = (text: string, key: string) => {
    navigator.clipboard.writeText(text);
    setCopiedKey(key);
    setTimeout(() => setCopiedKey(null), 2000);
  };

  const handleToggleFreeze = async (cardId: string) => {
    try {
      const res = await fetch('/api/cards/toggle-freeze', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ cardId })
      });
      if (res.ok) {
        fetchData();
      }
    } catch (_) {}
  };

  const handleIssueCard = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const res = await fetch('/api/cards/create', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: 'tonerocool1@gmail.com',
          cardholderName: newCardholder || 'Ehomes Corporate Admin',
          currency: newCardCurrency,
          brand: newCardBrand,
          initialFunding: newCardCurrency === 'USD' ? 250 : 50000
        })
      });
      if (res.ok) {
        setShowIssueModal(false);
        setNewCardholder('');
        fetchData();
      }
    } catch (_) {}
  };

  const handleFundCard = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedCardForFund) return;
    try {
      const res = await fetch('/api/cards/fund', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          cardId: selectedCardForFund.id,
          amount: Number(fundAmount),
          email: 'tonerocool1@gmail.com'
        })
      });
      if (res.ok) {
        setShowFundModal(false);
        setSelectedCardForFund(null);
        fetchData();
      }
    } catch (_) {}
  };

  const activeAccount = accounts.find(a => a.currency === selectedCurrency) || accounts[0];
  const totalUsdLiquidity = cards.reduce((acc, c) => acc + (c.currency === 'USD' ? c.balance : c.balance / 1510), 0);

  return (
    <div className="space-y-6 font-sans">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold text-white flex items-center gap-2">
            <Globe className="w-6 h-6 text-emerald-400" />
            <span>Global Multi-Currency Vault & Virtual Cards</span>
          </h1>
          <p className="text-xs text-slate-400 mt-0.5">
            Dedicated multi-currency collections (USD, GBP, EUR, NGN) via Korapay & programmatic virtual card issuing via Bridgecard.
          </p>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={() => setShowIssueModal(true)}
            className="flex items-center gap-2 px-4 py-2 rounded-xl bg-gradient-to-r from-emerald-600 to-teal-600 text-white text-xs font-semibold hover:from-emerald-500 hover:to-teal-500 transition shadow-lg shadow-emerald-950/40"
          >
            <Plus className="w-4 h-4" />
            <span>Issue Virtual Card</span>
          </button>
          <button
            onClick={fetchData}
            title="Refresh Vault"
            className="p-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-400 hover:text-white transition"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
          </button>
        </div>
      </div>

      {/* Top Metrics Row */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-3.5">
        <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800/80 backdrop-blur-sm">
          <div className="flex items-center justify-between text-slate-400 mb-2">
            <span className="text-xs font-medium">USD Vault Liquidity</span>
            <DollarSign className="w-4 h-4 text-emerald-400" />
          </div>
          <div className="text-2xl font-bold text-white tracking-tight">
            ${(accounts.find(a => a.currency === 'USD')?.balance || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
          </div>
          <span className="text-[10px] text-emerald-400 flex items-center gap-1 mt-1 font-medium">
            <ShieldCheck className="w-3 h-3" /> {accounts.some(a => a.currency === 'USD') ? 'Lead Bank (US) Active' : 'Multi-Currency Vault'}
          </span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800/80 backdrop-blur-sm">
          <div className="flex items-center justify-between text-slate-400 mb-2">
            <span className="text-xs font-medium">Active Virtual Cards</span>
            <CreditCard className="w-4 h-4 text-teal-400" />
          </div>
          <div className="text-2xl font-bold text-white tracking-tight">
            {cards.filter(c => !c.isFrozen).length} Active
          </div>
          <span className="text-[10px] text-slate-400 mt-1 block">
            {cards.length} total cards issued
          </span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800/80 backdrop-blur-sm">
          <div className="flex items-center justify-between text-slate-400 mb-2">
            <span className="text-xs font-medium">Total Card Balance</span>
            <TrendingUp className="w-4 h-4 text-amber-400" />
          </div>
          <div className="text-2xl font-bold text-white tracking-tight">
            ${totalUsdLiquidity.toFixed(2)}
          </div>
          <span className="text-[10px] text-amber-400 mt-1 block font-medium">
            Bridgecard CaaS Connected
          </span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800/80 backdrop-blur-sm relative group">
          <div className="flex items-center justify-between text-slate-400 mb-2">
            <span className="text-xs font-medium">Live FX Benchmark</span>
            <button
              onClick={() => setShowFxModal(true)}
              className="px-2 py-0.5 rounded-lg bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 text-[10px] font-bold transition flex items-center gap-1"
              title="Edit Exchange Rates"
            >
              <span>Edit Rates</span>
            </button>
          </div>
          <div className="text-xl font-bold text-white tracking-tight">
            $1 = ₦{(fxRates.USD_NGN || 1510).toLocaleString()}
          </div>
          <span className="text-[10px] text-slate-400 mt-1 block truncate">
            £1 = ₦{(fxRates.GBP_NGN || 1980).toLocaleString()} | €1 = ₦{(fxRates.EUR_NGN || 1660).toLocaleString()}
          </span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800/80 backdrop-blur-sm relative group">
          <div className="flex items-center justify-between text-slate-400 mb-2">
            <span className="text-xs font-medium">Card Issuance Fee</span>
            <button
              onClick={() => setShowCardPricingModal(true)}
              className="px-2 py-0.5 rounded-lg bg-amber-500/10 hover:bg-amber-500/20 text-amber-400 border border-amber-500/30 text-[10px] font-bold transition flex items-center gap-1"
              title="Edit Card Fees"
            >
              <span>Edit Fees</span>
            </button>
          </div>
          <div className="text-xl font-bold text-amber-400 tracking-tight">
            ${(cardPricing.issuanceFeeUsd ?? 3.00).toFixed(2)}
          </div>
          <span className="text-[10px] text-slate-400 mt-1 block">
            Top-up: {cardPricing.fundingFeePercent ?? 1.5}% | Min: ${cardPricing.minFundingUsd ?? 5.00}
          </span>
        </div>
      </div>

      {/* Multi-Currency Virtual Accounts Section */}
      <div className="p-5 rounded-2xl bg-slate-900/70 border border-slate-800/80">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-4">
          <div>
            <h2 className="text-sm font-bold text-white flex items-center gap-2">
              <Building className="w-4 h-4 text-emerald-400" />
              <span>Dedicated Multi-Currency Virtual Inbound Accounts</span>
            </h2>
            <p className="text-xs text-slate-400 mt-0.5">
              Select a currency to inspect its dedicated domestic banking collection coordinates.
            </p>
          </div>

          {/* Currency Switcher Tabs */}
          <div className="flex items-center bg-slate-950 p-1 rounded-xl border border-slate-800 self-start sm:self-auto">
            {(['USD', 'GBP', 'EUR', 'NGN'] as const).map(curr => {
              const acc = accounts.find(a => a.currency === curr);
              const isSelected = selectedCurrency === curr;
              return (
                <button
                  key={curr}
                  onClick={() => setSelectedCurrency(curr)}
                  className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition ${
                    isSelected 
                      ? 'bg-emerald-600 text-white shadow-md shadow-emerald-950' 
                      : 'text-slate-400 hover:text-white'
                  }`}
                >
                  <span>{acc?.flagEmoji || '🌐'}</span>
                  <span>{curr}</span>
                </button>
              );
            })}
          </div>
        </div>

        {/* Selected Currency Account Detail Card */}
        {activeAccount && (
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 p-4 rounded-xl bg-slate-950/70 border border-slate-800/60">
            <div className="space-y-1 md:col-span-1 border-b md:border-b-0 md:border-r border-slate-800 pb-3 md:pb-0 md:pr-4">
              <span className="text-[10px] font-bold text-emerald-400 uppercase tracking-wider">Vault Currency</span>
              <div className="text-lg font-bold text-white flex items-center gap-2">
                <span>{activeAccount.flagEmoji}</span>
                <span>{activeAccount.currencyName} ({activeAccount.currency})</span>
              </div>
              <div className="text-2xl font-extrabold text-white mt-2">
                {activeAccount.currencySymbol}{activeAccount.balance.toLocaleString('en-US', { minimumFractionDigits: 2 })}
              </div>
              <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-semibold bg-emerald-950 text-emerald-400 border border-emerald-800/50 mt-2">
                <CheckCircle className="w-3 h-3" /> {activeAccount.status}
              </span>
            </div>

            <div className="space-y-2 md:col-span-2 text-xs">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div className="p-2.5 rounded-lg bg-slate-900 border border-slate-800/60">
                  <span className="text-[10px] text-slate-400 block font-medium">Depository Bank Name</span>
                  <span className="font-semibold text-white">{activeAccount.bankName}</span>
                </div>

                <div className="p-2.5 rounded-lg bg-slate-900 border border-slate-800/60 flex items-center justify-between">
                  <div>
                    <span className="text-[10px] text-slate-400 block font-medium">
                      {activeAccount.currency === 'USD' ? 'Account Number' : activeAccount.currency === 'EUR' ? 'IBAN' : 'Account Number'}
                    </span>
                    <span className="font-mono font-bold text-white tracking-wider">
                      {activeAccount.iban || activeAccount.accountNumber}
                    </span>
                  </div>
                  <button
                    onClick={() => handleCopy(activeAccount.iban || activeAccount.accountNumber, 'acc')}
                    className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 transition"
                  >
                    {copiedKey === 'acc' ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
                  </button>
                </div>

                {activeAccount.routingNumber && (
                  <div className="p-2.5 rounded-lg bg-slate-900 border border-slate-800/60 flex items-center justify-between">
                    <div>
                      <span className="text-[10px] text-slate-400 block font-medium">US ACH / Fedwire Routing Number</span>
                      <span className="font-mono font-bold text-white">{activeAccount.routingNumber}</span>
                    </div>
                    <button
                      onClick={() => handleCopy(activeAccount.routingNumber!, 'routing')}
                      className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 transition"
                    >
                      {copiedKey === 'routing' ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
                    </button>
                  </div>
                )}

                {activeAccount.sortCode && (
                  <div className="p-2.5 rounded-lg bg-slate-900 border border-slate-800/60 flex items-center justify-between">
                    <div>
                      <span className="text-[10px] text-slate-400 block font-medium">UK Sort Code</span>
                      <span className="font-mono font-bold text-white">{activeAccount.sortCode}</span>
                    </div>
                    <button
                      onClick={() => handleCopy(activeAccount.sortCode!, 'sort')}
                      className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 transition"
                    >
                      {copiedKey === 'sort' ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
                    </button>
                  </div>
                )}

                <div className="p-2.5 rounded-lg bg-slate-900 border border-slate-800/60 sm:col-span-2">
                  <span className="text-[10px] text-slate-400 block font-medium">Beneficiary / Account Name</span>
                  <span className="font-semibold text-white">{activeAccount.accountName}</span>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Bridgecard Virtual Cards Section */}
      <div className="space-y-4">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-sm font-bold text-white flex items-center gap-2">
              <CreditCard className="w-4 h-4 text-teal-400" />
              <span>Issued Virtual Cards (Bridgecard Infrastructure)</span>
            </h2>
            <p className="text-xs text-slate-400">
              Manage physical & digital card issuing, programmatic spending limits, and security locks.
            </p>
          </div>
        </div>

        {/* Cards Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
          {cards.length === 0 ? (
            <div className="p-8 rounded-2xl bg-slate-900/40 border border-slate-800/80 border-dashed text-center col-span-full space-y-3">
              <div className="w-12 h-12 rounded-2xl bg-slate-800/80 border border-slate-700/50 flex items-center justify-center mx-auto text-slate-400">
                <CreditCard className="w-6 h-6" />
              </div>
              <div>
                <h3 className="text-sm font-bold text-white">No Virtual Cards Issued Yet</h3>
                <p className="text-xs text-slate-400 mt-1 max-w-sm mx-auto">
                  Issue corporate dollar or naira debit cards for rental payments, partner spending, and vendor settlements.
                </p>
              </div>
              <button
                onClick={() => setShowIssueModal(true)}
                className="px-4 py-2 rounded-xl bg-gradient-to-r from-emerald-600 to-teal-600 text-white text-xs font-semibold hover:from-emerald-500 hover:to-teal-500 transition inline-flex items-center gap-2 shadow-lg shadow-emerald-950/40"
              >
                <Plus className="w-4 h-4" />
                <span>Issue First Virtual Card</span>
              </button>
            </div>
          ) : (
            cards.map((card) => {
              const isRevealed = revealedCardId === card.id;
              return (
                <div 
                  key={card.id}
                  className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-slate-900 via-slate-950 to-slate-900 border border-slate-800 shadow-xl p-5 flex flex-col justify-between h-56 transition hover:border-emerald-500/40"
                >
                  {/* Background Accent Gradients */}
                  <div className="absolute top-0 right-0 w-36 h-36 bg-emerald-500/10 rounded-full blur-2xl pointer-events-none" />
                  <div className="absolute bottom-0 left-0 w-36 h-36 bg-teal-500/10 rounded-full blur-2xl pointer-events-none" />

                  {/* Card Top Row */}
                  <div className="flex items-center justify-between relative z-10">
                    <div className="flex items-center gap-2">
                      <span className="text-xs font-black tracking-wider text-emerald-400 uppercase">RENTILLY</span>
                      <span className="text-[10px] px-1.5 py-0.5 rounded bg-slate-800 text-slate-300 font-bold">
                        {card.currency} {card.cardType.replace('_', ' ')}
                      </span>
                    </div>

                    <span className="text-xs font-extrabold text-white tracking-widest">
                      {card.brand}
                    </span>
                  </div>

                  {/* Card Middle (PAN) */}
                  <div className="my-auto relative z-10 space-y-1">
                    <div className="flex items-center justify-between">
                      <span className="font-mono text-sm sm:text-base font-bold text-white tracking-widest">
                        {isRevealed && card.fullPan ? card.fullPan : card.maskedPan}
                      </span>
                      <button
                        onClick={() => setRevealedCardId(isRevealed ? null : card.id)}
                        className="p-1 rounded text-slate-400 hover:text-white transition"
                        title={isRevealed ? 'Hide PAN' : 'Reveal PAN'}
                      >
                        {isRevealed ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
                      </button>
                    </div>
                    <div className="flex items-center gap-4 text-[10px] text-slate-400 font-mono">
                      <span>EXP: {card.expiryMonth}/{card.expiryYear}</span>
                      <span>CVV: {isRevealed && card.cvv ? card.cvv : '•••'}</span>
                    </div>
                  </div>

                  {/* Card Bottom Row */}
                  <div className="flex items-end justify-between relative z-10 pt-2 border-t border-slate-800/80">
                    <div>
                      <span className="text-[9px] text-slate-400 uppercase block font-medium">Cardholder</span>
                      <span className="text-xs font-bold text-white tracking-wide truncate max-w-[140px] block">
                        {card.cardholderName}
                      </span>
                    </div>

                    <div className="text-right">
                      <span className="text-[9px] text-slate-400 uppercase block font-medium">Card Balance</span>
                      <span className="text-sm font-extrabold text-emerald-400">
                        {card.currency === 'USD' ? '$' : '₦'}{card.balance.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                      </span>
                    </div>
                  </div>

                  {/* Quick Action Overlay Bar */}
                  <div className="flex items-center justify-between pt-2 mt-2 border-t border-slate-800/50 text-xs">
                    <button
                      onClick={() => {
                        setSelectedCardForFund(card);
                        setShowFundModal(true);
                      }}
                      className="text-[11px] font-semibold text-emerald-400 hover:text-emerald-300 transition flex items-center gap-1"
                    >
                      <Plus className="w-3 h-3" /> Fund Card
                    </button>

                    <button
                      onClick={() => handleToggleFreeze(card.id)}
                      className={`text-[11px] font-semibold transition flex items-center gap-1 ${
                        card.isFrozen ? 'text-amber-400 hover:text-amber-300' : 'text-slate-400 hover:text-white'
                      }`}
                    >
                      {card.isFrozen ? (
                        <>
                          <Lock className="w-3 h-3" /> Frozen (Unfreeze)
                        </>
                      ) : (
                        <>
                          <Unlock className="w-3 h-3 text-emerald-400" /> Active (Freeze)
                        </>
                      )}
                    </button>
                  </div>
                </div>
              );
            })
          )}
        </div>
      </div>

      {/* Modal: Issue Virtual Card */}
      {showIssueModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl w-full max-w-md p-6 space-y-4 shadow-2xl">
            <h3 className="text-base font-bold text-white flex items-center gap-2">
              <CreditCard className="w-5 h-5 text-emerald-400" />
              <span>Issue New Virtual Card</span>
            </h3>
            <p className="text-xs text-slate-400">
              Instantly provisions an institutional Mastercard or Visa virtual card via the Bridgecard Issuing rail.
            </p>

            <form onSubmit={handleIssueCard} className="space-y-4 text-xs">
              <div>
                <label className="text-slate-300 font-medium block mb-1">Embossed Cardholder Name</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. EHOMES GLOBAL OPERATIONS"
                  value={newCardholder}
                  onChange={(e) => setNewCardholder(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500 font-medium"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-slate-300 font-medium block mb-1">Card Currency</label>
                  <select
                    value={newCardCurrency}
                    onChange={(e: any) => setNewCardCurrency(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500"
                  >
                    <option value="USD">USD ($)</option>
                    <option value="NGN">NGN (₦)</option>
                  </select>
                </div>

                <div>
                  <label className="text-slate-300 font-medium block mb-1">Card Brand</label>
                  <select
                    value={newCardBrand}
                    onChange={(e: any) => setNewCardBrand(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500"
                  >
                    <option value="VISA">VISA</option>
                    <option value="MASTERCARD">Mastercard</option>
                  </select>
                </div>
              </div>

              <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setShowIssueModal(false)}
                  className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 font-semibold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 rounded-xl bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-500 hover:to-teal-500 text-white font-semibold"
                >
                  Issue Card Now
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal: Fund Virtual Card */}
      {showFundModal && selectedCardForFund && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl w-full max-w-sm p-6 space-y-4 shadow-2xl">
            <h3 className="text-base font-bold text-white flex items-center gap-2">
              <DollarSign className="w-5 h-5 text-emerald-400" />
              <span>Fund Virtual Card</span>
            </h3>
            <p className="text-xs text-slate-400">
              Load funds from your Rentilly Vault directly onto card ending in {selectedCardForFund.maskedPan.slice(-4)}.
            </p>

            <form onSubmit={handleFundCard} className="space-y-4 text-xs">
              <div>
                <label className="text-slate-300 font-medium block mb-1">Amount to Load ({selectedCardForFund.currency})</label>
                <input
                  type="number"
                  required
                  min="5"
                  value={fundAmount}
                  onChange={(e) => setFundAmount(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500 text-lg font-bold"
                />
              </div>

              <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setShowFundModal(false)}
                  className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 font-semibold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 rounded-xl bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-500 hover:to-teal-500 text-white font-semibold"
                >
                  Confirm & Fund
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal: Edit Live Currency Exchange Rates */}
      {showFxModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl w-full max-w-md p-6 space-y-4 shadow-2xl">
            <div className="flex items-center justify-between">
              <h3 className="text-base font-bold text-white flex items-center gap-2">
                <ArrowRightLeft className="w-5 h-5 text-emerald-400" />
                <span>Edit Live FX Exchange Rates</span>
              </h3>
              <span className="text-[10px] px-2 py-0.5 rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/30 font-bold">
                Admin Control
              </span>
            </div>
            <p className="text-xs text-slate-400">
              Update platform conversion benchmarks relative to Nigerian Naira (NGN). All multi-currency vault conversions and card limits will instantly recalculate against these rates.
            </p>

            <form onSubmit={handleSaveFxRates} className="space-y-4 text-xs">
              {/* USDT Bid / Ask Spread Engine Section */}
              <div className="p-3.5 rounded-xl bg-slate-950/80 border border-emerald-500/30 space-y-3">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-1.5 text-emerald-400 font-bold text-xs">
                    <Zap className="w-3.5 h-3.5 text-emerald-400" />
                    <span>USDT (TRC20) Spread & Profit Margins</span>
                  </div>
                  <span className="text-[9px] bg-emerald-500/20 text-emerald-300 font-bold px-1.5 py-0.5 rounded">
                    Mobile Swaps & Cashouts
                  </span>
                </div>

                <div className="grid grid-cols-3 gap-2">
                  <div>
                    <label className="text-[10px] text-slate-400 font-medium block mb-1">Market Benchmark</label>
                    <div className="relative">
                      <span className="absolute left-2 top-2 text-slate-500 text-xs">₦</span>
                      <input
                        type="number"
                        step="1"
                        required
                        min="1"
                        value={spreadBase}
                        onChange={(e) => {
                          const val = e.target.value;
                          setSpreadBase(val);
                          const num = Number(val);
                          if (num > 60) {
                            setSpreadBuyRate((num - 30).toString());
                            setSpreadSellRate((num + 30).toString());
                          }
                        }}
                        className="w-full bg-slate-900 border border-slate-700 rounded-lg pl-5 pr-2 py-1.5 text-white font-mono text-xs font-bold focus:outline-none focus:border-emerald-500"
                      />
                    </div>
                  </div>

                  <div>
                    <label className="text-[10px] text-amber-400 font-medium block mb-1">Buy Rate (Cashout)</label>
                    <div className="relative">
                      <span className="absolute left-2 top-2 text-slate-500 text-xs">₦</span>
                      <input
                        type="number"
                        step="1"
                        required
                        min="1"
                        value={spreadBuyRate}
                        onChange={(e) => setSpreadBuyRate(e.target.value)}
                        className="w-full bg-slate-900 border border-slate-700 rounded-lg pl-5 pr-2 py-1.5 text-amber-300 font-mono text-xs font-bold focus:outline-none focus:border-amber-500"
                      />
                    </div>
                  </div>

                  <div>
                    <label className="text-[10px] text-cyan-400 font-medium block mb-1">Sell Rate (Buy USDT)</label>
                    <div className="relative">
                      <span className="absolute left-2 top-2 text-slate-500 text-xs">₦</span>
                      <input
                        type="number"
                        step="1"
                        required
                        min="1"
                        value={spreadSellRate}
                        onChange={(e) => setSpreadSellRate(e.target.value)}
                        className="w-full bg-slate-900 border border-slate-700 rounded-lg pl-5 pr-2 py-1.5 text-cyan-300 font-mono text-xs font-bold focus:outline-none focus:border-cyan-500"
                      />
                    </div>
                  </div>
                </div>

                <div className="p-2 rounded-lg bg-emerald-950/40 border border-emerald-500/20 text-[10px] text-emerald-300 font-mono space-y-0.5">
                  <div className="flex justify-between">
                    <span>• Cashout Margin (User sells USDT):</span>
                    <span className="font-bold text-emerald-400">+₦{(Math.max(0, Number(spreadBase) - Number(spreadBuyRate))).toLocaleString()} / USDT</span>
                  </div>
                  <div className="flex justify-between">
                    <span>• Swap Margin (User buys USDT):</span>
                    <span className="font-bold text-emerald-400">+₦{(Math.max(0, Number(spreadSellRate) - Number(spreadBase))).toLocaleString()} / USDT</span>
                  </div>
                  <div className="text-[9px] text-slate-400 pt-1 font-sans">
                    ⚡ Saving broadcasts live to all mobile apps (Rentals, Landlords, Partners) via Supabase Cloud.
                  </div>
                </div>
              </div>

              <div>
                <label className="text-slate-300 font-medium block mb-1">USD / NGN (Virtual Cards & USD Vault)</label>
                <div className="relative">
                  <span className="absolute left-3 top-2.5 text-slate-500 font-bold">₦</span>
                  <input
                    type="number"
                    step="0.01"
                    required
                    min="1"
                    value={fxUsd}
                    onChange={(e) => setFxUsd(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl pl-8 pr-3 py-2 text-white font-mono font-bold focus:outline-none focus:border-emerald-500 text-sm"
                  />
                </div>
              </div>

              <div>
                <label className="text-slate-300 font-medium block mb-1">GBP / NGN (British Pound Sterling)</label>
                <div className="relative">
                  <span className="absolute left-3 top-2.5 text-slate-500 font-bold">₦</span>
                  <input
                    type="number"
                    step="0.01"
                    required
                    min="1"
                    value={fxGbp}
                    onChange={(e) => setFxGbp(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl pl-8 pr-3 py-2 text-white font-mono font-bold focus:outline-none focus:border-emerald-500 text-sm"
                  />
                </div>
              </div>

              <div>
                <label className="text-slate-300 font-medium block mb-1">EUR / NGN (Euro)</label>
                <div className="relative">
                  <span className="absolute left-3 top-2.5 text-slate-500 font-bold">₦</span>
                  <input
                    type="number"
                    step="0.01"
                    required
                    min="1"
                    value={fxEur}
                    onChange={(e) => setFxEur(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl pl-8 pr-3 py-2 text-white font-mono font-bold focus:outline-none focus:border-emerald-500 text-sm"
                  />
                </div>
              </div>

              <div className="p-3 rounded-xl bg-slate-950 border border-slate-800 space-y-1 text-[11px] text-slate-300 font-mono">
                <div className="text-[10px] text-slate-400 font-bold uppercase tracking-wider mb-1 font-sans">Live Conversion Preview</div>
                <div>• $100.00 = ₦{(Number(fxUsd) * 100).toLocaleString()}</div>
                <div>• 100 USDT (Cashout) = ₦{(Number(spreadBuyRate) * 100).toLocaleString()}</div>
                <div>• 100 USDT (Buy) = ₦{(Number(spreadSellRate) * 100).toLocaleString()}</div>
              </div>

              <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setShowFxModal(false)}
                  className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 font-semibold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={savingFx}
                  className="px-4 py-2 rounded-xl bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-500 hover:to-teal-500 text-white font-semibold flex items-center gap-2 disabled:opacity-50"
                >
                  {savingFx ? <RefreshCw className="w-4 h-4 animate-spin" /> : <Check className="w-4 h-4" />}
                  <span>Save Rates</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Card Pricing & Revenue Configuration Modal */}
      {showCardPricingModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-fadeIn">
          <div className="bg-slate-900 border border-slate-800 rounded-3xl p-6 w-full max-w-md shadow-2xl space-y-4">
            <div className="flex items-center justify-between pb-3 border-b border-slate-800">
              <div className="flex items-center gap-2.5">
                <div className="p-2 rounded-xl bg-amber-500/10 text-amber-400 border border-amber-500/20">
                  <CreditCard className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="text-base font-bold text-white">Card Pricing & Revenue Fees</h3>
                  <p className="text-xs text-slate-400">Configure virtual card issuance, top-up margin & limits</p>
                </div>
              </div>
              <button
                onClick={() => setShowCardPricingModal(false)}
                className="p-1 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleSaveCardPricing} className="space-y-4 text-xs">
              <div>
                <label className="text-slate-300 font-medium block mb-1">
                  Card Issuance Fee (USD)
                  <span className="text-slate-500 font-normal ml-1">(Wholesale: $2.00)</span>
                </label>
                <div className="relative">
                  <span className="absolute left-3 top-2.5 text-slate-500 font-bold">$</span>
                  <input
                    type="number"
                    step="0.10"
                    required
                    min="0"
                    value={pricingIssuance}
                    onChange={(e) => setPricingIssuance(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl pl-8 pr-3 py-2 text-white font-mono font-bold focus:outline-none focus:border-amber-500 text-sm"
                  />
                </div>
                <p className="text-[10px] text-emerald-400 mt-1">
                  Net profit per card: +${(Number(pricingIssuance) - 2.00 > 0 ? Number(pricingIssuance) - 2.00 : 0).toFixed(2)} USD
                </p>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-slate-300 font-medium block mb-1">Top-Up Spread Fee (%)</label>
                  <div className="relative">
                    <input
                      type="number"
                      step="0.1"
                      required
                      min="0"
                      value={pricingFunding}
                      onChange={(e) => setPricingFunding(e.target.value)}
                      className="w-full bg-slate-950 border border-slate-800 rounded-xl pl-3 pr-7 py-2 text-white font-mono font-bold focus:outline-none focus:border-amber-500 text-sm"
                    />
                    <span className="absolute right-3 top-2.5 text-slate-500 font-bold">%</span>
                  </div>
                </div>

                <div>
                  <label className="text-slate-300 font-medium block mb-1">Monthly Maintenance (USD)</label>
                  <div className="relative">
                    <span className="absolute left-3 top-2.5 text-slate-500 font-bold">$</span>
                    <input
                      type="number"
                      step="0.10"
                      required
                      min="0"
                      value={pricingMaintenance}
                      onChange={(e) => setPricingMaintenance(e.target.value)}
                      className="w-full bg-slate-950 border border-slate-800 rounded-xl pl-8 pr-3 py-2 text-white font-mono font-bold focus:outline-none focus:border-amber-500 text-sm"
                    />
                  </div>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-slate-300 font-medium block mb-1">Min Initial Funding (USD)</label>
                  <div className="relative">
                    <span className="absolute left-3 top-2.5 text-slate-500 font-bold">$</span>
                    <input
                      type="number"
                      step="1"
                      required
                      min="0"
                      value={pricingMinFunding}
                      onChange={(e) => setPricingMinFunding(e.target.value)}
                      className="w-full bg-slate-950 border border-slate-800 rounded-xl pl-8 pr-3 py-2 text-white font-mono font-bold focus:outline-none focus:border-amber-500 text-sm"
                    />
                  </div>
                </div>

                <div>
                  <label className="text-slate-300 font-medium block mb-1">Card Unload / Liquidation (%)</label>
                  <div className="relative">
                    <input
                      type="number"
                      step="0.1"
                      required
                      min="0"
                      value={pricingLiquidation}
                      onChange={(e) => setPricingLiquidation(e.target.value)}
                      className="w-full bg-slate-950 border border-slate-800 rounded-xl pl-3 pr-7 py-2 text-white font-mono font-bold focus:outline-none focus:border-amber-500 text-sm"
                    />
                    <span className="absolute right-3 top-2.5 text-slate-500 font-bold">%</span>
                  </div>
                </div>
              </div>

              <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setShowCardPricingModal(false)}
                  className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 font-semibold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={savingCardPricing}
                  className="px-4 py-2 rounded-xl bg-gradient-to-r from-amber-600 to-orange-600 hover:from-amber-500 hover:to-orange-500 text-white font-semibold flex items-center gap-2 disabled:opacity-50"
                >
                  {savingCardPricing ? <RefreshCw className="w-4 h-4 animate-spin" /> : <Check className="w-4 h-4" />}
                  <span>Save Card Pricing</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
