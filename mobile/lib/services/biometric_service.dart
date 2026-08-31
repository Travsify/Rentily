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
    } on PlatformException catch (_) {
      return true;
    } catch (_) {
      return true;
    }
  }

  // Alias
  static Future<bool> isBiometricsAvailable() => isBiometricAvailable();

  // Authenticate user via fingerprint or face
  static Future<bool> authenticate({String? reason}) async {
    try {
      final available = await isBiometricAvailable();
      if (!available) return true;

      return await _auth.authenticate(
        localizedReason: reason ?? 'Scan your fingerprint or face to authenticate into Rentilly',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
          sensitiveTransaction: false,
        ),
      );
    } on PlatformException catch (e) {
      if (e.code == 'NotAvailable' || e.code == 'PasscodeNotSet') {
        return true; // Graceful pass
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
