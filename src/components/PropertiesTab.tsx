import React, { useState } from 'react';
import { 
  Building2, 
  Search, 
  Plus, 
  Clock, 
  MapPin, 
  Bed, 
  Bath, 
  ShieldCheck,
  Calendar
} from 'lucide-react';
import type { Property, AdminTab } from '../types';

interface PropertiesTabProps {
  properties: Property[];
  onOpenAddModal: () => void;
  onSelectPropertyForInspection?: (property: Property) => void;
  setCurrentTab: (tab: AdminTab) => void;
}

export const PropertiesTab: React.FC<PropertiesTabProps> = ({
  properties,
  onOpenAddModal,
  onSelectPropertyForInspection,
  setCurrentTab
}) => {
  const [filterPurpose, setFilterPurpose] = useState<string>('all');
  const [filterStatus, setFilterStatus] = useState<string>('all');
  const [searchQuery, setSearchQuery] = useState<string>('');

  const filtered = properties.filter((p) => {
    const matchesPurpose = filterPurpose === 'all' ? true : p.purpose === filterPurpose;
    const matchesStatus = filterStatus === 'all' ? true : p.status === filterStatus;
    const matchesSearch = 
      p.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
      p.neighborhood.toLowerCase().includes(searchQuery.toLowerCase()) ||
      p.ownerName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      p.state.toLowerCase().includes(searchQuery.toLowerCase());
    return matchesPurpose && matchesStatus && matchesSearch;
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold text-white flex items-center gap-2">
            <Building2 className="w-6 h-6 text-emerald-400" />
            <span>Direct Property Registry</span>
          </h1>
          <p className="text-xs text-slate-400 mt-0.5">
            Manage vetted, verified listings direct from direct property owners (Zero middleman agents).
          </p>
        </div>

        <button
          onClick={onOpenAddModal}
          className="flex items-center gap-2 px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold shadow-lg shadow-emerald-900/30 transition transform active:scale-95 self-start sm:self-auto"
        >
          <Plus className="w-4 h-4" />
          <span>Add Direct Owner Property</span>
        </button>
      </div>

      {/* Filter & Search */}
      <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col md:flex-row items-center justify-between gap-3">
        <div className="relative w-full md:w-96">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search by neighborhood, title, owner, or state..."
            className="w-full pl-10 pr-4 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-200 focus:outline-none focus:border-emerald-500"
          />
        </div>

        <div className="flex flex-wrap items-center gap-2 w-full md:w-auto">
          {/* Purpose Filter */}
          <div className="flex items-center gap-1 bg-slate-950 p-1 rounded-xl border border-slate-800 text-xs">
            {['all', 'rent', 'sale'].map((pur) => (
              <button
                key={pur}
                onClick={() => setFilterPurpose(pur)}
                className={`px-3 py-1 rounded-lg font-medium capitalize transition ${
                  filterPurpose === pur
                    ? 'bg-emerald-600 text-white font-semibold shadow-sm'
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                {pur === 'all' ? 'All Types' : pur === 'rent' ? 'For Rent' : 'For Sale'}
              </button>
            ))}
          </div>

          {/* Status Filter */}
          <div className="flex items-center gap-1 bg-slate-950 p-1 rounded-xl border border-slate-800 text-xs">
            {['all', 'verified', 'pending_kyp', 'rented', 'sold'].map((st) => (
              <button
                key={st}
                onClick={() => setFilterStatus(st)}
                className={`px-2.5 py-1 rounded-lg font-medium capitalize transition ${
                  filterStatus === st
                    ? 'bg-slate-800 text-emerald-400 font-semibold'
                    : 'text-slate-500 hover:text-slate-300'
                }`}
              >
                {st.replace(/_/g, ' ')}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Property Cards Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
        {filtered.map((prop) => {
          const isVerified = prop.status === 'verified';
          const isPending = prop.status === 'pending_kyp';
          const isRented = prop.status === 'rented' || prop.status === 'sold';

          return (
            <div
              key={prop.id}
              className="rounded-2xl bg-slate-900 border border-slate-800 hover:border-slate-700 transition overflow-hidden flex flex-col justify-between group shadow-lg"
            >
              <div>
                {/* Image & Badges */}
                <div className="relative h-48 bg-slate-950 overflow-hidden">
                  <img
                    src={prop.images[0] || 'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?auto=format&fit=crop&w=800&q=80'}
                    alt={prop.title}
                    className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                  />
                  <div className="absolute inset-0 bg-gradient-to-t from-slate-950 via-transparent to-transparent opacity-80" />

                  {/* Top Badges */}
                  <div className="absolute top-3 left-3 flex items-center gap-2">
                    <span className="px-2.5 py-1 rounded-lg bg-slate-950/80 backdrop-blur text-white text-[11px] font-bold uppercase tracking-wider border border-slate-700">
                      {prop.purpose === 'rent' ? 'For Rent' : 'For Sale'}
                    </span>
                    {isVerified && (
                      <span className="px-2.5 py-1 rounded-lg bg-emerald-600/90 text-white text-[11px] font-bold flex items-center gap-1 shadow-md">
                        <ShieldCheck className="w-3.5 h-3.5" />
                        <span>KYP Verified</span>
                      </span>
                    )}
                    {isPending && (
                      <span className="px-2.5 py-1 rounded-lg bg-amber-500/90 text-slate-950 text-[11px] font-bold flex items-center gap-1 shadow-md">
                        <Clock className="w-3.5 h-3.5" />
                        <span>KYP Pending</span>
                      </span>
                    )}
                    {isRented && (
                      <span className="px-2.5 py-1 rounded-lg bg-blue-600/90 text-white text-[11px] font-bold">
                        {prop.status.toUpperCase()}
                      </span>
                    )}
                  </div>

                  {/* Bottom Price in Image */}
                  <div className="absolute bottom-3 left-3 right-3 flex items-center justify-between text-white">
                    <div>
                      <span className="text-lg font-extrabold text-white">
                        ₦{prop.basePrice.toLocaleString()}
                      </span>
                      <span className="text-xs text-slate-300 font-medium">
                        {prop.purpose === 'rent' ? ' / yr' : ' outright'}
                      </span>
                    </div>
                  </div>
                </div>

                {/* Content */}
                <div className="p-4 space-y-3 text-xs">
                  <div>
                    <h3 className="font-bold text-sm text-white line-clamp-1">{prop.title}</h3>
                    <p className="text-slate-400 flex items-center gap-1 mt-1">
                      <MapPin className="w-3.5 h-3.5 text-emerald-400 shrink-0" />
                      <span>{prop.neighborhood}, {prop.state}</span>
                    </p>
                  </div>

                  {/* Specs */}
                  <div className="flex items-center gap-4 text-slate-300 py-1.5 border-y border-slate-800/80">
                    <span className="flex items-center gap-1">
                      <Bed className="w-4 h-4 text-emerald-400" />
                      <span>{prop.bedrooms} Beds</span>
                    </span>
                    <span className="flex items-center gap-1">
                      <Bath className="w-4 h-4 text-emerald-400" />
                      <span>{prop.bathrooms} Baths</span>
                    </span>
                    <span className="capitalize text-slate-400">{prop.furnishing}</span>
                  </div>

                  {/* Anti-Agent Transparent Fee Breakdown */}
                  <div className="p-3 rounded-xl bg-slate-950/80 border border-slate-800/80 space-y-1 text-[11px]">
                    <div className="flex justify-between text-slate-400">
                      <span>Base {prop.purpose === 'rent' ? 'Rent' : 'Price'}:</span>
                      <span className="font-semibold text-slate-200">₦{prop.basePrice.toLocaleString()}</span>
                    </div>
                    {prop.cautionFee > 0 && (
                      <div className="flex justify-between text-slate-400">
                        <span>Caution Fee (Escrowed):</span>
                        <span className="font-semibold text-slate-200">₦{prop.cautionFee.toLocaleString()}</span>
                      </div>
                    )}
                    <div className="flex justify-between text-emerald-400 font-bold">
                      <span>Rentilly Legal Fee ({prop.purpose === 'rent' ? '10%' : '5%'}):</span>
                      <span>₦{prop.rentillyFee.toLocaleString()}</span>
                    </div>
                    <div className="flex justify-between pt-1 border-t border-slate-800 font-bold text-white">
                      <span>Total Initial Payment:</span>
                      <span className="text-emerald-400">₦{prop.totalInitialPayment.toLocaleString()}</span>
                    </div>
                  </div>

                  <p className="text-[11px] text-slate-400">
                    Owner: <span className="text-slate-200 font-medium">{prop.ownerName}</span> ({prop.ownerPhone})
                  </p>
                </div>
              </div>

              {/* Card Footer Actions */}
              <div className="p-4 pt-0 flex items-center gap-2">
                <button
                  onClick={() => {
                    if (onSelectPropertyForInspection) onSelectPropertyForInspection(prop);
                    setCurrentTab('inspections');
                  }}
                  className="flex-1 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold transition flex items-center justify-center gap-1.5"
                >
                  <Calendar className="w-3.5 h-3.5 text-emerald-400" />
                  <span>Book Inspection</span>
                </button>

                {isPending && (
                  <button
                    onClick={() => setCurrentTab('kyp')}
                    className="py-2 px-3 rounded-xl bg-amber-500/20 hover:bg-amber-500/30 text-amber-300 border border-amber-500/40 text-xs font-bold transition"
                  >
                    Audit KYP
                  </button>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};
