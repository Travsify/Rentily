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
import '../services/notification_service.dart';

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

    // Immediately resolve mode from current cached user profile or initial flags
    final cached = AuthService.currentUserNotifier.value;
    if (cached != null && cached.isPartner) {
      _activeViewMode = 'partner';
    } else if (cached != null && cached.isLandlord) {
      _activeViewMode = 'landlord';
    } else if (widget.initialPartnerMode) {
      _activeViewMode = 'partner';
    } else if (widget.initialLandlordMode) {
      _activeViewMode = 'landlord';
    } else {
      _activeViewMode = 'consumer';
    }

    _checkUserRole();
    AuthService.currentUserNotifier.addListener(_onUserAuthChanged);
    NotificationService.startRealtimeSync();
  }

  void _onUserAuthChanged() {
    if (mounted) {
      final u = AuthService.currentUserNotifier.value;
      if (u != null) {
        setState(() {
          _user = u;
          if (u.isPartner && _activeViewMode != 'partner') {
            _activeViewMode = 'partner';
          } else if (u.isLandlord && _activeViewMode == 'consumer') {
            _activeViewMode = 'landlord';
          }
        });
      }
    }
  }

  @override
  void dispose() {
    NotificationService.stopRealtimeSync();
    AuthService.currentUserNotifier.removeListener(_onUserAuthChanged);
    super.dispose();
  }

  void _checkUserRole() async {
    final user = await AuthService.getCurrentUser();
    if (mounted && user != null) {
      setState(() {
        _user = user;
        if (user.isPartner && _activeViewMode != 'partner') {
          _activeViewMode = 'partner';
        } else if (user.isLandlord && _activeViewMode == 'consumer') {
          _activeViewMode = 'landlord';
        }
      });
    }
  }

  void switchTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void setViewMode(String mode) {
    if (mounted) {
      setState(() {
        _activeViewMode = mode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_activeViewMode == 'partner') {
      return const PartnerDashboardScreen();
    }

    if (_activeViewMode == 'landlord') {
      return const LandlordDashboardScreen();
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
