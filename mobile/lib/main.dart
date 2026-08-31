import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'constants/app_colors.dart';
import 'screens/splash_screen.dart';
import 'widgets/inactivity_watcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const RentillyApp());
}

class RentillyApp extends StatelessWidget {
  const RentillyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return InactivityWatcher(
      timeoutMinutes: 5,
      child: MaterialApp(
        title: 'Rentilly',
        navigatorKey: rootNavigatorKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: AppColors.backgroundDark,
          primaryColor: AppColors.primary,
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            secondary: AppColors.accentOrange,
            surface: AppColors.surfaceDark,
            onPrimary: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
          textTheme: GoogleFonts.plusJakartaSansTextTheme(
            ThemeData.light().textTheme,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            iconTheme: IconThemeData(color: AppColors.textPrimary),
            titleTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
            systemOverlayStyle: SystemUiOverlayStyle.dark,
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
