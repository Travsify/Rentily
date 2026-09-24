import React, { useState, useEffect } from 'react';
import { 
  Building2, 
  CheckCircle, 
  Clock, 
  Lock, 
  DollarSign, 
  Stamp, 
  ExternalLink
} from 'lucide-react';
import type { LegalAgreement, LegalEscrowMilestone, Property } from '../types';

interface LegalPurchasesSalesTabProps {
  properties?: Property[];
  agreements?: LegalAgreement[];
}

export const LegalPurchasesSalesTab: React.FC<LegalPurchasesSalesTabProps> = () => {
  const [milestones, setMilestones] = useState<LegalEscrowMilestone[]>([]);
  const [salesAgreements, setSalesAgreements] = useState<LegalAgreement[]>([]);
  const [selectedAgreement, setSelectedAgreement] = useState<LegalAgreement | null>(null);
  const [isSignOffModalOpen, setIsSignOffModalOpen] = useState(false);
  const [selectedMilestone, setSelectedMilestone] = useState<LegalEscrowMilestone | null>(null);
  const [executionNote, setExecutionNote] = useState('');
  const [actionSuccessMsg, setActionSuccessMsg] = useState<string | null>(null);

  const loadData = async () => {
    try {
      const [mRes, aRes] = await Promise.all([
        fetch('/api/legal/escrow-milestones'),
        fetch('/api/legal/agreements?agreementType=contract_of_sale')
      ]);

      if (mRes.ok) {
        const mData = await mRes.json();
        setMilestones(mData);
      }

      if (aRes.ok) {
        const aData = await aRes.json();
        setSalesAgreements(aData);
        if (aData.length > 0 && !selectedAgreement) {
          setSelectedAgreement(aData[0]);
        }
      }
    } catch (_) {}
  };

  useEffect(() => {
    loadData();
  }, []);

  const handleExecutePayout = async () => {
    if (!selectedMilestone) return;
    try {
      const res = await fetch(`/api/legal/escrow-milestones/${selectedMilestone.id}/execute`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-actor-role': 'legal_officer',
          'x-actor-name': 'Barr. Chijioke Okonkwo, SAN'
        },
        body: JSON.stringify({ executionNotes: executionNote })
      });
      if (res.ok) {
        const data = await res.json();
        setIsSignOffModalOpen(false);
        setActionSuccessMsg(`Tranche disbursed! Payout Ref: ${data.payoutTxReference}`);
        loadData();
        setTimeout(() => setActionSuccessMsg(null), 5000);
      }
    } catch (_) {}
  };

  const formatNaira = (amt: number) => {
    return new Intl.NumberFormat('en-NG', { style: 'currency', currency: 'NGN', maximumFractionDigits: 0 }).format(amt);
  };

  return (
    <div className="space-y-6">
      {/* Banner */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-slate-900/60 p-6 rounded-3xl border border-slate-800 shadow-xl">
        <div className="flex items-center gap-4">
          <div className="w-14 h-14 rounded-2xl bg-gradient-to-tr from-amber-600 to-orange-500 flex items-center justify-center shadow-lg shadow-amber-600/30">
            <Building2 className="w-7 h-7 text-white" />
          </div>
          <div>
            <h2 className="text-xl font-bold text-white tracking-tight">Outright Purchases & Conveyancing Controller</h2>
            <p className="text-xs text-slate-400 mt-0.5">
              3-Tranche Milestone Escrow Releases (30% / 40% / 30%), Stamped Deeds of Assignment & Governor's Consent Tracking.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <span className="px-3.5 py-1.5 rounded-full text-xs font-bold bg-amber-500/10 text-amber-400 border border-amber-500/20">
            Escrow Protection: Active
          </span>
        </div>
      </div>

      {actionSuccessMsg && (
        <div className="p-4 rounded-2xl bg-emerald-950/60 border border-emerald-500/40 text-xs text-emerald-300 flex items-center gap-3 animate-fade-in">
          <CheckCircle className="w-5 h-5 text-emerald-400 flex-shrink-0" />
          <span>{actionSuccessMsg}</span>
        </div>
      )}

      {/* Grid: Active Sales Dossiers + Milestone Controller */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Left: Active Outright Sales Transactions (4 Cols) */}
        <div className="lg:col-span-4 space-y-4">
          <h3 className="text-xs font-bold text-slate-400 uppercase tracking-wider px-1">Active Outright Sales</h3>
          
          <div className="space-y-3">
            {salesAgreements.length === 0 ? (
              <div className="p-6 text-center bg-slate-900/40 rounded-2xl border border-slate-800 text-slate-500 text-xs">
                No outright purchase agreements currently in conveyance.
              </div>
            ) : (
              salesAgreements.map((agr) => {
                const isSelected = selectedAgreement?.id === agr.id;
                return (
                  <div
                    key={agr.id}
                    onClick={() => setSelectedAgreement(agr)}
                    className={`p-4 rounded-2xl border transition-all cursor-pointer ${
                      isSelected
                        ? 'bg-slate-800/90 border-amber-500/50 shadow-lg shadow-amber-950/30'
                        : 'bg-slate-900/60 border-slate-800/80 hover:bg-slate-800/40'
                    }`}
                  >
                    <div className="flex items-start justify-between gap-2 mb-2">
                      <h4 className="text-xs font-bold text-white line-clamp-1">{agr.propertyTitle}</h4>
                      <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-500/10 text-amber-400 border border-amber-500/20">
                        Sale
                      </span>
                    </div>
                    <p className="text-[11px] text-slate-400">Buyer: {agr.tenantName}</p>
                    <p className="text-[11px] text-slate-400">Seller: {agr.landlordName}</p>

                    <div className="mt-3 pt-3 border-t border-slate-800/60 flex items-center justify-between text-xs">
                      <span className="text-slate-500">Consideration</span>
                      <span className="font-bold text-emerald-400">{formatNaira(agr.considerationAmount || agr.annualRent || 0)}</span>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>

        {/* Right: Milestone Escrow & Conveyance Pipeline (8 Cols) */}
        <div className="lg:col-span-8 space-y-6">
          {selectedAgreement ? (
            <div className="bg-slate-900/80 border border-slate-800 rounded-3xl p-6 space-y-6 shadow-xl">
              {/* Header Info */}
              <div className="flex items-start justify-between border-b border-slate-800 pb-5">
                <div>
                  <div className="flex items-center gap-2 mb-1">
                    <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider bg-amber-500/10 text-amber-400 border border-amber-500/20">
                      Conveyance #{selectedAgreement.id.slice(-6)}
                    </span>
                    <span className="text-xs text-slate-500">• {selectedAgreement.governingLaw}</span>
                  </div>
                  <h3 className="text-lg font-bold text-white">{selectedAgreement.propertyTitle}</h3>
                  <p className="text-xs text-slate-400 mt-0.5">{selectedAgreement.propertyAddress}, {selectedAgreement.propertyState}</p>
                </div>

                <div className="text-right">
                  <span className="text-xs text-slate-500 block">Total Consideration</span>
                  <span className="text-xl font-bold text-emerald-400">
                    {formatNaira(selectedAgreement.considerationAmount || selectedAgreement.annualRent || 0)}
                  </span>
                </div>
              </div>

              {/* 4-Stage Conveyance Progress Tracker */}
              <div className="bg-slate-950 p-5 rounded-2xl border border-slate-800 space-y-3">
                <span className="text-xs font-bold text-slate-300 uppercase tracking-wider block">
                  Conveyancing Lifecycle Stages
                </span>
                <div className="grid grid-cols-4 gap-2 text-center text-xs">
                  <div className="bg-emerald-500/10 border border-emerald-500/30 p-2.5 rounded-xl">
                    <CheckCircle className="w-4 h-4 text-emerald-400 mx-auto mb-1" />
                    <span className="font-bold text-white block text-[11px]">1. Title Audit</span>
                    <span className="text-[10px] text-emerald-400">Passed</span>
                  </div>
                  <div className="bg-emerald-500/10 border border-emerald-500/30 p-2.5 rounded-xl">
                    <CheckCircle className="w-4 h-4 text-emerald-400 mx-auto mb-1" />
                    <span className="font-bold text-white block text-[11px]">2. Contract Signed</span>
                    <span className="text-[10px] text-emerald-400">Executed</span>
                  </div>
                  <div className="bg-amber-500/10 border border-amber-500/30 p-2.5 rounded-xl">
                    <Clock className="w-4 h-4 text-amber-400 mx-auto mb-1 animate-spin" />
                    <span className="font-bold text-white block text-[11px]">3. Stamped Deed</span>
                    <span className="text-[10px] text-amber-400">In Handover</span>
                  </div>
                  <div className="bg-slate-900 border border-slate-800 p-2.5 rounded-xl opacity-60">
                    <Lock className="w-4 h-4 text-slate-500 mx-auto mb-1" />
                    <span className="font-bold text-slate-300 block text-[11px]">4. Gov's Consent</span>
                    <span className="text-[10px] text-slate-500">Pending OTP</span>
                  </div>
                </div>
              </div>

              {/* 3-Tranche Milestone Escrow Release Cards */}
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-bold text-slate-300 uppercase tracking-wider flex items-center gap-1.5">
                    <DollarSign className="w-4 h-4 text-amber-400" />
                    Milestone Escrow Tranche Disbursal Controller
                  </span>
                  <span className="text-[10px] text-slate-400">Gated by Legal Officer Sign-Off</span>
                </div>

                <div className="space-y-3">
                  {/* Tranche 1 */}
                  <div className="bg-slate-950 p-4 rounded-2xl border border-slate-800 space-y-3">
                    <div className="flex items-start justify-between">
                      <div>
                        <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-blue-500/10 text-blue-400 border border-blue-500/20 mr-2">
                          Tranche 1 (30%)
                        </span>
                        <span className="text-xs font-bold text-white">Title Clearance & Contract Execution</span>
                        <p className="text-[11px] text-slate-400 mt-1">
                          Released upon Alausa/AGIS root-of-title verification and Contract of Sale sign-off.
                        </p>
                      </div>
                      <span className="text-sm font-bold text-emerald-400">
                        {formatNaira((selectedAgreement.considerationAmount || 10000000) * 0.3)}
                      </span>
                    </div>

                    <div className="flex items-center justify-between pt-2 border-t border-slate-800/60 text-xs">
                      <span className="text-emerald-400 flex items-center gap-1 font-semibold">
                        <CheckCircle className="w-3.5 h-3.5" /> Disbursed (PAYOUT-RENTILLY-M1-4091)
                      </span>
                      <span className="text-slate-500 text-[10px]">Signed by Legal Desk</span>
                    </div>
                  </div>

                  {/* Tranche 2 */}
                  <div className="bg-slate-950 p-4 rounded-2xl border border-amber-500/30 space-y-3 shadow-lg shadow-amber-950/20">
                    <div className="flex items-start justify-between">
                      <div>
                        <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-500/10 text-amber-400 border border-amber-500/20 mr-2">
                          Tranche 2 (40%)
                        </span>
                        <span className="text-xs font-bold text-white">Stamped Deed & Physical Keys Handover</span>
                        <p className="text-[11px] text-slate-400 mt-1">
                          Requires certified counterparts, Level-4 tamper pouch packaging, and key handover attestation.
                        </p>
                      </div>
                      <span className="text-sm font-bold text-amber-400">
                        {formatNaira((selectedAgreement.considerationAmount || 10000000) * 0.4)}
                      </span>
                    </div>

                    <div className="flex items-center justify-between pt-2 border-t border-slate-800/60 text-xs">
                      <span className="text-amber-400 flex items-center gap-1 font-semibold">
                        <Clock className="w-3.5 h-3.5" /> Ready for Legal Sign-Off
                      </span>

                      <button
                        onClick={() => {
                          const existingTranche2 = milestones.find(m => m.milestoneNumber === 2 && (m.transactionId === selectedAgreement.transactionId || m.agreementId === selectedAgreement.id));
                          setSelectedMilestone(existingTranche2 || {
                            id: 'mls_tranche_2_demo',
                            agreementId: selectedAgreement.id,
                            propertyId: selectedAgreement.propertyId,
                            transactionId: selectedAgreement.transactionId || 'TXN_SALE_01',
                            milestoneNumber: 2,
                            title: 'Tranche 2: Stamped Deed & Physical Keys',
                            releasePercentage: 40,
                            releaseAmountNgn: (selectedAgreement.considerationAmount || 10000000) * 0.4,
                            status: 'pending_clearance',
                            conditions: ['Deed Stamped', 'Keys Handover Form Signed'],
                            createdAt: new Date().toISOString(),
                            updatedAt: new Date().toISOString()
                          });
                          setIsSignOffModalOpen(true);
                        }}
                        className="px-3 py-1.5 rounded-xl bg-amber-600 hover:bg-amber-500 text-white font-bold text-xs shadow-md shadow-amber-600/30 transition"
                      >
                        Authorize & Disburse Tranche
                      </button>
                    </div>
                  </div>

                  {/* Tranche 3 */}
                  <div className="bg-slate-950 p-4 rounded-2xl border border-slate-800 space-y-3 opacity-75">
                    <div className="flex items-start justify-between">
                      <div>
                        <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-slate-500/10 text-slate-400 border border-slate-500/20 mr-2">
                          Tranche 3 (30%)
                        </span>
                        <span className="text-xs font-bold text-slate-300">Final Settlement & Gov's Consent Filing</span>
                        <p className="text-[11px] text-slate-500 mt-1">
                          Locked until recipient verifies 6-Digit Delivery OTP and Governor's Consent lodgment folio is issued.
                        </p>
                      </div>
                      <span className="text-sm font-bold text-slate-400">
                        {formatNaira((selectedAgreement.considerationAmount || 10000000) * 0.3)}
                      </span>
                    </div>

                    <div className="flex items-center justify-between pt-2 border-t border-slate-800/60 text-xs">
                      <span className="text-slate-500 flex items-center gap-1 font-semibold">
                        <Lock className="w-3.5 h-3.5" /> Gated by 6-Digit Delivery OTP
                      </span>
                      <span className="text-slate-600 text-[10px]">Step 3 of 3</span>
                    </div>
                  </div>
                </div>
              </div>

              {/* Instrument Provenance Hash */}
              <div className="p-4 rounded-2xl bg-slate-950 border border-slate-800 flex items-center justify-between text-xs">
                <div>
                  <span className="text-slate-500 block uppercase text-[10px] font-bold">Evidence Act Sec 84 Hash</span>
                  <span className="font-mono text-emerald-400 font-medium">{selectedAgreement.legalHash || 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'}</span>
                </div>
                <a
                  href={`/verify-deed/${selectedAgreement.legalHash || selectedAgreement.id}`}
                  target="_blank"
                  rel="noreferrer"
                  className="px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 flex items-center gap-1 font-semibold"
                >
                  <span>Verify Deed</span>
                  <ExternalLink className="w-3.5 h-3.5" />
                </a>
              </div>
            </div>
          ) : (
            <div className="bg-slate-900/60 border border-slate-800 rounded-3xl p-12 text-center text-slate-500">
              Select an outright purchase conveyancing file from the left to view the 3-tranche milestone release controller.
            </div>
          )}
        </div>
      </div>

      {/* Cryptographic Officer Sign-Off Modal */}
      {isSignOffModalOpen && selectedMilestone && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-3xl max-w-lg w-full p-6 space-y-5 shadow-2xl">
            <div className="flex items-center gap-3 border-b border-slate-800 pb-4">
              <div className="w-12 h-12 rounded-2xl bg-amber-500/10 border border-amber-500/30 flex items-center justify-center text-amber-400">
                <Stamp className="w-6 h-6" />
              </div>
              <div>
                <h3 className="text-base font-bold text-white">Execute Escrow Milestone Payout</h3>
                <p className="text-xs text-slate-400">Legal Officer Cryptographic Authorization</p>
              </div>
            </div>

            <div className="bg-slate-950 p-4 rounded-2xl border border-slate-800 space-y-2 text-xs">
              <div className="flex justify-between">
                <span className="text-slate-400">Milestone Tranche</span>
                <span className="font-bold text-white">{selectedMilestone.title}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-400">Disbursal Amount</span>
                <span className="font-bold text-emerald-400">{formatNaira(selectedMilestone.releaseAmountNgn)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-400">Authorized Legal Signatory</span>
                <span className="font-bold text-slate-200">Barr. Chijioke Okonkwo, SAN</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-400">Supreme Court Enrolment</span>
                <span className="font-mono text-slate-300">SCN/NBA/2008/049182</span>
              </div>
            </div>

            <div>
              <label className="block text-xs text-slate-400 font-semibold mb-1">Execution & Handover Notes</label>
              <textarea
                rows={3}
                value={executionNote}
                onChange={(e) => setExecutionNote(e.target.value)}
                placeholder="Confirming stamped counterparts received and verified at Land Registry..."
                className="w-full bg-slate-950 border border-slate-800 rounded-xl p-2.5 text-xs text-white focus:outline-none focus:border-amber-500"
              ></textarea>
            </div>

            <div className="flex justify-end gap-3 pt-3 border-t border-slate-800">
              <button
                type="button"
                onClick={() => setIsSignOffModalOpen(false)}
                className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleExecutePayout}
                className="px-5 py-2 rounded-xl bg-amber-600 hover:bg-amber-500 text-white text-xs font-bold shadow-lg shadow-amber-600/30"
              >
                Affix Bar Seal & Disburse Funds
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
