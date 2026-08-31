import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/rentilly_bottom_bar.dart';
import '../widgets/quick_utilities_modal.dart';
import 'home/home_screen.dart';
import 'properties/properties_screen.dart';
import 'inspections/inspections_screen.dart';
import 'vaults/vaults_screen.dart';
import 'profile/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({super.key, this.initialIndex = 0});

  static _MainNavigationScreenState? of(BuildContext context) {
    return context.findAncestorStateOfType<_MainNavigationScreenState>();
  }

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;

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
  }

  void switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
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
