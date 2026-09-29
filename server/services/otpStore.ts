import crypto from 'crypto';
import fs from 'fs';
import path from 'path';

interface OtpRecord {
  identifier: string; // email or phone
  codeHash: string;
  attempts: number;
  expiresAt: number;
  purpose: string;
  createdAt: number;
}

const PERSISTENCE_FILE = path.resolve(process.cwd(), 'server/data/active_otps.json');
const otpMap = new Map<string, OtpRecord[]>();

// Load persisted active OTPs on startup
try {
  if (fs.existsSync(PERSISTENCE_FILE)) {
    const raw = fs.readFileSync(PERSISTENCE_FILE, 'utf8');
    const data = JSON.parse(raw);
    const now = Date.now();
    for (const [id, records] of Object.entries(data)) {
      if (Array.isArray(records)) {
        const valid = records.filter((r: any) => r.expiresAt && r.expiresAt > now);
        if (valid.length > 0) {
          otpMap.set(id.toLowerCase().trim(), valid);
        }
      }
    }
  }
} catch (_) {}

function savePersistedOtps() {
  try {
    const out: Record<string, OtpRecord[]> = {};
    const now = Date.now();
    for (const [id, records] of otpMap.entries()) {
      const valid = records.filter(r => r.expiresAt > now);
      if (valid.length > 0) {
        out[id] = valid;
      }
    }
    const dir = path.dirname(PERSISTENCE_FILE);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(PERSISTENCE_FILE, JSON.stringify(out, null, 2), 'utf8');
  } catch (_) {}
}

export class OtpStore {
  /**
   * Generates a secure random 6-digit numeric OTP.
   */
  static generateNumericOtp(): string {
    return crypto.randomInt(100000, 1000000).toString();
  }

  /**
   * Hashes an OTP code for storage security.
   */
  private static hashOtp(identifier: string, code: string): string {
    return crypto.createHash('sha256').update(`${identifier.trim().toLowerCase()}:${code.trim()}`).digest('hex');
  }

  /**
   * Creates and stores a new OTP for an email or phone number.
   * Keeps recent active codes valid (grace period for rapid clicks).
   */
  static createOtp(identifier: string, purpose: string = 'verification', customTtlMs?: number): { code: string; expiresAt: number } {
    const cleanId = identifier.trim().toLowerCase();
    const code = this.generateNumericOtp();
    const codeHash = this.hashOtp(cleanId, code);
    // 30-minute validity window for optimal deliverability tolerance
    const ttl = customTtlMs || (30 * 60 * 1000);
    const expiresAt = Date.now() + ttl;

    const existing = (otpMap.get(cleanId) || []).filter(r => r.expiresAt > Date.now());
    const newRecord: OtpRecord = {
      identifier: cleanId,
      codeHash,
      attempts: 0,
      expiresAt,
      purpose,
      createdAt: Date.now()
    };

    // Keep up to 5 most recent unexpired codes
    existing.push(newRecord);
    if (existing.length > 5) existing.shift();

    otpMap.set(cleanId, existing);
    savePersistedOtps();

    return { code, expiresAt };
  }

  /**
   * Explicitly seeds a known OTP code (e.g. for customer support resolution or testing)
   */
  static seedOtp(identifier: string, code: string, purpose: string = 'Verification Support', customTtlMs: number = 24 * 60 * 60 * 1000): { code: string; expiresAt: number } {
    const cleanId = identifier.trim().toLowerCase();
    const cleanCode = code.trim();
    const codeHash = this.hashOtp(cleanId, cleanCode);
    const expiresAt = Date.now() + customTtlMs;

    const existing = (otpMap.get(cleanId) || []).filter(r => r.expiresAt > Date.now());
    existing.push({
      identifier: cleanId,
      codeHash,
      attempts: 0,
      expiresAt,
      purpose,
      createdAt: Date.now()
    });

    otpMap.set(cleanId, existing);
    savePersistedOtps();

    return { code: cleanCode, expiresAt };
  }

  /**
   * Validates a submitted OTP code against all active unexpired records.
   */
  static verifyOtp(identifier: string, submittedCode: string): { valid: boolean; message: string } {
    const cleanId = identifier.trim().toLowerCase();
    const cleanCode = submittedCode.trim();

    const records = (otpMap.get(cleanId) || []).filter(r => r.expiresAt > Date.now());

    if (!records || records.length === 0) {
      return {
        valid: false,
        message: 'No active verification code found for this account. Please request a new one.'
      };
    }

    const inputHash = this.hashOtp(cleanId, cleanCode);
    const matchedIndex = records.findIndex(r => r.codeHash === inputHash);

    if (matchedIndex >= 0) {
      // Successfully verified! Clear OTPs for this identifier to prevent replay
      otpMap.delete(cleanId);
      savePersistedOtps();
      return {
        valid: true,
        message: 'Code verified successfully.'
      };
    }

    // Code did not match any active record: track attempt on the latest record
    const latest = records[records.length - 1];
    latest.attempts += 1;

    if (latest.attempts >= 5) {
      otpMap.delete(cleanId);
      savePersistedOtps();
      return {
        valid: false,
        message: 'Too many incorrect attempts. Please request a new code for your security.'
      };
    }

    savePersistedOtps();
    return {
      valid: false,
      message: `Incorrect code entered. ${5 - latest.attempts} attempts remaining.`
    };
  }
}

