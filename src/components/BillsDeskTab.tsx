import React, { useState, useEffect } from 'react';
import { 
  Zap, 
  Search, 
  Copy, 
  Check, 
  Phone, 
  Lightbulb, 
  Smartphone, 
  RefreshCw
} from 'lucide-react';

interface UtilityItem {
  id: string;
  userId?: string;
  email: string;
  title: string;
  type: string;
  amount: number;
  reference: string;
  status: string;
  token?: string;
  units?: string;
  beneficiary?: string;
  date: string;
}

export const BillsDeskTab: React.FC = () => {
  const [items, setItems] = useState<UtilityItem[]>([]);
  const [search, setSearch] = useState('');
  const [filterType, setFilterType] = useState('all');
  const [copiedToken, setCopiedToken] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const fetchData = async () => {
    try {
      const res = await fetch('/api/bills/transactions');
      if (res.ok) {
        const d = await res.json();
        setItems(d.utilities || []);
      }
    } catch (_) {}
    setLoading(false);
  };

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 15000);
    return () => clearInterval(interval);
  }, []);

  const handleCopy = (token: string) => {
    navigator.clipboard.writeText(token);
    setCopiedToken(token);
    setTimeout(() => setCopiedToken(null), 2000);
  };

  const filtered = items.filter((item) => {
    const isPower = item.title.toLowerCase().includes('electricity') || item.type.toLowerCase().includes('electricity');
    const isTelecom = item.title.toLowerCase().includes('airtime') || item.title.toLowerCase().includes('data');

    const matchesType = 
      filterType === 'all' ||
      (filterType === 'power' && isPower) ||
      (filterType === 'telecom' && isTelecom);

    const matchesSearch = 
      item.title.toLowerCase().includes(search.toLowerCase()) ||
      item.reference.toLowerCase().includes(search.toLowerCase()) ||
      (item.token && item.token.includes(search)) ||
      (item.beneficiary && item.beneficiary.includes(search)) ||
      item.email.toLowerCase().includes(search.toLowerCase());

    return matchesType && matchesSearch;
  });

  const totalVolume = items.reduce((acc, i) => acc + Number(i.amount || 0), 0);
  const powerCount = items.filter(i => i.title.toLowerCase().includes('electricity')).length;
  const telecomCount = items.filter(i => i.title.toLowerCase().includes('airtime') || i.title.toLowerCase().includes('data')).length;

  return (
    <div className="space-y-6 font-sans">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold text-white flex items-center gap-2">
            <Zap className="w-6 h-6 text-amber-400" />
            <span>Bills & Utilities Operations Desk</span>
          </h1>
          <p className="text-xs text-slate-400 mt-0.5">
            Monitor EKEDC / IKEDC electricity token issuances, MTN / Airtel / Glo mobile data recharges, and customer tokens.
          </p>
        </div>

        <button
          onClick={fetchData}
          title="Refresh Utilities"
          className="p-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-400 hover:text-white transition self-start sm:self-auto"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
        </button>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Total Bills Volume</span>
          <div className="text-2xl font-bold text-white mt-1">₦{totalVolume.toLocaleString()}</div>
          <span className="text-[10px] text-slate-400">{items.length} total utility recharges</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Electricity Tokens (Disco)</span>
            <Lightbulb className="w-4 h-4 text-amber-400" />
          </div>
          <div className="text-2xl font-bold text-amber-400 mt-1">{powerCount}</div>
          <span className="text-[10px] text-slate-400">IKEDC, EKEDC, AEDC Prepaid Meters</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Mobile Telecom Bundles</span>
            <Smartphone className="w-4 h-4 text-blue-400" />
          </div>
          <div className="text-2xl font-bold text-blue-400 mt-1">{telecomCount}</div>
          <span className="text-[10px] text-slate-400">MTN, Airtel, Glo, 9mobile</span>
        </div>
      </div>

      {/* Filter and Search Bar */}
      <div className="flex flex-col md:flex-row gap-3 items-center justify-between bg-slate-900/60 p-3.5 rounded-2xl border border-slate-800">
        <div className="relative w-full md:w-80">
          <Search className="w-4 h-4 text-slate-500 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by meter no, token, phone, ref..."
            className="w-full pl-9 pr-4 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-200 focus:outline-none focus:border-amber-500"
          />
        </div>

        <div className="flex items-center gap-2 w-full md:w-auto">
          <select
            value={filterType}
            onChange={(e) => setFilterType(e.target.value)}
            className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-300 focus:outline-none focus:border-amber-500"
          >
            <option value="all">All Utility Types</option>
            <option value="power">Electricity Meters (Disco)</option>
            <option value="telecom">Airtime & Mobile Data</option>
          </select>
        </div>
      </div>

      {/* Table */}
      {filtered.length === 0 ? (
        <div className="p-12 text-center rounded-3xl bg-slate-900/40 border border-slate-800/80 space-y-3">
          <div className="w-12 h-12 rounded-2xl bg-slate-800/80 flex items-center justify-center mx-auto text-slate-500">
            <Zap className="w-6 h-6" />
          </div>
          <div className="space-y-1">
            <h3 className="text-sm font-bold text-white">No Utility Transactions Found</h3>
            <p className="text-xs text-slate-400">
              When tenants recharge electricity tokens or buy data bundles, records and tokens will appear here.
            </p>
          </div>
        </div>
      ) : (
        <div className="rounded-2xl bg-slate-900 border border-slate-800 overflow-hidden shadow-sm">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="border-b border-slate-800 text-slate-400 uppercase font-semibold text-[10px] tracking-wider bg-slate-950/40">
                <tr>
                  <th className="py-3.5 px-4 font-semibold">Service & Date</th>
                  <th className="py-3.5 font-semibold">Meter / Phone Target</th>
                  <th className="py-3.5 font-semibold">Generated Token / Units</th>
                  <th className="py-3.5 font-semibold">Amount</th>
                  <th className="py-3.5 font-semibold">User</th>
                  <th className="py-3.5 px-4 font-semibold text-right">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60">
                {filtered.map((item) => (
                  <tr key={item.id} className="hover:bg-slate-850/50 transition">
                    <td className="py-3 px-4">
                      <div className="font-bold text-white flex items-center gap-1.5">
                        {item.title.toLowerCase().includes('electricity') ? (
                          <Lightbulb className="w-3.5 h-3.5 text-amber-400" />
                        ) : (
                          <Phone className="w-3.5 h-3.5 text-blue-400" />
                        )}
                        <span>{item.title}</span>
                      </div>
                      <div className="text-[10px] text-slate-500 font-mono">
                        {new Date(item.date).toLocaleString()}
                      </div>
                    </td>
                    <td className="py-3 font-mono text-[11px] text-slate-300">
                      {item.beneficiary || 'N/A'}
                    </td>
                    <td className="py-3">
                      {item.token ? (
                        <div className="flex items-center gap-2">
                          <span className="font-mono text-amber-300 bg-amber-950/60 px-2 py-0.5 rounded border border-amber-800/60 font-bold">
                            {item.token}
                          </span>
                          <button
                            onClick={() => handleCopy(item.token!)}
                            title="Copy Token"
                            className="p-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-400 hover:text-white transition"
                          >
                            {copiedToken === item.token ? <Check className="w-3 h-3 text-emerald-400" /> : <Copy className="w-3 h-3" />}
                          </button>
                        </div>
                      ) : (
                        <span className="text-slate-500 text-[10px] italic">Instant Direct Top-Up</span>
                      )}
                      {item.units && (
                        <div className="text-[10px] text-slate-400 mt-0.5">Units: {item.units} kWh</div>
                      )}
                    </td>
                    <td className="py-3 font-mono font-bold text-white">
                      ₦{Number(item.amount || 0).toLocaleString()}
                    </td>
                    <td className="py-3 text-[11px] text-slate-400">
                      {item.email}
                    </td>
                    <td className="py-3 px-4 text-right">
                      <span className="px-2 py-0.5 rounded-full text-[10px] font-bold uppercase bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                        {item.status}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
};
