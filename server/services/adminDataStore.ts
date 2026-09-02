import fs from 'fs';
import path from 'path';
import type { Property, KYPRecord, Inspection, LegalAgreement, Transaction } from '../types';

// DATA_DIR: try multiple candidate paths, use first writable one
function getDataDir(): string {
  const candidates = [
    path.join(process.cwd(), 'server', 'data'),
    path.join('/opt/render/project/src', 'server', 'data'),
    path.join('/tmp', 'rentilly-data'),
  ];
  for (const dir of candidates) {
    try {
      if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
      fs.writeFileSync(path.join(dir, '.write_test'), 'ok', 'utf-8');
      fs.unlinkSync(path.join(dir, '.write_test'));
      return dir;
    } catch { continue; }
  }
  return '/tmp';
}

let _DATA_DIR: string | null = null;
function DATA_DIR(): string {
  if (!_DATA_DIR) _DATA_DIR = getDataDir();
  return _DATA_DIR;
}

// In-memory cache — primary source of truth within this process lifetime
const _memCache: Record<string, any[]> = {};

function readFile<T>(filename: string): T[] {
  // 1. In-memory cache (fastest)
  if (_memCache[filename]) {
    return _memCache[filename] as T[];
  }
  // 2. Disk
  try {
    const filePath = path.join(DATA_DIR(), filename);
    if (fs.existsSync(filePath)) {
      const parsed = JSON.parse(fs.readFileSync(filePath, 'utf-8') || '[]');
      if (Array.isArray(parsed)) {
        _memCache[filename] = parsed;
        return parsed as T[];
      }
    }
  } catch { /* disk unavailable */ }
  // 3. Default empty array (no mock data)
  _memCache[filename] = [];
  return [];
}

function writeFile<T>(filename: string, data: T[]): void {
  _memCache[filename] = data; // always update in-memory
  try { fs.writeFileSync(path.join(DATA_DIR(), filename), JSON.stringify(data, null, 2), 'utf-8'); } catch { /* read-only */ }
}

// ============================================================
// ADMIN DATA STORE — Unified Real-Time Access Layer (No Mock Data)
// ============================================================
export class AdminDataStore {

  // PROPERTIES
  static getProperties(): Property[] {
    return readFile<Property>('admin_properties.json');
  }

  static saveProperties(data: Property[]): void {
    writeFile('admin_properties.json', data);
  }

  static addProperty(p: Property): Property {
    const all = this.getProperties();
    // Prevent duplicate entries
    const existingIdx = all.findIndex(item => item.id === p.id);
    if (existingIdx >= 0) {
      all[existingIdx] = { ...all[existingIdx], ...p, updatedAt: new Date().toISOString() };
    } else {
      all.unshift(p);
    }
    this.saveProperties(all);
    return p;
  }

  static updatePropertyStatus(id: string, status: Property['status']): Property | null {
    const all = this.getProperties();
    const idx = all.findIndex(p => p.id === id);
    if (idx === -1) return null;
    all[idx] = { ...all[idx], status, updatedAt: new Date().toISOString() };
    this.saveProperties(all);
    return all[idx];
  }

  // KYP RECORDS
  static getKYP(status?: string): KYPRecord[] {
    const all = readFile<KYPRecord>('admin_kyp.json');
    if (status) return all.filter(k => k.status === status);
    return all;
  }

  static addKYP(record: KYPRecord): KYPRecord {
    const all = readFile<KYPRecord>('admin_kyp.json');
    const existingIdx = all.findIndex(item => item.id === record.id || item.propertyId === record.propertyId);
    if (existingIdx >= 0) {
      all[existingIdx] = { ...all[existingIdx], ...record };
    } else {
      all.unshift(record);
    }
    writeFile('admin_kyp.json', all);
    return record;
  }

  static reviewKYP(id: string, status: KYPRecord['status'], notes?: string, reason?: string): KYPRecord | null {
    const all = readFile<KYPRecord>('admin_kyp.json');
    const idx = all.findIndex(k => k.id === id);
    if (idx === -1) return null;
    all[idx] = {
      ...all[idx],
      status,
      landRegistrySearchNotes: notes || all[idx].landRegistrySearchNotes,
      rejectionReason: reason,
      reviewedBy: 'Rentilly Admin',
      reviewedAt: new Date().toISOString(),
    };
    writeFile('admin_kyp.json', all);
    return all[idx];
  }

  // INSPECTIONS
  static getInspections(): Inspection[] {
    return readFile<Inspection>('admin_inspections.json');
  }

  static addInspection(insp: Inspection): Inspection {
    const all = this.getInspections();
    const existingIdx = all.findIndex(item => item.id === insp.id);
    if (existingIdx >= 0) {
      all[existingIdx] = { ...all[existingIdx], ...insp };
    } else {
      all.unshift(insp);
    }
    writeFile('admin_inspections.json', all);
    return insp;
  }

  static updateInspectionStatus(id: string, status: Inspection['status'], ownerNotes?: string): Inspection | null {
    const all = this.getInspections();
    const idx = all.findIndex(i => i.id === id);
    if (idx === -1) return null;
    all[idx] = { ...all[idx], status, ownerNotes: ownerNotes || all[idx].ownerNotes };
    writeFile('admin_inspections.json', all);
    return all[idx];
  }

  // LEGAL AGREEMENTS
  static getLegalAgreements(): LegalAgreement[] {
    return readFile<LegalAgreement>('admin_legal.json');
  }

  static addLegalAgreement(a: LegalAgreement): LegalAgreement {
    const all = this.getLegalAgreements();
    const existingIdx = all.findIndex(item => item.id === a.id);
    if (existingIdx >= 0) {
      all[existingIdx] = { ...all[existingIdx], ...a };
    } else {
      all.unshift(a);
    }
    writeFile('admin_legal.json', all);
    return a;
  }

  // ESCROW & ALL ORDERS/TRANSACTIONS — built from live WalletTransactions in TransactionStore
  static buildEscrowTransactions(walletTxs: Array<any>): Transaction[] {
    return walletTxs.map(tx => {
      const isDeposit = tx.isCredit === true;
      const isEscrow = tx.category === 'escrow' || tx.category === 'rent';
      const isPayout = tx.category === 'withdrawal';
      const isUtility = tx.category === 'utility';

      let displayTitle = tx.title || 'Inbound Transaction';
      if (isPayout) {
        displayTitle = `Payout: ${tx.recipientAccount || 'Bank Transfer'}`;
      } else if (isUtility) {
        displayTitle = `Utility Payment (${tx.type || 'Disco/Airtime'})`;
      }

      // If transaction has an explicit escrowStatus, respect it
      let escrowStatus: 'held_in_escrow' | 'released_to_owner' | 'refunded' | 'disputed' = 'held_in_escrow';
      if (tx.escrowStatus) {
        escrowStatus = tx.escrowStatus;
      } else if (!isDeposit) {
        escrowStatus = 'released_to_owner';
      }

      return {
        id: tx.id,
        propertyId: tx.propertyId || 'wallet_ops',
        propertyTitle: displayTitle,
        payerId: tx.userId || tx.email,
        payerName: tx.sender || tx.email,
        ownerId: tx.userId || tx.email,
        ownerName: tx.beneficiary || tx.email,
        transactionType: (isEscrow ? 'rent' : 'sale') as 'rent' | 'sale',
        paymentReference: tx.reference || tx.id,
        paymentGateway: (isPayout ? 'paystack' : 'flutterwave') as any,
        baseAmount: tx.amount,
        rentillyLegalFee: Math.round(tx.amount * 0.1),
        cautionFee: 0,
        serviceCharge: 0,
        totalAmount: tx.amount,
        escrowStatus,
        ownerPayoutReference: tx.ownerPayoutReference,
        payoutReleasedAt: tx.payoutReleasedAt,
        createdAt: tx.date || new Date().toISOString(),
      };
    });
  }
}
