import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../models/user_profile.dart';
import 'auth_service.dart';

class VerificationService {
  static const String baseUrl = AppConstants.apiBaseUrl;

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

    // Sole authoritative call: Rentilly Maplerad Tier 1 KYC / KYB Provisioning Router
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
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && (data['status'] == true || data['success'] == true)) {
        final accNum = data['accountNumber']?.toString() ?? currentUser?.accountNumber ?? '';
        String rawBank = data['bankName']?.toString() ?? currentUser?.bankName ?? '9PSB (Rentilly)';
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
          accountNumber: accNum.isNotEmpty ? accNum : currentUser?.accountNumber,
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
          'message': data['message'] ?? (isPartner
              ? 'Corporate KYB verified! Dedicated commission vault provisioned in your business name: $effectiveName.'
              : 'Identity verified successfully! Dedicated Rentilly account provisioned.'),
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? data['message'] ?? 'Verification failed. Please check your BVN, CAC, and identity document details.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Could not connect to verification server ($e). Please check your internet connection and try again.',
      };
    }
  }
}
