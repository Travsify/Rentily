import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class OtpService {
  static const String baseUrl = AppConstants.apiBaseUrl;

  /// Dispatches a 6-digit OTP code to the user's Email (Resend) and/or Mobile Phone (Twilio)
  static Future<Map<String, dynamic>> sendOtp({
    String? email,
    String? phoneNumber,
    String? userName,
    String channel = 'both', // 'email', 'sms', 'both'
    String purpose = 'Account Verification',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'phoneNumber': phoneNumber,
          'userName': userName,
          'channel': channel,
          'purpose': purpose,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Verification code sent successfully.',
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Unable to send security code. Please try again.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: Unable to dispatch verification code ($e)',
      };
    }
  }

  /// Verifies the 6-digit OTP code submitted by the user
  static Future<Map<String, dynamic>> verifyOtp({
    String? email,
    String? phoneNumber,
    required String code,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'phoneNumber': phoneNumber,
          'code': code.trim(),
        }),
      ).timeout(const Duration(seconds: 12));

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Code verified successfully!',
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Invalid code entered. Please try again.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: Verification failed ($e)',
      };
    }
  }
}
