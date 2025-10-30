class Earning {
  final String id;
  final String driverId;
  final double amount;
  final double commission;
  final double netEarnings;
  final String status;
  final DateTime createdAt;

  Earning({
    required this.id,
    required this.driverId,
    required this.amount,
    required this.commission,
    required this.netEarnings,
    required this.status,
    required this.createdAt,
  });

  factory Earning.fromMap(Map<String, dynamic> m) => Earning(
    id: m['id'] as String,
    driverId: m['driver_id'] as String,
    amount: (m['amount'] as num).toDouble(),
    commission: (m['commission'] as num).toDouble(),
    netEarnings: (m['net_earnings'] as num).toDouble(),
    status: m['payment_status'] as String,
    createdAt: DateTime.parse(m['created_at'] as String),
  );
}
