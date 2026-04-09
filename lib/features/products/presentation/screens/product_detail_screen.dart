import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/datasources/providers.dart';
import '../../../../data/models/product_model.dart';
import '../../../../data/models/variant_model.dart';

/// Halaman detail produk & manajemen varian
class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  ProductModel? _product;
  bool _productLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProduct());
  }

  void _loadProduct() {
    try {
      final repo = ref.read(productRepositoryProvider);
      final product = repo.getProductById(widget.productId);
      if (product != null) {
        _product = product;
        setState(() => _productLoaded = true);
      } else {
        if (mounted) context.pop();
      }
    } catch (e) {
      if (mounted) context.pop();
    }
  }

  void _showAddVariantSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VariantFormSheet(
        productId: widget.productId,
        onSaved: () {
          ref.read(variantsProvider.notifier).load();
        },
      ),
    );
  }

  void _showEditVariantSheet(VariantModel variant) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VariantFormSheet(
        productId: widget.productId,
        variant: variant,
        onSaved: () {
          ref.read(variantsProvider.notifier).load();
        },
      ),
    );
  }

  Future<void> _deleteVariant(String variantId) async {
    final confirm = await showDeleteConfirmDialog(
      context,
      title: 'Hapus Varian',
      content: 'Hapus varian ini? Tindakan tidak bisa dibatalkan.',
    );
    if (confirm == true) {
      await ref.read(variantsProvider.notifier).deleteVariant(variantId);
      if (mounted) showSuccessSnackBar(context, 'Varian dihapus');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_productLoaded || _product == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final product = _product!;
    final variants = ref.watch(variantsByProductProvider(widget.productId));
    final totalStock = variants.fold<int>(0, (sum, v) => sum + v.stock);
    final avgCostPrice = variants.isEmpty
        ? 0.0
        : variants.fold<double>(0, (sum, v) => sum + v.costPrice) /
            variants.length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(product.name),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_rounded),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/products/edit/${widget.productId}'),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Produk',
          ),
        ],
      ),
      body: Column(
        children: [
          // Product info card
          Container(
            margin: const EdgeInsets.all(AppTheme.spacingMd),
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              gradient: AppTheme.cardGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              boxShadow: AppTheme.elevatedShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Center(
                    child: Text(
                      product.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusFull),
                            ),
                            child: Text(
                              product.category,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${variants.length} ukuran • $totalStock item',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Mini stats
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
            child: Row(
              children: [
                _MiniStat(
                  label: 'Total Stok',
                  value: '$totalStock',
                  icon: Icons.inventory_rounded,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 12),
                _MiniStat(
                  label: 'Rata-rata Modal',
                  value: CurrencyFormatter.compact(avgCostPrice),
                  icon: Icons.local_offer_outlined,
                  color: AppTheme.success,
                ),
                const SizedBox(width: 12),
                _MiniStat(
                  label: 'Ukuran Tersedia',
                  value: '${variants.length}',
                  icon: Icons.format_size_rounded,
                  color: AppTheme.accent,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacingMd),

          SectionHeader(
            title: 'Varian Ukuran',
            action: TextButton.icon(
              onPressed: _showAddVariantSheet,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Tambah'),
            ),
          ),

          // Variant list
          Expanded(
            child: variants.isEmpty
                ? EmptyState(
                    icon: Icons.format_size_outlined,
                    title: 'Belum ada varian',
                    message: 'Tambahkan ukuran, harga modal, dan stok',
                    action: ElevatedButton.icon(
                      onPressed: _showAddVariantSheet,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Tambah Varian'),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingMd),
                    itemCount: variants.length,
                    itemBuilder: (context, index) {
                      final variant = variants[index];
                      return _VariantCard(
                        variant: variant,
                        onEdit: () => _showEditVariantSheet(variant),
                        onDelete: () => _deleteVariant(variant.id),
                        onSell: () => context.push('/transaction/new'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.neutral900,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: AppTheme.neutral500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _VariantCard extends StatelessWidget {
  final VariantModel variant;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSell;

  const _VariantCard({
    required this.variant,
    required this.onEdit,
    required this.onDelete,
    required this.onSell,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.cardShadow,
          border: variant.isOutOfStock
              ? Border.all(color: AppTheme.error.withValues(alpha: 0.3))
              : variant.isLowStock
                  ? Border.all(color: AppTheme.warning.withValues(alpha: 0.3))
                  : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Row(
            children: [
              // Size badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.neutral100,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Center(
                  child: Text(
                    variant.size,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.neutral700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Modal: ${CurrencyFormatter.format(variant.costPrice)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.neutral700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    StockBadge(stock: variant.stock),
                  ],
                ),
              ),

              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    iconSize: 18,
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    color: AppTheme.neutral400,
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    iconSize: 18,
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: AppTheme.error,
                    tooltip: 'Hapus',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet form untuk tambah/edit varian
class _VariantFormSheet extends ConsumerStatefulWidget {
  final String productId;
  final VariantModel? variant;
  final VoidCallback onSaved;

  const _VariantFormSheet({
    required this.productId,
    this.variant,
    required this.onSaved,
  });

  @override
  ConsumerState<_VariantFormSheet> createState() => _VariantFormSheetState();
}

class _VariantFormSheetState extends ConsumerState<_VariantFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _costController = TextEditingController();
  final _stockController = TextEditingController();
  String? _selectedSize;
  bool _loading = false;

  bool get _isEditing => widget.variant != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _costController.text = widget.variant!.costPrice.toInt().toString();
      _stockController.text = widget.variant!.stock.toString();
      _selectedSize = widget.variant!.size;
    }
  }

  @override
  void dispose() {
    _costController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSize == null) {
      showErrorSnackBar(context, 'Pilih ukuran terlebih dahulu');
      return;
    }
    setState(() => _loading = true);
    try {
      final costPrice = double.parse(_costController.text.replaceAll('.', ''));
      final stock = int.parse(_stockController.text);

      if (_isEditing) {
        await ref.read(variantsProvider.notifier).updateVariant(
              widget.variant!.copyWith(
                size: _selectedSize!,
                costPrice: costPrice,
                stock: stock,
              ),
            );
        if (mounted) showSuccessSnackBar(context, 'Varian diperbarui');
      } else {
        await ref.read(variantsProvider.notifier).addVariant(
              productId: widget.productId,
              size: _selectedSize!,
              costPrice: costPrice,
              stock: stock,
            );
        if (mounted) showSuccessSnackBar(context, 'Varian ditambahkan');
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizes = ref.watch(sizesProvider);
    final insets = MediaQuery.of(context).viewInsets;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + insets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.neutral200,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isEditing ? 'Edit Varian' : 'Tambah Varian',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Size selector
            const Text('Pilih Ukuran',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.neutral600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: sizes.map((size) {
                  final isSelected = _selectedSize == size;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedSize = size),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary : AppTheme.neutral100,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        child: Center(
                          child: Text(
                            size,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : AppTheme.neutral600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Cost price
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Harga Modal (Rp)',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.neutral600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _costController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          hintText: '0',
                          prefixText: 'Rp ',
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Wajib diisi';
                          if (double.tryParse(v) == null) return 'Angka tidak valid';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Stok Awal',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.neutral600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _stockController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(hintText: '0'),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Wajib diisi';
                          if (int.tryParse(v) == null) return 'Angka tidak valid';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            PrimaryButton(
              label: _isEditing ? 'Simpan Perubahan' : 'Tambah Varian',
              icon: Icons.save_rounded,
              onPressed: _save,
              loading: _loading,
            ),
          ],
        ),
      ),
    );
  }
}
