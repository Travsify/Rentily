class IdUtils {
  /// Generates a standardized ops ID with at most 3 alphanumeric characters e.g. RNT-7A9, RNT-B01, RNT-K22
  static String formatOpsId(String? userId, {bool isPartner = false}) {
    if (userId == null || userId.isEmpty) {
      return isPartner ? 'RNT-P01' : 'RNT-L01';
    }
    // Remove all non-alphanumeric chars and capitalize
    final clean = userId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (clean.length >= 3) {
      return 'RNT-${clean.substring(0, 3)}';
    }
    return 'RNT-${clean.padRight(3, 'X')}';
  }
}
