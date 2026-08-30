import React from 'react';
import { 
  BadgePercent, 
  Wallet, 
  CheckCircle2, 
  Clock 
} from 'lucide-react';
import type { Transaction } from '../types';

interface EscrowTabProps {
  transactions: Transaction[];
  onReleasePayout: (transactionId: string) => void;
}

export const EscrowTab: React.FC<EscrowTabProps> = ({ transactions, onReleasePayout }) => {
  const totalGMV = transactions.reduce((acc, t) => acc + t.totalAmount, 0);
  const totalRentillyFee = transactions.reduce((acc, t) => acc + t.rentillyLegalFee, 0);
  const totalEscrowHeld = transactions
    .filter(t => t.escrowStatus === 'held_in_escrow')
    .reduce((acc, t) => acc + t.totalAmount, 0);
  const totalCautionHeld = transactions
    .filter(t => t.escrowStatus === 'held_in_escrow')
    .reduce((acc, t) => acc + (t.cautionFee || 0), 0);

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold text-white flex items-center gap-2">
            <BadgePercent className="w-6 h-6 text-blue-400" />
            <span>Escrow & Landlord Payout Control</span>
          </h1>
          <p className="text-xs text-slate-400 mt-0.5">
            Holding tenant & buyer funds in protected escrow until physical key handover and signed legal agreements.
          </p>
        </div>
      </div>

      {/* Escrow Metric Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Total GMV Processed</span>
          <div className="text-2xl font-bold text-white mt-1">₦{totalGMV.toLocaleString()}</div>
          <span className="text-[10px] text-emerald-400">Paystack / Flutterwave Gateways</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Rentilly Legal Fees (10%/5%)</span>
          <div className="text-2xl font-bold text-emerald-400 mt-1">₦{totalRentillyFee.toLocaleString()}</div>
          <span className="text-[10px] text-slate-400">Net Platform Revenue</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Escrow Held for Landlords</span>
          <div className="text-2xl font-bold text-blue-400 mt-1">₦{totalEscrowHeld.toLocaleString()}</div>
          <span className="text-[10px] text-blue-300">Awaiting Move-In Execution</span>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
          <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Caution Deposits Held</span>
          <div className="text-2xl font-bold text-purple-400 mt-1">₦{totalCautionHeld.toLocaleString()}</div>
          <span className="text-[10px] text-slate-400">Refundable at tenancy expiration</span>
        </div>
      </div>

      {/* Transactions Table or Empty State */}
      {transactions.length === 0 ? (
        <div className="p-12 text-center rounded-3xl bg-slate-900/40 border border-slate-800/80 space-y-3">
          <div className="w-14 h-14 rounded-2xl bg-slate-800/80 flex items-center justify-center mx-auto text-blue-400">
            <Wallet className="w-7 h-7" />
          </div>
          <div className="space-y-1 max-w-sm mx-auto">
            <h3 className="text-base font-bold text-white">No Escrow Transactions Recorded</h3>
            <p className="text-xs text-slate-400">
              When tenants or buyers pay rent or purchase deposits via Paystack/Flutterwave, payment escrow records and 1-click landlord payouts will be controlled here.
            </p>
          </div>
        </div>
      ) : (
        <div className="p-6 rounded-3xl bg-slate-900 border border-slate-800 space-y-4">
          <h2 className="text-sm font-bold text-white flex items-center gap-2">
            <Wallet className="w-4 h-4 text-emerald-400" />
            <span>Escrow Ledger & Landlord Payout Release</span>
          </h2>

          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="border-b border-slate-800 text-slate-400 uppercase font-semibold text-[10px] tracking-wider">
                <tr>
                  <th className="pb-3 font-semibold">Transaction & Date</th>
                  <th className="pb-3 font-semibold">Property Title</th>
                  <th className="pb-3 font-semibold">Payer / Tenant</th>
                  <th className="pb-3 font-semibold">Base Price</th>
                  <th className="pb-3 font-semibold">Rentilly Fee</th>
                  <th className="pb-3 font-semibold">Total Escrow</th>
                  <th className="pb-3 font-semibold">Escrow Status</th>
                  <th className="pb-3 font-semibold text-right">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60">
                {transactions.map((txn) => {
                  const isHeld = txn.escrowStatus === 'held_in_escrow';
                  const isReleased = txn.escrowStatus === 'released_to_owner';

                  return (
                    <tr key={txn.id} className="hover:bg-slate-850/50 transition">
                      <td className="py-3 font-mono text-[11px] text-slate-400">
                        <div>{txn.id}</div>
                        <div className="text-[10px] text-slate-500">{new Date(txn.createdAt).toLocaleDateString()}</div>
                      </td>
                      <td className="py-3 font-semibold text-white max-w-[180px] truncate">
                        {txn.propertyTitle}
                      </td>
                      <td className="py-3 text-slate-300">
                        {txn.payerName}
                      </td>
                      <td className="py-3 font-semibold text-slate-200">
                        ₦{(txn.baseAmount || 0).toLocaleString()}
                      </td>
                      <td className="py-3 text-emerald-400 font-semibold">
                        ₦{txn.rentillyLegalFee.toLocaleString()}
                      </td>
                      <td className="py-3 font-bold text-white">
                        ₦{txn.totalAmount.toLocaleString()}
                      </td>
                      <td className="py-3">
                        {isHeld && (
                          <span className="flex items-center gap-1 text-[10px] font-bold px-2 py-0.5 rounded-full bg-blue-500/10 text-blue-400 border border-blue-500/30 w-fit">
                            <Clock className="w-3 h-3" />
                            <span>Held in Escrow</span>
                          </span>
                        )}
                        {isReleased && (
                          <span className="flex items-center gap-1 text-[10px] font-bold px-2 py-0.5 rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/30 w-fit">
                            <CheckCircle2 className="w-3 h-3" />
                            <span>Paid to Landlord</span>
                          </span>
                        )}
                      </td>
                      <td className="py-3 text-right">
                        {isHeld ? (
                          <button
                            onClick={() => onReleasePayout(txn.id)}
                            className="px-3 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs shadow-md shadow-emerald-950/40 transition transform active:scale-95"
                          >
                            Release Payout to Owner
                          </button>
                        ) : (
                          <span className="text-[11px] text-slate-500 font-mono">
                            {txn.ownerPayoutReference || 'Settled'}
                          </span>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
};
