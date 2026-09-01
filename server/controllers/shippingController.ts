import type { Request, Response } from 'express';
import { ShippingService, create250kgToyManifest } from '../services/shippingService';
import type { ToyShipmentManifest } from '../services/shippingService';

export async function getToyManifest(req: Request, res: Response) {
  try {
    const packageType = (req.query.type as 'multi_piece_cartons' | 'palletized_freight') || 'multi_piece_cartons';
    const manifest = create250kgToyManifest(packageType);
    res.json({
      success: true,
      manifest
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function compareRates(req: Request, res: Response) {
  try {
    const packageType = (req.body.packageType as 'multi_piece_cartons' | 'palletized_freight') || 'multi_piece_cartons';
    const customManifest: ToyShipmentManifest = req.body.manifest || create250kgToyManifest(packageType);
    
    const keys = {
      shipEngineApiKey: req.body.shipEngineApiKey || (req.headers['x-shipengine-key'] as string),
      shippoToken: req.body.shippoToken || (req.headers['x-shippo-token'] as string),
      easyPostKey: req.body.easyPostKey || (req.headers['x-easypost-key'] as string),
      sendcloudPubKey: req.body.sendcloudPubKey || (req.headers['x-sendcloud-pub'] as string),
      sendcloudSecKey: req.body.sendcloudSecKey || (req.headers['x-sendcloud-sec'] as string)
    };

    const result = await ShippingService.compareAllProviders(customManifest, keys);
    res.json({
      success: true,
      ...result
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function getShipEngineRates(req: Request, res: Response) {
  try {
    const manifest = req.body.manifest || create250kgToyManifest(req.body.packageType);
    const key = req.body.apiKey || (req.headers['x-shipengine-key'] as string);
    const quotes = await ShippingService.queryShipEngine(manifest, key);
    res.json({ success: true, provider: 'ShipEngine', quotes });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function getShippoRates(req: Request, res: Response) {
  try {
    const manifest = req.body.manifest || create250kgToyManifest(req.body.packageType);
    const token = req.body.apiToken || (req.headers['x-shippo-token'] as string);
    const quotes = await ShippingService.queryShippo(manifest, token);
    res.json({ success: true, provider: 'Shippo', quotes });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function getEasyPostRates(req: Request, res: Response) {
  try {
    const manifest = req.body.manifest || create250kgToyManifest(req.body.packageType);
    const key = req.body.apiKey || (req.headers['x-easypost-key'] as string);
    const quotes = await ShippingService.queryEasyPost(manifest, key);
    res.json({ success: true, provider: 'EasyPost', quotes });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function getSendcloudRates(req: Request, res: Response) {
  try {
    const manifest = req.body.manifest || create250kgToyManifest(req.body.packageType);
    const pub = req.body.publicKey || (req.headers['x-sendcloud-pub'] as string);
    const sec = req.body.secretKey || (req.headers['x-sendcloud-sec'] as string);
    const quotes = await ShippingService.querySendcloud(manifest, pub, sec);
    res.json({ success: true, provider: 'Sendcloud', quotes });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

/**
 * Render Interactive HTML Test Portal
 */
export function renderShippingPortal(_req: Request, res: Response) {
  res.send(`
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>UK ➔ Dubai 250kg Toy Shipping Engine</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
  <style>
    body { font-family: 'Plus Jakarta Sans', sans-serif; background: #0b0f19; color: #f1f5f9; }
    .font-mono { font-family: 'JetBrains Mono', monospace; }
  </style>
</head>
<body class="min-h-screen p-4 md:p-8">
  <div class="max-w-6xl mx-auto space-y-8">
    
    <!-- Top Bar -->
    <header class="flex flex-col md:flex-row md:items-center justify-between gap-4 p-6 bg-slate-900/80 border border-slate-800 rounded-2xl backdrop-blur-xl shadow-2xl">
      <div>
        <div class="flex items-center gap-3">
          <span class="px-3 py-1 text-xs font-bold uppercase tracking-wider rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">Active Engine</span>
          <span class="px-3 py-1 text-xs font-bold uppercase tracking-wider rounded-full bg-blue-500/10 text-blue-400 border border-blue-500/20">Localhost Testbench</span>
        </div>
        <h1 class="text-2xl md:text-3xl font-extrabold text-white mt-2">UK ➔ Dubai 250kg Toy Shipping Engine</h1>
        <p class="text-slate-400 text-sm mt-1">Multi-Carrier Cross-Border Rate Simulator: Sendcloud • ShipEngine • Shippo • EasyPost</p>
      </div>
      <div class="flex items-center gap-3">
        <button onclick="runComparison()" id="btn-refresh" class="px-5 py-2.5 bg-gradient-to-r from-emerald-500 to-teal-600 hover:from-emerald-400 hover:to-teal-500 text-slate-950 font-bold text-sm rounded-xl transition-all shadow-lg shadow-emerald-500/20 flex items-center gap-2">
          <svg class="w-4 h-4 animate-spin hidden" id="spinner" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
          <span>Calculate / Compare Rates</span>
        </button>
      </div>
    </header>

    <!-- Manifest Summary Card -->
    <section class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <div class="lg:col-span-2 bg-slate-900/60 border border-slate-800/80 rounded-2xl p-6 space-y-6 shadow-xl">
        <div class="flex items-center justify-between border-b border-slate-800 pb-4">
          <h2 class="text-lg font-bold text-slate-200 flex items-center gap-2">
            📦 Consignment Manifest (250kg Toys)
          </h2>
          <select id="packaging-type" onchange="runComparison()" class="bg-slate-950 border border-slate-700 text-slate-200 text-xs font-semibold rounded-lg px-3 py-1.5 focus:outline-none focus:border-emerald-500">
            <option value="multi_piece_cartons">10 Master Cartons (25kg each)</option>
            <option value="palletized_freight">1 Euro Pallet (120x80x160cm)</option>
          </select>
        </div>

        <!-- Route & Details -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="bg-slate-950/60 border border-slate-800/60 rounded-xl p-4">
            <div class="text-xs uppercase font-bold text-slate-500 mb-1">Origin (Shipper)</div>
            <div class="text-sm font-semibold text-white">London Toy Exporters Ltd</div>
            <div class="text-xs text-slate-400 mt-1">142 High Holborn, London, WC1V 6PX, United Kingdom (GB)</div>
          </div>
          <div class="bg-slate-950/60 border border-slate-800/60 rounded-xl p-4">
            <div class="text-xs uppercase font-bold text-slate-500 mb-1">Destination (Consignee)</div>
            <div class="text-sm font-semibold text-white">Dubai Fun & Play Distribution LLC</div>
            <div class="text-xs text-slate-400 mt-1">Bay Square 07, Business Bay, Dubai, UAE (AE)</div>
          </div>
        </div>

        <!-- Commodity Items & HS Codes -->
        <div class="space-y-3">
          <div class="text-xs font-bold uppercase tracking-wider text-slate-400">Customs Declarations & HS Classification</div>
          <div class="divide-y divide-slate-800/80 border border-slate-800/80 rounded-xl overflow-hidden text-xs bg-slate-950/40">
            <div class="p-3 grid grid-cols-12 font-semibold text-slate-400 bg-slate-900/50">
              <div class="col-span-5">Item Description</div>
              <div class="col-span-2 text-center">HS Code</div>
              <div class="col-span-2 text-center">Qty / Weight</div>
              <div class="col-span-3 text-right">Declared Value</div>
            </div>
            <div class="p-3 grid grid-cols-12 items-center text-slate-300">
              <div class="col-span-5 font-medium text-white">STEM Building Block Sets (Plastic)</div>
              <div class="col-span-2 text-center font-mono text-emerald-400">9503.00.35</div>
              <div class="col-span-2 text-center">120 pcs (85kg)</div>
              <div class="col-span-3 text-right font-mono font-bold">£1,500.00</div>
            </div>
            <div class="p-3 grid grid-cols-12 items-center text-slate-300">
              <div class="col-span-5 font-medium text-white">Die-Cast Toy Vehicles & Racing Tracks</div>
              <div class="col-span-2 text-center font-mono text-emerald-400">9503.00.70</div>
              <div class="col-span-2 text-center">90 pcs (90kg)</div>
              <div class="col-span-3 text-right font-mono font-bold">£1,600.00</div>
            </div>
            <div class="p-3 grid grid-cols-12 items-center text-slate-300">
              <div class="col-span-5 font-medium text-white">Plush Stuffed Toys (Non-Electronic)</div>
              <div class="col-span-2 text-center font-mono text-emerald-400">9503.00.41</div>
              <div class="col-span-2 text-center">140 pcs (75kg)</div>
              <div class="col-span-3 text-right font-mono font-bold">£1,400.00</div>
            </div>
          </div>
        </div>
      </div>

      <!-- Quick Metrics Column -->
      <div class="bg-slate-900/60 border border-slate-800/80 rounded-2xl p-6 space-y-4 shadow-xl flex flex-col justify-between">
        <div>
          <h2 class="text-lg font-bold text-slate-200 mb-4 flex items-center gap-2">
            📊 Cargo Summary
          </h2>
          <div class="space-y-3 font-mono text-sm">
            <div class="flex justify-between p-3 bg-slate-950/60 rounded-xl border border-slate-800/60">
              <span class="text-slate-400">Actual Weight:</span>
              <span class="font-bold text-white" id="m-act-weight">250.0 kg</span>
            </div>
            <div class="flex justify-between p-3 bg-slate-950/60 rounded-xl border border-slate-800/60">
              <span class="text-slate-400">Volumetric Weight:</span>
              <span class="font-bold text-slate-300" id="m-vol-weight">192.0 kg</span>
            </div>
            <div class="flex justify-between p-3 bg-emerald-500/10 border border-emerald-500/20 rounded-xl">
              <span class="text-emerald-400 font-sans font-semibold">Chargeable Weight:</span>
              <span class="font-bold text-emerald-300 text-base" id="m-chg-weight">250.0 kg</span>
            </div>
            <div class="flex justify-between p-3 bg-slate-950/60 rounded-xl border border-slate-800/60">
              <span class="text-slate-400">Declared Value:</span>
              <span class="font-bold text-amber-400" id="m-val">£4,500.00 (AED 21,375)</span>
            </div>
          </div>
        </div>

        <div class="p-4 bg-slate-950/80 border border-slate-800 rounded-xl text-xs space-y-2">
          <div class="font-bold text-slate-300 flex items-center gap-1.5">
            <span>🇦🇪 UAE Import Customs Estimate:</span>
          </div>
          <div class="flex justify-between text-slate-400">
            <span>5% Customs Duty:</span>
            <span class="font-mono text-slate-200" id="m-duty">AED 1,068.75 (~£225.00)</span>
          </div>
          <div class="flex justify-between text-slate-400">
            <span>5% Import VAT:</span>
            <span class="font-mono text-slate-200" id="m-vat">AED 1,122.19 (~£236.25)</span>
          </div>
        </div>
      </div>
    </section>

    <!-- Side-by-Side Comparison Results -->
    <section class="space-y-4">
      <div class="flex items-center justify-between">
        <h2 class="text-xl font-extrabold text-white flex items-center gap-2">
          ⚡ Multi-Carrier Rate Comparison (UK ➔ Dubai)
        </h2>
        <span class="text-xs text-slate-400" id="rate-count">Showing 9 courier quotes</span>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5" id="quotes-container">
        <!-- Rendered by JS -->
      </div>
    </section>

    <!-- REST API Endpoints Quick Reference -->
    <section class="bg-slate-900/60 border border-slate-800/80 rounded-2xl p-6 space-y-4 shadow-xl">
      <h3 class="text-base font-bold text-slate-200">🚀 Available Localhost REST Endpoints for Testing</h3>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-3 font-mono text-xs">
        <div class="p-3 bg-slate-950 rounded-xl border border-slate-800">
          <span class="text-emerald-400 font-bold">GET</span> <span class="text-slate-300">/api/shipping/manifest</span>
          <p class="font-sans text-slate-400 text-xs mt-1">Returns full 250kg toy manifest with HS codes & packaging.</p>
        </div>
        <div class="p-3 bg-slate-950 rounded-xl border border-slate-800">
          <span class="text-blue-400 font-bold">POST</span> <span class="text-slate-300">/api/shipping/compare</span>
          <p class="font-sans text-slate-400 text-xs mt-1">Queries/simulates all 4 APIs and ranks rates by price/speed.</p>
        </div>
        <div class="p-3 bg-slate-950 rounded-xl border border-slate-800">
          <span class="text-amber-400 font-bold">POST</span> <span class="text-slate-300">/api/shipping/sendcloud</span>
          <p class="font-sans text-slate-400 text-xs mt-1">Direct Sendcloud UK to UAE shipping methods query.</p>
        </div>
        <div class="p-3 bg-slate-950 rounded-xl border border-slate-800">
          <span class="text-purple-400 font-bold">POST</span> <span class="text-slate-300">/api/shipping/shipengine</span>
          <p class="font-sans text-slate-400 text-xs mt-1">Direct ShipEngine international rate & multi-box engine.</p>
        </div>
      </div>
    </section>

  </div>

  <script>
    async function runComparison() {
      const type = document.getElementById('packaging-type').value;
      const btn = document.getElementById('btn-refresh');
      const spinner = document.getElementById('spinner');
      const container = document.getElementById('quotes-container');
      
      spinner.classList.remove('hidden');
      btn.disabled = true;

      try {
        const res = await fetch('/api/shipping/compare', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ packageType: type })
        });
        const data = await res.json();
        
        if (data.success) {
          const m = data.manifest;
          document.getElementById('m-act-weight').textContent = m.totalActualWeightKg + ' kg';
          document.getElementById('m-vol-weight').textContent = m.totalVolumetricWeightKg + ' kg';
          document.getElementById('m-chg-weight').textContent = m.chargeableWeightKg + ' kg';
          document.getElementById('m-val').textContent = '£' + m.totalDeclaredValueGbp.toLocaleString() + ' (AED ' + m.totalDeclaredValueAed.toLocaleString() + ')';
          
          document.getElementById('rate-count').textContent = 'Showing ' + data.quotes.length + ' courier quotes';

          container.innerHTML = data.quotes.map((q, idx) => {
            const isTop = idx === 0;
            return \`
              <div class="relative bg-slate-900/80 border \${isTop ? 'border-emerald-500/50 shadow-emerald-500/10' : 'border-slate-800/80'} rounded-2xl p-5 flex flex-col justify-between space-y-4 hover:border-slate-700 transition-all shadow-xl">
                \${isTop ? '<div class="absolute -top-3 right-4 px-2.5 py-0.5 bg-emerald-500 text-slate-950 font-bold text-[10px] uppercase tracking-wider rounded-full shadow-md">Cheapest Rate</div>' : ''}
                
                <div>
                  <div class="flex items-center justify-between mb-2">
                    <span class="text-xs font-bold uppercase tracking-wider px-2 py-0.5 rounded bg-slate-800 text-slate-300">\${q.provider} API</span>
                    <span class="text-xs font-semibold text-slate-400">\${q.carrier}</span>
                  </div>
                  <h4 class="font-bold text-white text-base leading-snug">\${q.serviceName}</h4>
                  <p class="text-xs text-slate-400 mt-1 flex items-center gap-1.5">
                    <span>⏱️ \${q.deliveryDays}</span> • <span>Est. \${q.estimatedDeliveryDate}</span>
                  </p>
                </div>

                <div class="space-y-2 border-t border-slate-800 pt-3 text-xs">
                  <div class="flex justify-between text-slate-400">
                    <span>Base Freight (\${m.chargeableWeightKg}kg):</span>
                    <span class="font-mono text-slate-200">£\${q.baseShippingCostGbp.toFixed(2)}</span>
                  </div>
                  <div class="flex justify-between text-slate-400">
                    <span>Fuel & Customs Clearance:</span>
                    <span class="font-mono text-slate-200">£\${(q.fuelSurchargeGbp + q.customsClearanceFeeGbp).toFixed(2)}</span>
                  </div>
                  <div class="flex justify-between items-baseline border-t border-slate-800/60 pt-2">
                    <span class="font-bold text-slate-200">Total Shipping:</span>
                    <div class="text-right">
                      <div class="font-mono font-extrabold text-lg text-emerald-400">£\${q.totalShippingCostGbp.toFixed(2)}</div>
                      <div class="font-mono text-[11px] text-slate-400">AED \${q.totalCostAed.toFixed(2)} / $\${q.totalCostUsd.toFixed(2)}</div>
                    </div>
                  </div>
                </div>

                <div class="text-[11px] text-slate-500 italic bg-slate-950/40 p-2 rounded-lg border border-slate-900">
                  \${q.notes}
                </div>
              </div>
            \`;
          }).join('');
        }
      } catch (err) {
        console.error(err);
      } finally {
        spinner.classList.add('hidden');
        btn.disabled = false;
      }
    }

    // Run automatically on page load
    window.addEventListener('DOMContentLoaded', runComparison);
  </script>
</body>
</html>
  `);
}
