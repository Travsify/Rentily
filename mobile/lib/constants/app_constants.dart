class AppConstants {
  static const String appName = 'Rentilly';
  static const String appTagline = 'Zero Agents • Direct Owners • Legal Escrow';

  // Live High-Availability Production Backend (with VPS fallback reference)
  static const String apiBaseUrl = 'https://rentilly-admin-api.onrender.com/api';
  static const String vpsBaseUrl = 'https://api.myrentilly.com/api';

  // Supabase Direct Primary / Fallback
  static const String supabaseUrl = 'https://zuxvxuqxomsxgiljykzj.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_LiVL01tqjp7jQQZwxFTayQ_TrhSswA_';

  // OneSignal Push Notifications
  // OneSignal Push Notifications
  static const String oneSignalAppId = '41b932e7-a242-4e35-89c4-f743b0ff005a';

  // Storage Keys
  static const String tokenKey = 'rentilly_user_token';
  static const String userKey = 'rentilly_user_profile';
  static const String seenOnboardingKey = 'rentilly_seen_onboarding';
}
