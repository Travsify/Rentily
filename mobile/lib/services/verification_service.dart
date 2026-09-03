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
    String? officeAddress,
    String? state,
    String? city,
    String? lga,
    String? landmark,
  }) async {
    final currentUser = await AuthService.getCurrentUser();
    final userId = currentUser?.id ?? 'usr_${DateTime.now().millisecondsSinceEpoch}';
    final email = currentUser?.email ?? '';
    final phone = currentUser?.phoneNumber ?? '';
    final isPartner = currentUser?.role == 'partner';

    final partnerBizName = businessName ?? currentUser?.businessName;
    final effectiveName = isPartner
        ? ((partnerBizName != null && partnerBizName.trim().isNotEmpty) ? partnerBizName.trim() : (currentUser?.fullName.trim().isNotEmpty == true ? currentUser!.fullName.trim() : 'Rentilly Partner'))
        : (currentUser?.fullName.trim().isNotEmpty == true ? currentUser!.fullName.trim() : 'Rentilly User');

    final bvnToUse = bvn.trim().isNotEmpty ? bvn.trim() : (idType == 'bvn' ? idNumber.trim() : '');

    // Sole authoritative call: Rentilly Central Tier 1 KYC / KYB Provisioning Router
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
          'officeAddress': officeAddress ?? currentUser?.officeAddress,
          'state': state ?? currentUser?.state,
          'city': city,
          'lga': lga,
          'landmark': landmark,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && (data['status'] == true || data['success'] == true)) {
        final isProcessing = data['processing'] == true || data['accountNumber'] == null || data['accountNumber'] == '';
        final accNum = data['accountNumber']?.toString() ?? '';
        String rawBank = data['bankName']?.toString() ?? '9PSB (Rentilly)';
        final cleanBank = rawBank.contains('(') ? rawBank.split('(')[0].trim() : rawBank;

        final serverBal = (data['walletBalance'] as num?)?.toDouble() ?? currentUser?.walletBalance ?? 0.0;
        final serverUsdt = (data['usdtBalance'] as num?)?.toDouble() ?? currentUser?.usdtBalance ?? 0.0;
        final failReason = data['reason']?.toString() ?? data['message']?.toString() ?? '9PSB account generation is pending validation with NIBSS.';

        final updatedUser = (currentUser ?? UserProfile(
          id: userId,
          email: email,
          fullName: effectiveName,
          phoneNumber: phone,
          role: currentUser?.role ?? 'renter',
        )).copyWith(
          isVerified: !isProcessing,
          bvnVerified: !isProcessing,
          rekycRequired: isProcessing,
          kycFailureReason: isProcessing ? failReason : null,
          businessName: isPartner ? partnerBizName : currentUser?.businessName,
          cacNumber: isPartner ? (cacNumber ?? currentUser?.cacNumber) : currentUser?.cacNumber,
          ninNumber: idType == 'nin' ? idNumber : currentUser?.ninNumber,
          accountNumber: accNum.isNotEmpty ? accNum : null,
          bankName: isProcessing ? '9PSB (Rentilly Processing)' : cleanBank,
          walletBalance: serverBal,
          usdtBalance: serverUsdt,
        );

        await AuthService.updateUser(updatedUser);

        if (isProcessing) {
          return {
            'success': false,
            'processing': true,
            'message': failReason,
            'user': updatedUser,
          };
        }

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
