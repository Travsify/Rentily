import 'dart:async';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  // Check if device supports biometrics
  static Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (_) {
      return true;
    }
  }

  // Alias
  static Future<bool> isBiometricsAvailable() => isBiometricAvailable();

  // Authenticate user via fingerprint or face (with safety timeout and non-blocking options)
  static Future<bool> authenticate({String? reason}) async {
    try {
      final available = await isBiometricAvailable();
      if (!available) return true;

      final authFuture = _auth.authenticate(
        localizedReason: reason ?? 'Scan your fingerprint or face to authenticate into Rentilly',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
          sensitiveTransaction: false,
        ),
      );

      return await authFuture.timeout(const Duration(seconds: 30), onTimeout: () => false);
    } on PlatformException catch (e) {
      if (e.code == 'NotAvailable' || e.code == 'PasscodeNotSet') {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
