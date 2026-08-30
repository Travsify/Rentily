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
    .reduce((acc, t) => acc + t.cautionFee, 0);

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
          <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Caution Escrow Reserve</span>
          <div className="text-2xl font-bold text-amber-400 mt-1">₦{totalCautionHeld.toLocaleString()}</div>
          <span className="text-[10px] text-amber-300">Protected for Tenant Move-Out</span>
        </div>
      </div>

      {/* Escrow Transactions Table */}
      <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 space-y-4">
        <h2 className="text-sm font-bold text-white flex items-center gap-2">
          <Wallet className="w-4 h-4 text-emerald-400" />
          <span>Active Escrow Transactions</span>
        </h2>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="border-b border-slate-800 text-slate-400 text-[10px] uppercase tracking-wider">
              <tr>
                <th className="py-3 px-4">Ref & Date</th>
                <th className="py-3 px-4">Property & Parties</th>
                <th className="py-3 px-4">Base Amount</th>
                <th className="py-3 px-4">Rentilly Legal Fee</th>
                <th className="py-3 px-4">Total Paid</th>
                <th className="py-3 px-4">Escrow Status</th>
                <th className="py-3 px-4 text-right">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60">
              {transactions.map((txn) => {
                const isHeld = txn.escrowStatus === 'held_in_escrow';

                return (
                  <tr key={txn.id} className="hover:bg-slate-850/50 transition">
                    <td className="py-3.5 px-4">
                      <span className="font-mono text-emerald-400 font-bold block">{txn.paymentReference}</span>
                      <span className="text-[10px] text-slate-500">{new Date(txn.createdAt).toLocaleDateString()}</span>
                    </td>

                    <td className="py-3.5 px-4 space-y-0.5">
                      <span className="font-semibold text-white block">{txn.propertyTitle}</span>
                      <span className="text-[11px] text-slate-400 block">
                        Tenant: <span className="text-slate-200">{txn.payerName}</span> • Owner: <span className="text-slate-200">{txn.ownerName}</span>
                      </span>
                    </td>

                    <td className="py-3.5 px-4 font-mono font-medium text-slate-200">
                      ₦{txn.baseAmount.toLocaleString()}
                    </td>

                    <td className="py-3.5 px-4 font-mono font-bold text-emerald-400">
                      ₦{txn.rentillyLegalFee.toLocaleString()} ({txn.transactionType === 'rent' ? '10%' : '5%'})
                    </td>

                    <td className="py-3.5 px-4 font-mono font-bold text-white">
                      ₦{txn.totalAmount.toLocaleString()}
                    </td>

                    <td className="py-3.5 px-4">
                      {isHeld ? (
                        <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-blue-500/20 text-blue-300 border border-blue-500/30 text-[10px] font-bold">
                          <Clock className="w-3 h-3" />
                          <span>Held in Escrow</span>
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 text-[10px] font-bold">
                          <CheckCircle2 className="w-3 h-3" />
                          <span>Disbursed to Landlord</span>
                        </span>
                      )}
                    </td>

                    <td className="py-3.5 px-4 text-right">
                      {isHeld ? (
                        <button
                          onClick={() => onReleasePayout(txn.id)}
                          className="px-3.5 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs shadow-md transition"
                        >
                          Release Payout & Delist
                        </button>
                      ) : (
                        <span className="text-[10px] text-slate-500 font-mono">
                          {txn.ownerPayoutReference}
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
    </div>
  );
};
