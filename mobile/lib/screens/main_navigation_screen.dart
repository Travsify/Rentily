import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import 'home/home_screen.dart';
import 'search/search_screen.dart';
import 'inspections/inspections_screen.dart';
import 'messages/messages_screen.dart';
import 'profile/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    InspectionsScreen(),
    MessagesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          border: Border(
            top: BorderSide(
              color: AppColors.borderDark.withOpacity(0.5),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() => _currentIndex = index);
              },
              backgroundColor: Colors.transparent,
              type: BottomNavigationBarType.fixed,
              elevation: 0,
              selectedItemColor: AppColors.primaryLight,
              unselectedItemColor: AppColors.textMuted,
              selectedLabelStyle: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined, size: 22),
                  activeIcon: Icon(Icons.home_rounded, size: 22),
                  label: 'Explore',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.search_rounded, size: 22),
                  activeIcon: Icon(Icons.search_rounded, size: 24),
                  label: 'Search',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_today_outlined, size: 20),
                  activeIcon: Icon(Icons.calendar_month_rounded, size: 20),
                  label: 'Inspections',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outline_rounded, size: 20),
                  activeIcon: Icon(Icons.chat_bubble_rounded, size: 20),
                  label: 'Messages',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline_rounded, size: 22),
                  activeIcon: Icon(Icons.person_rounded, size: 22),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
