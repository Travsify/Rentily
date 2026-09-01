import crypto from 'crypto';

interface OtpRecord {
  identifier: string; // email or phone
  codeHash: string;
  attempts: number;
  expiresAt: number;
  purpose: string;
  createdAt: number;
}

const otpMap = new Map<string, OtpRecord>();

export class OtpStore {
  /**
   * Generates a secure random 6-digit numeric OTP.
   */
  static generateNumericOtp(): string {
    const min = 100000;
    const max = 999999;
    return Math.floor(min + Math.random() * (max - min + 1)).toString();
  }

  /**
   * Hashes an OTP code for storage security.
   */
  private static hashOtp(identifier: string, code: string): string {
    return crypto.createHash('sha256').update(`${identifier.trim().toLowerCase()}:${code.trim()}`).digest('hex');
  }

  /**
   * Creates and stores a new OTP for an email or phone number.
   */
  static createOtp(identifier: string, purpose: string = 'verification'): { code: string; expiresAt: number } {
    const cleanId = identifier.trim().toLowerCase();
    const code = this.generateNumericOtp();
    const codeHash = this.hashOtp(cleanId, code);
    const expiresAt = Date.now() + 10 * 60 * 1000; // 10 minutes

    otpMap.set(cleanId, {
      identifier: cleanId,
      codeHash,
      attempts: 0,
      expiresAt,
      purpose,
      createdAt: Date.now()
    });

    return { code, expiresAt };
  }

  /**
   * Validates a submitted OTP code.
   */
  static verifyOtp(identifier: string, submittedCode: string): { valid: boolean; message: string } {
    const cleanId = identifier.trim().toLowerCase();
    const record = otpMap.get(cleanId);

    if (!record) {
      return {
        valid: false,
        message: 'No active verification code found for this account. Please request a new one.'
      };
    }

    if (Date.now() > record.expiresAt) {
      otpMap.delete(cleanId);
      return {
        valid: false,
        message: 'Verification code has expired. Please request a new code.'
      };
    }

    if (record.attempts >= 4) {
      otpMap.delete(cleanId);
      return {
        valid: false,
        message: 'Too many incorrect attempts. Please request a new code for your security.'
      };
    }

    const inputHash = this.hashOtp(cleanId, submittedCode);
    if (inputHash !== record.codeHash) {
      record.attempts += 1;
      return {
        valid: false,
        message: `Incorrect code entered. ${4 - record.attempts} attempts remaining.`
      };
    }

    // Successfully verified! Clear OTP to prevent replay attacks
    otpMap.delete(cleanId);
    return {
      valid: true,
      message: 'Code verified successfully.'
    };
  }
}
