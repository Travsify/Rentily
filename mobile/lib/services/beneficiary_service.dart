import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../services/auth_service.dart';

class BeneficiaryService {
  static const String _storagePrefix = 'rentilly_beneficiaries_';

  /// Returns normalized storage key for a user
  static String _getKey(String email) {
    return '$_storagePrefix${email.trim().toLowerCase()}';
  }

  /// Get all saved beneficiaries for a user, automatically merged with past transaction recipients
  static Future<List<Map<String, dynamic>>> getBeneficiaries({String? userEmail}) async {
    try {
      final email = userEmail?.trim().toLowerCase() ?? 
          (await AuthService.getCurrentUser())?.email.trim().toLowerCase() ?? '';

      if (email.isEmpty) return [];

      final prefs = await SharedPreferences.getInstance();
      final key = _getKey(email);
      final rawJson = prefs.getString(key);

      Map<String, Map<String, dynamic>> deduped = {};

      // 1. Ingest locally saved beneficiaries
      if (rawJson != null && rawJson.isNotEmpty) {
        try {
          final decoded = json.decode(rawJson);
          if (decoded is List) {
            for (final item in decoded) {
              if (item is Map) {
                final m = Map<String, dynamic>.from(item);
                final acc = (m['accountNumber'] ?? '').toString().trim();
                final name = (m['accountName'] ?? '').toString().trim();
                final dedupeKey = acc.length == 10 ? acc : name.toLowerCase();
                if (dedupeKey.isNotEmpty) {
                  deduped[dedupeKey] = m;
                }
              }
            }
          }
        } catch (e) {
          debugPrint('[BeneficiaryService] Error decoding saved beneficiaries: $e');
        }
      }

      // 2. Scan locally cached transactions
      final cachedTxJson = prefs.getString('rentilly_cached_tx_$email');
      if (cachedTxJson != null && cachedTxJson.isNotEmpty) {
        try {
          final decodedTx = json.decode(cachedTxJson);
          if (decodedTx is List) {
            for (final tx in decodedTx) {
              if (tx is Map) {
                final extracted = _extractFromTx(Map<String, dynamic>.from(tx));
                if (extracted != null) {
                  final acc = (extracted['accountNumber'] ?? '').toString().trim();
                  final name = (extracted['accountName'] ?? '').toString().trim();
                  final dedupeKey = acc.length == 10 ? acc : name.toLowerCase();
                  if (dedupeKey.isNotEmpty && !deduped.containsKey(dedupeKey)) {
                    deduped[dedupeKey] = extracted;
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('[BeneficiaryService] Error scanning local cached tx: $e');
        }
      }

      // 3. Network Fetch: Try dedicated server beneficiaries endpoint first
      try {
        final benUrl = Uri.parse('${AppConstants.apiBaseUrl}/payments/beneficiaries?email=${Uri.encodeComponent(email)}');
        final benRes = await http.get(benUrl).timeout(const Duration(seconds: 4));
        if (benRes.statusCode == 200) {
          final benJson = json.decode(benRes.body);
          if (benJson['status'] == true && benJson['data'] is List) {
            for (final item in benJson['data']) {
              if (item is Map) {
                final m = Map<String, dynamic>.from(item);
                final acc = (m['accountNumber'] ?? '').toString().trim();
                final name = (m['accountName'] ?? '').toString().trim();
                final dedupeKey = acc.length == 10 ? acc : name.toLowerCase();
                if (dedupeKey.isNotEmpty) {
                  if (deduped.containsKey(dedupeKey)) {
                    final existing = deduped[dedupeKey]!;
                    deduped[dedupeKey] = {
                      ...existing,
                      ...m,
                      'useCount': ((existing['useCount'] as num?)?.toInt() ?? 1) + 
                                  ((m['useCount'] as num?)?.toInt() ?? 1),
                    };
                  } else {
                    deduped[dedupeKey] = m;
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[BeneficiaryService] Remote beneficiaries sync warning: $e');
      }

      // 4. Fallback Network Fetch: If still empty, fetch live transactions
      if (deduped.isEmpty) {
        try {
          final txUrl = Uri.parse('${AppConstants.apiBaseUrl}/payments/transactions?email=${Uri.encodeComponent(email)}');
          final txRes = await http.get(txUrl).timeout(const Duration(seconds: 4));
          if (txRes.statusCode == 200) {
            final txJson = json.decode(txRes.body);
            if (txJson['status'] == true && txJson['data'] is List) {
              final txList = List<Map<String, dynamic>>.from(txJson['data']);
              // Update local cache
              await prefs.setString('rentilly_cached_tx_$email', json.encode(txList));

              for (final tx in txList) {
                final extracted = _extractFromTx(tx);
                if (extracted != null) {
                  final acc = (extracted['accountNumber'] ?? '').toString().trim();
                  final name = (extracted['accountName'] ?? '').toString().trim();
                  final dedupeKey = acc.length == 10 ? acc : name.toLowerCase();
                  if (dedupeKey.isNotEmpty && !deduped.containsKey(dedupeKey)) {
                    deduped[dedupeKey] = extracted;
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('[BeneficiaryService] Remote transactions sync warning: $e');
        }
      }

      final result = deduped.values.toList();

      // Sort by lastUsed descending
      result.sort((a, b) {
        final dateA = DateTime.tryParse(a['lastUsed']?.toString() ?? '') ?? DateTime(2020);
        final dateB = DateTime.tryParse(b['lastUsed']?.toString() ?? '') ?? DateTime(2020);
        return dateB.compareTo(dateA);
      });

      // Persist merged beneficiaries locally for fast offline access
      if (result.isNotEmpty) {
        await prefs.setString(key, json.encode(result.take(50).toList()));
      }

      return result;
    } catch (e) {
      debugPrint('[BeneficiaryService] getBeneficiaries error: $e');
      return [];
    }
  }

  /// Extracts structured beneficiary info from any transaction record
  static Map<String, dynamic>? _extractFromTx(Map<String, dynamic> tx) {
    final title = (tx['title'] ?? '').toString();
    final narration = (tx['narration'] ?? '').toString();
    final description = (tx['description'] ?? '').toString();
    final subtitle = (tx['subtitle'] ?? '').toString();
    final fullText = '$title $narration $description $subtitle';

    final isWithdrawal = tx['category'] == 'withdrawal' ||
        tx['type'] == 'debit' ||
        tx['type'] == 'Instant Direct Bank Payout' ||
        title.toLowerCase().contains('payout') ||
        title.toLowerCase().contains('withdrawal') ||
        subtitle.toLowerCase().contains('to:') ||
        narration.toLowerCase().contains('payout');

    if (!isWithdrawal) return null;

    String name = (tx['beneficiary'] ?? tx['accountName'] ?? tx['recipient'] ?? '').toString().trim();
    String account = (tx['accountNumber'] ?? tx['recipientAccount'] ?? tx['account_number'] ?? '').toString().trim();
    String bank = (tx['bankName'] ?? tx['recipientBank'] ?? tx['bank_name'] ?? '').toString().trim();

    // Regex 1: "Payout to NAME (ACCOUNT)"
    final m1 = RegExp(r'Payout to\s+([A-Za-z\s]+?)\s*\((\d{10})\)', caseSensitive: false).firstMatch(fullText);
    if (m1 != null) {
      if (name.isEmpty) name = m1.group(1)?.trim() ?? '';
      if (account.isEmpty) account = m1.group(2)?.trim() ?? '';
    }

    // Regex 2: "Payout to NAME • Incl" or "Bank Transfer Payout to NAME"
    if (name.isEmpty) {
      final m2 = RegExp(r'Payout to\s+([A-Za-z\s]+?)(?:[•\(\-\[]|$)', caseSensitive: false).firstMatch(fullText);
      if (m2 != null) name = m2.group(1)?.trim() ?? '';
    }

    // Regex 3: Any 10-digit number
    if (account.isEmpty || account.length != 10) {
      final mAcc = RegExp(r'\b(\d{10})\b').firstMatch(fullText);
      if (mAcc != null) account = mAcc.group(1) ?? '';
    }

    if (name.length < 2) return null;

    // Clean up name
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    name = name.replaceAll(RegExp(r'•.*$'), '').trim();

    if (bank.isEmpty || bank.toLowerCase() == 'direct bank transfer') {
      bank = _guessBankNameFromText(account, fullText);
    }

    final bankCode = tx['bankCode']?.toString() ?? _guessBankCode(bank);
    final lastUsed = tx['date'] ?? tx['createdAt'] ?? tx['created_at'] ?? DateTime.now().toIso8601String();

    return {
      'accountName': name,
      'accountNumber': account.isNotEmpty ? account : '0000000000',
      'bankName': bank,
      'bankCode': bankCode,
      'type': 'bank',
      'lastUsed': lastUsed.toString(),
      'useCount': 1,
    };
  }

  /// Saves or updates a beneficiary locally and to server
  static Future<bool> saveBeneficiary({
    required String userEmail,
    required String accountName,
    required String accountNumber,
    required String bankName,
    required String bankCode,
    String type = 'bank',
    String? cryptoAddress,
  }) async {
    try {
      final cleanEmail = userEmail.trim().toLowerCase();
      if (cleanEmail.isEmpty) return false;

      final prefs = await SharedPreferences.getInstance();
      final key = _getKey(cleanEmail);
      final list = await getBeneficiaries(userEmail: cleanEmail);

      final cleanAcc = accountNumber.trim();
      final cleanBankCode = bankCode.trim();
      final cleanCrypto = cryptoAddress?.trim() ?? '';

      int existingIdx = -1;
      if (type == 'crypto') {
        existingIdx = list.indexWhere((b) => 
            b['type'] == 'crypto' && b['cryptoAddress'] == cleanCrypto);
      } else {
        existingIdx = list.indexWhere((b) => 
            b['accountNumber'] == cleanAcc && b['bankCode'] == cleanBankCode);
      }

      final nowIso = DateTime.now().toIso8601String();

      if (existingIdx >= 0) {
        final current = list[existingIdx];
        final currentCount = (current['useCount'] as num?)?.toInt() ?? 1;
        list[existingIdx] = {
          ...current,
          'accountName': accountName.trim(),
          'bankName': bankName.trim(),
          'bankCode': cleanBankCode,
          'lastUsed': nowIso,
          'useCount': currentCount + 1,
          if (cryptoAddress != null) 'cryptoAddress': cleanCrypto,
        };
      } else {
        list.insert(0, {
          'accountName': accountName.trim(),
          'accountNumber': cleanAcc,
          'bankName': bankName.trim(),
          'bankCode': cleanBankCode,
          'type': type,
          'lastUsed': nowIso,
          'useCount': 1,
          if (cryptoAddress != null) 'cryptoAddress': cleanCrypto,
        });
      }

      // Limit to 50 saved beneficiaries
      final trimmed = list.take(50).toList();
      await prefs.setString(key, json.encode(trimmed));

      // Push to server in background
      try {
        final url = Uri.parse('${AppConstants.apiBaseUrl}/payments/beneficiaries');
        http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'email': cleanEmail,
            'accountName': accountName.trim(),
            'accountNumber': cleanAcc,
            'bankName': bankName.trim(),
            'bankCode': cleanBankCode,
            'type': type,
            if (cryptoAddress != null) 'cryptoAddress': cleanCrypto,
          }),
        ).timeout(const Duration(seconds: 4));
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('[BeneficiaryService] saveBeneficiary error: $e');
      return false;
    }
  }

  /// Deletes a saved beneficiary
  static Future<bool> deleteBeneficiary({
    required String userEmail,
    required String accountNumber,
    required String bankCode,
  }) async {
    try {
      final cleanEmail = userEmail.trim().toLowerCase();
      final prefs = await SharedPreferences.getInstance();
      final key = _getKey(cleanEmail);
      final list = await getBeneficiaries(userEmail: cleanEmail);

      list.removeWhere((b) => 
          b['accountNumber'] == accountNumber.trim() && 
          b['bankCode'] == bankCode.trim());

      await prefs.setString(key, json.encode(list));
      return true;
    } catch (e) {
      debugPrint('[BeneficiaryService] deleteBeneficiary error: $e');
      return false;
    }
  }

  /// Search beneficiaries by name, bank name, or account number
  static List<Map<String, dynamic>> search(String query, List<Map<String, dynamic>> all) {
    if (query.trim().isEmpty) return all;
    final q = query.trim().toLowerCase();
    return all.where((b) {
      final name = (b['accountName'] ?? '').toString().toLowerCase();
      final bank = (b['bankName'] ?? '').toString().toLowerCase();
      final acc = (b['accountNumber'] ?? '').toString().toLowerCase();
      final crypto = (b['cryptoAddress'] ?? '').toString().toLowerCase();
      return name.contains(q) || bank.contains(q) || acc.contains(q) || crypto.contains(q);
    }).toList();
  }

  /// Guesses bank name from context and account structure
  static String _guessBankNameFromText(String account, String text) {
    final t = text.toLowerCase();
    if (t.contains('opay')) return 'OPay Digital Services (OPay)';
    if (t.contains('palmpay')) return 'PalmPay';
    if (t.contains('kuda')) return 'Kuda Microfinance Bank';
    if (t.contains('moniepoint')) return 'Moniepoint Microfinance Bank';
    if (t.contains('gtb') || t.contains('guaranty')) return 'Guaranty Trust Bank (GTBank)';
    if (t.contains('zenith')) return 'Zenith Bank';
    if (t.contains('access')) return 'Access Bank';
    if (t.contains('first bank')) return 'First Bank of Nigeria';
    if (t.contains('uba') || t.contains('united bank')) return 'United Bank for Africa (UBA)';
    if (t.contains('wema')) return 'Wema Bank';
    if (t.contains('providus')) return 'Providus Bank';
    if (t.contains('fidelity')) return 'Fidelity Bank';
    if (t.contains('stanbic')) return 'Stanbic IBTC Bank';
    if (t.contains('sterling')) return 'Sterling Bank';
    if (RegExp(r'^[789]\d{9}$').hasMatch(account)) return 'OPay Digital Services (OPay)';
    return 'Nigerian Bank';
  }

  /// Helper to guess bank code from standard Nigerian bank names
  static String _guessBankCode(String bankName) {
    final bn = bankName.toLowerCase();
    if (bn.contains('guaranty') || bn.contains('gtb')) return '058';
    if (bn.contains('zenith')) return '057';
    if (bn.contains('access')) return '044';
    if (bn.contains('first bank')) return '011';
    if (bn.contains('uba') || bn.contains('united bank')) return '033';
    if (bn.contains('kuda')) return '50211';
    if (bn.contains('opay')) return '999992';
    if (bn.contains('palmpay')) return '999991';
    if (bn.contains('wema')) return '035';
    if (bn.contains('providus')) return '101';
    if (bn.contains('fidelity')) return '070';
    if (bn.contains('stanbic')) return '221';
    if (bn.contains('moniepoint')) return '50515';
    if (bn.contains('sterling')) return '232';
    if (bn.contains('union')) return '032';
    if (bn.contains('ecobank')) return '050';
    if (bn.contains('fcmb')) return '214';
    if (bn.contains('polaris')) return '076';
    if (bn.contains('vfd')) return '566';
    if (bn.contains('jaiz')) return '301';
    if (bn.contains('taj')) return '302';
    return '058'; // Default
  }
}
