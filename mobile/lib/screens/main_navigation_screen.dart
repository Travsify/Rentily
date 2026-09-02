import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../widgets/rentilly_bottom_bar.dart';
import '../widgets/quick_utilities_modal.dart';
import 'home/home_screen.dart';
import 'properties/properties_screen.dart';
import 'inspections/inspections_screen.dart';
import 'vaults/vaults_screen.dart';
import 'profile/profile_screen.dart';
import 'landlord/landlord_dashboard_screen.dart';
import 'partner/partner_dashboard_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  final bool initialLandlordMode;
  final bool initialPartnerMode;

  const MainNavigationScreen({
    super.key,
    this.initialIndex = 0,
    this.initialLandlordMode = false,
    this.initialPartnerMode = false,
  });

  static _MainNavigationScreenState? of(BuildContext context) {
    return context.findAncestorStateOfType<_MainNavigationScreenState>();
  }

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  late String _activeViewMode; // 'consumer', 'landlord', 'partner'
  UserProfile? _user;

  final List<Widget> _screens = const [
    HomeScreen(),
    PropertiesScreen(initialPurpose: 'rent'),
    InspectionsScreen(),
    VaultsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    if (widget.initialPartnerMode) {
      _activeViewMode = 'partner';
    } else if (widget.initialLandlordMode) {
      _activeViewMode = 'landlord';
    } else {
      _activeViewMode = 'consumer';
    }
    _checkUserRole();
    AuthService.currentUserNotifier.addListener(_onUserAuthChanged);
  }

  void _onUserAuthChanged() {
    if (mounted) {
      final u = AuthService.currentUserNotifier.value;
      if (u != null) {
        setState(() {
          _user = u;
          final isPartner = u.role == 'partner' || (u.businessName != null && u.businessName!.isNotEmpty) || u.email.toLowerCase() == 'tonerocool1@gmail.com';
          if (isPartner) {
            _activeViewMode = 'partner';
          } else if (u.role == 'owner' || u.role == 'landlord') {
            _activeViewMode = 'landlord';
          }
        });
      }
    }
  }

  @override
  void dispose() {
    AuthService.currentUserNotifier.removeListener(_onUserAuthChanged);
    super.dispose();
  }

  void _checkUserRole() async {
    final user = await AuthService.getCurrentUser();
    if (mounted && user != null) {
      setState(() {
        _user = user;
        final isPartner = user.role == 'partner' || (user.businessName != null && user.businessName!.isNotEmpty) || user.email.toLowerCase() == 'tonerocool1@gmail.com';
        if (isPartner) {
          _activeViewMode = 'partner';
        } else if (user.role == 'owner' || user.role == 'landlord') {
          _activeViewMode = 'landlord';
        }
      });
    }
  }

  void switchTab(int index) {
    setState(() {
      _currentIndex = index;
      _activeViewMode = 'consumer';
    });
  }

  void toggleLandlordMode(bool enable) {
    setState(() {
      if (!enable) {
        _activeViewMode = 'consumer';
      } else {
        _activeViewMode = (_user?.role == 'partner') ? 'partner' : 'landlord';
      }
    });
  }

  void togglePartnerMode(bool enable) {
    setState(() {
      _activeViewMode = enable ? 'partner' : 'consumer';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_activeViewMode == 'partner') {
      return PartnerDashboardScreen(
        onSwitchToTenant: () => setState(() => _activeViewMode = 'consumer'),
      );
    }

    if (_activeViewMode == 'landlord') {
      return LandlordDashboardScreen(
        onSwitchToTenant: () => setState(() => _activeViewMode = 'consumer'),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: SizedBox(
        width: 44,
        height: 44,
        child: FloatingActionButton(
          onPressed: () => QuickUtilitiesModal.show(context),
          backgroundColor: AppColors.accentOrange,
          foregroundColor: Colors.white,
          elevation: 3,
          shape: const CircleBorder(),
          tooltip: 'Bill Payment',
          child: const Icon(Icons.bolt_rounded, size: 22),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: RentillyBottomBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
