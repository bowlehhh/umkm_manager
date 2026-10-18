import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Thumbnail produk yang aman dipakai untuk foto dari Supabase maupun mode
/// pratinjau lokal. Bila foto belum ada, tampilkan placeholder yang konsisten.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    this.imageUrl,
    this.memoryBytes,
    required this.borderRadius,
    this.fit = BoxFit.cover,
  });

  final String? imageUrl;
  final Uint8List? memoryBytes;
  final BorderRadius borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final dataBytes = memoryBytes ?? _dataUriBytes(imageUrl);
    final child = dataBytes != null
        ? Image.memory(dataBytes, fit: fit, errorBuilder: _errorBuilder)
        : imageUrl?.trim().isNotEmpty == true
        ? Image.network(imageUrl!, fit: fit, errorBuilder: _errorBuilder)
        : _placeholder(context);
    return ClipRRect(borderRadius: borderRadius, child: child);
  }

  Widget _errorBuilder(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) => _placeholder(context);

  Widget _placeholder(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Center(
      child: Icon(
        Icons.fastfood_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );

  Uint8List? _dataUriBytes(String? value) {
    if (value == null || !value.startsWith('data:image/')) return null;
    final comma = value.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(value.substring(comma + 1));
    } on FormatException {
      return null;
    }
  }
}
