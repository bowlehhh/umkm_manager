import 'package:flutter/material.dart';

import 'domain/business_configuration.dart';

/// Renderer form data-driven untuk custom feature; tidak memuat atau menjalankan kode dari AI.
class DynamicFormRenderer extends StatelessWidget {
  const DynamicFormRenderer({
    super.key,
    required this.fields,
    required this.controllers,
  });
  final List<CustomFieldConfig> fields;
  final Map<String, TextEditingController> controllers;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final field in fields)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _field(context, field),
        ),
    ],
  );

  Widget _field(BuildContext context, CustomFieldConfig field) {
    final controller = controllers.putIfAbsent(
      field.key,
      TextEditingController.new,
    );
    final label = '${field.label}${field.required ? ' *' : ''}';
    if (field.type == CustomFieldType.boolean) {
      return SwitchListTile(
        title: Text(label),
        value: controller.text == 'true',
        onChanged: (value) => controller.text = '$value',
      );
    }
    if (field.type == CustomFieldType.dropdown) {
      return DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: label),
        items: field.options
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: (value) => controller.text = value ?? '',
        validator: field.required
            ? (value) => value == null ? 'Wajib diisi.' : null
            : null,
      );
    }
    final numeric =
        field.type == CustomFieldType.number ||
        field.type == CustomFieldType.currency;
    return TextFormField(
      controller: controller,
      minLines: field.type == CustomFieldType.multilineText ? 3 : 1,
      maxLines: field.type == CustomFieldType.multilineText ? 5 : 1,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : field.type == CustomFieldType.email
          ? TextInputType.emailAddress
          : field.type == CustomFieldType.phone
          ? TextInputType.phone
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      validator: field.required
          ? (value) => (value?.trim().isEmpty ?? true) ? 'Wajib diisi.' : null
          : null,
    );
  }
}
