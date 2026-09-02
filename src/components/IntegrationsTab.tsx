import React, { useState } from 'react';
import { 
  Key, 
  ShieldCheck, 
  Wallet, 
  RefreshCw, 
  Copy, 
  Check, 
  ExternalLink,
  Zap
} from 'lucide-react';

export const IntegrationsTab: React.FC = () => {
  // Identitypass / Prembly state
  const [testingIdPass, setTestingIdPass] = useState(false);
  const [idPassResult, setIdPassResult] = useState<any>(null);
  const [testNin, setTestNin] = useState('12345678901');

  // Flutterwave state
  const [testingFlw, setTestingFlw] = useState(false);
  const [flwResult, setFlwResult] = useState<any>(null);
  const [copiedWebhook, setCopiedWebhook] = useState(false);

  const webhookUrl = 'https://rentilly-admin-api.onrender.com/api/webhooks/flutterwave';

  const handleTestIdentitypass = async () => {
    setTestingIdPass(true);
    setIdPassResult(null);
    try {
      const res = await fetch('https://rentilly-admin-api.onrender.com/api/verify/nin', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ninNumber: testNin })
      });
      const data = await res.json();
      setIdPassResult(data);
    } catch (e: any) {
      setIdPassResult({ status: false, message: e.message });
    } finally {
      setTestingIdPass(false);
    }
  };

  const handleTestFlutterwave = async () => {
    setTestingFlw(true);
    setFlwResult(null);
    try {
      const res = await fetch('https://rentilly-admin-api.onrender.com/api/payments/create-virtual-account', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          propertyId: 'test-prop-001',
          propertyTitle: 'Luxury 3-Bed Terrace Lekki Phase 1',
          email: 'admin@myrentilly.com',
          tenantName: 'Femi Adesanya (Test Renter)',
          expectedAmount: 7500000
        })
      });
      const data = await res.json();
      setFlwResult(data);
    } catch (e: any) {
      setFlwResult({ status: false, message: e.message });
    } finally {
      setTestingFlw(false);
    }
  };

  const handleCopyWebhook = () => {
    navigator.clipboard.writeText(webhookUrl);
    setCopiedWebhook(true);
    setTimeout(() => setCopiedWebhook(false), 2000);
  };

  return (
    <div className="space-y-6 font-sans">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-lg font-bold text-white flex items-center gap-2">
            <Key className="w-5 h-5 text-emerald-400" />
            <span>Third-Party Production Integrations Hub</span>
          </h1>
          <p className="text-xs text-slate-400 mt-0.5">
            Manage live API keys for Identitypass (Prembly) NIMC/BVN identity verification and Flutterwave Dedicated Escrow Virtual Accounts.
          </p>
        </div>

        <div className="flex items-center gap-2 text-xs">
          <span className="px-2.5 py-1 rounded-lg bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-semibold flex items-center gap-1.5">
            <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
            Render API Online
          </span>
        </div>
      </div>

      {/* Two Column Layout: Identitypass & Flutterwave */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
        {/* Card 1: Identitypass / Prembly */}
        <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 space-y-4 flex flex-col justify-between shadow-sm">
          <div className="space-y-3">
            <div className="flex items-start justify-between">
              <div className="flex items-center gap-2.5">
                <div className="w-9 h-9 rounded-xl bg-purple-500/10 border border-purple-500/20 flex items-center justify-center text-purple-400">
                  <ShieldCheck className="w-5 h-5" />
                </div>
                <div>
                  <h2 className="text-xs font-bold text-white">Identitypass (Prembly) Verification</h2>
                  <p className="text-[10px] text-slate-400">NIMC NIN, NIBSS BVN & CAC Business Registry</p>
                </div>
              </div>

              <span className="text-[10px] px-2 py-0.5 rounded-full bg-purple-500/10 text-purple-300 border border-purple-500/30 font-semibold">
                KYC / KYP Engine
              </span>
            </div>

            <div className="p-3 rounded-xl bg-slate-950/70 border border-slate-800 text-[11px] space-y-1 text-slate-300">
              <p>• Used by Rentilly to verify the direct landlord's National ID (NIN) against property title deeds.</p>
              <p>• Verifies CAC registration number for corporate landlords & real estate developer companies.</p>
            </div>

            {/* Test Input Box */}
            <div className="space-y-2 text-xs pt-1">
              <label className="block text-slate-300 font-semibold text-[11px]">Test NIN / BVN Lookup</label>
              <div className="flex gap-2">
                <input
                  type="text"
                  value={testNin}
                  onChange={(e) => setTestNin(e.target.value)}
                  placeholder="Enter 11-digit NIN or BVN"
                  className="flex-1 px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-200 focus:outline-none focus:border-purple-500 font-mono"
                />
                <button
                  onClick={handleTestIdentitypass}
                  disabled={testingIdPass}
                  className="px-4 py-2 rounded-xl bg-purple-600 hover:bg-purple-500 text-white font-bold text-xs shadow-md transition flex items-center gap-1.5 disabled:opacity-50"
                >
                  {testingIdPass ? <RefreshCw className="w-3.5 h-3.5 animate-spin" /> : <Zap className="w-3.5 h-3.5" />}
                  <span>Test API</span>
                </button>
              </div>
            </div>

            {/* Response Preview */}
            {idPassResult && (
              <div className={`p-3 rounded-xl border text-[11px] font-mono space-y-1 ${
                idPassResult.status 
                  ? 'bg-emerald-950/30 border-emerald-500/30 text-emerald-300' 
                  : 'bg-red-950/30 border-red-500/30 text-red-300'
              }`}>
                <div className="flex items-center justify-between font-sans font-bold">
                  <span>Identitypass Response:</span>
                  <span>{idPassResult.status ? '✓ Verified' : '✕ Failed'}</span>
                </div>
                {idPassResult.data && (
                  <div className="pt-1 space-y-0.5 text-[10px]">
                    <div>Full Name: {idPassResult.data.fullName}</div>
                    <div>Phone: {idPassResult.data.phone}</div>
                    <div>DOB: {idPassResult.data.dateOfBirth}</div>
                  </div>
                )}
                {idPassResult.message && <div className="text-[10px] text-slate-400 font-sans">{idPassResult.message}</div>}
              </div>
            )}
          </div>

          <div className="pt-3 border-t border-slate-800/80 flex items-center justify-between text-[11px] text-slate-400">
            <span>Docs: <a href="https://docs.prembly.com/" target="_blank" rel="noreferrer" className="text-purple-400 hover:underline inline-flex items-center gap-1">Prembly API Portal <ExternalLink className="w-2.5 h-2.5" /></a></span>
            <span className="text-emerald-400 font-medium">Ready in Environment</span>
          </div>
        </div>

        {/* Card 2: Flutterwave Escrow & Virtual Accounts */}
        <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 space-y-4 flex flex-col justify-between shadow-sm">
          <div className="space-y-3">
            <div className="flex items-start justify-between">
              <div className="flex items-center gap-2.5">
                <div className="w-9 h-9 rounded-xl bg-orange-500/10 border border-orange-500/20 flex items-center justify-center text-orange-400">
                  <Wallet className="w-5 h-5" />
                </div>
                <div>
                  <h2 className="text-xs font-bold text-white">Flutterwave Escrow & Virtual Accounts</h2>
                  <p className="text-[10px] text-slate-400">Dedicated Nigerian Virtual Bank Accounts & Payouts</p>
                </div>
              </div>

              <span className="text-[10px] px-2 py-0.5 rounded-full bg-orange-500/10 text-orange-300 border border-orange-500/30 font-semibold">
                Fintech Engine
              </span>
            </div>

            <div className="p-3 rounded-xl bg-slate-950/70 border border-slate-800 text-[11px] space-y-1 text-slate-300">
              <p>• Automatically provisions dynamic Wema/Providus virtual accounts for each property deal.</p>
              <p>• Automatically triggers instant landlord bank account payout upon key handover.</p>
            </div>

            {/* Webhook Endpoint Display */}
            <div className="space-y-1 text-xs">
              <label className="block text-slate-300 font-semibold text-[11px]">Flutterwave Webhook URL</label>
              <div className="flex items-center justify-between p-2 rounded-xl bg-slate-950 border border-slate-800 text-[10px] font-mono text-slate-300">
                <span className="truncate mr-2">{webhookUrl}</span>
                <button
                  onClick={handleCopyWebhook}
                  className="p-1 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 transition"
                  title="Copy Webhook URL"
                >
                  {copiedWebhook ? <Check className="w-3 h-3 text-emerald-400" /> : <Copy className="w-3 h-3" />}
                </button>
              </div>
            </div>

            {/* Test Generate Virtual Account */}
            <button
              onClick={handleTestFlutterwave}
              disabled={testingFlw}
              className="w-full py-2.5 rounded-xl bg-orange-600 hover:bg-orange-500 text-white font-bold text-xs shadow-md transition flex items-center justify-center gap-1.5 disabled:opacity-50"
            >
              {testingFlw ? <RefreshCw className="w-3.5 h-3.5 animate-spin" /> : <Zap className="w-3.5 h-3.5" />}
              <span>Test Generate Escrow Virtual Bank Account</span>
            </button>

            {/* Response Preview */}
            {flwResult && (
              <div className={`p-3 rounded-xl border text-[11px] font-mono space-y-1 ${
                flwResult.status 
                  ? 'bg-emerald-950/30 border-emerald-500/30 text-emerald-300' 
                  : 'bg-red-950/30 border-red-500/30 text-red-300'
              }`}>
                <div className="flex items-center justify-between font-sans font-bold">
                  <span>Virtual Account Generated:</span>
                  <span>{flwResult.status ? '✓ Active' : '✕ Failed'}</span>
                </div>
                {flwResult.data && (
                  <div className="pt-1 space-y-0.5 text-[10px]">
                    <div>Bank: {flwResult.data.bankName}</div>
                    <div>Account Number: <strong className="text-white text-xs">{flwResult.data.accountNumber}</strong></div>
                    <div>Expected Amount: ₦{(flwResult.data.amount || 0).toLocaleString()}</div>
                    <div>Reference: {flwResult.data.accountReference}</div>
                  </div>
                )}
                {flwResult.message && <div className="text-[10px] text-slate-400 font-sans">{flwResult.message}</div>}
              </div>
            )}
          </div>

          <div className="pt-3 border-t border-slate-800/80 flex items-center justify-between text-[11px] text-slate-400">
            <span>Docs: <a href="https://developer.flutterwave.com/" target="_blank" rel="noreferrer" className="text-orange-400 hover:underline inline-flex items-center gap-1">Flutterwave Developer Portal <ExternalLink className="w-2.5 h-2.5" /></a></span>
            <span className="text-emerald-400 font-medium">Ready in Environment</span>
          </div>
        </div>
      </div>
    </div>
  );
};
