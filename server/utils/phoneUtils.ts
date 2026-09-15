/**
 * Phone Number Utilities — International E.164 Standard Formatter & Validator
 * 
 * Enforces strict E.164 standards (+[CountryCode][SubscriberNumber])
 * Required by Twilio SMS API to prevent Error 21614 ('To' number is not a valid mobile number).
 */

/**
 * Validates whether a given string is a valid E.164 phone number.
 * E.164 format: starts with '+', followed by 1-3 digit country code, and subscriber number.
 * Total length between 8 and 15 digits (excluding '+').
 */
export function isValidE164(phone: string): boolean {
  if (!phone || typeof phone !== 'string') return false;
  const e164Regex = /^\+[1-9]\d{7,14}$/;
  if (!e164Regex.test(phone)) return false;

  // Specific Nigerian (+234) validation
  if (phone.startsWith('+234')) {
    return isValidNigerianMobile(phone);
  }

  return true;
}

/**
 * Validates that a Nigerian phone number is a genuine mobile number.
 * Nigerian mobile numbers must have exactly 10 digits after +234
 * and must start with mobile network prefixes: 7, 8, or 9 (e.g., 070, 071, 080, 081, 090, 091).
 */
export function isValidNigerianMobile(phone: string): boolean {
  if (!phone || typeof phone !== 'string') return false;
  // +234 followed by [7, 8, or 9] and 9 more digits = 14 chars total
  const nigerianMobileRegex = /^\+234[789][01]\d{8}$/;
  return nigerianMobileRegex.test(phone);
}

/**
 * Formats and sanitizes a raw phone number into strict E.164 format.
 * 
 * Rules:
 * 1. Strips all spaces, dashes, parentheses, dots, slashes, and non-numeric characters except leading '+'.
 * 2. If starts with '+2340', strips the domestic trunk '0' -> '+234...'.
 * 3. If starts with '2340', strips trunk '0' and prepends '+' -> '+234...'.
 * 4. If starts with '234' without '+', prepends '+' -> '+234...'.
 * 5. If starts with '0' (domestic Nigerian format, e.g. 080..., 090..., 070...), strips '0' and prepends defaultCountryCode ('+234').
 * 6. If exactly 10 digits starting with 7, 8, or 9 (e.g. 8012345678), prepends defaultCountryCode ('+234').
 * 7. If missing leading '+', prepends defaultCountryCode.
 * 8. Validates against E.164 regex (/^\+[1-9]\d{7,14}$/).
 * 9. For Nigerian numbers (+234), validates exact 10-digit mobile length and valid mobile prefix (07, 08, 09).
 * 
 * Throws Error if number is invalid.
 */
export function formatToE164(phone: string, defaultCountryCode: string = '+234'): string {
  if (!phone || typeof phone !== 'string') {
    throw new Error('Phone number must be a non-empty string.');
  }

  // 1. Remove all spaces, dashes, parentheses, dots, and special characters except '+'
  let cleaned = phone.trim().replace(/[^\d+]/g, '');

  if (!cleaned) {
    throw new Error('Phone number contains no digits.');
  }

  // Handle accidental double pluses like '++234...'
  if (cleaned.startsWith('++')) {
    cleaned = '+' + cleaned.replace(/^\++/, '');
  }

  // 2. Handle Nigerian phone prefix variations:
  // Case A: User entered '+234080...' (country code + local trunk 0)
  if (cleaned.startsWith('+2340')) {
    cleaned = '+234' + cleaned.substring(5);
  }
  // Case B: User entered '234080...' (country code without plus + local trunk 0)
  else if (cleaned.startsWith('2340')) {
    cleaned = '+234' + cleaned.substring(4);
  }
  // Case C: User entered '23480...' (country code without plus)
  else if (cleaned.startsWith('234') && !cleaned.startsWith('+')) {
    cleaned = '+' + cleaned;
  }
  // Case D: User entered standard local format '080...', '090...', '070...'
  else if (cleaned.startsWith('0')) {
    cleaned = defaultCountryCode + cleaned.substring(1);
  }
  // Case E: User entered 10 digits without leading zero (e.g. '8012345678')
  else if (!cleaned.startsWith('+') && cleaned.length === 10 && /^[789]/.test(cleaned)) {
    cleaned = defaultCountryCode + cleaned;
  }
  // Case F: Any other number without '+' -> prepend defaultCountryCode
  else if (!cleaned.startsWith('+')) {
    cleaned = defaultCountryCode + cleaned;
  }

  // 3. General E.164 standard check: starts with +, followed by 8 to 15 digits
  const e164Regex = /^\+[1-9]\d{7,14}$/;
  if (!e164Regex.test(cleaned)) {
    throw new Error(`Invalid E.164 mobile number format: "${phone}" (parsed as "${cleaned}"). Must start with '+' followed by 8 to 15 digits.`);
  }

  // 4. Strict Nigerian (+234) Mobile Validation:
  if (cleaned.startsWith('+234')) {
    const subscriberDigits = cleaned.substring(4); // digits after +234
    
    if (subscriberDigits.length !== 10) {
      throw new Error(
        `Invalid Nigerian mobile number length: must have exactly 10 digits after +234 (received ${subscriberDigits.length} digits in "${cleaned}"). Example: +2348012345678`
      );
    }

    // Must start with 7, 8, or 9 (standard Nigerian mobile lines: MTN, Airtel, Glo, 9mobile)
    if (!/^[789][01]\d{8}$/.test(subscriberDigits)) {
      throw new Error(
        `Invalid Nigerian mobile operator prefix in "${cleaned}". Nigerian mobile numbers must start with 070, 071, 080, 081, 090, or 091.`
      );
    }
  }

  return cleaned;
}

/**
 * Safe version of formatToE164 that returns an object instead of throwing.
 */
export function tryFormatToE164(
  phone: string,
  defaultCountryCode: string = '+234'
): { success: boolean; formatted?: string; error?: string } {
  try {
    const formatted = formatToE164(phone, defaultCountryCode);
    return { success: true, formatted };
  } catch (err: any) {
    return { success: false, error: err.message };
  }
}
