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
          <span>Add Direct Listing</span>
        </button>
      </div>

      {/* Filter & Search Bar */}
      <div className="flex flex-col md:flex-row gap-3 items-center justify-between bg-slate-900/60 p-3.5 rounded-2xl border border-slate-800">
        {/* Search */}
        <div className="relative w-full md:w-80">
          <Search className="w-4 h-4 text-slate-500 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search by title, location, or owner..."
            className="w-full pl-9 pr-4 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-200 focus:outline-none focus:border-emerald-500"
          />
        </div>

        {/* Filter Badges */}
        <div className="flex items-center gap-2 overflow-x-auto w-full md:w-auto">
          {/* Purpose Filter */}
          <div className="flex items-center bg-slate-950 p-1 rounded-xl border border-slate-800 text-xs">
            <button
              onClick={() => setFilterPurpose('all')}
              className={`px-3 py-1 rounded-lg font-medium transition ${
                filterPurpose === 'all' ? 'bg-emerald-600 text-white shadow-sm' : 'text-slate-400 hover:text-white'
              }`}
            >
              All
            </button>
            <button
              onClick={() => setFilterPurpose('rent')}
              className={`px-3 py-1 rounded-lg font-medium transition ${
                filterPurpose === 'rent' ? 'bg-emerald-600 text-white shadow-sm' : 'text-slate-400 hover:text-white'
              }`}
            >
              For Rent
            </button>
            <button
              onClick={() => setFilterPurpose('sale')}
              className={`px-3 py-1 rounded-lg font-medium transition ${
                filterPurpose === 'sale' ? 'bg-emerald-600 text-white shadow-sm' : 'text-slate-400 hover:text-white'
              }`}
            >
              For Sale
            </button>
          </div>

          {/* Status Filter */}
          <select
            value={filterStatus}
            onChange={(e) => setFilterStatus(e.target.value)}
            className="px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-300 focus:outline-none focus:border-emerald-500"
          >
            <option value="all">All Verification Status</option>
            <option value="verified">Verified (Active)</option>
            <option value="pending_kyp">Pending KYP Audit</option>
            <option value="rented">Rented (Delisted)</option>
            <option value="sold">Sold (Delisted)</option>
            <option value="rejected">Rejected</option>
          </select>
        </div>
      </div>

      {/* Properties Grid or Empty State */}
      {filtered.length === 0 ? (
        <div className="p-12 text-center rounded-3xl bg-slate-900/40 border border-slate-800/80 space-y-4">
          <div className="w-14 h-14 rounded-2xl bg-slate-800/80 flex items-center justify-center mx-auto text-slate-500">
            <Building2 className="w-7 h-7" />
          </div>
          <div className="space-y-1 max-w-sm mx-auto">
            <h3 className="text-base font-bold text-white">No Properties Found</h3>
            <p className="text-xs text-slate-400">
              {searchQuery || filterPurpose !== 'all' || filterStatus !== 'all'
                ? 'Try adjusting your search query or filters.'
                : 'Direct property listings created by owners or legal admins will appear here.'}
            </p>
          </div>
          <button
            onClick={onOpenAddModal}
            className="px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold shadow-lg shadow-emerald-950/50 transition inline-flex items-center gap-1.5"
          >
            <Plus className="w-3.5 h-3.5" />
            <span>Add First Direct Listing</span>
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
          {filtered.map((prop) => {
            const isVerified = prop.status === 'verified';
            const isPending = prop.status === 'pending_kyp';
            const isDelisted = prop.status === 'rented' || prop.status === 'sold';

            return (
              <div
                key={prop.id}
                className="rounded-2xl bg-slate-900 border border-slate-800 overflow-hidden shadow-sm hover:border-slate-700 transition flex flex-col justify-between"
              >
                {/* Property Image & Status Badges */}
                <div className="relative h-44 w-full bg-slate-950 overflow-hidden group">
                  <img
                    src={prop.images[0] || 'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?auto=format&fit=crop&w=800&q=80'}
                    alt={prop.title}
                    className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                  />
                  <div className="absolute inset-0 bg-gradient-to-t from-slate-950/80 via-transparent to-transparent" />

                  {/* Top Badges */}
                  <div className="absolute top-3 left-3 flex items-center gap-1.5">
                    <span
                      className={`text-[10px] uppercase font-bold tracking-wider px-2.5 py-1 rounded-full backdrop-blur-md shadow-sm ${
                        prop.purpose === 'rent'
                          ? 'bg-emerald-500/90 text-white'
                          : 'bg-teal-500/90 text-white'
                      }`}
                    >
                      {prop.purpose === 'rent' ? 'For Rent' : 'For Sale'}
                    </span>

                    <span className="text-[10px] font-semibold px-2.5 py-1 rounded-full bg-slate-900/80 backdrop-blur-md text-slate-300 border border-slate-700/60">
                      {prop.propertyType.replace('_', ' ')}
                    </span>
                  </div>

                  {/* Right Status Badge */}
                  <div className="absolute top-3 right-3">
                    {isVerified && (
                      <span className="flex items-center gap-1 text-[10px] font-bold px-2 py-1 rounded-full bg-emerald-500/90 text-white shadow-md">
                        <ShieldCheck className="w-3 h-3" />
                        <span>KYP Verified</span>
                      </span>
                    )}
                    {isPending && (
                      <span className="flex items-center gap-1 text-[10px] font-bold px-2 py-1 rounded-full bg-amber-500/90 text-slate-950 shadow-md animate-pulse">
                        <Clock className="w-3 h-3" />
                        <span>Pending KYP</span>
                      </span>
                    )}
                    {isDelisted && (
                      <span className="text-[10px] font-bold px-2 py-1 rounded-full bg-red-500/90 text-white shadow-md">
                        {prop.status === 'rented' ? 'Rented & Delisted' : 'Sold & Delisted'}
                      </span>
                    )}
                  </div>

                  {/* Bottom Price Pill */}
                  <div className="absolute bottom-3 left-3 right-3 flex items-end justify-between">
                    <div>
                      <span className="text-xs text-slate-300 block">Direct Owner Price:</span>
                      <span className="text-lg font-extrabold text-white">
                        ₦{prop.basePrice.toLocaleString()}
                        {prop.purpose === 'rent' && <span className="text-xs font-normal text-slate-300"> /yr</span>}
                      </span>
                    </div>
                  </div>
                </div>

                {/* Property Details */}
                <div className="p-4 space-y-3 flex-1 flex flex-col justify-between">
                  <div>
                    <h3 className="text-sm font-bold text-white line-clamp-1 hover:text-emerald-400 transition cursor-pointer">
                      {prop.title}
                    </h3>
                    <p className="text-xs text-slate-400 flex items-center gap-1 mt-1">
                      <MapPin className="w-3.5 h-3.5 text-slate-500 shrink-0" />
                      <span className="truncate">{prop.neighborhood}, {prop.state}</span>
                    </p>
                  </div>

                  {/* Bed/Bath Specs */}
                  <div className="flex items-center gap-4 text-xs text-slate-300 py-2 border-y border-slate-800/80">
                    <div className="flex items-center gap-1.5">
                      <Bed className="w-4 h-4 text-emerald-400" />
                      <span>{prop.bedrooms} Beds</span>
                    </div>
                    <div className="flex items-center gap-1.5">
                      <Bath className="w-4 h-4 text-teal-400" />
                      <span>{prop.bathrooms} Baths</span>
                    </div>
                  </div>

                  {/* Pricing Breakdown Card */}
                  <div className="p-3 rounded-xl bg-slate-950/80 border border-slate-800 text-xs space-y-1.5">
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
                    Owner: <span className="text-slate-200 font-medium">{prop.ownerName}</span> ({prop.ownerPhone || 'Direct Landlord'})
                  </p>
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
      )}
    </div>
  );
};
