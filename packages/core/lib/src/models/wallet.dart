class Wallet {
  const Wallet({required this.balancePaise, this.currency = 'INR'});

  final int balancePaise;
  final String currency;

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
        balancePaise: (json['balance_paise'] as num?)?.toInt() ?? 0,
        currency: json['currency'] as String? ?? 'INR',
      );

  Map<String, dynamic> toJson() =>
      {'balance_paise': balancePaise, 'currency': currency};
}

enum WalletTxType { topup, debit, refund, credit, payout, adjustment }

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amountPaise,
    required this.balanceAfterPaise,
    required this.note,
    required this.createdAt,
    this.referenceId,
  });

  final String id;
  final WalletTxType type;
  final int amountPaise;
  final int balanceAfterPaise;
  final String note;
  final DateTime createdAt;
  final String? referenceId;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: json['id'] as String,
        type: WalletTxType.values.asNameMap()[json['type'] as String? ?? 'credit'] ??
            WalletTxType.credit,
        amountPaise: (json['amount_paise'] as num?)?.toInt() ?? 0,
        balanceAfterPaise: (json['balance_after_paise'] as num?)?.toInt() ?? 0,
        note: json['note'] as String? ?? '',
        createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ??
            DateTime.now(),
        referenceId: json['reference_id'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'amount_paise': amountPaise,
        'balance_after_paise': balanceAfterPaise,
        'note': note,
        'created_at': createdAt.toIso8601String(),
        'reference_id': referenceId,
      };
}
