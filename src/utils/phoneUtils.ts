/**
 * International E.164 Phone Number Formatter & Validator (Frontend)
 *
 * Ensures all phone numbers passed to API endpoints and SMS dispatch rails
 * strictly adhere to international E.164 standard (+[CountryCode][SubscriberNumber]).
 */

export function isValidNigerianMobile(phone: string): boolean {
  if (!phone || typeof phone !== 'string') return false;
  const nigerianMobileRegex = /^\+234[789][01]\d{8}$/;
  return nigerianMobileRegex.test(phone.trim());
}

export function isValidE164(phone: string): boolean {
  if (!phone || typeof phone !== 'string') return false;
  const clean = phone.trim();
  const e164Regex = /^\+[1-9]\d{7,14}$/;
  if (!e164Regex.test(clean)) return false;

  if (clean.startsWith('+234')) {
    return isValidNigerianMobile(clean);
  }
  return true;
}

export function formatToE164(phone: string, defaultCountryCode: string = '+234'): string {
  if (!phone || typeof phone !== 'string') {
    throw new Error('Phone number must be a non-empty string.');
  }

  let cleaned = phone.trim().replace(/[^\d+]/g, '');

  if (!cleaned) {
    throw new Error('Phone number contains no numeric digits.');
  }

  if (cleaned.startsWith('++')) {
    cleaned = '+' + cleaned.replace(/^\++/, '');
  }

  // Handle Nigerian prefix variations
  if (cleaned.startsWith('+2340')) {
    cleaned = '+234' + cleaned.substring(5);
  } else if (cleaned.startsWith('2340')) {
    cleaned = '+234' + cleaned.substring(4);
  } else if (cleaned.startsWith('234') && !cleaned.startsWith('+')) {
    cleaned = '+' + cleaned;
  } else if (cleaned.startsWith('0')) {
    cleaned = defaultCountryCode + cleaned.substring(1);
  } else if (!cleaned.startsWith('+') && cleaned.length === 10 && /^[789]/.test(cleaned)) {
    cleaned = defaultCountryCode + cleaned;
  } else if (!cleaned.startsWith('+')) {
    cleaned = defaultCountryCode + cleaned;
  }

  const e164Regex = /^\+[1-9]\d{7,14}$/;
  if (!e164Regex.test(cleaned)) {
    throw new Error(`Invalid E.164 mobile number format: "${phone}"`);
  }

  if (cleaned.startsWith('+234')) {
    const subscriberDigits = cleaned.substring(4);
    if (subscriberDigits.length !== 10) {
      throw new Error(
        `Invalid Nigerian mobile number length: must have exactly 10 digits after +234 (received ${subscriberDigits.length}). Example: +2348012345678`
      );
    }
    if (!/^[789][01]\d{8}$/.test(subscriberDigits)) {
      throw new Error(
        `Invalid Nigerian mobile operator prefix in "${cleaned}". Mobile numbers must start with 070, 071, 080, 081, 090, or 091.`
      );
    }
  }

  return cleaned;
}

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
