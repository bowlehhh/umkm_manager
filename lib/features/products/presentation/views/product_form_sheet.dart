import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/categories/data/category_repository.dart';
import '../../../../shared/widgets/app_async_button.dart';
import '../../domain/product.dart';
import '../controllers/product_controller.dart';

class ProductFormSheet extends ConsumerStatefulWidget {
  const ProductFormSheet({
    super.key,
    required this.businessId,
    required this.itemLabel,
    required this.usesInventory,
    this.product,
  });

  final String businessId;
  final String itemLabel;
  final bool usesInventory;
  final Product? product;

  @override
  ConsumerState<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends ConsumerState<ProductFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _barcode;
  late final TextEditingController _purchasePrice;
  late final TextEditingController _sellingPrice;
  late final TextEditingController _stock;
  late final TextEditingController _minimumStock;
  late final TextEditingController _unit;
  final _formKey = GlobalKey<FormState>();
  String? _categoryId;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name);
    _sku = TextEditingController(text: product?.sku);
    _barcode = TextEditingController(text: product?.barcode);
    _purchasePrice = TextEditingController(
      text: product?.purchasePrice.toString(),
    );
    _sellingPrice = TextEditingController(
      text: product?.sellingPrice.toString(),
    );
    _stock = TextEditingController(
      text: product?.stock.toString() ?? (widget.usesInventory ? '' : '0'),
    );
    _minimumStock = TextEditingController(
      text:
          product?.minimumStock.toString() ?? (widget.usesInventory ? '' : '0'),
    );
    _unit = TextEditingController(
      text: product?.unit ?? (widget.usesInventory ? 'pcs' : 'layanan'),
    );
    _categoryId = product?.categoryId;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _sku,
      _barcode,
      _purchasePrice,
      _sellingPrice,
      _stock,
      _minimumStock,
      _unit,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  int? _parseRupiah(String value) =>
      int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final error = await ref
        .read(productControllerProvider.notifier)
        .save(
          businessId: widget.businessId,
          existing: widget.product,
          name: _name.text,
          sku: _sku.text,
          barcode: _barcode.text,
          categoryId: _categoryId,
          purchasePrice: _parseRupiah(_purchasePrice.text)!,
          sellingPrice: _parseRupiah(_sellingPrice.text)!,
          stock: int.parse(_stock.text),
          minimumStock: int.parse(_minimumStock.text),
          unit: _unit.text,
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

  String? _required(String? value, String label) =>
      (value?.trim().isEmpty ?? true) ? '$label wajib diisi.' : null;

  String? _moneyValidator(String? value, String label) {
    final amount = _parseRupiah(value ?? '');
    if (amount == null) return '$label harus berupa angka.';
    if (amount < 0) return '$label tidak boleh negatif.';
    return null;
  }

  String? _quantityValidator(String? value, String label) {
    final amount = int.tryParse(value ?? '');
    if (amount == null || amount < 0) return '$label tidak boleh negatif.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider(widget.businessId));
    final isLoading = ref.watch(productControllerProvider).isLoading;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.product == null
                      ? 'Tambah ${widget.itemLabel.toLowerCase()}'
                      : 'Ubah ${widget.itemLabel.toLowerCase()}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nama ${widget.itemLabel.toLowerCase()}',
                  ),
                  validator: (value) => _required(
                    value,
                    'Nama ${widget.itemLabel.toLowerCase()}',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sku,
                  decoration: const InputDecoration(labelText: 'SKU'),
                  validator: (value) => _required(value, 'SKU'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: categories.maybeWhen(
                    data: (items) => [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Tanpa kategori'),
                      ),
                      ...items.map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      ),
                    ],
                    orElse: () => const [],
                  ),
                  onChanged: (value) => setState(() => _categoryId = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _barcode,
                  decoration: const InputDecoration(
                    labelText: 'Barcode (opsional)',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _purchasePrice,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Harga beli',
                        ),
                        validator: (value) =>
                            _moneyValidator(value, 'Harga beli'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _sellingPrice,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Harga jual',
                        ),
                        validator: (value) =>
                            _moneyValidator(value, 'Harga jual'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (widget.usesInventory) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _stock,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Stok awal',
                          ),
                          validator: (value) =>
                              _quantityValidator(value, 'Stok'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _minimumStock,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Stok minimum',
                          ),
                          validator: (value) =>
                              _quantityValidator(value, 'Stok minimum'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _unit,
                  decoration: InputDecoration(
                    labelText: widget.usesInventory
                        ? 'Satuan (mis. pcs)'
                        : 'Satuan layanan (mis. jam atau sesi)',
                  ),
                  validator: (value) => _required(value, 'Satuan'),
                ),
                const SizedBox(height: 24),
                AppAsyncButton(
                  label: widget.product == null
                      ? 'Simpan ${widget.itemLabel.toLowerCase()}'
                      : 'Simpan perubahan',
                  isLoading: isLoading,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
