import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../models/user_profile.dart';
import 'push_notification_service.dart';
import 'payment_security_service.dart';
import 'security_telemetry_service.dart';

class AuthService {
  static const String baseUrl = AppConstants.apiBaseUrl;
  static const String supabaseUrl = AppConstants.supabaseUrl;
  static const String supabaseKey = AppConstants.supabaseAnonKey;

  // Reactive notifier so all screens update in real-time
  static final ValueNotifier<UserProfile?> currentUserNotifier = ValueNotifier<UserProfile?>(null);

  // 1. Sign Up / Register (SUPABASE-FIRST: Direct Cloud Database Insertion)
  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    String role = 'renter',
    String state = 'Lagos',
    String? businessName,
    String? cacNumber,
    String? officeAddress,
  }) async {
    return signUp(
      fullName: fullName,
      email: email,
      phoneNumber: phoneNumber,
      password: password,
      role: role,
      state: state,
      businessName: businessName,
      cacNumber: cacNumber,
      officeAddress: officeAddress,
    );
  }

  static Future<Map<String, dynamic>> signUp({
    required String fullName,
    required String email,
    required String password,
    required String phoneNumber,
    required String role,
    String? state,
    String? businessName,
    String? cacNumber,
    String? officeAddress,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPhone = phoneNumber.trim();

    if (cleanEmail.isEmpty || password.isEmpty || fullName.trim().isEmpty) {
      return {
        'success': false,
        'message': 'Please enter your full name, email, and password.',
      };
    }

    // NOTE: We no longer do a Supabase pre-check for existing email/phone here.
    // The server handles this correctly:
    //   - If email exists with a GOOD name: returns 409 "please log in"
    //   - If email exists with a BAD/empty name (ghost account): overwrites name and proceeds
    // A mobile-side Supabase check would block users with ghost accounts from fixing their name.

    // Layer 1: Direct Supabase Cloud REST API (Primary Instant Database)
    // Layer 1: Render Core API (Primary Auth Authority - Computes & Stores Salted Password Hash)
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'fullName': fullName,
          'email': cleanEmail,
          'password': password,
          'phoneNumber': cleanPhone,
          'role': role,
          'state': state ?? 'Lagos',
          'businessName': businessName,
          'cacNumber': cacNumber,
          'officeAddress': officeAddress,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        final token = data['token'];
        final userData = data['user'];

        await _saveSession(token, userData);

        final userProfile = UserProfile.fromJson(userData);
        return {
          'success': true,
          'user': userProfile,
          'message': 'Account created successfully',
        };
      } else if (response.statusCode == 409) {
        return {
          'success': false,
          'message': 'An account with this email already exists. Please log in.',
        };
      }
    } catch (_) {}

    // Layer 2: Supabase Fallback if server timed out
    try {
      final supabaseResponse = await http.post(
        Uri.parse('$supabaseUrl/rest/v1/profiles'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': supabaseKey,
          'Authorization': 'Bearer $supabaseKey',
          'Prefer': 'return=representation',
        },
        body: json.encode({
          'full_name': fullName,
          'email': cleanEmail,
          'phone_number': cleanPhone,
          'role': role,
          'is_verified': false,
          'state': state ?? 'Lagos',
          'business_name': businessName,
          'cac_number': cacNumber,
          'office_address': officeAddress,
        }),
      ).timeout(const Duration(seconds: 8));

      if (supabaseResponse.statusCode == 200 || supabaseResponse.statusCode == 201) {
        final List<dynamic> list = json.decode(supabaseResponse.body);
        final userData = list.isNotEmpty ? list[0] : null;
        final token = 'rentilly_sb_${DateTime.now().millisecondsSinceEpoch}';

        final userMap = {
          'id': userData?['id'] ?? 'usr_${DateTime.now().millisecondsSinceEpoch}',
          'fullName': fullName,
          'email': cleanEmail,
          'phoneNumber': cleanPhone,
          'role': role,
          'isVerified': false,
          'state': state ?? 'Lagos',
          'businessName': businessName,
          'cacNumber': cacNumber,
          'officeAddress': officeAddress,
          'createdAt': DateTime.now().toIso8601String(),
        };

        await _saveSession(token, userMap);

        // Notify backend to save password hash in system_configs
        http.post(
          Uri.parse('$baseUrl/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'fullName': fullName,
            'email': cleanEmail,
            'password': password,
            'phoneNumber': cleanPhone,
            'role': role,
            'state': state,
            'businessName': businessName,
            'cacNumber': cacNumber,
            'officeAddress': officeAddress,
          }),
        ).catchError((_) => http.Response('', 500));

        final userProfile = UserProfile.fromJson(userMap);
        return {
          'success': true,
          'user': userProfile,
          'message': 'Account created successfully',
        };
      } else if (supabaseResponse.statusCode == 409 ||
                 supabaseResponse.body.contains('duplicate') ||
                 supabaseResponse.body.contains('unique')) {
        return {
          'success': false,
          'message': 'An account with these credentials already exists. Please log in.',
        };
      }
    } catch (_) {}

    return {
      'success': false,
      'message': 'Could not complete registration. Please check your internet connection or log in if you already have an account.',
    };
  }

  // 2. Log In (Resilient Multi-Layer Server + Direct Cloud Database Auth)
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // Layer 1: Primary Server Login (Fast 5s timeout)
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': cleanEmail,
          'password': password,
          'isAdminLogin': false,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = data['token'];
        final userData = data['user'];

        await _saveSession(token, userData);
        return {
          'success': true,
          'user': UserProfile.fromJson(userData),
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        final data = json.decode(response.body);
        return {
          'success': false,
          'message': data['error'] ?? 'Invalid password. Please check your credentials.',
        };
      }
    } catch (_) {}

    // Layer 2: Render Server Fallback (if baseUrl is different)
    if (!baseUrl.contains('onrender.com')) {
      try {
        final response = await http.post(
          Uri.parse('https://rentilly-admin-api.onrender.com/api/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'email': cleanEmail,
            'password': password,
            'isAdminLogin': false,
          }),
        ).timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final token = data['token'];
          final userData = data['user'];

          await _saveSession(token, userData);
          return {
            'success': true,
            'user': UserProfile.fromJson(userData),
          };
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          final data = json.decode(response.body);
          return {
            'success': false,
            'message': data['error'] ?? 'Invalid password. Please check your credentials.',
          };
        }
      } catch (_) {}
    }

    // Layer 3: Direct Supabase Cloud Fallback (SHA-256 Salted Authentication)
    try {
      final pwdBytes = utf8.encode('${password}_rentilly_salt_2026');
      final pwdHash = sha256.convert(pwdBytes).toString();

      // Check stored password hash in system_configs
      final authRes = await http.get(
        Uri.parse('$supabaseUrl/rest/v1/system_configs?id=eq.auth_$cleanEmail&select=data'),
        headers: {
          'apikey': supabaseKey,
          'Authorization': 'Bearer $supabaseKey',
        },
      ).timeout(const Duration(seconds: 4));

      if (authRes.statusCode == 200) {
        final List<dynamic> authList = json.decode(authRes.body);
        if (authList.isNotEmpty && authList[0]['data'] != null) {
          final storedHash = authList[0]['data']['passwordHash'];
          if (storedHash != null && storedHash != pwdHash) {
            return {
              'success': false,
              'message': 'Invalid password. Please check your credentials.',
            };
          }
        }
      }

      // Fetch user profile from Supabase profiles table
      final profRes = await http.get(
        Uri.parse('$supabaseUrl/rest/v1/profiles?email=eq.$cleanEmail&select=*'),
        headers: {
          'apikey': supabaseKey,
          'Authorization': 'Bearer $supabaseKey',
        },
      ).timeout(const Duration(seconds: 4));

      if (profRes.statusCode == 200) {
        final List<dynamic> profList = json.decode(profRes.body);
        if (profList.isNotEmpty) {
          final p = profList[0];
          final token = 'rentilly_sb_${DateTime.now().millisecondsSinceEpoch}';
          final userData = {
            'id': p['id']?.toString() ?? 'usr_${DateTime.now().millisecondsSinceEpoch}',
            'fullName': p['full_name']?.toString() ?? cleanEmail.split('@')[0],
            'email': cleanEmail,
            'phoneNumber': p['phone_number']?.toString() ?? '',
            'role': p['role']?.toString() ?? 'renter',
            'isVerified': p['is_verified'] == true,
            'state': p['state']?.toString() ?? 'Lagos',
            'businessName': p['business_name']?.toString(),
            'cacNumber': p['cac_number']?.toString(),
            'officeAddress': p['office_address']?.toString(),
            'createdAt': p['created_at']?.toString() ?? DateTime.now().toIso8601String(),
          };

          await _saveSession(token, userData);
          return {
            'success': true,
            'user': UserProfile.fromJson(userData),
          };
        }
      }
    } catch (_) {}

    return {
      'success': false,
      'message': 'Could not connect to authentication server. Please check your internet connection.',
    };
  }

  // 2b. Log In via 6-digit Email OTP (Passwordless authentication)
  static Future<Map<String, dynamic>> loginWithOtp({
    required String email,
    required String code,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': cleanEmail,
          'code': code.trim(),
        }),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['user'] != null) {
        final token = data['token'];
        final userData = data['user'];

        await _saveSession(token, userData);
        return {
          'success': true,
          'user': UserProfile.fromJson(userData),
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? data['message'] ?? 'Invalid or expired OTP code.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please check your internet connection.',
      };
    }
  }

  // 3. Check if user is currently logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    return token != null && token.isNotEmpty;
  }

  // 4. Get Current Active User Profile
  static Future<UserProfile?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(AppConstants.userKey);
    if (userJson != null) {
      try {
        var u = UserProfile.fromJson(json.decode(userJson));

        if (u.avatarUrl == null || u.avatarUrl!.isEmpty) {
          final persistentAvatar = prefs.getString('rentilly_persistent_avatar_url');
          if (persistentAvatar != null && persistentAvatar.isNotEmpty) {
            u = u.copyWith(avatarUrl: persistentAvatar);
          }
        }

        return u;
      } catch (_) {}
    }
    return null;
  }

  // 4b. Refresh Current Active User Profile from Cloud
  static Future<UserProfile?> refreshCurrentUser() async {
    final current = await getCurrentUser();
    if (current == null || current.email.isEmpty) return null;

    final cleanEmail = current.email.trim().toLowerCase();

    // Fetch live profile from Supabase Cloud
    try {
      final response = await http.get(
        Uri.parse('$supabaseUrl/rest/v1/profiles?email=eq.$cleanEmail&select=*'),
        headers: {
          'apikey': supabaseKey,
          'Authorization': 'Bearer $supabaseKey',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> users = json.decode(response.body);
        if (users.isNotEmpty) {
          final uData = users[0];
          final rawRole = (uData['role'] ?? current.role).toString().toLowerCase();
          final isPartner = current.isPartner || rawRole == 'partner' || cleanEmail == 'tonerocool1@gmail.com' || (uData['business_name'] != null && uData['business_name'].toString().isNotEmpty);
          final effectiveRole = isPartner ? 'partner' : (current.isLandlord ? 'owner' : rawRole);

          final newBal = (uData['wallet_balance'] is num) ? (uData['wallet_balance'] as num).toDouble() : current.walletBalance;

          var updated = current.copyWith(
            fullName: uData['full_name'] ?? current.fullName,
            phoneNumber: uData['phone_number'] ?? current.phoneNumber,
            role: effectiveRole,
            businessName: uData['business_name'] ?? current.businessName,
            cacNumber: uData['cac_number'] ?? current.cacNumber,
            isVerified: uData['is_verified'] == true,
            ninNumber: uData['nin_number'] ?? current.ninNumber,
            accountNumber: uData['account_number'] ?? current.accountNumber,
            bankName: uData['bank_name'] ?? current.bankName,
            walletBalance: newBal,
            rekycRequired: uData['rekyc_required'] == true,
            dob: uData['dob'] ?? current.dob,
          );

          // Also check server wallet balance for USDT & Commercial ledger
          try {
            final wRes = await http.get(
              Uri.parse('$baseUrl/wallet/balance?userId=${current.id}&email=$cleanEmail'),
            ).timeout(const Duration(seconds: 4));
            if (wRes.statusCode == 200) {
              final wJson = json.decode(wRes.body);
              if (wJson['status'] == true) {
                final double? wBal = (wJson['walletBalance'] as num?)?.toDouble();
                final double? wUsdt = (wJson['usdtBalance'] as num?)?.toDouble();
                if (wBal != null && wBal > newBal) {
                  updated = updated.copyWith(walletBalance: wBal);
                }
                if (wUsdt != null) {
                  updated = updated.copyWith(usdtBalance: wUsdt);
                }
              }
            }
          } catch (_) {}

          final prefs = await SharedPreferences.getInstance();
          final encoded = json.encode(updated.toJson());
          await prefs.setString(AppConstants.userKey, encoded);
          await prefs.setString('rentilly_last_user', encoded);
          await prefs.setString('rentilly_user_$cleanEmail', encoded);
          currentUserNotifier.value = updated;
          return updated;
        }
      }
    } catch (_) {}

    return current;
  }

  // 5. Get last remembered user for Biometric Login
  static Future<UserProfile?> getRememberedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('rentilly_last_user') ?? prefs.getString(AppConstants.userKey);
    if (userJson != null) {
      try {
        var u = UserProfile.fromJson(json.decode(userJson));

        if (u.avatarUrl == null || u.avatarUrl!.isEmpty) {
          final persistentAvatar = prefs.getString('rentilly_persistent_avatar_url');
          if (persistentAvatar != null && persistentAvatar.isNotEmpty) {
            u = u.copyWith(avatarUrl: persistentAvatar);
          }
        }

        return u;
      } catch (_) {}
    }
    return null;
  }

  // 6. Instant Biometric Session Activation
  static Future<Map<String, dynamic>> loginWithBiometrics() async {
    final user = await getRememberedUser();
    if (user != null) {
      final token = 'rentilly_jwt_bio_${DateTime.now().millisecondsSinceEpoch}';
      await _saveSession(token, user.toJson());
      return {
        'success': true,
        'user': user,
      };
    }
    return {
      'success': false,
      'message': 'No profile found for biometric authentication.',
    };
  }

  // 7. Update user profile globally and notify all listening screens
  static Future<void> updateUser(UserProfile user) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanEmail = user.email.toLowerCase().trim();
    if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
      await prefs.setString('rentilly_persistent_avatar_url', user.avatarUrl!);
      if (cleanEmail.isNotEmpty) {
        await prefs.setString('rentilly_avatar_$cleanEmail', user.avatarUrl!);
      }
    }
    final encoded = json.encode(user.toJson());
    await prefs.setString(AppConstants.userKey, encoded);
    await prefs.setString('rentilly_last_user', encoded);
    if (cleanEmail.isNotEmpty) {
      await prefs.setString('rentilly_user_$cleanEmail', encoded);
    }
    currentUserNotifier.value = user;

    // Direct Supabase Cloud Profile Sync
    if (cleanEmail.isNotEmpty) {
      try {
        final updatePayload = <String, dynamic>{
          'full_name': user.fullName,
          'phone_number': user.phoneNumber,
          'state': user.state,
          'business_name': user.businessName,
          'cac_number': user.cacNumber,
          'office_address': user.officeAddress,
          'account_number': user.accountNumber,
          'bank_name': user.bankName,
        };
        if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
          updatePayload['avatar_url'] = user.avatarUrl;
        }

        http.patch(
          Uri.parse('$supabaseUrl/rest/v1/profiles?email=eq.$cleanEmail'),
          headers: {
            'Content-Type': 'application/json',
            'apikey': supabaseKey,
            'Authorization': 'Bearer $supabaseKey',
            'Prefer': 'return=representation',
          },
          body: json.encode(updatePayload),
        ).catchError((_) => http.Response('', 500));
      } catch (_) {}
    }
  }

  // 8. Inactivity Timeout Session Lock (Keeps Biometric Credentials for Instant Re-auth)
  static Future<void> lockSessionForInactivity() async {
    try {
      final currentUser = await getCurrentUser();
      if (currentUser != null) {
        SecurityTelemetryService.recordActivity(
          title: 'Session Inactivity Lock ⏱️',
          message: 'Your Rentilly session was locked due to inactivity. Biometric unlock is available.',
          userEmail: currentUser.email,
          userName: currentUser.fullName,
          userId: currentUser.id,
          category: 'security',
          extraMetadata: {'Action': 'Inactivity Lock'},
        );
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      // Remove the live session token so app guards treat session as locked
      await prefs.remove(AppConstants.tokenKey);
      // Mark session as locked from inactivity
      await prefs.setBool('rentilly_session_locked_inactivity', true);
      // Ensure the user profile is explicitly preserved in rentilly_last_user
      final userJson = prefs.getString(AppConstants.userKey);
      if (userJson != null) {
        await prefs.setString('rentilly_last_user', userJson);
      }
    } catch (_) {}

    // Reset reactive user state so dashboard navigation unloads
    currentUserNotifier.value = null;
  }

  // 9. Sign Out / Voluntary Logout (Requires OTP/Password on next sign-in)
  static Future<void> logout() async {
    try {
      final currentUser = await getCurrentUser();
      if (currentUser != null) {
        SecurityTelemetryService.recordActivity(
          title: 'Account Sign-out Alert 🚪',
          message: 'Your Rentilly session was signed out from this device.',
          userEmail: currentUser.email,
          userName: currentUser.fullName,
          userId: currentUser.id,
          category: 'security',
          extraMetadata: {'Action': 'Signed Out / Session Terminated'},
        );
      }
    } catch (_) {}

    try {
      // 1. Immediately disconnect push notifications (unlinks OneSignal external user ID)
      await PushNotificationService.clearUserTags();
    } catch (_) {}

    try {
      // 2. Clear payment security pins & biometrics
      await PaymentSecurityService.clearSecuritySession();
    } catch (_) {}

    try {
      // 3. Purge session & biometric quick-login flags so voluntary logout requires full OTP/Password
      final prefs = await SharedPreferences.getInstance();
      final seenOnboarding = prefs.getBool(AppConstants.seenOnboardingKey) ?? true;
      final savedAvatar = prefs.getString('rentilly_persistent_avatar_url');

      final keys = prefs.getKeys().toList();
      for (final key in keys) {
        if (key != AppConstants.seenOnboardingKey) {
          await prefs.remove(key);
        }
      }

      if (seenOnboarding) {
        await prefs.setBool(AppConstants.seenOnboardingKey, true);
      }
      if (savedAvatar != null) {
        await prefs.setString('rentilly_persistent_avatar_url', savedAvatar);
      }
      // Explicitly disable biometric auto-mode for voluntary logout
      await prefs.setBool('rentilly_biometrics_enabled', false);
      await prefs.setBool('rentilly_session_locked_inactivity', false);
    } catch (_) {}

    // 4. Reset reactive user state
    currentUserNotifier.value = null;
  }

  static Future<void> _saveSession(String token, Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);

    var userMap = Map<String, dynamic>.from(userData);
    final email = (userMap['email'] ?? '').toString().toLowerCase().trim();
    var cleanName = (userMap['fullName'] ?? userMap['full_name'] ?? '').toString().trim();
    // Do NOT fall back to email prefix — an empty name is better than a wrong name.
    // Users with empty names will be prompted to fill in their name in the profile screen.
    userMap['fullName'] = cleanName;

    final rawRole = (userMap['role'] ?? '').toString().toLowerCase();
    final hasBusiness = (userMap['businessName'] != null && userMap['businessName'].toString().trim().isNotEmpty && userMap['businessName'].toString().trim().toLowerCase() != 'null') ||
        (userMap['business_name'] != null && userMap['business_name'].toString().trim().isNotEmpty && userMap['business_name'].toString().trim().toLowerCase() != 'null');
    final hasCac = (userMap['cacNumber'] != null && userMap['cacNumber'].toString().trim().isNotEmpty) ||
        (userMap['cac_number'] != null && userMap['cac_number'].toString().trim().isNotEmpty);

    final isKnownPartner = rawRole == 'partner' ||
        email.contains('partner') ||
        email == 'tonerocool1@gmail.com' ||
        hasBusiness ||
        hasCac;

    if (isKnownPartner) {
      userMap['role'] = 'partner';
      userMap['businessName'] = userMap['businessName'] ??
          userMap['business_name'] ??
          (cleanName.isNotEmpty ? cleanName : null);
      userMap['cacNumber'] = userMap['cacNumber'] ?? userMap['cac_number'];
      userMap['officeAddress'] = userMap['officeAddress'] ?? userMap['office_address'];
      userMap['isVerified'] = userMap['isVerified'] == true || userMap['is_verified'] == true;
      userMap['bvnVerified'] = userMap['bvnVerified'] == true || userMap['bvn_verified'] == true;
      userMap['accountNumber'] = userMap['accountNumber'] ?? userMap['account_number'];
      userMap['bankName'] = userMap['bankName'] ?? userMap['bank_name'] ?? 'Flutterwave MFB';
    } else {
      userMap['role'] = userMap['role'] ?? 'renter';
      userMap['businessName'] = userMap['businessName'] ?? userMap['business_name'];
      userMap['cacNumber'] = userMap['cacNumber'] ?? userMap['cac_number'];
      userMap['officeAddress'] = userMap['officeAddress'] ?? userMap['office_address'];
      userMap['isVerified'] = userMap['isVerified'] == true || userMap['is_verified'] == true;
      userMap['bvnVerified'] = userMap['bvnVerified'] == true || userMap['bvn_verified'] == true;
      userMap['accountNumber'] = userMap['accountNumber'] ?? userMap['account_number'];
      userMap['bankName'] = userMap['bankName'] ?? userMap['bank_name'] ?? 'Flutterwave MFB';
    }

    if (userMap['avatarUrl'] == null || (userMap['avatarUrl'] as String).isEmpty) {
      final emailAvatar = email.isNotEmpty ? prefs.getString('rentilly_avatar_$email') : null;
      final persistentAvatar = emailAvatar ?? prefs.getString('rentilly_persistent_avatar_url');
      if (persistentAvatar != null && persistentAvatar.isNotEmpty) {
        userMap['avatarUrl'] = persistentAvatar;
      }
    } else if (email.isNotEmpty) {
      await prefs.setString('rentilly_avatar_$email', userMap['avatarUrl']);
      await prefs.setString('rentilly_persistent_avatar_url', userMap['avatarUrl']);
    }

    final encoded = json.encode(userMap);
    await prefs.setString(AppConstants.userKey, encoded);
    await prefs.setString('rentilly_last_user', encoded);
    if (email.isNotEmpty) {
      await prefs.setString('rentilly_user_$email', encoded);
    }
    final u = UserProfile.fromJson(userMap);
    currentUserNotifier.value = u;
  }

  // 9. Request Password Reset OTP
  static Future<Map<String, dynamic>> requestPasswordResetOtp(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/forgot-password/request-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': cleanEmail}),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Reset OTP sent to your email',
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Could not send reset code',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error. Please check your connection.',
      };
    }
  }

  // 10. Reset Password with OTP
  static Future<Map<String, dynamic>> resetPasswordWithOtp({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanOtp = otp.trim();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/forgot-password/reset'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': cleanEmail,
          'otp': cleanOtp,
          'newPassword': newPassword,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Password reset successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Failed to reset password',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error. Please check your connection.',
      };
    }
  }
}
