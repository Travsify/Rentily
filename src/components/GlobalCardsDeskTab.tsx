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
  EyeOff
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
  const [selectedCardForFund, setSelectedCardForFund] = useState<VirtualCard | null>(null);
  const [fundAmount, setFundAmount] = useState('100');
  const [newCardholder, setNewCardholder] = useState('');
  const [newCardCurrency, setNewCardCurrency] = useState<'USD' | 'NGN'>('USD');
  const [newCardBrand, setNewCardBrand] = useState<'VISA' | 'MASTERCARD'>('VISA');
  const [revealedCardId, setRevealedCardId] = useState<string | null>(null);

  const fetchData = async () => {
    try {
      const [accRes, cardRes] = await Promise.all([
        fetch('/api/wallet/multi-currency-accounts?email=tonerocool1@gmail.com'),
        fetch('/api/cards/user-cards?email=tonerocool1@gmail.com')
      ]);

      if (accRes.ok) {
        const d = await accRes.json();
        setAccounts(d.data || []);
      }
      if (cardRes.ok) {
        const d = await cardRes.json();
        setCards(d.data || []);
      }
    } catch (_) {}
    setLoading(false);
  };

  useEffect(() => {
    fetchData();
  }, []);

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
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800/80 backdrop-blur-sm">
          <div className="flex items-center justify-between text-slate-400 mb-2">
            <span className="text-xs font-medium">USD Vault Liquidity</span>
            <DollarSign className="w-4 h-4 text-emerald-400" />
          </div>
          <div className="text-2xl font-bold text-white tracking-tight">
            ${accounts.find(a => a.currency === 'USD')?.balance.toLocaleString() || '1,250.00'}
          </div>
          <span className="text-[10px] text-emerald-400 flex items-center gap-1 mt-1 font-medium">
            <ShieldCheck className="w-3 h-3" /> Lead Bank (US) Active
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

        <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800/80 backdrop-blur-sm">
          <div className="flex items-center justify-between text-slate-400 mb-2">
            <span className="text-xs font-medium">Live FX Exchange Benchmark</span>
            <ArrowRightLeft className="w-4 h-4 text-cyan-400" />
          </div>
          <div className="text-xl font-bold text-white tracking-tight">
            $1 = ₦1,510.00
          </div>
          <span className="text-[10px] text-slate-400 mt-1 block">
            £1 = ₦1,980.00 | €1 = ₦1,660.00
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
          {cards.map((card) => {
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
          })}
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
    </div>
  );
};
