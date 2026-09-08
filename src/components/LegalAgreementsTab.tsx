import React, { useState, useEffect } from 'react';
import { 
  FileText, 
  CheckCircle, 
  Stamp, 
  ShieldCheck, 
  Printer,
  Truck,
  Globe,
  Package,
  ExternalLink,
  Plus,
  Search,
  Clock,
  Send,
  X
} from 'lucide-react';
import type { LegalAgreement, LegalDispatch } from '../types';

interface LegalAgreementsTabProps {
  agreements: LegalAgreement[];
}

export const LegalAgreementsTab: React.FC<LegalAgreementsTabProps> = ({ agreements }) => {
  const [activeSubTab, setActiveSubTab] = useState<'contracts' | 'dispatches'>('contracts');
  const [selectedAgreement, setSelectedAgreement] = useState<LegalAgreement>(agreements[0]);
  
  // Courier Dispatches state
  const [dispatches, setDispatches] = useState<LegalDispatch[]>([]);
  const [isLoadingDispatches, setIsLoadingDispatches] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingDispatch, setEditingDispatch] = useState<LegalDispatch | null>(null);

  // Form state
  const [formData, setFormData] = useState({
    id: '',
    agreementId: '',
    propertyTitle: '',
    propertyAddress: '',
    recipientName: '',
    recipientEmail: '',
    recipientPhone: '',
    deliveryAddress: '',
    deliveryCity: '',
    deliveryState: 'Lagos',
    deliveryCountry: 'Nigeria',
    isDiaspora: false,
    docusignStatus: 'not_applicable' as 'not_applicable' | 'sent' | 'signed' | 'completed',
    docusignEnvelopeUrl: '',
    courierPartner: 'GIG Logistics' as 'DHL Express' | 'FedEx' | 'GIG Logistics' | 'Red Star Express' | 'UPS' | 'Internal Dispatch',
    waybillNumber: '',
    status: 'drafting' as 'drafting' | 'docusign_pending' | 'signed' | 'stamped_and_sealed' | 'dispatched' | 'in_transit' | 'delivered',
    estimatedDeliveryDate: '2-3 Business Days',
    notes: '',
  });

  const loadDispatches = async () => {
    setIsLoadingDispatches(true);
    try {
      const res = await fetch('/api/legal/dispatches');
      if (res.ok) {
        const data = await res.json();
        setDispatches(data);
      }
    } catch (_) {}
    setIsLoadingDispatches(false);
  };

  useEffect(() => {
    loadDispatches();
  }, []);

  const handlePrint = () => {
    window.print();
  };

  const openNewDispatchModal = (agr?: LegalAgreement) => {
    setEditingDispatch(null);
    setFormData({
      id: '',
      agreementId: agr?.id || (agreements[0]?.id ?? 'legal_01'),
      propertyTitle: agr?.propertyTitle || (agreements[0]?.propertyTitle ?? ''),
      propertyAddress: agr?.propertyAddress || '',
      recipientName: agr?.tenantName || '',
      recipientEmail: '',
      recipientPhone: '',
      deliveryAddress: '',
      deliveryCity: 'Lagos',
      deliveryState: agr?.propertyState || 'Lagos',
      deliveryCountry: 'Nigeria',
      isDiaspora: false,
      docusignStatus: 'not_applicable',
      docusignEnvelopeUrl: '',
      courierPartner: 'GIG Logistics',
      waybillNumber: '',
      status: 'drafting',
      estimatedDeliveryDate: '2-3 Business Days',
      notes: 'Physical hard copy deed/tenancy agreement with corporate seal.',
    });
    setIsModalOpen(true);
  };

  const openEditModal = (dsp: LegalDispatch) => {
    setEditingDispatch(dsp);
    setFormData({
      id: dsp.id,
      agreementId: dsp.agreementId,
      propertyTitle: dsp.propertyTitle,
      propertyAddress: dsp.propertyAddress,
      recipientName: dsp.recipientName,
      recipientEmail: dsp.recipientEmail,
      recipientPhone: dsp.recipientPhone,
      deliveryAddress: dsp.deliveryAddress,
      deliveryCity: dsp.deliveryCity,
      deliveryState: dsp.deliveryState,
      deliveryCountry: dsp.deliveryCountry,
      isDiaspora: dsp.isDiaspora,
      docusignStatus: dsp.docusignStatus,
      docusignEnvelopeUrl: dsp.docusignEnvelopeUrl || '',
      courierPartner: dsp.courierPartner,
      waybillNumber: dsp.waybillNumber,
      status: dsp.status,
      estimatedDeliveryDate: dsp.estimatedDeliveryDate,
      notes: dsp.notes || '',
    });
    setIsModalOpen(true);
  };

  const handleCountryChange = (country: string) => {
    const isDiaspora = country.trim().toLowerCase() !== 'nigeria';
    setFormData(prev => ({
      ...prev,
      deliveryCountry: country,
      isDiaspora,
      courierPartner: isDiaspora ? 'DHL Express' : 'GIG Logistics',
      estimatedDeliveryDate: isDiaspora ? '3-5 Business Days' : '2-3 Business Days',
      docusignStatus: isDiaspora && prev.docusignStatus === 'not_applicable' ? 'sent' : prev.docusignStatus,
    }));
  };

  const handleSaveDispatch = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const res = await fetch('/api/legal/dispatches', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData),
      });
      if (res.ok) {
        setIsModalOpen(false);
        loadDispatches();
      }
    } catch (_) {}
  };

  // Metrics
  const totalDispatches = dispatches.length;
  const inTransitCount = dispatches.filter(d => d.status === 'in_transit' || d.status === 'dispatched').length;
  const diasporaCount = dispatches.filter(d => d.isDiaspora).length;
  const deliveredCount = dispatches.filter(d => d.status === 'delivered').length;

  const filteredDispatches = dispatches.filter(d => {
    const q = searchQuery.toLowerCase();
    return (
      (d.recipientName || '').toLowerCase().includes(q) ||
      (d.recipientEmail || '').toLowerCase().includes(q) ||
      (d.waybillNumber || '').toLowerCase().includes(q) ||
      (d.propertyTitle || '').toLowerCase().includes(q) ||
      (d.deliveryCity || '').toLowerCase().includes(q) ||
      (d.deliveryCountry || '').toLowerCase().includes(q)
    );
  });

  return (
    <div className="space-y-6">
      {/* Header & Sub-Tab Navigation */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold text-white flex items-center gap-2">
            <FileText className="w-6 h-6 text-emerald-400" />
            <span>Nigerian Legal Agreement Engine & Conveyance Hub</span>
          </h1>
          <p className="text-xs text-slate-400 mt-0.5">
            Automated legal contracts, DocuSign digital envelopes, and hard copy logistics dispatch across Nigeria & Diaspora.
          </p>
        </div>

        <div className="flex items-center gap-2 self-start sm:self-auto">
          {activeSubTab === 'contracts' ? (
            <button
              onClick={handlePrint}
              className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-bold transition flex items-center gap-2 border border-slate-700"
            >
              <Printer className="w-4 h-4 text-emerald-400" />
              <span>Print Legal PDF</span>
            </button>
          ) : (
            <button
              onClick={() => openNewDispatchModal()}
              className="px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold transition flex items-center gap-2 shadow-lg shadow-emerald-900/30"
            >
              <Plus className="w-4 h-4" />
              <span>Log New Physical Dispatch</span>
            </button>
          )}
        </div>
      </div>

      {/* Sub Tab Buttons */}
      <div className="flex border-b border-slate-800 gap-6">
        <button
          onClick={() => setActiveSubTab('contracts')}
          className={`pb-3 text-xs font-bold transition border-b-2 flex items-center gap-2 ${
            activeSubTab === 'contracts'
              ? 'border-emerald-500 text-emerald-400'
              : 'border-transparent text-slate-400 hover:text-slate-200'
          }`}
        >
          <FileText className="w-4 h-4" />
          <span>Executed Contracts & Deeds ({agreements.length})</span>
        </button>

        <button
          onClick={() => setActiveSubTab('dispatches')}
          className={`pb-3 text-xs font-bold transition border-b-2 flex items-center gap-2 ${
            activeSubTab === 'dispatches'
              ? 'border-emerald-500 text-emerald-400'
              : 'border-transparent text-slate-400 hover:text-slate-200'
          }`}
        >
          <Truck className="w-4 h-4" />
          <span>Physical & DocuSign Courier Desk ({dispatches.length})</span>
        </button>
      </div>

      {/* VIEW 1: CONTRACTS & PDF VIEWER */}
      {activeSubTab === 'contracts' && (
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
          {/* Left List (4 cols) */}
          <div className="lg:col-span-4 space-y-3">
            <h2 className="text-xs font-bold uppercase tracking-wider text-slate-400">
              Executed Agreements ({agreements.length})
            </h2>

            <div className="space-y-3">
              {agreements.map((agr) => {
                const isSelected = selectedAgreement?.id === agr.id;
                return (
                  <div
                    key={agr.id}
                    onClick={() => setSelectedAgreement(agr)}
                    className={`p-4 rounded-2xl cursor-pointer border transition ${
                      isSelected
                        ? 'bg-slate-850 border-emerald-500 ring-1 ring-emerald-500/30'
                        : 'bg-slate-900 border-slate-800 hover:border-slate-700'
                    }`}
                  >
                    <span className="text-[10px] font-mono uppercase text-slate-500">{agr.id}</span>
                    <h3 className="font-bold text-sm text-white mt-0.5">{agr.propertyTitle}</h3>
                    <div className="text-xs text-slate-400 mt-2 space-y-0.5">
                      <p>Tenant: <span className="text-slate-200">{agr.tenantName}</span></p>
                      <p>Landlord: <span className="text-slate-200">{agr.landlordName}</span></p>
                      <p className="text-emerald-400 font-semibold mt-1">₦{agr.annualRent.toLocaleString()} / year</p>
                    </div>

                    <div className="mt-3 pt-2.5 border-t border-slate-800 flex items-center justify-between text-[11px]">
                      <span className="flex items-center gap-1 text-emerald-400 font-bold">
                        <CheckCircle className="w-3.5 h-3.5" />
                        <span>Digitally Signed</span>
                      </span>
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          openNewDispatchModal(agr);
                        }}
                        className="text-xs text-emerald-400 hover:text-emerald-300 font-bold flex items-center gap-1"
                      >
                        <Truck className="w-3 h-3" />
                        <span>Dispatch Dossier</span>
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Right Contract Preview (8 cols) */}
          <div className="lg:col-span-8">
            {selectedAgreement ? (
              <div className="p-8 rounded-2xl bg-white text-slate-900 border border-slate-300 shadow-2xl space-y-6 print:p-0 print:border-none print:shadow-none font-serif">
                {/* Official Header */}
                <div className="text-center pb-6 border-b-2 border-slate-900 space-y-1">
                  <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded bg-slate-100 border border-slate-300 text-[11px] font-sans font-bold uppercase tracking-wider text-slate-700 mb-2">
                    <ShieldCheck className="w-4 h-4 text-emerald-700" />
                    <span>Rentilly Legal Protection Document</span>
                  </div>
                  <h1 className="text-xl font-bold uppercase tracking-wide">
                    Standard Residential Tenancy Agreement
                  </h1>
                  <p className="text-xs text-slate-600 font-sans">
                    Pursuant to the {selectedAgreement.governingLaw}
                  </p>
                </div>

                {/* Parties */}
                <div className="space-y-3 text-xs leading-relaxed">
                  <p>
                    <strong>THIS TENANCY AGREEMENT</strong> is made this <strong>15th day of September, 2026</strong>.
                  </p>
                  <div className="p-3 bg-slate-50 rounded border border-slate-200 space-y-1 font-sans text-xs">
                    <p><strong>BETWEEN:</strong></p>
                    <p><strong>LANDLORD:</strong> {selectedAgreement.landlordName} (hereinafter referred to as the <em>"Landlord"</em>, which expression shall where the context so admits include his heirs, executors, and assigns).</p>
                    <p className="pt-1"><strong>AND</strong></p>
                    <p><strong>TENANT:</strong> {selectedAgreement.tenantName} (hereinafter referred to as the <em>"Tenant"</em>, which expression shall where the context so admits include his successors-in-title).</p>
                  </div>
                </div>

                {/* Terms & Demise */}
                <div className="space-y-2 text-xs leading-relaxed">
                  <h3 className="font-bold uppercase tracking-wider text-slate-900 text-sm font-sans border-b border-slate-300 pb-1">
                    1. Demise, Rent & Term
                  </h3>
                  <p>
                    The Landlord demises unto the Tenant the residential apartment known and described as <strong>{selectedAgreement.propertyTitle}</strong> to HOLD the same for a term certain of <strong>ONE (1) YEAR</strong> commencing from <strong>{selectedAgreement.tenancyCommencementDate}</strong> and expiring on <strong>{selectedAgreement.tenancyExpirationDate}</strong>.
                  </p>
                  <p>
                    YIELDING AND PAYING therefore the sum of <strong>₦{selectedAgreement.annualRent.toLocaleString()} (Naira)</strong> per annum, with a refundable caution deposit of <strong>₦{selectedAgreement.cautionDeposit.toLocaleString()}</strong> held in Rentilly Escrow.
                  </p>
                </div>

                {/* Tenant Covenants */}
                <div className="space-y-2 text-xs leading-relaxed">
                  <h3 className="font-bold uppercase tracking-wider text-slate-900 text-sm font-sans border-b border-slate-300 pb-1">
                    2. Tenant Covenants & Obligations
                  </h3>
                  <ul className="list-decimal pl-5 space-y-1 text-slate-800">
                    <li>To pay all personal electricity bills via the dedicated prepaid meter during the subsistence of the tenancy.</li>
                    <li>To keep the interior of the demised premises in good and tenantable repair, reasonable wear and tear excepted.</li>
                    <li>Not to assign, sublet, or part with possession of the premises or any part thereof without prior written consent.</li>
                    <li>Not to use the premises for any unlawful purpose or nuisance to adjoining co-tenants.</li>
                  </ul>
                </div>

                {/* Landlord Covenants */}
                <div className="space-y-2 text-xs leading-relaxed">
                  <h3 className="font-bold uppercase tracking-wider text-slate-900 text-sm font-sans border-b border-slate-300 pb-1">
                    3. Landlord Covenants & Rentilly Protection
                  </h3>
                  <ul className="list-decimal pl-5 space-y-1 text-slate-800">
                    <li>To guarantee peaceful and quiet enjoyment of the premises throughout the tenancy term.</li>
                    <li>To keep external roofs, walls, and common water facilities in good structural order.</li>
                    <li>To honor the Rentilly Move-In Guarantee within the initial 30 days of occupation.</li>
                  </ul>
                </div>

                {/* Digital Signatures Box */}
                <div className="pt-6 border-t-2 border-slate-900 grid grid-cols-3 gap-4 text-xs font-sans">
                  <div className="space-y-2 text-center p-3 bg-slate-50 rounded border border-slate-200">
                    <span className="text-[10px] text-slate-500 uppercase font-bold block">Landlord Digital Signature</span>
                    <div className="font-mono text-emerald-800 font-bold text-sm py-1 border-b border-slate-400">
                      /s/ {selectedAgreement.landlordName}
                    </div>
                    <span className="text-[9px] text-slate-500 block">Signed: 2026-08-29 16:30 GMT+1</span>
                  </div>

                  <div className="space-y-2 text-center p-3 bg-slate-50 rounded border border-slate-200">
                    <span className="text-[10px] text-slate-500 uppercase font-bold block">Tenant Digital Signature</span>
                    <div className="font-mono text-emerald-800 font-bold text-sm py-1 border-b border-slate-400">
                      /s/ {selectedAgreement.tenantName}
                    </div>
                    <span className="text-[9px] text-slate-500 block">Signed: 2026-08-29 16:45 GMT+1</span>
                  </div>

                  <div className="space-y-2 text-center p-3 bg-emerald-50 rounded border border-emerald-300">
                    <span className="text-[10px] text-emerald-800 uppercase font-bold block">Rentilly Legal Seal</span>
                    <div className="flex items-center justify-center gap-1 text-emerald-900 font-bold text-xs py-1 border-b border-emerald-400">
                      <Stamp className="w-4 h-4" />
                      <span>AUDITED & SEALED</span>
                    </div>
                    <span className="text-[9px] text-emerald-700 block">Barr. Chijioke Okonkwo</span>
                  </div>
                </div>
              </div>
            ) : (
              <div className="p-12 text-center text-slate-500 text-xs rounded-2xl bg-slate-900 border border-slate-800">
                Select an executed contract to preview legal terms.
              </div>
            )}
          </div>
        </div>
      )}

      {/* VIEW 2: PHYSICAL & DOCUSIGN COURIER DESK */}
      {activeSubTab === 'dispatches' && (
        <div className="space-y-6">
          {/* Metrics Row */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
              <div className="flex items-center justify-between">
                <span className="text-xs text-slate-400 font-medium">Total Dossiers</span>
                <Package className="w-4 h-4 text-emerald-400" />
              </div>
              <div className="text-2xl font-bold text-white mt-2">{totalDispatches}</div>
              <span className="text-[11px] text-slate-500">Legal packages managed</span>
            </div>

            <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
              <div className="flex items-center justify-between">
                <span className="text-xs text-slate-400 font-medium">In Transit</span>
                <Truck className="w-4 h-4 text-sky-400" />
              </div>
              <div className="text-2xl font-bold text-sky-400 mt-2">{inTransitCount}</div>
              <span className="text-[11px] text-sky-500/80">With courier / moving</span>
            </div>

            <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
              <div className="flex items-center justify-between">
                <span className="text-xs text-slate-400 font-medium">Diaspora / DocuSign</span>
                <Globe className="w-4 h-4 text-purple-400" />
              </div>
              <div className="text-2xl font-bold text-purple-400 mt-2">{diasporaCount}</div>
              <span className="text-[11px] text-purple-500/80">International buyers</span>
            </div>

            <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
              <div className="flex items-center justify-between">
                <span className="text-xs text-slate-400 font-medium">Delivered & Confirmed</span>
                <CheckCircle className="w-4 h-4 text-emerald-400" />
              </div>
              <div className="text-2xl font-bold text-emerald-400 mt-2">{deliveredCount}</div>
              <span className="text-[11px] text-emerald-500/80">Physical title received</span>
            </div>
          </div>

          {/* Search & Actions Bar */}
          <div className="flex flex-col sm:flex-row items-center justify-between gap-4 p-4 rounded-2xl bg-slate-900 border border-slate-800">
            <div className="relative w-full sm:w-80">
              <Search className="w-4 h-4 absolute left-3 top-3 text-slate-500" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search recipient, waybill, property..."
                className="w-full pl-9 pr-4 py-2 rounded-xl bg-slate-850 border border-slate-700 text-xs text-slate-200 placeholder:text-slate-500 focus:outline-none focus:border-emerald-500"
              />
            </div>

            <div className="flex items-center gap-2 self-end sm:self-auto text-xs text-slate-400">
              <span>Auto-generating direct tracking links for DHL, FedEx, GIG Logistics, Red Star Express.</span>
            </div>
          </div>

          {/* Dispatches Table */}
          <div className="overflow-x-auto rounded-2xl border border-slate-800 bg-slate-900">
            <table className="w-full text-left text-xs">
              <thead className="bg-slate-850 text-slate-400 border-b border-slate-800 text-[11px] uppercase tracking-wider font-semibold">
                <tr>
                  <th className="py-3.5 px-4">Recipient / Buyer</th>
                  <th className="py-3.5 px-4">Property & Deed</th>
                  <th className="py-3.5 px-4">Destination</th>
                  <th className="py-3.5 px-4">DocuSign Status</th>
                  <th className="py-3.5 px-4">Courier & Waybill</th>
                  <th className="py-3.5 px-4">Delivery Status</th>
                  <th className="py-3.5 px-4 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800 text-slate-300">
                {isLoadingDispatches ? (
                  <tr>
                    <td colSpan={7} className="py-8 text-center text-slate-500">
                      Loading legal conveyance dispatches...
                    </td>
                  </tr>
                ) : filteredDispatches.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="py-8 text-center text-slate-500">
                      No courier dispatches logged yet. Click "Log New Physical Dispatch" to create one.
                    </td>
                  </tr>
                ) : (
                  filteredDispatches.map((dsp) => (
                    <tr key={dsp.id} className="hover:bg-slate-850/50 transition">
                      <td className="py-3.5 px-4">
                        <div className="font-bold text-white">{dsp.recipientName}</div>
                        <div className="text-[11px] text-slate-400">{dsp.recipientEmail}</div>
                        <div className="text-[10px] text-slate-500">{dsp.recipientPhone}</div>
                      </td>

                      <td className="py-3.5 px-4 max-w-[220px]">
                        <div className="font-medium text-slate-200 truncate">{dsp.propertyTitle}</div>
                        <div className="text-[11px] text-slate-400 truncate">{dsp.propertyAddress}</div>
                      </td>

                      <td className="py-3.5 px-4">
                        <div className="flex items-center gap-1.5 font-medium">
                          {dsp.isDiaspora ? (
                            <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-purple-500/10 text-purple-400 border border-purple-500/30 flex items-center gap-1">
                              <Globe className="w-3 h-3" />
                              <span>Diaspora ({dsp.deliveryCountry})</span>
                            </span>
                          ) : (
                            <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                              🇳🇬 Nigeria ({dsp.deliveryState})
                            </span>
                          )}
                        </div>
                        <div className="text-[10px] text-slate-400 mt-1 truncate max-w-[180px]">
                          {dsp.deliveryAddress}, {dsp.deliveryCity}
                        </div>
                      </td>

                      <td className="py-3.5 px-4">
                        {dsp.docusignStatus === 'not_applicable' ? (
                          <span className="text-[11px] text-slate-500">Not Applicable</span>
                        ) : dsp.docusignStatus === 'signed' ? (
                          <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-500/10 text-emerald-400 border border-emerald-500/30 flex items-center gap-1 w-fit">
                            <CheckCircle className="w-3 h-3" />
                            <span>Signed via DocuSign</span>
                          </span>
                        ) : (
                          <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-500/10 text-amber-400 border border-amber-500/30 flex items-center gap-1 w-fit">
                            <Clock className="w-3 h-3" />
                            <span>Envelope Sent</span>
                          </span>
                        )}
                        {dsp.docusignEnvelopeUrl && (
                          <a
                            href={dsp.docusignEnvelopeUrl}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="text-[10px] text-sky-400 hover:text-sky-300 flex items-center gap-1 mt-1 font-medium"
                          >
                            <span>DocuSign Audit Trail</span>
                            <ExternalLink className="w-2.5 h-2.5" />
                          </a>
                        )}
                      </td>

                      <td className="py-3.5 px-4">
                        <div className="font-bold text-slate-200">{dsp.courierPartner}</div>
                        {dsp.waybillNumber ? (
                          <a
                            href={dsp.trackingUrl}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="font-mono text-emerald-400 hover:text-emerald-300 font-semibold flex items-center gap-1 mt-0.5"
                          >
                            <span>{dsp.waybillNumber}</span>
                            <ExternalLink className="w-3 h-3" />
                          </a>
                        ) : (
                          <span className="text-slate-500 italic text-[11px]">Waybill Pending</span>
                        )}
                        <div className="text-[10px] text-slate-500 mt-0.5">ETA: {dsp.estimatedDeliveryDate}</div>
                      </td>

                      <td className="py-3.5 px-4">
                        <span className={`px-2.5 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider inline-flex items-center gap-1 ${
                          dsp.status === 'delivered'
                            ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/30'
                            : dsp.status === 'in_transit' || dsp.status === 'dispatched'
                            ? 'bg-sky-500/10 text-sky-400 border border-sky-500/30'
                            : 'bg-amber-500/10 text-amber-400 border border-amber-500/30'
                        }`}>
                          {dsp.status === 'delivered' ? <CheckCircle className="w-3 h-3" /> : <Clock className="w-3 h-3" />}
                          <span>{dsp.status.replace(/_/g, ' ')}</span>
                        </span>
                        {dsp.recipientConfirmed && (
                          <div className="text-[10px] text-emerald-400 mt-1 font-semibold flex items-center gap-1">
                            <span>✓ Recipient Confirmed</span>
                          </div>
                        )}
                      </td>

                      <td className="py-3.5 px-4 text-right">
                        <button
                          onClick={() => openEditModal(dsp)}
                          className="px-3 py-1 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 font-bold text-xs transition border border-slate-700"
                        >
                          Update
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* DISPATCH EDIT / CREATE MODAL */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm">
          <div className="bg-slate-900 border border-slate-800 rounded-3xl max-w-xl w-full p-6 space-y-4 shadow-2xl max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <div className="flex items-center gap-2">
                <Truck className="w-5 h-5 text-emerald-400" />
                <h3 className="font-bold text-base text-white">
                  {editingDispatch ? 'Update Physical & DocuSign Dispatch' : 'Log New Physical Legal Dispatch'}
                </h3>
              </div>
              <button
                onClick={() => setIsModalOpen(false)}
                className="text-slate-400 hover:text-white p-1 rounded-lg hover:bg-slate-800"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleSaveDispatch} className="space-y-4 text-xs">
              {/* Recipient & Property */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-slate-400 font-medium mb-1">Recipient / Buyer Name</label>
                  <input
                    type="text"
                    required
                    value={formData.recipientName}
                    onChange={(e) => setFormData({ ...formData, recipientName: e.target.value })}
                    placeholder="Full legal name"
                    className="w-full px-3 py-2 rounded-xl bg-slate-850 border border-slate-700 text-white placeholder:text-slate-500 focus:outline-none focus:border-emerald-500"
                  />
                </div>

                <div>
                  <label className="block text-slate-400 font-medium mb-1">Recipient Email</label>
                  <input
                    type="email"
                    required
                    value={formData.recipientEmail}
                    onChange={(e) => setFormData({ ...formData, recipientEmail: e.target.value })}
                    placeholder="buyer@gmail.com"
                    className="w-full px-3 py-2 rounded-xl bg-slate-850 border border-slate-700 text-white placeholder:text-slate-500 focus:outline-none focus:border-emerald-500"
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-slate-400 font-medium mb-1">Phone Number</label>
                  <input
                    type="text"
                    required
                    value={formData.recipientPhone}
                    onChange={(e) => setFormData({ ...formData, recipientPhone: e.target.value })}
                    placeholder="+2348000000000 or +44..."
                    className="w-full px-3 py-2 rounded-xl bg-slate-850 border border-slate-700 text-white placeholder:text-slate-500 focus:outline-none focus:border-emerald-500"
                  />
                </div>

                <div>
                  <label className="block text-slate-400 font-medium mb-1">Property Title</label>
                  <input
                    type="text"
                    required
                    value={formData.propertyTitle}
                    onChange={(e) => setFormData({ ...formData, propertyTitle: e.target.value })}
                    placeholder="e.g. 3-Bed Terrace, Lekki"
                    className="w-full px-3 py-2 rounded-xl bg-slate-850 border border-slate-700 text-white placeholder:text-slate-500 focus:outline-none focus:border-emerald-500"
                  />
                </div>
              </div>

              {/* Destination & Country (Diaspora Detection) */}
              <div className="p-3.5 rounded-2xl bg-slate-850 border border-slate-800 space-y-3">
                <div className="flex items-center justify-between">
                  <span className="font-bold text-slate-200">Delivery Destination</span>
                  <span className="text-[11px] text-slate-400">
                    {formData.isDiaspora ? '🌍 Diaspora Route (DocuSign + DHL)' : '🇳🇬 Domestic Nigeria Route'}
                  </span>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-3 gap-2.5">
                  <div>
                    <label className="block text-slate-400 text-[11px] mb-1">Country</label>
                    <input
                      type="text"
                      required
                      value={formData.deliveryCountry}
                      onChange={(e) => handleCountryChange(e.target.value)}
                      placeholder="Nigeria, UK, USA..."
                      className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-700 text-white focus:outline-none focus:border-emerald-500"
                    />
                  </div>

                  <div>
                    <label className="block text-slate-400 text-[11px] mb-1">State / Region</label>
                    <input
                      type="text"
                      required
                      value={formData.deliveryState}
                      onChange={(e) => setFormData({ ...formData, deliveryState: e.target.value })}
                      placeholder="Lagos, London..."
                      className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-700 text-white focus:outline-none focus:border-emerald-500"
                    />
                  </div>

                  <div>
                    <label className="block text-slate-400 text-[11px] mb-1">City / Town</label>
                    <input
                      type="text"
                      required
                      value={formData.deliveryCity}
                      onChange={(e) => setFormData({ ...formData, deliveryCity: e.target.value })}
                      placeholder="Lekki, Canary Wharf..."
                      className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-700 text-white focus:outline-none focus:border-emerald-500"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-slate-400 text-[11px] mb-1">Full Street Address</label>
                  <input
                    type="text"
                    required
                    value={formData.deliveryAddress}
                    onChange={(e) => setFormData({ ...formData, deliveryAddress: e.target.value })}
                    placeholder="House number, Street name, Apt/Flat"
                    className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-700 text-white focus:outline-none focus:border-emerald-500"
                  />
                </div>
              </div>

              {/* DocuSign Section */}
              <div className="p-3.5 rounded-2xl bg-purple-950/20 border border-purple-800/40 space-y-3">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-1.5 font-bold text-purple-300">
                    <Globe className="w-4 h-4 text-purple-400" />
                    <span>DocuSign eSignature Integration</span>
                  </div>
                  <select
                    value={formData.docusignStatus}
                    onChange={(e: any) => setFormData({ ...formData, docusignStatus: e.target.value })}
                    className="px-2.5 py-1 rounded-lg bg-slate-900 border border-purple-700 text-purple-300 font-bold focus:outline-none"
                  >
                    <option value="not_applicable">Not Applicable</option>
                    <option value="sent">Envelope Sent</option>
                    <option value="signed">Digitally Signed</option>
                    <option value="completed">Completed & Audited</option>
                  </select>
                </div>

                {formData.docusignStatus !== 'not_applicable' && (
                  <div>
                    <label className="block text-purple-300/80 text-[11px] mb-1">DocuSign Envelope / Certificate Link</label>
                    <input
                      type="url"
                      value={formData.docusignEnvelopeUrl}
                      onChange={(e) => setFormData({ ...formData, docusignEnvelopeUrl: e.target.value })}
                      placeholder="https://app.docusign.com/documents/details/..."
                      className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-purple-700 text-white placeholder:text-purple-400/40 focus:outline-none focus:border-purple-400"
                    />
                  </div>
                )}
              </div>

              {/* Courier & Tracking */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-slate-400 font-medium mb-1">Courier Partner</label>
                  <select
                    value={formData.courierPartner}
                    onChange={(e: any) => setFormData({ ...formData, courierPartner: e.target.value })}
                    className="w-full px-3 py-2 rounded-xl bg-slate-850 border border-slate-700 text-white focus:outline-none focus:border-emerald-500"
                  >
                    <option value="GIG Logistics">GIG Logistics (Nigeria)</option>
                    <option value="DHL Express">DHL Express (Global / Diaspora)</option>
                    <option value="FedEx">FedEx (Global / Nigeria)</option>
                    <option value="Red Star Express">Red Star Express (FedEx NG)</option>
                    <option value="UPS">UPS (Global)</option>
                    <option value="Internal Dispatch">Internal Rentilly Dispatch</option>
                  </select>
                </div>

                <div>
                  <label className="block text-slate-400 font-medium mb-1">Waybill / Tracking Number</label>
                  <input
                    type="text"
                    value={formData.waybillNumber}
                    onChange={(e) => setFormData({ ...formData, waybillNumber: e.target.value })}
                    placeholder="e.g. DHL-9482910482"
                    className="w-full px-3 py-2 rounded-xl bg-slate-850 border border-slate-700 text-white placeholder:text-slate-500 focus:outline-none focus:border-emerald-500"
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-slate-400 font-medium mb-1">Conveyance Status</label>
                  <select
                    value={formData.status}
                    onChange={(e: any) => setFormData({ ...formData, status: e.target.value })}
                    className="w-full px-3 py-2 rounded-xl bg-slate-850 border border-slate-700 text-white focus:outline-none focus:border-emerald-500"
                  >
                    <option value="drafting">1. Drafting Legal Documents</option>
                    <option value="docusign_pending">2. DocuSign Envelope Pending</option>
                    <option value="signed">3. Signed / Executed</option>
                    <option value="stamped_and_sealed">4. Stamped & Affixed Corporate Seal</option>
                    <option value="dispatched">5. Dispatched with Courier</option>
                    <option value="in_transit">6. In Transit to Destination</option>
                    <option value="delivered">7. Delivered & Received</option>
                  </select>
                </div>

                <div>
                  <label className="block text-slate-400 font-medium mb-1">Estimated Delivery Window</label>
                  <input
                    type="text"
                    value={formData.estimatedDeliveryDate}
                    onChange={(e) => setFormData({ ...formData, estimatedDeliveryDate: e.target.value })}
                    placeholder="e.g. 2-3 Business Days"
                    className="w-full px-3 py-2 rounded-xl bg-slate-850 border border-slate-700 text-white placeholder:text-slate-500 focus:outline-none focus:border-emerald-500"
                  />
                </div>
              </div>

              <div>
                <label className="block text-slate-400 font-medium mb-1">Legal Officers Notes & Seals</label>
                <textarea
                  rows={2}
                  value={formData.notes}
                  onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
                  placeholder="Deed particulars, Governor's consent stamps, or courier notes..."
                  className="w-full px-3 py-2 rounded-xl bg-slate-850 border border-slate-700 text-white placeholder:text-slate-500 focus:outline-none focus:border-emerald-500"
                />
              </div>

              <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 font-bold transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold transition flex items-center gap-1.5 shadow-lg shadow-emerald-900/30"
                >
                  <Send className="w-3.5 h-3.5" />
                  <span>{editingDispatch ? 'Update Dispatch' : 'Log Dispatch'}</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

