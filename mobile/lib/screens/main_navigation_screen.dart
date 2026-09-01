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

  const MainNavigationScreen({
    super.key,
    this.initialIndex = 0,
    this.initialLandlordMode = false,
  });

  static _MainNavigationScreenState? of(BuildContext context) {
    return context.findAncestorStateOfType<_MainNavigationScreenState>();
  }

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  String _activeViewMode = 'consumer'; // 'consumer', 'landlord', 'partner'
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
    _checkUserRole();
  }

  void _checkUserRole() async {
    final user = await AuthService.getCurrentUser();
    if (mounted && user != null) {
      setState(() {
        _user = user;
        if (user.role == 'partner') {
          _activeViewMode = 'partner';
        } else if (user.role == 'owner' || user.role == 'landlord' || widget.initialLandlordMode) {
          _activeViewMode = 'landlord';
        } else {
          _activeViewMode = 'consumer';
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
          tooltip: 'Quick Utilities',
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
