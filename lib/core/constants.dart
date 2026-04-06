class AppConstants {
  // --- Supabase Configuration ---
  // Using the project reference from your organization: jhumanay9-hub
  static const String supabaseUrl = 'https://w8quj2ckpxzuukc9ue1m.supabase.co';

  // Fallback Supabase URLs for DNS failover (same project, different regions)
  static const List<String> supabaseFallbackUrls = [
    'https://w8quj2ckpxzuukc9ue1m.supabase.co', // Primary
    'https://supabase.co', // Generic fallback for DNS resolution test
  ];

  // Your Project API Key (Anon/Public)
  static const String supabaseAnonKey =
      'sb_publishable_W8Quj2cKPXzUUkc9Ue1mMA_vPc5ue6M';

  // DNS servers for fallback (Google & Cloudflare)
  static const List<String> dnsServers = [
    '8.8.8.8', // Google Primary
    '8.8.4.4', // Google Secondary
    '1.1.1.1', // Cloudflare Primary
    '1.0.0.1', // Cloudflare Secondary
  ];

  // --- Database Table Names ---
  static const String tableTransactions = 'transactions';

  // --- UI Colors (Pesa Budget/Emerald Palette) ---
  static const int pesaBudgetPrimary = 0xFF2ECC71; // Emerald Green
  static const int pesaBudgetDark = 0xFF27AE60; // Darker Green for accents
  static const int pesaBudgetBackground =
      0xFFF9FBF9; // Very light emerald-white
}
