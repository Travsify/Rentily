import React, { useState } from 'react';
import { 
  X, 
  ShieldCheck, 
  FileText, 
  UserCheck, 
  Zap, 
  CheckCircle, 
  XCircle, 
  ExternalLink,
  MapPin,
  FileCheck2,
  Briefcase
} from 'lucide-react';
import type { KYPRecord } from '../types';
import { formatOpsId } from '../utils/idGenerator';

interface KYPModalProps {
  kyp: KYPRecord | null;
  onClose: () => void;
  onReview: (
    kypId: string, 
    status: 'approved' | 'rejected' | 'more_info_required',
    notes?: string,
    rejectionReason?: string
  ) => void;
}

export const KYPModal: React.FC<KYPModalProps> = ({ kyp, onClose, onReview }) => {
  if (!kyp) return null;

  const [searchNotes, setSearchNotes] = useState(
    kyp.landRegistrySearchNotes || 
    (kyp.propertyNeighborhood.includes('Abuja')
      ? 'Searched on AGIS Portal & File verification. Ground rent verified up to current year. No pending caveats.'
      : 'Searched at Lagos Lands Bureau (Alausa). Governor Consent verified under registered file. No family dispute or encumbrance.')
  );
  const [rejectionReason, setRejectionReason] = useState('');
  const [activeDocTab, setActiveDocTab] = useState<'title' | 'id' | 'utility' | 'partner'>('title');

  const handleApprove = () => {
    onReview(kyp.id, 'approved', searchNotes);
    onClose();
  };

  const handleReject = () => {
    if (!rejectionReason.trim()) {
      alert('Please specify a rejection reason for the property owner.');
      return;
    }
    onReview(kyp.id, 'rejected', searchNotes, rejectionReason);
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm overflow-y-auto">
      <div className="bg-slate-900 border border-slate-700 rounded-2xl w-full max-w-4xl max-h-[90vh] flex flex-col shadow-2xl overflow-hidden">
        {/* Header */}
        <div className="px-6 py-4 border-b border-slate-800 flex items-center justify-between bg-slate-950/60">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-amber-500/20 text-amber-300 flex items-center justify-center">
              <ShieldCheck className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-base font-bold text-white flex items-center gap-2">
                <span>KYP Title Audit Desk</span>
                <span className="text-xs uppercase px-2 py-0.5 rounded bg-slate-800 text-slate-300 font-mono">
                  {kyp.id}
                </span>
              </h2>
              <p className="text-xs text-slate-400">Verifying direct ownership rights & legal title documents</p>
            </div>
          </div>
          <button 
            onClick={onClose}
            className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content Body */}
        <div className="flex-1 overflow-y-auto p-6 space-y-6">
          {/* Property Summary Card */}
          <div className="p-4 rounded-xl bg-slate-950/80 border border-slate-800 grid grid-cols-1 md:grid-cols-3 gap-4 text-xs">
            <div>
              <span className="text-slate-500 font-medium block">Property Title</span>
              <span className="text-white font-bold text-sm block mt-0.5">{kyp.propertyTitle}</span>
              <span className="text-slate-400 flex items-center gap-1 mt-1">
                <MapPin className="w-3 h-3 text-emerald-400" />
                {kyp.propertyNeighborhood}
              </span>
            </div>

            <div>
              <span className="text-slate-500 font-medium block">Listed By (Owner)</span>
              <span className="text-white font-bold block mt-0.5">{kyp.ownerName}</span>
              <span className="text-slate-400 block">{kyp.ownerEmail}</span>
              <span className="text-emerald-400 font-medium block">{kyp.ownerPhone}</span>
            </div>

            <div>
              <span className="text-slate-500 font-medium block">Financials & Purpose</span>
              <span className="text-white font-bold text-sm block mt-0.5">
                ₦{kyp.propertyPrice.toLocaleString()} ({kyp.propertyPurpose === 'rent' ? '/year' : 'Outright Sale'})
              </span>
              <span className="text-emerald-400 font-bold block mt-0.5">
                Rentilly Fee: ₦{Math.round(kyp.propertyPrice * (kyp.propertyPurpose === 'rent' ? 0.10 : 0.05)).toLocaleString()} ({kyp.propertyPurpose === 'rent' ? '10%' : '5%'})
              </span>
            </div>
          </div>

          {/* Document Tabs */}
          <div className="space-y-3">
            <div className="flex items-center gap-2 border-b border-slate-800 pb-2">
              <button
                onClick={() => setActiveDocTab('title')}
                className={`flex items-center gap-2 px-3.5 py-1.5 rounded-lg text-xs font-semibold transition ${
                  activeDocTab === 'title'
                    ? 'bg-emerald-600 text-white'
                    : 'text-slate-400 hover:text-white hover:bg-slate-800'
                }`}
              >
                <FileText className="w-4 h-4" />
                <span>1. Title Deed ({kyp.titleDocumentType.toUpperCase()})</span>
              </button>

              <button
                onClick={() => setActiveDocTab('id')}
                className={`flex items-center gap-2 px-3.5 py-1.5 rounded-lg text-xs font-semibold transition ${
                  activeDocTab === 'id'
                    ? 'bg-emerald-600 text-white'
                    : 'text-slate-400 hover:text-white hover:bg-slate-800'
                }`}
              >
                <UserCheck className="w-4 h-4" />
                <span>2. Owner ID ({kyp.ownerIdType})</span>
              </button>

              <button
                onClick={() => setActiveDocTab('utility')}
                className={`flex items-center gap-2 px-3.5 py-1.5 rounded-lg text-xs font-semibold transition ${
                  activeDocTab === 'utility'
                    ? 'bg-emerald-600 text-white'
                    : 'text-slate-400 hover:text-white hover:bg-slate-800'
                }`}
              >
                <Zap className="w-4 h-4" />
                <span>3. Utility Bill ({kyp.discoProvider})</span>
              </button>

              {kyp.listedByRole === 'verified_partner' && (
                <button
                  onClick={() => setActiveDocTab('partner')}
                  className={`flex items-center gap-2 px-3.5 py-1.5 rounded-lg text-xs font-semibold transition ${
                    activeDocTab === 'partner'
                      ? 'bg-amber-600 text-white'
                      : 'text-amber-400 hover:text-white hover:bg-slate-800'
                  }`}
                >
                  <Briefcase className="w-4 h-4" />
                  <span>4. Partner Mandate & Selfie 🛡️</span>
                </button>
              )}
            </div>

            {/* Document Viewer Box */}
            <div className="p-4 rounded-xl bg-slate-950 border border-slate-800">
              {activeDocTab === 'title' && (
                <div className="space-y-4">
                  <div className="flex items-center justify-between text-xs">
                    <div>
                      <span className="text-slate-400 font-medium">Document Registration Ref: </span>
                      <span className="text-emerald-400 font-mono font-bold">{kyp.titleDocumentNumber}</span>
                    </div>
                    <span className="px-2 py-0.5 rounded bg-emerald-950 text-emerald-300 border border-emerald-800 font-mono text-[11px]">
                      Type: {kyp.titleDocumentType.replace(/_/g, ' ').toUpperCase()}
                    </span>
                  </div>

                  <div className="relative rounded-lg overflow-hidden border border-slate-800 max-h-64 bg-slate-900 flex items-center justify-center">
                    <img
                      src={kyp.titleDocumentUrls[0]}
                      alt="Title document deed"
                      className="w-full h-64 object-cover"
                    />
                    <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-transparent to-transparent flex items-end p-4">
                      <a
                        href={kyp.titleDocumentUrls[0]}
                        target="_blank"
                        rel="noreferrer"
                        className="px-3 py-1.5 rounded-lg bg-slate-900/90 hover:bg-slate-900 text-white text-xs font-semibold flex items-center gap-1.5 border border-slate-700 backdrop-blur"
                      >
                        <ExternalLink className="w-3.5 h-3.5" />
                        <span>Inspect High-Res Scan</span>
                      </a>
                    </div>
                  </div>
                </div>
              )}

              {activeDocTab === 'id' && (
                <div className="space-y-4">
                  <div className="flex items-center justify-between text-xs">
                    <div>
                      <span className="text-slate-400 font-medium">Identification Number: </span>
                      <span className="text-emerald-400 font-mono font-bold">{kyp.ownerIdNumber}</span>
                    </div>
                    <span className="px-2 py-0.5 rounded bg-blue-950 text-blue-300 border border-blue-800 font-mono text-[11px]">
                      ID Type: {kyp.ownerIdType}
                    </span>
                  </div>

                  <div className="flex items-center gap-4">
                    <img
                      src={kyp.ownerIdUrl}
                      alt="Owner Government ID"
                      className="w-32 h-32 rounded-xl object-cover border border-slate-800"
                    />
                    <div className="text-xs space-y-1 text-slate-300">
                      <p className="font-bold text-white text-sm">{kyp.ownerName}</p>
                      <p>NIN / ID Status: <span className="text-emerald-400 font-bold">Valid & Verified</span></p>
                      <p>Full Phone Number: {kyp.ownerPhone}</p>
                      <p>Email: {kyp.ownerEmail}</p>
                    </div>
                  </div>
                </div>
              )}

              {activeDocTab === 'utility' && (
                <div className="space-y-4">
                  <div className="flex items-center justify-between text-xs">
                    <div>
                      <span className="text-slate-400 font-medium">Disco Meter Number: </span>
                      <span className="text-emerald-400 font-mono font-bold">{kyp.discoMeterNumber}</span>
                    </div>
                    <span className="px-2 py-0.5 rounded bg-amber-950 text-amber-300 border border-amber-800 font-mono text-[11px]">
                      Provider: {kyp.discoProvider}
                    </span>
                  </div>

                  <div className="flex items-center gap-4">
                    <img
                      src={kyp.utilityBillUrl}
                      alt="Utility Bill"
                      className="w-48 h-32 rounded-xl object-cover border border-slate-800"
                    />
                    <div className="text-xs space-y-1 text-slate-300">
                      <p className="font-semibold text-white">Physical Possession & Meter Verification</p>
                      <p className="text-slate-400">Address on bill matches: <span className="text-emerald-400 font-medium">{kyp.propertyNeighborhood}</span></p>
                      <p className="text-slate-400">Disco provider: {kyp.discoProvider}</p>
                    </div>
                  </div>
                </div>
              )}

              {activeDocTab === 'partner' && (
                <div className="space-y-4">
                  <div className="flex items-center justify-between text-xs">
                    <div>
                      <span className="text-slate-400 font-medium">Corporate Brokerage Firm: </span>
                      <span className="text-amber-400 font-bold">{kyp.partnerBusinessName || kyp.partnerName || 'Accredited Partner'}</span>
                    </div>
                    <span className="px-2 py-0.5 rounded bg-amber-950 text-amber-300 border border-amber-800 font-mono text-[11px]">
                      CAC: {kyp.partnerCacNumber || 'Verified Entity'} • ID: {formatOpsId(kyp.partnerId, true)}
                    </span>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    {/* Ghost Shield Presence Photo */}
                    <div className="p-3 rounded-xl bg-slate-900 border border-slate-800 space-y-2">
                      <div className="flex items-center justify-between text-xs">
                        <span className="text-slate-300 font-bold">Presence Selfie (Ghost Shield)</span>
                        <span className="text-emerald-400 text-[10px] font-bold">PHYSICAL PROOF</span>
                      </div>
                      <div className="h-48 rounded-lg overflow-hidden border border-slate-800 bg-black flex items-center justify-center">
                        {kyp.partnerPresencePhotoUrl ? (
                          <img
                            src={kyp.partnerPresencePhotoUrl}
                            alt="Partner Presence Proof"
                            className="w-full h-full object-cover"
                          />
                        ) : (
                          <span className="text-xs text-slate-500">Selfie Recorded at Property</span>
                        )}
                      </div>
                      <p className="text-[11px] text-slate-400">Impromptu photo taken on-site inside or immediately fronting the premises.</p>
                    </div>

                    {/* Power of Attorney Mandate Document */}
                    <div className="p-3 rounded-xl bg-slate-900 border border-slate-800 space-y-2">
                      <div className="flex items-center justify-between text-xs">
                        <span className="text-slate-300 font-bold">Power of Attorney Mandate</span>
                        <span className="text-amber-400 text-[10px] font-bold">LEGAL MANDATE</span>
                      </div>
                      <div className="h-48 rounded-lg overflow-hidden border border-slate-800 bg-black flex items-center justify-center p-4">
                        {kyp.powerOfAttorneyUrl ? (
                          <div className="text-center space-y-3">
                            <FileText className="w-10 h-10 text-amber-400 mx-auto" />
                            <p className="text-xs text-slate-300 font-semibold">Executed Representation Mandate</p>
                            <a
                              href={kyp.powerOfAttorneyUrl}
                              target="_blank"
                              rel="noreferrer"
                              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-amber-600 hover:bg-amber-500 text-white text-xs font-bold transition"
                            >
                              <ExternalLink className="w-3.5 h-3.5" />
                              <span>Inspect Mandate Document</span>
                            </a>
                          </div>
                        ) : (
                          <span className="text-xs text-slate-500">Representation Deed Verified</span>
                        )}
                      </div>
                      <p className="text-[11px] text-slate-400">Grants accredited firm legal mandate to represent property owner.</p>
                    </div>
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Legal Audit Checklist & Notes */}
          <div className="space-y-3">
            <h3 className="text-xs font-bold uppercase tracking-wider text-slate-400 flex items-center gap-2">
              <FileCheck2 className="w-4 h-4 text-emerald-400" />
              <span>Land Registry Search & Legal Findings (Alausa / AGIS)</span>
            </h3>
            <textarea
              rows={3}
              value={searchNotes}
              onChange={(e) => setSearchNotes(e.target.value)}
              placeholder="Enter legal findings, file number search status, and confirmation notes..."
              className="w-full px-3.5 py-2.5 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-200 focus:outline-none focus:border-emerald-500 font-sans"
            />
          </div>

          {/* Rejection Note Field if Needed */}
          <div className="space-y-2">
            <label className="text-xs font-semibold text-slate-400 block">
              Rejection Reason (Only required if rejecting):
            </label>
            <input
              type="text"
              value={rejectionReason}
              onChange={(e) => setRejectionReason(e.target.value)}
              placeholder="e.g. Title deed is missing Governor's signature page, please re-upload..."
              className="w-full px-3.5 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-200 focus:outline-none focus:border-red-500"
            />
          </div>
        </div>

        {/* Footer Actions */}
        <div className="px-6 py-4 border-t border-slate-800 bg-slate-950 flex items-center justify-between">
          <button
            onClick={onClose}
            className="px-4 py-2 rounded-xl text-slate-400 hover:text-white hover:bg-slate-800 text-xs font-medium transition"
          >
            Cancel
          </button>

          <div className="flex items-center gap-3">
            <button
              onClick={handleReject}
              className="px-4 py-2 rounded-xl bg-red-600/20 hover:bg-red-600/30 text-red-300 border border-red-500/40 text-xs font-bold transition flex items-center gap-1.5"
            >
              <XCircle className="w-4 h-4" />
              <span>Save & Reject Listing</span>
            </button>

            <button
              onClick={handleApprove}
              className="px-5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold shadow-lg shadow-emerald-900/30 transition flex items-center gap-1.5"
            >
              <CheckCircle className="w-4 h-4" />
              <span>Save Changes & Approve Badge</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
