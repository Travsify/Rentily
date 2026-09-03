import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../models/user_profile.dart';
import 'auth_service.dart';

class VerificationService {
  static const String baseUrl = AppConstants.apiBaseUrl;
  static const String premblySecretKey = 'live_sec_oOq6uB3m6J3k2V9xR8tP1wS4nF5zY7aD';
  static const String premblyAppId = 'app_live_88492048';
  static const String flutterwaveSecretKey = 'FLWSECK-2a833d7d7454e38e1215b225916053aa-193498877521-X';

  /// Performs Corporate KYB / Identity verification and issues a dedicated NUBAN virtual bank account.
  /// For Partners: account is issued in the Partner's Business Name.
  /// For Landlords / Renters: account is issued in their personal Legal Full Name.
  static Future<Map<String, dynamic>> verifyAndProvision({
    required String idType,
    required String idNumber,
    required String bvn,
    required String dob,
    String? businessName,
    String? cacNumber,
  }) async {
    final currentUser = await AuthService.getCurrentUser();
    final userId = currentUser?.id ?? 'usr_${DateTime.now().millisecondsSinceEpoch}';
    final email = currentUser?.email ?? 'info@myrentilly.com';
    final phone = currentUser?.phoneNumber ?? '08120000000';
    final isPartner = currentUser?.role == 'partner';

    final partnerBizName = businessName ?? currentUser?.businessName;
    final effectiveName = isPartner
        ? ((partnerBizName != null && partnerBizName.trim().isNotEmpty) ? partnerBizName.trim() : currentUser?.fullName.trim() ?? 'Corporate Partner')
        : (currentUser?.fullName.trim().isNotEmpty == true ? currentUser!.fullName.trim() : 'Property Owner');

    final bvnToUse = bvn.trim().isNotEmpty ? bvn.trim() : (idType == 'bvn' ? idNumber.trim() : '');

    // Step A: Attempt via Core Backend (Flutterwave MFB provisioning router)
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verification/verify-and-provision'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'email': email,
          'fullName': effectiveName,
          'businessName': partnerBizName,
          'cacNumber': cacNumber ?? currentUser?.cacNumber,
          'phoneNumber': phone,
          'idType': idType,
          'idNumber': idNumber.trim(),
          'bvn': bvnToUse,
          'dob': dob,
          'role': currentUser?.role ?? 'renter',
        }),
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['accountNumber'] != null) {
          final accNum = data['accountNumber']?.toString() ?? '';
          if (accNum.isNotEmpty) {
            String rawBank = data['bankName']?.toString() ?? '9PSB';
            final cleanBank = rawBank.contains('(') ? rawBank.split('(')[0].trim() : rawBank;

            final serverBal = (data['walletBalance'] as num?)?.toDouble() ?? currentUser?.walletBalance ?? 0.0;
            final serverUsdt = (data['usdtBalance'] as num?)?.toDouble() ?? currentUser?.usdtBalance ?? 0.0;

            final updatedUser = (currentUser ?? UserProfile(
              id: userId,
              email: email,
              fullName: effectiveName,
              phoneNumber: phone,
              role: currentUser?.role ?? 'renter',
            )).copyWith(
              isVerified: true,
              bvnVerified: true,
              businessName: isPartner ? partnerBizName : currentUser?.businessName,
              cacNumber: isPartner ? (cacNumber ?? currentUser?.cacNumber) : currentUser?.cacNumber,
              ninNumber: idType == 'nin' ? idNumber : currentUser?.ninNumber,
              accountNumber: accNum,
              bankName: cleanBank,
              walletBalance: serverBal,
              usdtBalance: serverUsdt,
            );

            await AuthService.updateUser(updatedUser);

            return {
              'success': true,
              'accountNumber': accNum,
              'bankName': cleanBank,
              'user': updatedUser,
              'message': isPartner
                  ? 'Corporate KYB verified! Dedicated commission account issued in your business name.'
                  : 'Identity verified and dedicated account issued!',
            };
          }
        }
      }
    } catch (_) {}

    // Step B: Direct Call to Flutterwave Cloud API
    try {
      String firstName;
      String lastName;

      if (isPartner) {
        firstName = effectiveName;
        lastName = 'Rentilly Partner';
      } else {
        final nameParts = effectiveName.split(' ');
        firstName = nameParts.first;
        lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : 'Rentilly';
      }

      final flwRes = await http.post(
        Uri.parse('https://api.flutterwave.com/v3/virtual-account-numbers'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $flutterwaveSecretKey',
        },
        body: json.encode({
          'email': email,
          'is_permanent': true,
          'bvn': bvnToUse,
          'tx_ref': 'RENTILLY_ACC_${userId}_${DateTime.now().millisecondsSinceEpoch}',
          'phonenumber': phone,
          'firstname': firstName,
          'lastname': lastName,
          'narration': isPartner ? 'Rentilly Partner - $effectiveName' : 'Rentilly Living - $effectiveName',
        }),
      ).timeout(const Duration(seconds: 25));

      final flwJson = json.decode(flwRes.body);

      if (flwRes.statusCode == 200 && flwJson['status'] == 'success' && flwJson['data'] != null) {
        final realAccount = flwJson['data']['account_number']?.toString();
        String rawBank = flwJson['data']['bank_name']?.toString() ?? 'Flutterwave MFB';
        final cleanBank = rawBank.contains('(') ? rawBank.split('(')[0].trim() : rawBank;

        if (realAccount != null && realAccount.isNotEmpty) {
          final updatedUser = (currentUser ?? UserProfile(
            id: userId,
            email: email,
            fullName: effectiveName,
            phoneNumber: phone,
            role: currentUser?.role ?? 'renter',
          )).copyWith(
            isVerified: true,
            bvnVerified: true,
            businessName: isPartner ? partnerBizName : currentUser?.businessName,
            cacNumber: isPartner ? (cacNumber ?? currentUser?.cacNumber) : currentUser?.cacNumber,
            ninNumber: idNumber,
            accountNumber: realAccount,
            bankName: cleanBank,
          );

          await AuthService.updateUser(updatedUser);

          return {
            'success': true,
            'accountNumber': realAccount,
            'bankName': cleanBank,
            'user': updatedUser,
            'message': isPartner
                ? 'Corporate KYB verified! Dedicated commission vault provisioned in your business name: $effectiveName.'
                : 'Identity verified! Your Rentilly dedicated account has been provisioned.',
          };
        }
      }

      return {
        'success': false,
        'message': flwJson['message'] ?? 'Failed to provision dedicated NUBAN from Flutterwave.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to reach Flutterwave API: $e',
      };
    }
  }
}
