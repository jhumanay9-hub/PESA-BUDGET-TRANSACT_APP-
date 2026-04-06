/// ============================================================================
/// VENDOR SIGNATURE NORMALIZER
/// ============================================================================
/// This utility cleans vendor names to ensure consistent pattern matching.
///
/// Examples:
/// - "NAIVAS SUPERMARKET" -> "naivas"
/// - "Kenya Power (KPLC)" -> "kenya power"
/// - "Car & General Ltd" -> "car general"
/// - "M-PESA Payment - Naivas" -> "naivas"
/// ============================================================================
library;

class VendorSignature {
  /// Normalize vendor name for pattern matching
  /// Returns a clean, consistent signature
  static String normalize(String vendorName) {
    if (vendorName.isEmpty) return 'unknown';

    String signature = vendorName.trim().toLowerCase();

    // Remove common prefixes/suffixes that don't identify the vendor
    signature = _removeCommonPatterns(signature);

    // Remove special characters except spaces and hyphens
    signature = signature.replaceAll(RegExp(r'[^\w\s\-]'), ' ');

    // Remove extra whitespace
    signature = signature.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Remove common business terms that don't identify the vendor
    signature = _removeBusinessTerms(signature);

    // If signature is too short, use original (normalized)
    if (signature.length < 2) {
      return vendorName.toLowerCase().trim();
    }

    return signature;
  }

  /// Remove common M-PESA patterns
  static String _removeCommonPatterns(String text) {
    String result = text;

    // Remove M-PESA prefixes
    result = result.replaceAll(RegExp(r'^m-?pesa\s*'), '');
    result = result.replaceAll(RegExp(r'^mpesa\s*'), '');

    // Remove payment/transaction terms
    result = result.replaceAll(RegExp(r'\s*payment\s*'), ' ');
    result = result.replaceAll(RegExp(r'\s*transaction\s*'), ' ');
    result = result.replaceAll(RegExp(r'\s*completed\s*'), ' ');

    // Remove common suffixes
    result = result.replaceAll(RegExp(r'\s+limited$'), ' ');
    result = result.replaceAll(RegExp(r'\s+ltd$'), ' ');
    result = result.replaceAll(RegExp(r'\s+plc$'), ' ');
    result = result.replaceAll(RegExp(r'\s+co$'), ' ');
    result = result.replaceAll(RegExp(r'\s+company$'), ' ');
    result = result.replaceAll(RegExp(r'\s+inc$'), ' ');
    result = result.replaceAll(RegExp(r'\s+inc[.]$'), ' ');
    result = result.replaceAll(RegExp(r'\s+corp$'), ' ');
    result = result.replaceAll(RegExp(r'\s+corporation$'), ' ');

    // Remove parenthetical content (e.g., "Kenya Power (KPLC)" -> "Kenya Power")
    result = result.replaceAll(RegExp(r'\s*\([^)]*\)'), ' ');

    // Remove "on date" patterns (e.g., "on 23/05/24")
    result = result.replaceAll(RegExp(r'\s+on\s+\d{1,2}/\d{1,2}/\d{2,4}'), ' ');
    result = result.replaceAll(RegExp(r'\s+at\s+\d{1,2}:\d{2}'), ' ');

    return result;
  }

  /// Remove business terms that don't identify the vendor
  static String _removeBusinessTerms(String text) {
    String result = text;

    // Remove generic business type terms
    final businessTerms = [
      'supermarket',
      'shop',
      'store',
      'mart',
      'plaza',
      'center',
      'centre',
      'outlet',
      'branch',
      'services',
      'services ltd',
      'enterprise',
      'enterprises',
      'traders',
      'trading',
      'company',
      'limited',
      'ltd',
      'plc',
      'inc',
      'corp',
      'corporation',
      'partners',
      'group',
      'holdings',
    ];

    for (final term in businessTerms) {
      // Remove term if it appears at the end
      result = result.replaceAll(RegExp(r'\s+' + term + r'$'), ' ');
      // Remove term if it appears at the start (less common)
      result = result.replaceAll(RegExp(r'^' + term + r'\s+'), ' ');
    }

    return result.trim();
  }

  /// Extract vendor signature from M-PESA SMS body
  /// This is the main entry point for SMS parsing
  static String extractFromSms(String smsBody, String extractedVendor) {
    // First try the extracted vendor name
    if (extractedVendor.isNotEmpty && extractedVendor != 'M-PESA Payment') {
      return normalize(extractedVendor);
    }

    // Fallback: Try to extract from SMS body
    return _extractFromBody(smsBody);
  }

  /// Fallback extraction from SMS body
  static String _extractFromBody(String body) {
    String text = body.toLowerCase();

    // Try to find vendor after "paid to"
    final paidToMatch =
        RegExp(r'''paid\s+to\s+([a-z][a-z0-9 &.'-]+?)\s+on''').firstMatch(text);
    if (paidToMatch != null) {
      return normalize(paidToMatch.group(1) ?? 'unknown');
    }

    // Try to find vendor after "completed to"
    final completedMatch =
        RegExp(r'''Completed\s+to\s+([a-z][a-z0-9 &.'-]+)''').firstMatch(text);
    if (completedMatch != null) {
      return normalize(completedMatch.group(1) ?? 'unknown');
    }

    return 'unknown';
  }

  /// Check if two vendor signatures likely refer to the same vendor
  static bool isSameVendor(String signature1, String signature2) {
    final norm1 = normalize(signature1);
    final norm2 = normalize(signature2);

    // Exact match
    if (norm1 == norm2) return true;

    // One contains the other (e.g., "naivas" vs "naivas supermarket")
    if (norm1.contains(norm2) || norm2.contains(norm1)) return true;

    // Check for common abbreviations
    return _areAbbreviationsEquivalent(norm1, norm2);
  }

  /// Check if two signatures are abbreviation equivalents
  static bool _areAbbreviationsEquivalent(String sig1, String sig2) {
    // Common abbreviation mappings
    final abbreviations = {
      'kplc': 'kenya power',
      'kpl': 'kenya power',
      'naivas': 'naivas supermarket',
      'carrefour': 'carrefour kenya',
      'quickmart': 'quick mart',
      'shoprite': 'shop rite',
    };

    for (final entry in abbreviations.entries) {
      if ((sig1 == entry.key && sig2.contains(entry.value)) ||
          (sig2 == entry.key && sig1.contains(entry.value))) {
        return true;
      }
    }

    return false;
  }
}
