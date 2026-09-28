import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../screens/properties/properties_screen.dart';
import '../screens/wallet/wallet_screen.dart';
import '../screens/cards/cards_screen.dart';
import '../screens/lifestyle/lifestyle_hub_screen.dart';
import '../screens/global_pay/global_pay_home_screen.dart';
import '../screens/global_pay/tuition_payment_screen.dart';
import '../screens/global_pay/supplier_payout_screen.dart';
import '../screens/partner/partner_dashboard_screen.dart';
import '../screens/partner/partner_mandates_screen.dart';
import '../screens/landlord/landlord_dashboard_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/shared/notification_center_screen.dart';
import '../screens/referrals/referral_screen.dart';
import '../screens/vaults/vaults_screen.dart';
import '../screens/support/support_chat_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String properties = '/properties';
  static const String wallet = '/wallet';
  static const String cards = '/cards';
  static const String lifestyle = '/lifestyle';
  static const String globalPay = '/global-pay';
  static const String tuition = '/global-pay/tuition';
  static const String supplier = '/global-pay/supplier';
  static const String partner = '/partner';
  static const String partnerMandates = '/partner/mandates';
  static const String landlord = '/landlord';
  static const String profile = '/profile';
  static const String notifications = '/notifications';
  static const String referrals = '/referrals';
  static const String vaults = '/vaults';
  static const String support = '/support';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen(), settings: settings);
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen(), settings: settings);
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen(), settings: settings);
      case home:
        return MaterialPageRoute(builder: (_) => const MainNavigationScreen(), settings: settings);
      case properties:
        return MaterialPageRoute(builder: (_) => const PropertiesScreen(), settings: settings);
      case wallet:
        return MaterialPageRoute(builder: (_) => const WalletScreen(), settings: settings);
      case cards:
        return MaterialPageRoute(builder: (_) => const CardsScreen(), settings: settings);
      case lifestyle:
        return MaterialPageRoute(builder: (_) => const LifestyleHubScreen(), settings: settings);
      case globalPay:
        return MaterialPageRoute(builder: (_) => const GlobalPayHomeScreen(), settings: settings);
      case tuition:
        return MaterialPageRoute(builder: (_) => const TuitionPaymentScreen(), settings: settings);
      case supplier:
        return MaterialPageRoute(builder: (_) => const SupplierPayoutScreen(), settings: settings);
      case partner:
        return MaterialPageRoute(builder: (_) => const PartnerDashboardScreen(), settings: settings);
      case partnerMandates:
        return MaterialPageRoute(builder: (_) => const PartnerMandatesScreen(), settings: settings);
      case landlord:
        return MaterialPageRoute(builder: (_) => const LandlordDashboardScreen(), settings: settings);
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen(), settings: settings);
      case notifications:
        return MaterialPageRoute(builder: (_) => const NotificationCenterScreen(), settings: settings);
      case referrals:
        return MaterialPageRoute(builder: (_) => const ReferralScreen(), settings: settings);
      case vaults:
        return MaterialPageRoute(builder: (_) => const VaultsScreen(), settings: settings);
      case support:
        return MaterialPageRoute(builder: (_) => const SupportChatScreen(), settings: settings);
      default:
        return MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(),
          settings: settings,
        );
    }
  }
}
