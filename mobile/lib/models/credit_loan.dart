class CreditEligibility {
  final bool isEligible;
  final double minSavingsThreshold;
  final double currentSavingsBalance;
  final double maxBorrowableAmount;
  final CreditLoan? activeLoan;
  final double interestRatePerMonth;
  final double annualSavingsYieldRate;
  final String? reason;
  final List<CreditTenureOption> tenureOptions;

  CreditEligibility({
    required this.isEligible,
    required this.minSavingsThreshold,
    required this.currentSavingsBalance,
    required this.maxBorrowableAmount,
    this.activeLoan,
    this.interestRatePerMonth = 0.025,
    this.annualSavingsYieldRate = 0.025,
    this.reason,
    required this.tenureOptions,
  });

  factory CreditEligibility.fromJson(Map<String, dynamic> json) {
    return CreditEligibility(
      isEligible: json['isEligible'] ?? false,
      minSavingsThreshold: ((json['minSavingsThreshold'] ?? 20000.0) as num).toDouble(),
      currentSavingsBalance: ((json['currentSavingsBalance'] ?? 0.0) as num).toDouble(),
      maxBorrowableAmount: ((json['maxBorrowableAmount'] ?? 0.0) as num).toDouble(),
      activeLoan: json['activeLoan'] != null ? CreditLoan.fromJson(json['activeLoan']) : null,
      interestRatePerMonth: ((json['interestRatePerMonth'] ?? 0.025) as num).toDouble(),
      annualSavingsYieldRate: ((json['annualSavingsYieldRate'] ?? 0.025) as num).toDouble(),
      reason: json['reason'],
      tenureOptions: (json['tenureOptions'] as List<dynamic>? ?? [])
          .map((e) => CreditTenureOption.fromJson(e))
          .toList(),
    );
  }
}

class CreditTenureOption {
  final int days; // 30, 60, 90
  final String label;
  final double ratePct;
  final double monthlyInterestPct;

  CreditTenureOption({
    required this.days,
    required this.label,
    required this.ratePct,
    required this.monthlyInterestPct,
  });

  factory CreditTenureOption.fromJson(Map<String, dynamic> json) {
    return CreditTenureOption(
      days: (json['days'] as num?)?.toInt() ?? 30,
      label: json['label'] ?? '30 Days',
      ratePct: ((json['ratePct'] ?? 2.5) as num).toDouble(),
      monthlyInterestPct: ((json['monthlyInterestPct'] ?? 2.5) as num).toDouble(),
    );
  }
}

class CreditLoan {
  final String id;
  final String userId;
  final String userEmail;
  final String userName;
  final String userPhone;
  final double principalAmount;
  final int tenureDays;
  final double monthlyInterestRate;
  final double totalInterestRate;
  final double interestAmount;
  final double totalRepaymentDue;
  final double amountRepaid;
  final double outstandingBalance;
  final double collateralLocked;
  final double savingsBalanceAtBorrow;
  final String status; // 'active' | 'repaid' | 'liquidated' | 'overdue'
  final DateTime disbursedAt;
  final DateTime dueDate;
  final DateTime? settledAt;
  final List<CreditRepaymentRecord> repaymentHistory;

  CreditLoan({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.userPhone,
    required this.principalAmount,
    required this.tenureDays,
    required this.monthlyInterestRate,
    required this.totalInterestRate,
    required this.interestAmount,
    required this.totalRepaymentDue,
    required this.amountRepaid,
    required this.outstandingBalance,
    required this.collateralLocked,
    required this.savingsBalanceAtBorrow,
    required this.status,
    required this.disbursedAt,
    required this.dueDate,
    this.settledAt,
    this.repaymentHistory = const [],
  });

  factory CreditLoan.fromJson(Map<String, dynamic> json) {
    return CreditLoan(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      userEmail: json['userEmail'] ?? '',
      userName: json['userName'] ?? '',
      userPhone: json['userPhone'] ?? '',
      principalAmount: ((json['principalAmount'] ?? 0.0) as num).toDouble(),
      tenureDays: (json['tenureDays'] as num?)?.toInt() ?? 30,
      monthlyInterestRate: ((json['monthlyInterestRate'] ?? 0.025) as num).toDouble(),
      totalInterestRate: ((json['totalInterestRate'] ?? 0.025) as num).toDouble(),
      interestAmount: ((json['interestAmount'] ?? 0.0) as num).toDouble(),
      totalRepaymentDue: ((json['totalRepaymentDue'] ?? 0.0) as num).toDouble(),
      amountRepaid: ((json['amountRepaid'] ?? 0.0) as num).toDouble(),
      outstandingBalance: ((json['outstandingBalance'] ?? 0.0) as num).toDouble(),
      collateralLocked: ((json['collateralLocked'] ?? 0.0) as num).toDouble(),
      savingsBalanceAtBorrow: ((json['savingsBalanceAtBorrow'] ?? 0.0) as num).toDouble(),
      status: json['status'] ?? 'active',
      disbursedAt: DateTime.tryParse(json['disbursedAt'] ?? '') ?? DateTime.now(),
      dueDate: DateTime.tryParse(json['dueDate'] ?? '') ?? DateTime.now().add(const Duration(days: 30)),
      settledAt: json['settledAt'] != null ? DateTime.tryParse(json['settledAt']) : null,
      repaymentHistory: (json['repaymentHistory'] as List<dynamic>? ?? [])
          .map((e) => CreditRepaymentRecord.fromJson(e))
          .toList(),
    );
  }

  bool get isActive => status == 'active';
  bool get isRepaid => status == 'repaid';
  bool get isOverdue => status == 'overdue';
  bool get isLiquidated => status == 'liquidated';

  int get daysRemaining {
    final diff = dueDate.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }
}

class CreditRepaymentRecord {
  final String id;
  final double amount;
  final DateTime timestamp;
  final String method;
  final double previousBalance;
  final double newBalance;
  final String reference;

  CreditRepaymentRecord({
    required this.id,
    required this.amount,
    required this.timestamp,
    required this.method,
    required this.previousBalance,
    required this.newBalance,
    required this.reference,
  });

  factory CreditRepaymentRecord.fromJson(Map<String, dynamic> json) {
    return CreditRepaymentRecord(
      id: json['id'] ?? '',
      amount: ((json['amount'] ?? 0.0) as num).toDouble(),
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      method: json['method'] ?? 'wallet_balance',
      previousBalance: ((json['previousBalance'] ?? 0.0) as num).toDouble(),
      newBalance: ((json['newBalance'] ?? 0.0) as num).toDouble(),
      reference: json['reference'] ?? '',
    );
  }
}
