import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../shared/widgets/app_async_button.dart';
import '../../../../shared/widgets/product_image.dart';
import '../../../businesses/domain/business.dart';
import '../../domain/product.dart';
import '../controllers/product_controller.dart';

/// Form utama sengaja hanya meminta data yang mudah dipahami pemilik usaha.
/// Nilai teknis tetap dipertahankan untuk schema, kasir, dan laporan.
class ProductFormSheet extends ConsumerStatefulWidget {
  const ProductFormSheet({
    super.key,
    required this.businessId,
    required this.businessType,
    required this.itemLabel,
    required this.usesInventory,
    this.product,
  });

  final String businessId;
  final BusinessType businessType;
  final String itemLabel;
  final bool usesInventory;
  final Product? product;

  @override
  ConsumerState<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends ConsumerState<ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _sellingPrice;
  late final TextEditingController _stock;
  late final TextEditingController _minimumStock;
  late final TextEditingController _unit;
  final _imagePicker = ImagePicker();
  Uint8List? _selectedImageBytes;
  String? _selectedImageContentType;
  var _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name);
    _sellingPrice = TextEditingController(
      text: product?.sellingPrice.toString(),
    );
    _stock = TextEditingController(text: product?.stock.toString() ?? '0');
    _minimumStock = TextEditingController(
      text: product?.minimumStock.toString() ?? '0',
    );
    _unit = TextEditingController(
      text:
          product?.unit ??
          (widget.businessType == BusinessType.culinary ? 'porsi' : 'buah'),
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _sellingPrice,
      _stock,
      _minimumStock,
      _unit,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  int? _number(String value) =>
      int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));
  String? _required(String? value, String label) =>
      (value?.trim().isEmpty ?? true) ? '$label wajib diisi.' : null;
  String? _priceValidator(String? value) => (_number(value ?? '') ?? -1) < 0
      ? 'Harga jual harus berupa angka.'
      : null;
  String? _stockValidator(String? value) =>
      (value ?? '').trim().isEmpty || ((int.tryParse(value!) ?? -1) >= 0)
      ? null
      : 'Stok harus berupa angka.';

  Future<void> _pickImage() async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 82,
        requestFullMetadata: false,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageContentType = image.mimeType ?? 'image/jpeg';
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto belum bisa dipilih. Coba buka ulang aplikasi.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.product;
    final generatedNumber = DateTime.now().microsecondsSinceEpoch;
    final error = await ref
        .read(productControllerProvider.notifier)
        .save(
          businessId: widget.businessId,
          businessType: widget.businessType,
          existing: existing,
          name: _name.text,
          // Kode teknis dibuat oleh aplikasi agar pengguna cukup mengisi
          // informasi yang dipakai saat berjualan.
          sku: existing?.sku ?? 'MENU-$generatedNumber',
          barcode: existing?.barcode ?? 'BRG-$generatedNumber',
          imageBytes: _selectedImageBytes,
          imageContentType: _selectedImageContentType,
          categoryId: existing?.categoryId,
          purchasePrice: existing?.purchasePrice ?? 0,
          sellingPrice: _number(_sellingPrice.text)!,
          stock: widget.usesInventory
              ? int.tryParse(_stock.text.trim()) ?? 0
              : existing?.stock ?? 0,
          minimumStock:
              _number(_minimumStock.text) ?? existing?.minimumStock ?? 0,
          unit: _unit.text.trim().isEmpty
              ? existing?.unit ?? 'buah'
              : _unit.text,
        );
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(productControllerProvider).isLoading;
    final item = widget.itemLabel.toLowerCase();
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, _) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                8,
                24,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product == null ? 'Tambah $item' : 'Ubah $item',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 112,
                      width: 112,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isPickingImage ? null : _pickImage,
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ProductImage(
                                imageUrl: widget.product?.imageUrl,
                                memoryBytes: _selectedImageBytes,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: CircleAvatar(
                                  radius: 16,
                                  child: _isPickingImage
                                      ? const SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.edit_rounded,
                                          size: 18,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _isPickingImage ? null : _pickImage,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(
                        _selectedImageBytes == null &&
                                widget.product?.imageUrl == null
                            ? 'Tambah foto'
                            : 'Ganti foto',
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _name,
                      autofocus: widget.product == null,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(labelText: 'Nama $item'),
                      validator: (value) => _required(value, 'Nama $item'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _sellingPrice,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Harga jual',
                        prefixText: 'Rp ',
                      ),
                      validator: _priceValidator,
                    ),
                    if (widget.usesInventory) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _stock,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Stok (boleh dikosongkan)',
                          helperText: 'Isi jika jumlah barang perlu dipantau.',
                        ),
                        validator: _stockValidator,
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _minimumStock,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Batas stok menipis',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _unit,
                      decoration: const InputDecoration(labelText: 'Satuan'),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: AppAsyncButton(
                        label: widget.product == null
                            ? 'Simpan $item'
                            : 'Simpan perubahan',
                        isLoading: isLoading,
                        onPressed: _save,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
