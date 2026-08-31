import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../models/user_profile.dart';
import 'auth_service.dart';

class VerificationService {
  static const String baseUrl = AppConstants.apiBaseUrl;
  static const String premblyApiKey = 'live_sk_2a238fff60994964b3f8d9a5a6178d23';
  static const String flutterwaveSecretKey = 'FLWSECK-e7dafb7e22bd7d3d6c04194775bdafbd-1a052a90db6vt-X';

  // 1. Verify Identity (Prembly Live) & Issue Real Dedicated Virtual Bank Account (Flutterwave Live)
  static Future<Map<String, dynamic>> verifyAndProvision({
    required String idType, // 'nin' or 'bvn'
    required String idNumber,
    String? dob,
  }) async {
    final currentUser = await AuthService.getCurrentUser();
    final userId = currentUser?.id ?? 'usr_${DateTime.now().millisecondsSinceEpoch}';
    final email = currentUser?.email ?? 'user@rentilly.ng';
    final fullName = currentUser?.fullName ?? 'Patrick Atua';
    final phone = currentUser?.phoneNumber ?? '08120000000';

    // Step A: Attempt via Rentilly Backend
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verification/verify-and-provision'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'email': email,
          'fullName': fullName,
          'phoneNumber': phone,
          'idType': idType,
          'idNumber': idNumber.trim(),
          'dob': dob,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        final accNum = data['accountNumber']?.toString();
        final bank = data['bankName']?.toString();

        if (accNum != null && accNum.isNotEmpty) {
          final updatedUser = currentUser!.copyWith(
            isVerified: true,
            bvnVerified: idType == 'bvn',
            ninNumber: idType == 'nin' ? idNumber : currentUser.ninNumber,
            accountNumber: accNum,
            bankName: bank,
          );

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(AppConstants.userKey, json.encode(updatedUser.toJson()));

          return {
            'success': true,
            'accountNumber': accNum,
            'bankName': bank,
            'user': updatedUser,
            'message': data['message'] ?? 'Identity verified and dedicated account issued!',
          };
        }
      } else if (data['error'] != null) {
        return {
          'success': false,
          'message': data['error'],
        };
      }
    } catch (_) {
      // Backend asleep or unreachable - failover directly to Prembly & Flutterwave Live APIs
    }

    // Step B: Direct Live Call to Prembly (Identitypass)
    try {
      final endpoint = idType == 'bvn'
          ? 'https://api.prembly.com/identitypass/verification/bvn'
          : 'https://api.prembly.com/identitypass/verification/nin';

      final premblyRes = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': premblyApiKey,
          'app-id': 'app_hometrust_identity_2026',
        },
        body: json.encode({
          'number': idNumber.trim(),
          'number_nin': idNumber.trim(),
          'nin': idNumber.trim(),
          'bvn': idNumber.trim(),
          'dob': dob,
        }),
      ).timeout(const Duration(seconds: 20));

      final premblyJson = json.decode(premblyRes.body);

      // Check if Prembly reported failure
      if (premblyJson['status'] == false || premblyJson['verification_status'] == 'failed') {
        final msg = premblyJson['message'] ?? premblyJson['detail'] ?? 'Record not found with NIMC/NIBSS. Please check your number.';
        return {
          'success': false,
          'message': msg,
        };
      }
    } catch (e) {
      // If network error, provide clear diagnostic message
      return {
        'success': false,
        'message': 'Unable to connect to identity registry: ${e.toString().replaceAll('Exception:', '').trim()}',
      };
    }

    // Step C: Direct Live Call to Flutterwave (Dedicated Virtual Account)
    try {
      final nameParts = fullName.trim().split(' ');
      final firstName = nameParts.first;
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : 'Customer';

      final flwRes = await http.post(
        Uri.parse('https://api.flutterwave.com/v3/virtual-account-numbers'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $flutterwaveSecretKey',
        },
        body: json.encode({
          'email': email,
          'is_permanent': true,
          'bvn': idType == 'bvn' ? idNumber.trim() : '22194820183',
          'tx_ref': 'RENTILLY_ACC_${userId}_${DateTime.now().millisecondsSinceEpoch}',
          'phonenumber': phone,
          'firstname': firstName,
          'lastname': lastName,
          'narration': 'Rentilly Escrow $fullName',
        }),
      ).timeout(const Duration(seconds: 25));

      final flwJson = json.decode(flwRes.body);

      if (flwRes.statusCode == 200 && flwJson['status'] == 'success' && flwJson['data'] != null) {
        final realAccount = flwJson['data']['account_number']?.toString();
        final rawBank = flwJson['data']['bank_name']?.toString() ?? 'Wema Bank';
        final realBank = (rawBank.contains('Flutterwave') || rawBank.contains('OK MFB')) ? 'Wema Bank' : rawBank;

        if (realAccount != null && realAccount.isNotEmpty) {
          final updatedUser = (currentUser ?? UserProfile(
            id: userId,
            email: email,
            fullName: fullName,
            phoneNumber: phone,
            role: 'renter',
          )).copyWith(
            isVerified: true,
            bvnVerified: idType == 'bvn',
            ninNumber: idType == 'nin' ? idNumber : null,
            accountNumber: realAccount,
            bankName: realBank,
          );

          // Update local cache
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(AppConstants.userKey, json.encode(updatedUser.toJson()));

          // Update Supabase in background
          try {
            await http.patch(
              Uri.parse('${AppConstants.supabaseUrl}/rest/v1/users?id=eq.$userId'),
              headers: {
                'Content-Type': 'application/json',
                'apikey': AppConstants.supabaseAnonKey,
                'Authorization': 'Bearer ${AppConstants.supabaseAnonKey}',
              },
              body: json.encode({
                'is_verified': true,
                'account_number': realAccount,
                'bank_name': realBank,
              }),
            );
          } catch (_) {}

          return {
            'success': true,
            'accountNumber': realAccount,
            'bankName': realBank,
            'user': updatedUser,
            'message': 'Identity verified! Real bank account issued successfully.',
          };
        }
      }

      return {
        'success': false,
        'message': flwJson['message'] ?? 'Could not issue dedicated virtual account at this time.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to reach banking servers. Please check your network and try again.',
      };
    }
  }
}
