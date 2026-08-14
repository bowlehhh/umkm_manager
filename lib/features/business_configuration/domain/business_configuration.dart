/// Konfigurasi yang menentukan capability aplikasi untuk satu usaha.
/// Semua data AI tetap melewati model ini; tidak ada output AI yang dieksekusi.
const supportedBusinessFeatureKeys = {
  'dashboard',
  'products',
  'stock',
  'cashier',
  'transactions',
  'customers',
  'debts',
  'expenses',
  'discounts',
  'employees',
  'reports',
  'booking',
  'appointments',
  'services',
  'projects',
  'orders',
  'payments',
};

/// Kontrak capability yang dapat dipilih AI. AI hanya mengisi konfigurasi dari
/// kontrak ini; ia tidak pernah membuat route atau action baru sendiri.
class FeatureCapabilityTemplate {
  const FeatureCapabilityTemplate({
    required this.key,
    required this.actions,
    this.supportedFields = const {},
    this.relations = const {},
    this.dashboardWidgets = const {},
    this.isImplemented = false,
  });

  final String key;
  final Set<String> actions;
  final Set<String> supportedFields;
  final Set<String> relations;
  final Set<String> dashboardWidgets;
  final bool isImplemented;
}

abstract final class FeatureCapabilityTemplates {
  static const _standardActions = {
    'list',
    'create',
    'view',
    'edit',
    'archive',
    'search',
  };

  static const all = <String, FeatureCapabilityTemplate>{
    'dashboard': FeatureCapabilityTemplate(
      key: 'dashboard',
      actions: {'view'},
      dashboardWidgets: {'today_sales', 'transactions', 'low_stock'},
      isImplemented: true,
    ),
    'customers': FeatureCapabilityTemplate(
      key: 'customers',
      actions: _standardActions,
      supportedFields: {'name', 'phone', 'email', 'address', 'notes'},
      relations: {'transactions', 'debts'},
      dashboardWidgets: {'unpaid_invoices'},
      isImplemented: true,
    ),
    'products': FeatureCapabilityTemplate(
      key: 'products',
      actions: _standardActions,
      supportedFields: {'name', 'sku', 'barcode', 'price', 'stock'},
      relations: {'transactions', 'stock'},
      dashboardWidgets: {'low_stock'},
      isImplemented: true,
    ),
    'cashier': FeatureCapabilityTemplate(
      key: 'cashier',
      actions: {'list', 'create'},
      relations: {'products', 'customers', 'transactions'},
      isImplemented: true,
    ),
    'transactions': FeatureCapabilityTemplate(
      key: 'transactions',
      actions: {'list', 'view', 'search'},
      relations: {'customers', 'products', 'debts'},
      dashboardWidgets: {'today_sales', 'transactions'},
      isImplemented: true,
    ),
    'stock': FeatureCapabilityTemplate(key: 'stock', actions: _standardActions),
    'expenses': FeatureCapabilityTemplate(
      key: 'expenses',
      actions: _standardActions,
    ),
    'booking': FeatureCapabilityTemplate(
      key: 'booking',
      actions: _standardActions,
    ),
    'projects': FeatureCapabilityTemplate(
      key: 'projects',
      actions: _standardActions,
    ),
    'employees': FeatureCapabilityTemplate(
      key: 'employees',
      actions: _standardActions,
    ),
    'services': FeatureCapabilityTemplate(
      key: 'services',
      actions: _standardActions,
    ),
    'orders': FeatureCapabilityTemplate(
      key: 'orders',
      actions: _standardActions,
    ),
    'debts': FeatureCapabilityTemplate(key: 'debts', actions: _standardActions),
    'discounts': FeatureCapabilityTemplate(
      key: 'discounts',
      actions: _standardActions,
    ),
    'reports': FeatureCapabilityTemplate(
      key: 'reports',
      actions: {'list', 'view'},
    ),
    'appointments': FeatureCapabilityTemplate(
      key: 'appointments',
      actions: _standardActions,
    ),
    'payments': FeatureCapabilityTemplate(
      key: 'payments',
      actions: _standardActions,
    ),
  };

  static FeatureCapabilityTemplate forKey(String key) =>
      all[key] ?? (throw FormatException('Capability tidak didukung: $key'));

  static bool supportsActions(String key, Iterable<String> actions) =>
      actions.every(forKey(key).actions.contains);
}

class BusinessConfiguration {
  const BusinessConfiguration({
    required this.businessCategory,
    required this.summary,
    required this.features,
    required this.customFields,
    required this.workflow,
    required this.paymentRule,
    required this.dashboardWidgets,
    this.unsupportedRequirements = const [],
  });

  factory BusinessConfiguration.fromJson(Map<String, dynamic> json) {
    const required = {
      'businessCategory',
      'summary',
      'customFields',
      'workflow',
      'paymentRules',
      'dashboardWidgets',
      'unsupportedRequirements',
    };
    if (!required.every(json.containsKey) ||
        (!json.containsKey('recommendedFeatures') &&
            !json.containsKey('features')) ||
        json['customFields'] is! List ||
        json['workflow'] is! List ||
        json['dashboardWidgets'] is! List ||
        json['unsupportedRequirements'] is! List ||
        json['paymentRules'] is! Map) {
      throw const FormatException('Struktur konfigurasi AI tidak lengkap.');
    }
    final features = _maps(
      json['recommendedFeatures'] ?? json['features'],
    ).map(BusinessFeatureConfig.fromJson).toList();
    final widgets = (json['dashboardWidgets'] as List? ?? const [])
        .whereType<String>()
        .toList();
    if (features.isEmpty || widgets.any((value) => value.trim().isEmpty)) {
      throw const FormatException(
        'Konfigurasi AI tidak memiliki fitur yang valid.',
      );
    }
    return BusinessConfiguration(
      businessCategory: _text(json['businessCategory']),
      summary: _text(json['summary']),
      features: features,
      customFields: _maps(
        json['customFields'],
      ).map(CustomFieldConfig.fromJson).toList(),
      workflow: _maps(json['workflow']).map(WorkflowStep.fromJson).toList(),
      paymentRule: PaymentRule.fromJson(_map(json['paymentRules'])),
      dashboardWidgets: widgets,
      unsupportedRequirements: _maps(
        json['unsupportedRequirements'],
      ).map(UnsupportedRequirement.fromJson).toList(),
    ).validated();
  }

  final String businessCategory;
  final String summary;
  final List<BusinessFeatureConfig> features;
  final List<CustomFieldConfig> customFields;
  final List<WorkflowStep> workflow;
  final PaymentRule paymentRule;
  final List<String> dashboardWidgets;
  final List<UnsupportedRequirement> unsupportedRequirements;

  BusinessConfiguration copyWith({
    List<BusinessFeatureConfig>? features,
    List<CustomFieldConfig>? customFields,
    List<WorkflowStep>? workflow,
    PaymentRule? paymentRule,
    List<String>? dashboardWidgets,
  }) => BusinessConfiguration(
    businessCategory: businessCategory,
    summary: summary,
    features: features ?? this.features,
    customFields: customFields ?? this.customFields,
    workflow: workflow ?? this.workflow,
    paymentRule: paymentRule ?? this.paymentRule,
    dashboardWidgets: dashboardWidgets ?? this.dashboardWidgets,
    unsupportedRequirements: unsupportedRequirements,
  );

  BusinessConfiguration validated() {
    if (businessCategory.isEmpty || summary.isEmpty) {
      throw const FormatException(
        'Kategori atau ringkasan rekomendasi tidak valid.',
      );
    }
    final keys = <String>{};
    for (final feature in features) {
      if (feature.key.isEmpty || !keys.add(feature.key)) {
        throw const FormatException(
          'Fitur rekomendasi tidak valid atau duplikat.',
        );
      }
      if (!FeatureCapabilityTemplates.supportsActions(
        feature.key,
        feature.actions,
      )) {
        throw const FormatException(
          'Action fitur tidak didukung oleh capability yang dipilih.',
        );
      }
    }
    return this;
  }

  Map<String, dynamic> toJson() => {
    'businessCategory': businessCategory,
    'summary': summary,
    'recommendedFeatures': features.map((item) => item.toJson()).toList(),
    'customFields': customFields.map((item) => item.toJson()).toList(),
    'workflow': workflow.map((item) => item.toJson()).toList(),
    'paymentRules': paymentRule.toJson(),
    'dashboardWidgets': dashboardWidgets,
    'unsupportedRequirements': unsupportedRequirements
        .map((item) => item.toJson())
        .toList(),
  };
}

class BusinessFeatureConfig {
  const BusinessFeatureConfig({
    required this.key,
    required this.name,
    required this.enabled,
    required this.reason,
    required this.actions,
  });
  factory BusinessFeatureConfig.fromJson(Map<String, dynamic> json) =>
      _featureFromJson(json);
  final String key;
  final String name;
  final bool enabled;
  final String reason;
  final List<String> actions;
  BusinessFeatureConfig copyWith({String? name, bool? enabled}) =>
      BusinessFeatureConfig(
        key: key,
        name: name ?? this.name,
        enabled: enabled ?? this.enabled,
        reason: reason,
        actions: actions,
      );
  Map<String, dynamic> toJson() => {
    'key': key,
    'name': name,
    'enabled': enabled,
    'reason': reason,
    'capability': key,
    'actions': actions,
  };
}

BusinessFeatureConfig _featureFromJson(Map<String, dynamic> json) {
  final key = _text(json['key']);
  if (!supportedBusinessFeatureKeys.contains(key)) {
    throw const FormatException(
      'AI merekomendasikan capability yang tidak didukung.',
    );
  }
  final rawActions = (json['actions'] as List? ?? const [])
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet();
  final actions = rawActions.isEmpty
      ? FeatureCapabilityTemplates.forKey(key).actions
      : rawActions;
  if (!FeatureCapabilityTemplates.supportsActions(key, actions)) {
    throw const FormatException(
      'AI memberikan action capability yang tidak didukung.',
    );
  }
  return BusinessFeatureConfig(
    key: key,
    name: _text(json['name']),
    enabled: json['enabled'] == true,
    reason: _text(json['reason']),
    actions: actions.toList()..sort(),
  );
}

enum CustomFieldType {
  text,
  multilineText,
  number,
  currency,
  date,
  time,
  dateTime,
  boolean,
  dropdown,
  phone,
  email,
}

class CustomFieldConfig {
  const CustomFieldConfig({
    required this.module,
    required this.key,
    required this.label,
    required this.type,
    required this.required,
    this.options = const [],
  });
  factory CustomFieldConfig.fromJson(Map<String, dynamic> json) {
    if (!supportedBusinessFeatureKeys.contains(_text(json['module']))) {
      throw const FormatException(
        'Custom field merujuk ke capability tidak didukung.',
      );
    }
    final type = CustomFieldType.values
        .where((item) => item.name == _text(json['type']))
        .firstOrNull;
    if (type == null) {
      throw const FormatException('Tipe custom field tidak didukung.');
    }
    return CustomFieldConfig(
      module: _text(json['module']),
      key: _text(json['key']),
      label: _text(json['label']),
      type: type,
      required: json['required'] == true,
      options: (json['options'] as List? ?? const [])
          .whereType<String>()
          .toList(),
    );
  }
  final String module;
  final String key;
  final String label;
  final CustomFieldType type;
  final bool required;
  final List<String> options;
  CustomFieldConfig copyWith({
    String? label,
    CustomFieldType? type,
    bool? required,
    List<String>? options,
  }) => CustomFieldConfig(
    module: module,
    key: key,
    label: label ?? this.label,
    type: type ?? this.type,
    required: required ?? this.required,
    options: options ?? this.options,
  );
  Map<String, dynamic> toJson() => {
    'module': module,
    'key': key,
    'label': label,
    'type': type.name,
    'required': required,
    'options': options,
  };
}

class WorkflowStep {
  const WorkflowStep({
    required this.key,
    required this.label,
    required this.order,
  });
  factory WorkflowStep.fromJson(Map<String, dynamic> json) => WorkflowStep(
    key: _text(json['key']),
    label: _text(json['label']),
    order: (json['order'] as num?)?.toInt() ?? 0,
  );
  final String key;
  final String label;
  final int order;
  WorkflowStep copyWith({String? label, int? order}) => WorkflowStep(
    key: key,
    label: label ?? this.label,
    order: order ?? this.order,
  );
  Map<String, dynamic> toJson() => {'key': key, 'label': label, 'order': order};
}

class PaymentRule {
  const PaymentRule({
    required this.supportsDownPayment,
    this.suggestedDownPaymentPercent,
  });
  factory PaymentRule.fromJson(Map<String, dynamic> json) {
    final percent = (json['suggestedDownPaymentPercent'] as num?)?.toInt();
    if (percent != null && (percent < 0 || percent > 100)) {
      throw const FormatException('Persentase DP tidak valid.');
    }
    return PaymentRule(
      supportsDownPayment: json['supportsDownPayment'] == true,
      suggestedDownPaymentPercent: percent,
    );
  }
  final bool supportsDownPayment;
  final int? suggestedDownPaymentPercent;
  PaymentRule copyWith({
    bool? supportsDownPayment,
    int? suggestedDownPaymentPercent,
  }) => PaymentRule(
    supportsDownPayment: supportsDownPayment ?? this.supportsDownPayment,
    suggestedDownPaymentPercent:
        suggestedDownPaymentPercent ?? this.suggestedDownPaymentPercent,
  );
  Map<String, dynamic> toJson() => {
    'supportsDownPayment': supportsDownPayment,
    'suggestedDownPaymentPercent': suggestedDownPaymentPercent,
  };
}

class UnsupportedRequirement {
  const UnsupportedRequirement({required this.name, required this.reason});
  factory UnsupportedRequirement.fromJson(Map<String, dynamic> json) =>
      UnsupportedRequirement(
        name: _text(json['name']),
        reason: _text(json['reason']),
      );
  final String name;
  final String reason;
  Map<String, dynamic> toJson() => {'name': name, 'reason': reason};
}

String _text(Object? value) => value is String ? value.trim() : '';
Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};
List<Map<String, dynamic>> _maps(Object? value) => (value as List? ?? const [])
    .whereType<Map>()
    .map((item) => Map<String, dynamic>.from(item))
    .toList();
