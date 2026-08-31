import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../models/user_profile.dart';

class AuthService {
  static const String baseUrl = AppConstants.apiBaseUrl;

  // 1. Sign Up / Register
  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    String role = 'renter',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'fullName': fullName,
          'email': email.trim().toLowerCase(),
          'phoneNumber': phoneNumber,
          'password': password,
          'role': role,
        }),
      ).timeout(const Duration(seconds: 12));

      final data = json.decode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final token = data['token'];
        final userData = data['user'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.tokenKey, token);
        await prefs.setString(AppConstants.userKey, json.encode(userData));

        return {
          'success': true,
          'user': UserProfile.fromJson(userData),
          'message': data['message'] ?? 'Account created successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Sign up failed. Please try again.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please check your network and try again.',
      };
    }
  }

  // 2. Log In
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email.trim().toLowerCase(),
          'password': password,
          'isAdminLogin': false,
        }),
      ).timeout(const Duration(seconds: 12));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        final token = data['token'];
        final userData = data['user'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.tokenKey, token);
        await prefs.setString(AppConstants.userKey, json.encode(userData));

        return {
          'success': true,
          'user': UserProfile.fromJson(userData),
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Invalid email or password.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Unable to connect to Rentilly servers. Please check your internet.',
      };
    }
  }

  // 3. Check if user is currently logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    return token != null && token.isNotEmpty;
  }

  // 4. Get active user profile from storage
  static Future<UserProfile?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(AppConstants.userKey);
    if (userJson != null) {
      try {
        return UserProfile.fromJson(json.decode(userJson));
      } catch (_) {}
    }
    return null;
  }

  // 5. Sign Out
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userKey);
  }
}
