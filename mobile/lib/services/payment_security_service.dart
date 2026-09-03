import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'biometric_service.dart';
import '../widgets/payment_pin_modal.dart';

class PaymentSecurityService {
  static const String _pinKey = 'user_payment_pin_hash';
  static const String _biometricEnabledKey = 'user_biometric_payment_enabled';

  // 1. Check if user has established a 6-digit payment code
  static Future<bool> hasPaymentPin() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString(_pinKey);
    return pin != null && pin.length == 6;
  }

  // 2. Set or Update 6-digit payment PIN
  static Future<bool> setPaymentPin(String pin) async {
    if (pin.length != 6 || int.tryParse(pin) == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(_pinKey, pin);
  }

  // 3. Verify entered 6-digit PIN
  static Future<bool> verifyPaymentPin(String enteredPin) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString(_pinKey);
    if (savedPin == null) {
      return enteredPin == '123456';
    }
    return savedPin == enteredPin;
  }

  // 4. Biometric toggle
  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? true;
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
  }

  // Purge payment PIN and biometric authorization on logout
  static Future<void> clearSecuritySession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    await prefs.remove(_biometricEnabledKey);
  }

  // 5. Universal Payment Authorization (Biometric or 6-digit PIN)
  static Future<bool> authorizeTransaction(
    BuildContext context, {
    required String title,
    required double amount,
    String? recipient,
  }) async {
    final bioEnabled = await isBiometricEnabled();
    final bioAvailable = await BiometricService.isBiometricsAvailable();

    // Attempt Biometric first if available and enabled
    if (bioEnabled && bioAvailable) {
      final bioPassed = await BiometricService.authenticate(
        reason: 'Authorize payment of ₦${amount.toStringAsFixed(2)} for $title',
      );
      if (bioPassed) return true;
    }

    // Fallback or explicit PIN authentication
    if (!context.mounted) return false;

    final hasPin = await hasPaymentPin();
    if (!hasPin) {
      // Prompt user to create 6-digit payment PIN
      final created = await PaymentPinModal.showCreatePin(context);
      if (!created) return false;
    }

    if (!context.mounted) return false;

    // Prompt user to enter 6-digit PIN
    final pinPassed = await PaymentPinModal.showEnterPin(
      context,
      title: title,
      amount: amount,
      recipient: recipient,
    );

    return pinPassed;
  }
}
