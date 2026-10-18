class Entitlement {
  const Entitlement({
    required this.isActive,
    this.expiresAt,
    this.planKey,
    this.role = 'user',
    this.accessEnabled = true,
    this.aiQuota = 0,
    this.aiUsed = 0,
  });

  final bool isActive;
  final DateTime? expiresAt;
  final String? planKey;
  final String role;
  final bool accessEnabled;

  int get remainingAiQuota => (aiQuota - aiUsed).clamp(0, aiQuota);

  final int aiQuota;
  final int aiUsed;

  bool get isAdmin => role == 'admin';
}
