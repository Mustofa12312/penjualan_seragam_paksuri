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

/// Layar transaksi penjualan baru (alur step-by-step)
class NewTransactionScreen extends ConsumerStatefulWidget {
  const NewTransactionScreen({super.key});

  @override
  ConsumerState<NewTransactionScreen> createState() =>
      _NewTransactionScreenState();
}

class _NewTransactionScreenState extends ConsumerState<NewTransactionScreen> {
  int _step = 0; // 0=kategori, 1=produk, 2=ukuran, 3=harga & konfirmasi

  String? _selectedCategory;
  ProductModel? _selectedProduct;
  VariantModel? _selectedVariant;
  final _sellPriceController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  bool _loading = false;

  @override
  void dispose() {
    _sellPriceController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  void _nextStep() => setState(() => _step++);
  void _prevStep() {
    if (_step == 0) {
      context.pop();
    } else {
      setState(() => _step--);
    }
  }

  Future<void> _submitTransaction() async {
    final sellPriceText = _sellPriceController.text.replaceAll('.', '').replaceAll(',', '');
    final sellPrice = double.tryParse(sellPriceText);
    if (sellPrice == null || sellPrice <= 0) {
      showErrorSnackBar(context, 'Masukkan harga jual yang valid');
      return;
    }

    final qty = int.tryParse(_qtyController.text) ?? 1;
    if (qty <= 0) {
      showErrorSnackBar(context, 'Jumlah harus lebih dari 0');
      return;
    }
    if (qty > (_selectedVariant?.stock ?? 0)) {
      showErrorSnackBar(context, 'Stok tidak mencukupi');
      return;
    }

    setState(() => _loading = true);

    final success = await ref.read(transactionsProvider.notifier).addTransaction(
          variantId: _selectedVariant!.id,
          productId: _selectedProduct!.id,
          productName: _selectedProduct!.name,
          size: _selectedVariant!.size,
          sellPrice: sellPrice,
          costPrice: _selectedVariant!.costPrice,
          category: _selectedProduct!.category,
          quantity: qty,
        );

    // Refresh variants
    ref.read(variantsProvider.notifier).load();

    setState(() => _loading = false);

    if (mounted) {
      if (success) {
        _showSuccessSheet(sellPrice, qty);
      } else {
        showErrorSnackBar(context, 'Stok tidak mencukupi atau terjadi kesalahan');
      }
    }
  }

  void _showSuccessSheet(double sellPrice, int qty) {
    final profit = (sellPrice - (_selectedVariant?.costPrice ?? 0)) * qty;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
        ),
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppTheme.success, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('Transaksi Berhasil!',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.neutral900)),
            const SizedBox(height: 8),
            Text(
              '${_selectedProduct?.name} - Ukuran ${_selectedVariant?.size}',
              style: const TextStyle(color: AppTheme.neutral500, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: AppTheme.neutral50,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Column(
                children: [
                  _SummaryRow(
                    label: 'Harga Jual',
                    value: CurrencyFormatter.format(sellPrice * qty),
                  ),
                  _SummaryRow(
                    label: 'Modal',
                    value: CurrencyFormatter.format(
                        (_selectedVariant?.costPrice ?? 0) * qty),
                  ),
                  const Divider(height: 16),
                  _SummaryRow(
                    label: 'Keuntungan',
                    value: CurrencyFormatter.format(profit),
                    valueColor: AppTheme.success,
                    bold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Reset for new transaction
                      setState(() {
                        _step = 0;
                        _selectedCategory = null;
                        _selectedProduct = null;
                        _selectedVariant = null;
                        _sellPriceController.clear();
                        _qtyController.text = '1';
                      });
                    },
                    child: const Text('Transaksi Lagi'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.pop();
                    },
                    child: const Text('Selesai'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Transaksi Baru'),
        leading: IconButton(
          onPressed: _prevStep,
          icon: _step == 0
              ? const Icon(Icons.close_rounded)
              : const Icon(Icons.arrow_back_ios_rounded),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / 4,
            backgroundColor: AppTheme.neutral100,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            minHeight: 4,
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.3, 0),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: _buildStep(),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildCategoryStep();
      case 1:
        return _buildProductStep();
      case 2:
        return _buildVariantStep();
      case 3:
        return _buildPriceStep();
      default:
        return const SizedBox();
    }
  }

  // Step 1: Pilih Kategori
  Widget _buildCategoryStep() {
    final categories = ref.watch(categoriesProvider);
    return _StepContainer(
      key: const ValueKey(0),
      title: 'Pilih Kategori',
      subtitle: 'Langkah 1 dari 4',
      child: GridView.builder(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          return _SelectionCard(
            label: cat,
            icon: Icons.category_rounded,
            selected: false,
            onTap: () {
              setState(() => _selectedCategory = cat);
              _nextStep();
            },
          );
        },
      ),
    );
  }

  // Step 2: Pilih Produk
  Widget _buildProductStep() {
    final products = ref.watch(productsProvider)
        .where((p) => p.category == _selectedCategory)
        .toList();

    return _StepContainer(
      key: const ValueKey(1),
      title: 'Pilih Produk',
      subtitle: 'Kategori: $_selectedCategory • Langkah 2 dari 4',
      child: products.isEmpty
          ? EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Belum ada produk',
              message: 'Tidak ada produk di kategori $_selectedCategory',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SelectionCard(
                    label: product.name,
                    icon: Icons.inventory_2_rounded,
                    selected: false,
                    onTap: () {
                      setState(() => _selectedProduct = product);
                      _nextStep();
                    },
                  ),
                );
              },
            ),
    );
  }

  // Step 3: Pilih Ukuran/Varian
  Widget _buildVariantStep() {
    final variants = ref.watch(variantsByProductProvider(_selectedProduct?.id));

    return _StepContainer(
      key: const ValueKey(2),
      title: 'Pilih Ukuran',
      subtitle: '${_selectedProduct?.name} • Langkah 3 dari 4',
      child: variants.isEmpty
          ? EmptyState(
              icon: Icons.format_size_outlined,
              title: 'Tidak ada varian',
              message: 'Produk ini belum memiliki ukuran',
            )
          : GridView.builder(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.0,
              ),
              itemCount: variants.length,
              itemBuilder: (context, index) {
                final variant = variants[index];
                return GestureDetector(
                  onTap: variant.isOutOfStock
                      ? null
                      : () {
                          setState(() => _selectedVariant = variant);
                          _nextStep();
                        },
                  child: Container(
                    decoration: BoxDecoration(
                      color: variant.isOutOfStock
                          ? AppTheme.neutral100
                          : AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      boxShadow:
                          variant.isOutOfStock ? null : AppTheme.cardShadow,
                      border: variant.isOutOfStock
                          ? Border.all(color: AppTheme.neutral200)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          variant.size,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: variant.isOutOfStock
                                ? AppTheme.neutral300
                                : AppTheme.neutral800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        StockBadge(stock: variant.stock),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.compact(variant.costPrice),
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.neutral400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  // Step 4: Input Harga Jual
  Widget _buildPriceStep() {
    final variant = _selectedVariant!;
    final qtyText = _qtyController.text;
    final qty = int.tryParse(qtyText) ?? 1;
    final sellPriceText = _sellPriceController.text.replaceAll('.', '');
    final sellPrice = double.tryParse(sellPriceText) ?? 0;
    final profit = (sellPrice - variant.costPrice) * qty;

    return _StepContainer(
      key: const ValueKey(3),
      title: 'Harga Jual',
      subtitle: '${_selectedProduct?.name} • Ukuran ${variant.size}',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          children: [
            // Summary card
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: AppTheme.neutral50,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppTheme.neutral200),
              ),
              child: Column(
                children: [
                  _SummaryRow(
                    label: 'Produk',
                    value: _selectedProduct?.name ?? '',
                  ),
                  _SummaryRow(
                    label: 'Ukuran',
                    value: variant.size,
                  ),
                  _SummaryRow(
                    label: 'Harga Modal',
                    value: CurrencyFormatter.format(variant.costPrice),
                  ),
                  _SummaryRow(
                    label: 'Stok Tersedia',
                    value: '${variant.stock}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),

            // Jumlah
            Row(
              children: [
                const Expanded(
                  child: Text('Jumlah',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.neutral700)),
                ),
                Row(
                  children: [
                    _QtyButton(
                      icon: Icons.remove_rounded,
                      onTap: () {
                        final v = int.tryParse(_qtyController.text) ?? 1;
                        if (v > 1) setState(() => _qtyController.text = '${v - 1}');
                      },
                    ),
                    SizedBox(
                      width: 50,
                      child: TextFormField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    _QtyButton(
                      icon: Icons.add_rounded,
                      onTap: () {
                        final v = int.tryParse(_qtyController.text) ?? 1;
                        if (v < variant.stock) {
                          setState(() => _qtyController.text = '${v + 1}');
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),

            // Sell price input
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Harga Jual (Rp)',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.neutral700)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _sellPriceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.neutral900,
              ),
              decoration: const InputDecoration(
                prefixText: 'Rp ',
                prefixStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.neutral400,
                ),
                hintText: '0',
                hintStyle: TextStyle(fontSize: 24, color: AppTheme.neutral200),
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),

            // Profit preview
            if (sellPrice > 0) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: profit >= 0
                      ? AppTheme.success.withValues(alpha: 0.08)
                      : AppTheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: profit >= 0
                        ? AppTheme.success.withValues(alpha: 0.3)
                        : AppTheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          profit >= 0
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          color: profit >= 0 ? AppTheme.success : AppTheme.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          profit >= 0 ? 'Keuntungan' : 'Kerugian',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: profit >= 0 ? AppTheme.success : AppTheme.error,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      CurrencyFormatter.format(profit.abs()),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: profit >= 0 ? AppTheme.success : AppTheme.error,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
            ],

            PrimaryButton(
              label: 'Simpan Transaksi',
              icon: Icons.check_circle_rounded,
              onPressed: _submitTransaction,
              loading: _loading,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepContainer extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _StepContainer({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontSize: 20)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.neutral400)),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.cardShadow,
          border: selected
              ? null
              : Border.all(color: AppTheme.neutral100),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Row(
            children: [
              Icon(icon,
                  color: selected ? Colors.white : AppTheme.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color:
                        selected ? Colors.white : AppTheme.neutral800,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: selected
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppTheme.neutral300,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.neutral500)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? AppTheme.neutral800,
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.neutral100,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Icon(icon, size: 18, color: AppTheme.neutral700),
      ),
    );
  }
}
