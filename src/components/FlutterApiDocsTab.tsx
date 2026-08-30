import React, { useState } from 'react';
import { 
  Copy, 
  Check, 
  Sparkles
} from 'lucide-react';

export const FlutterApiDocsTab: React.FC = () => {
  const [copiedIndex, setCopiedIndex] = useState<number | null>(null);

  const copyToClipboard = (text: string, index: number) => {
    navigator.clipboard.writeText(text);
    setCopiedIndex(index);
    setTimeout(() => setCopiedIndex(null), 2000);
  };

  const endpoints = [
    {
      method: 'GET',
      path: '/api/properties',
      description: 'Fetch verified properties for Flutter home & search feed (with filters: purpose=rent|sale, state=Lagos|Abuja)',
      sampleResponse: `[
  {
    "id": "prop-lekki-01",
    "title": "Luxury 3-Bedroom Serviced Apartment in Lekki Phase 1",
    "purpose": "rent",
    "basePrice": 4500000,
    "cautionFee": 400000,
    "serviceCharge": 500000,
    "rentillyFee": 450000,
    "totalInitialPayment": 5850000,
    "neighborhood": "Lekki Phase 1",
    "state": "Lagos",
    "status": "verified",
    "images": ["https://..."]
  }
]`
    },
    {
      method: 'POST',
      path: '/api/properties',
      description: 'Direct property owner creates listing & auto-queues for KYP verification with uploaded C of O / NIN',
      samplePayload: `{
  "title": "Contemporary 4-Bedroom Duplex",
  "purpose": "rent",
  "basePrice": 6000000,
  "cautionFee": 500000,
  "serviceCharge": 800000,
  "address": "Plot 20, Admiralty Way",
  "state": "Lagos",
  "neighborhood": "Lekki Phase 1",
  "titleDocumentType": "governors_consent",
  "titleDocumentNumber": "VOL-55/PAGE-200/LAGOS",
  "ownerIdType": "NIN",
  "ownerIdNumber": "57291830492",
  "discoProvider": "EKEDC",
  "discoMeterNumber": "04192837461"
}`
    },
    {
      method: 'POST',
      path: '/api/inspections/book',
      description: 'Prospect schedules inspection with owner; generates 6-digit security gate pass code',
      samplePayload: `{
  "propertyId": "prop-lekki-01",
  "scheduledDate": "2026-09-02",
  "scheduledTimeSlot": "11:00 AM - 12:00 PM",
  "prospectName": "Femi Adesanya",
  "prospectPhone": "+234 812 345 6789",
  "prospectNotes": "Moving from Victoria Island"
}`
    },
    {
      method: 'POST',
      path: '/api/legal/generate-agreement',
      description: 'Generates Nigerian Tenancy Agreement pursuant to Lagos Tenancy Law 2011 / FCT Laws with dynamic digital signature fields',
      samplePayload: `{
  "propertyId": "prop-lekki-01",
  "tenantId": "usr-renter-01",
  "tenantName": "Femi Adesanya",
  "commencementDate": "2026-09-15",
  "durationMonths": 12
}`
    },
    {
      method: 'POST',
      path: '/api/escrow/:id/release-payout',
      description: 'Release escrow funds to landlord upon key handover & auto-delists property from mobile feed',
      sampleResponse: `{
  "status": "success",
  "ownerPayoutReference": "PAYOUT-RENTILLY-1725000000",
  "propertyStatus": "rented",
  "delistedAt": "2026-08-30T10:00:00Z"
}`
    }
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="p-6 rounded-2xl bg-gradient-to-r from-emerald-950 via-slate-900 to-slate-900 border border-emerald-500/30 flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div className="space-y-1">
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 text-xs font-semibold">
            <Sparkles className="w-3.5 h-3.5" />
            <span>Ready for Flutter App Integration</span>
          </div>
          <h1 className="text-xl font-bold text-white">Flutter Mobile Client API Contracts</h1>
          <p className="text-xs text-slate-300">
            Clean REST endpoints designed for rapid Dart/Flutter integration (Dio / http / Supabase Dart SDK).
          </p>
        </div>

        <div className="p-3 bg-slate-950/80 rounded-xl border border-slate-800 text-xs font-mono text-emerald-400">
          Base API: http://localhost:4000/api
        </div>
      </div>

      {/* Endpoints List */}
      <div className="space-y-4">
        {endpoints.map((ep, idx) => (
          <div key={idx} className="p-5 rounded-2xl bg-slate-900 border border-slate-800 space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <span
                  className={`text-xs font-mono font-bold px-2.5 py-1 rounded-lg ${
                    ep.method === 'GET'
                      ? 'bg-blue-500/20 text-blue-300 border border-blue-500/30'
                      : 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/30'
                  }`}
                >
                  {ep.method}
                </span>
                <span className="font-mono text-sm font-bold text-white">{ep.path}</span>
              </div>

              <button
                onClick={() => copyToClipboard(ep.samplePayload || ep.sampleResponse || '', idx)}
                className="px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold flex items-center gap-1.5 transition"
              >
                {copiedIndex === idx ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
                <span>{copiedIndex === idx ? 'Copied JSON' : 'Copy Sample'}</span>
              </button>
            </div>

            <p className="text-xs text-slate-400">{ep.description}</p>

            <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 font-mono text-[11px] text-slate-300 overflow-x-auto">
              <pre>{ep.samplePayload ? `// Request Body:\n${ep.samplePayload}` : `// Response Body:\n${ep.sampleResponse}`}</pre>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};
