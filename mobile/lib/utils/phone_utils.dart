/// International E.164 Phone Number Formatter & Validator
///
/// Ensures all phone numbers passed to API endpoints and SMS dispatch rails
/// adhere strictly to the E.164 standard (+[CountryCode][SubscriberNumber]).
class PhoneUtils {
  /// Formats and sanitizes a raw phone number string into strict E.164 format.
  /// Throws [FormatException] if the phone number cannot be converted into a valid E.164 mobile number.
  static String formatToE164(String phone, {String defaultCountryCode = '+234'}) {
    if (phone.trim().isEmpty) {
      throw const FormatException('Phone number cannot be empty.');
    }

    // 1. Remove all spaces, dashes, parentheses, dots, and non-numeric characters except '+'
    var cleaned = phone.trim().replaceAll(RegExp(r'[^\d+]'), '');

    if (cleaned.isEmpty) {
      throw const FormatException('Phone number contains no numeric digits.');
    }

    // Strip accidental duplicate '+' prefixes like '++234...'
    if (cleaned.startsWith('++')) {
      cleaned = '+${cleaned.replaceFirst(RegExp(r'^\++'), '')}';
    }

    // 2. Handle Nigerian prefix variations
    if (cleaned.startsWith('+2340')) {
      cleaned = '+234${cleaned.substring(5)}';
    } else if (cleaned.startsWith('2340')) {
      cleaned = '+234${cleaned.substring(4)}';
    } else if (cleaned.startsWith('234') && !cleaned.startsWith('+')) {
      cleaned = '+$cleaned';
    } else if (cleaned.startsWith('0')) {
      cleaned = defaultCountryCode + cleaned.substring(1);
    } else if (!cleaned.startsWith('+') && cleaned.length == 10 && RegExp(r'^[789]').hasMatch(cleaned)) {
      cleaned = defaultCountryCode + cleaned;
    } else if (!cleaned.startsWith('+')) {
      cleaned = defaultCountryCode + cleaned;
    }

    // 3. E.164 standard check: starts with +, followed by 8 to 15 digits
    final e164Regex = RegExp(r'^\+[1-9]\d{7,14}$');
    if (!e164Regex.hasMatch(cleaned)) {
      throw FormatException('Invalid E.164 mobile number format: $phone');
    }

    // 4. Strict Nigerian (+234) Mobile Validation
    if (cleaned.startsWith('+234')) {
      final subscriberDigits = cleaned.substring(4);
      if (subscriberDigits.length != 10) {
        throw FormatException(
          'Nigerian mobile numbers must have exactly 10 digits after +234 (received ${subscriberDigits.length}). Example: +2348012345678',
        );
      }

      if (!RegExp(r'^[789][01]\d{8}$').hasMatch(subscriberDigits)) {
        throw FormatException(
          'Invalid Nigerian mobile network prefix in $cleaned. Mobile numbers must start with 070, 071, 080, 081, 090, or 091.',
        );
      }
    }

    return cleaned;
  }

  /// Safe helper that returns null instead of throwing on invalid input
  static String? tryFormatToE164(String? phone, {String defaultCountryCode = '+234'}) {
    if (phone == null || phone.trim().isEmpty) return null;
    try {
      return formatToE164(phone, defaultCountryCode: defaultCountryCode);
    } catch (_) {
      return null;
    }
  }

  /// Checks if a string is a valid E.164 phone number
  static bool isValidE164(String? phone) {
    if (phone == null || phone.trim().isEmpty) return false;
    final clean = phone.trim();
    final e164Regex = RegExp(r'^\+[1-9]\d{7,14}$');
    if (!e164Regex.hasMatch(clean)) return false;

    if (clean.startsWith('+234')) {
      return isValidNigerianMobile(clean);
    }
    return true;
  }

  /// Checks if a Nigerian number is a genuine mobile number
  static bool isValidNigerianMobile(String? phone) {
    if (phone == null || phone.trim().isEmpty) return false;
    return RegExp(r'^\+234[789][01]\d{8}$').hasMatch(phone.trim());
  }
}
