class GlobalPayCorridor {
  final String currency;
  final String country;
  final String rail;
  final String processingTime;
  final double flatFeeNgn;

  GlobalPayCorridor({
    required this.currency,
    required this.country,
    required this.rail,
    required this.processingTime,
    required this.flatFeeNgn,
  });

  factory GlobalPayCorridor.fromJson(Map<String, dynamic> json) {
    return GlobalPayCorridor(
      currency: json['currency']?.toString() ?? 'USD',
      country: json['country']?.toString() ?? 'Global',
      rail: json['rail']?.toString() ?? 'SWIFT',
      processingTime: json['processingTime']?.toString() ?? '24 - 48 Hours',
      flatFeeNgn: (json['flatFeeNgn'] as num?)?.toDouble() ?? 5000.0,
    );
  }
}

class GlobalPayQuote {
  final String quoteReference;
  final String sourceCurrency;
  final String destinationCurrency;
  final double destinationAmount;
  final double sourceAmountNgn;
  final double wholesaleRate;
  final double customerRate;
  final double fxSpreadPercent;
  final double platformFeePercent;
  final double platformFeeNgn;
  final double corridorFeeNgn;
  final double totalFeeNgn;
  final double totalDebitedNgn;
  final String paymentScheme;
  final String expiresAt;
  final int ttlSeconds;

  GlobalPayQuote({
    required this.quoteReference,
    required this.sourceCurrency,
    required this.destinationCurrency,
    required this.destinationAmount,
    required this.sourceAmountNgn,
    required this.wholesaleRate,
    required this.customerRate,
    required this.fxSpreadPercent,
    this.platformFeePercent = 1.20,
    this.platformFeeNgn = 0.0,
    required this.corridorFeeNgn,
    this.totalFeeNgn = 0.0,
    required this.totalDebitedNgn,
    required this.paymentScheme,
    required this.expiresAt,
    required this.ttlSeconds,
  });

  factory GlobalPayQuote.fromJson(Map<String, dynamic> json) {
    final corridor = (json['corridorFeeNgn'] as num?)?.toDouble() ?? 0.0;
    final platFee = (json['platformFeeNgn'] as num?)?.toDouble() ?? 0.0;
    final totFee = (json['totalFeeNgn'] as num?)?.toDouble() ?? (corridor + platFee);

    return GlobalPayQuote(
      quoteReference: json['quoteReference']?.toString() ?? '',
      sourceCurrency: json['sourceCurrency']?.toString() ?? 'NGN',
      destinationCurrency: json['destinationCurrency']?.toString() ?? 'USD',
      destinationAmount: (json['destinationAmount'] as num?)?.toDouble() ?? 0.0,
      sourceAmountNgn: (json['sourceAmountNgn'] as num?)?.toDouble() ?? 0.0,
      wholesaleRate: (json['wholesaleRate'] as num?)?.toDouble() ?? 0.0,
      customerRate: (json['customerRate'] as num?)?.toDouble() ?? 0.0,
      fxSpreadPercent: (json['fxSpreadPercent'] as num?)?.toDouble() ?? 1.2,
      platformFeePercent: (json['platformFeePercent'] as num?)?.toDouble() ?? ((json['fxSpreadPercent'] as num?)?.toDouble() ?? 1.2),
      platformFeeNgn: platFee,
      corridorFeeNgn: corridor,
      totalFeeNgn: totFee,
      totalDebitedNgn: (json['totalDebitedNgn'] as num?)?.toDouble() ?? 0.0,
      paymentScheme: json['paymentScheme']?.toString() ?? 'swift',
      expiresAt: json['expiresAt']?.toString() ?? '',
      ttlSeconds: (json['ttlSeconds'] as num?)?.toInt() ?? 900,
    );
  }
}

class UniversalBeneficiary {
  final String name;
  final String? email;
  final String countryCode;
  final String currency;
  final String? bankName;
  final String? bankAddress;
  final String accountNumberOrIban;
  final String? routingCode;
  final String? swiftBic;
  final String? mobileOperator;
  final String type; // 'individual' | 'corporate'

  UniversalBeneficiary({
    required this.name,
    this.email,
    required this.countryCode,
    required this.currency,
    this.bankName,
    this.bankAddress,
    required this.accountNumberOrIban,
    this.routingCode,
    this.swiftBic,
    this.mobileOperator,
    this.type = 'individual',
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (email != null && email!.isNotEmpty) 'email': email,
      'countryCode': countryCode,
      'currency': currency,
      if (bankName != null && bankName!.isNotEmpty) 'bankName': bankName,
      if (bankAddress != null && bankAddress!.isNotEmpty) 'bankAddress': bankAddress,
      'accountNumberOrIban': accountNumberOrIban,
      if (routingCode != null && routingCode!.isNotEmpty) 'routingCode': routingCode,
      if (swiftBic != null && swiftBic!.isNotEmpty) 'swiftBic': swiftBic,
      if (mobileOperator != null && mobileOperator!.isNotEmpty) 'mobileOperator': mobileOperator,
      'type': type,
    };
  }

  factory UniversalBeneficiary.fromJson(Map<String, dynamic> json) {
    return UniversalBeneficiary(
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString(),
      countryCode: json['countryCode']?.toString() ?? 'GB',
      currency: json['currency']?.toString() ?? 'GBP',
      bankName: json['bankName']?.toString(),
      bankAddress: json['bankAddress']?.toString(),
      accountNumberOrIban: json['accountNumberOrIban']?.toString() ?? '',
      routingCode: json['routingCode']?.toString(),
      swiftBic: json['swiftBic']?.toString(),
      mobileOperator: json['mobileOperator']?.toString(),
      type: json['type']?.toString() ?? 'individual',
    );
  }
}

class GlobalPayoutRecord {
  final String id;
  final String reference;
  final String orderType;
  final String? transferPurpose;
  final UniversalBeneficiary beneficiary;
  final String destinationCurrency;
  final double destinationAmount;
  final double sourceAmountNgn;
  final double customerRate;
  final double corridorFeeNgn;
  final double totalDebitedNgn;
  final String paymentScheme;
  final String status;
  final String? fincraPayoutReference;
  final String createdAt;

  GlobalPayoutRecord({
    required this.id,
    required this.reference,
    required this.orderType,
    this.transferPurpose,
    required this.beneficiary,
    required this.destinationCurrency,
    required this.destinationAmount,
    required this.sourceAmountNgn,
    required this.customerRate,
    required this.corridorFeeNgn,
    required this.totalDebitedNgn,
    required this.paymentScheme,
    required this.status,
    this.fincraPayoutReference,
    required this.createdAt,
  });

  factory GlobalPayoutRecord.fromJson(Map<String, dynamic> json) {
    return GlobalPayoutRecord(
      id: json['id']?.toString() ?? '',
      reference: json['reference']?.toString() ?? '',
      orderType: json['orderType']?.toString() ?? 'remittance',
      transferPurpose: json['transferPurpose']?.toString(),
      beneficiary: UniversalBeneficiary.fromJson(json['beneficiary'] is Map ? Map<String, dynamic>.from(json['beneficiary']) : {}),
      destinationCurrency: json['destinationCurrency']?.toString() ?? 'USD',
      destinationAmount: (json['destinationAmount'] as num?)?.toDouble() ?? 0.0,
      sourceAmountNgn: (json['sourceAmountNgn'] as num?)?.toDouble() ?? 0.0,
      customerRate: (json['customerRate'] as num?)?.toDouble() ?? 0.0,
      corridorFeeNgn: (json['corridorFeeNgn'] as num?)?.toDouble() ?? 0.0,
      totalDebitedNgn: (json['totalDebitedNgn'] as num?)?.toDouble() ?? 0.0,
      paymentScheme: json['paymentScheme']?.toString() ?? 'swift',
      status: json['status']?.toString() ?? 'PROCESSING',
      fincraPayoutReference: json['fincraPayoutReference']?.toString(),
      createdAt: json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }
}