import React, { useState } from 'react';
import { 
  FileText, 
  CheckCircle, 
  Stamp, 
  ShieldCheck, 
  Printer
} from 'lucide-react';
import type { LegalAgreement } from '../types';

interface LegalAgreementsTabProps {
  agreements: LegalAgreement[];
}

export const LegalAgreementsTab: React.FC<LegalAgreementsTabProps> = ({ agreements }) => {
  const [selectedAgreement, setSelectedAgreement] = useState<LegalAgreement>(agreements[0]);

  const handlePrint = () => {
    window.print();
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold text-white flex items-center gap-2">
            <FileText className="w-6 h-6 text-emerald-400" />
            <span>Nigerian Legal Agreement Engine & Vault</span>
          </h1>
          <p className="text-xs text-slate-400 mt-0.5">
            Automated legal tenancy contracts & deeds compliant with Lagos State Tenancy Law 2011 and Abuja FCT Laws.
          </p>
        </div>

        <button
          onClick={handlePrint}
          className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-bold transition flex items-center gap-2 self-start sm:self-auto border border-slate-700"
        >
          <Printer className="w-4 h-4 text-emerald-400" />
          <span>Print / Export Legal PDF</span>
        </button>
      </div>

      {/* Main Grid: Contracts List & Live Contract Document Viewer */}
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
                    <span className="text-slate-500 font-mono">10% Platform Legal</span>
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
                {/* Landlord Sign */}
                <div className="space-y-2 text-center p-3 bg-slate-50 rounded border border-slate-200">
                  <span className="text-[10px] text-slate-500 uppercase font-bold block">Landlord Digital Signature</span>
                  <div className="font-mono text-emerald-800 font-bold text-sm py-1 border-b border-slate-400">
                    /s/ {selectedAgreement.landlordName}
                  </div>
                  <span className="text-[9px] text-slate-500 block">Signed: 2026-08-29 16:30 GMT+1</span>
                </div>

                {/* Tenant Sign */}
                <div className="space-y-2 text-center p-3 bg-slate-50 rounded border border-slate-200">
                  <span className="text-[10px] text-slate-500 uppercase font-bold block">Tenant Digital Signature</span>
                  <div className="font-mono text-emerald-800 font-bold text-sm py-1 border-b border-slate-400">
                    /s/ {selectedAgreement.tenantName}
                  </div>
                  <span className="text-[9px] text-slate-500 block">Signed: 2026-08-29 16:45 GMT+1</span>
                </div>

                {/* Rentilly Legal Stamp */}
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
    </div>
  );
};
