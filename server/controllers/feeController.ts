import type { Request, Response } from 'express';
import fs from 'fs';
import path from 'path';

export interface PlatformFeeConfig {
  withdrawalFee: number;            // ₦ flat fee on bank withdrawals (default 50)
  electricityFee: number;           // ₦ convenience fee on Disco tokens (default 100)
  airtimeDataMarginPct: number;     // % margin on airtime/data (default 2.5)
  rentLegalFeePct: number;          // % on rent leases (default 10)
  saleEscrowFeePct: number;         // % on sales (default 5)
  partnerCommissionRentPct: number; // % partner commission rent (default 2.5)
  partnerCommissionSalePct: number; // % partner commission sale (default 2.0)
  depositStampDuty: number;         // ₦ stamp duty on deposits (default 50)
  minWithdrawal: number;            // ₦ minimum bank withdrawal (default 500)
  maxWithdrawal: number;            // ₦ maximum daily withdrawal (default 5000000)
  updatedAt: string;
}

const DEFAULT_FEES: PlatformFeeConfig = {
  withdrawalFee: 50,
  electricityFee: 100,
  airtimeDataMarginPct: 2.5,
  rentLegalFeePct: 10.0,
  saleEscrowFeePct: 5.0,
  partnerCommissionRentPct: 2.5,
  partnerCommissionSalePct: 2.0,
  depositStampDuty: 50,
  minWithdrawal: 500,
  maxWithdrawal: 5000000,
  updatedAt: new Date().toISOString()
};

function getFeeFilePath(): string {
  const candidates = [
    path.join(process.cwd(), 'server', 'data'),
    path.join('/opt/render/project/src', 'server', 'data'),
    path.join('/tmp', 'rentilly-data'),
  ];
  for (const dir of candidates) {
    try {
      if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
      return path.join(dir, 'platform_fees.json');
    } catch { continue; }
  }
  return path.join('/tmp', 'platform_fees.json');
}

let _feeCache: PlatformFeeConfig | null = null;

export function getStoredFees(): PlatformFeeConfig {
  if (_feeCache) return _feeCache;
  try {
    const file = getFeeFilePath();
    if (fs.existsSync(file)) {
      const data = JSON.parse(fs.readFileSync(file, 'utf-8'));
      _feeCache = { ...DEFAULT_FEES, ...data };
      return _feeCache!;
    }
  } catch (_) {}
  _feeCache = { ...DEFAULT_FEES };
  return _feeCache!;
}

export function saveStoredFees(fees: PlatformFeeConfig): void {
  _feeCache = fees;
  try {
    const file = getFeeFilePath();
    fs.writeFileSync(file, JSON.stringify(fees, null, 2), 'utf-8');
  } catch (err) {
    console.error('Failed to save platform fees to disk:', err);
  }
}

export function getFees(_req: Request, res: Response) {
  const fees = getStoredFees();
  res.json({ success: true, fees });
}

export function updateFees(req: Request, res: Response) {
  try {
    const current = getStoredFees();
    const updated: PlatformFeeConfig = {
      ...current,
      ...req.body,
      updatedAt: new Date().toISOString()
    };
    saveStoredFees(updated);
    res.json({ success: true, message: 'Platform fees updated successfully', fees: updated });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}
