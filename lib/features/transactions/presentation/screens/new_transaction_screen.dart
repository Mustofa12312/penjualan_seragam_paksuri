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

/// Layar transaksi penjualan baru (alur step-by-step yang dipersingkat)
///
/// Alur baru:
///   A) Kategori → Ukuran → Harga  (jika kategori hanya punya 1 produk — auto-skip)
///   B) Kategori → Produk → Ukuran → Harga  (jika ada lebih dari 1 produk)
///   C) Quick Access Terlaris → Ukuran → Harga  (shortcut super cepat)
class NewTransactionScreen extends ConsumerStatefulWidget {
  const NewTransactionScreen({super.key});

  @override
  ConsumerState<NewTransactionScreen> createState() =>
      _NewTransactionScreenState();
}

class _NewTransactionScreenState extends ConsumerState<NewTransactionScreen> {
  /// 0 = kategori, 1 = produk, 2 = ukuran, 3 = harga & konfirmasi
  int _step = 0;

  /// Flag: apakah step produk di-skip secara otomatis?
  /// Jika true, tombol back dari step ukuran akan langsung ke step kategori.
  bool _productStepSkipped = false;

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

  // ── Navigasi Step ────────────────────────────────────────────

  /// Hitung total step aktif (3 jika skip, 4 jika tidak)
  int get _totalSteps => _productStepSkipped ? 3 : 4;

  /// Hitung posisi visual step (untuk progress bar & subtitle)
  int get _visualStep {
    if (_productStepSkipped) {
      // step 0→1, step 2→2, step 3→3
      if (_step == 0) return 1;
      if (_step == 2) return 2;
      return 3;
    }
    return _step + 1;
  }

  void _goToNextStep() => setState(() => _step++);

  void _prevStep() {
    if (_step == 0) {
      context.pop();
    } else if (_step == 2 && _productStepSkipped) {
      // Setelah auto-skip, back dari Ukuran langsung ke Kategori
      setState(() {
        _step = 0;
        _selectedCategory = null;
        _selectedProduct = null;
        _productStepSkipped = false;
      });
    } else {
      setState(() => _step--);
    }
  }

  /// Dipanggil saat user memilih kategori.
  /// Jika hanya 1 produk → auto-skip ke Ukuran.
  void _onCategorySelected(String category) {
    final products = ref.read(productsByCategoryProvider(category));
    setState(() {
      _selectedCategory = category;
    });

    if (products.length == 1) {
      // Auto-skip: langsung pilih satu-satunya produk & lompat ke Ukuran
      setState(() {
        _selectedProduct = products.first;
        _productStepSkipped = true;
        _step = 2; // lompat ke step Ukuran
      });
    } else {
      // Banyak produk → alur normal ke step Produk
      setState(() {
        _productStepSkipped = false;
        _step = 1;
      });
    }
  }

  /// Dipanggil dari Quick Access Terlaris.
  /// Langsung set produk & variant, lompat ke step Harga.
  void _onQuickAccessTapped({
    required ProductModel product,
    required VariantModel variant,
  }) {
    setState(() {
      _selectedCategory = product.category;
      _selectedProduct = product;
      _selectedVariant = variant;
      _productStepSkipped = true;
      _step = 2; // ke step Ukuran agar user bisa konfirmasi / ganti ukuran
    });
  }

  // ── Submit Transaksi ─────────────────────────────────────────

  Future<void> _submitTransaction() async {
    final sellPriceText =
        _sellPriceController.text.replaceAll('.', '').replaceAll(',', '');
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

    final success =
        await ref.read(transactionsProvider.notifier).addTransaction(
              variantId: _selectedVariant!.id,
              productId: _selectedProduct!.id,
              productName: _selectedProduct!.name,
              size: _selectedVariant!.size,
              sellPrice: sellPrice,
              costPrice: _selectedVariant!.costPrice,
              category: _selectedProduct!.category,
              quantity: qty,
            );

    // Refresh variants agar stok langsung terupdate
    ref.read(variantsProvider.notifier).load();

    setState(() => _loading = false);

    if (mounted) {
      if (success) {
        _showSuccessSheet(sellPrice, qty);
      } else {
        showErrorSnackBar(
            context, 'Stok tidak mencukupi atau terjadi kesalahan');
      }
    }
  }

  void _showSuccessSheet(double sellPrice, int qty) {
    final profit =
        (sellPrice - (_selectedVariant?.costPrice ?? 0)) * qty;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
        ),
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
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
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusMd),
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
                      Navigator.pop(sheetContext);
                      // Reset untuk transaksi baru
                      setState(() {
                        _step = 0;
                        _selectedCategory = null;
                        _selectedProduct = null;
                        _selectedVariant = null;
                        _productStepSkipped = false;
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
                      Navigator.pop(sheetContext);
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

  // ── Build ────────────────────────────────────────────────────

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
            value: _visualStep / _totalSteps,
            backgroundColor: AppTheme.neutral100,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            minHeight: 4,
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, animation) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.25, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
              parent: animation, curve: Curves.easeOutCubic)),
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

  // ── Step 1: Pilih Kategori ───────────────────────────────────

  Widget _buildCategoryStep() {
    final categories = ref.watch(categoriesProvider);
    final topVariants = ref.watch(topVariantsProvider);

    return _StepContainer(
      key: const ValueKey(0),
      title: 'Pilih Kategori',
      subtitle: 'Langkah 1 dari $_totalSteps',
      child: CustomScrollView(
        slivers: [
          // ── Quick Access: Terlaris ─────────────────────────
          if (topVariants.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primary,
                            AppTheme.primary.withOpacity(0.7),
                          ],
                        ),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt_rounded,
                              size: 13, color: Colors.white),
                          SizedBox(width: 3),
                          Text(
                            'TERLARIS',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Akses cepat',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.neutral400),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  itemCount: topVariants.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final entry = topVariants[index];
                    return _QuickAccessCard(
                      product: entry.product,
                      variant: entry.variant,
                      onTap: () => _onQuickAccessTapped(
                        product: entry.product,
                        variant: entry.variant,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 1),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
          ],

          // ── Grid Kategori ──────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Semua Kategori',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.neutral400,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverGrid(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.6,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final cat = categories[index];
                  // Hitung jumlah produk per kategori untuk badge
                  final productCount = ref
                      .watch(productsByCategoryProvider(cat))
                      .length;
                  return _CategoryCard(
                    label: cat,
                    productCount: productCount,
                    onTap: () => _onCategorySelected(cat),
                  );
                },
                childCount: categories.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Pilih Produk (hanya muncul jika > 1 produk) ─────

  Widget _buildProductStep() {
    final products = ref
        .watch(productsProvider)
        .where((p) => p.category == _selectedCategory)
        .toList();

    return _StepContainer(
      key: const ValueKey(1),
      title: 'Pilih Produk',
      subtitle: 'Kategori: $_selectedCategory • Langkah 2 dari $_totalSteps',
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
                // Hitung total stok produk ini
                final variants =
                    ref.watch(variantsByProductProvider(product.id));
                final totalStock =
                    variants.fold<int>(0, (sum, v) => sum + v.stock);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ProductCard(
                    product: product,
                    totalStock: totalStock,
                    onTap: () {
                      setState(() => _selectedProduct = product);
                      _goToNextStep();
                    },
                  ),
                );
              },
            ),
    );
  }

  // ── Step 3: Pilih Ukuran/Varian ──────────────────────────────

  Widget _buildVariantStep() {
    final variants =
        ref.watch(variantsByProductProvider(_selectedProduct?.id));

    return _StepContainer(
      key: const ValueKey(2),
      title: 'Pilih Ukuran',
      subtitle:
          '${_selectedProduct?.name} • Langkah $_visualStep dari $_totalSteps',
      child: variants.isEmpty
          ? EmptyState(
              icon: Icons.format_size_outlined,
              title: 'Tidak ada varian',
              message: 'Produk ini belum memiliki ukuran',
            )
          : GridView.builder(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.0,
              ),
              itemCount: variants.length,
              itemBuilder: (context, index) {
                final variant = variants[index];
                final isSelected =
                    _selectedVariant?.id == variant.id;
                return GestureDetector(
                  onTap: variant.isOutOfStock
                      ? null
                      : () {
                          setState(() => _selectedVariant = variant);
                          _goToNextStep();
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: variant.isOutOfStock
                          ? AppTheme.neutral100
                          : isSelected
                              ? AppTheme.primary
                              : AppTheme.surface,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusLg),
                      boxShadow: variant.isOutOfStock
                          ? null
                          : AppTheme.cardShadow,
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
                                : isSelected
                                    ? Colors.white
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
                            color: variant.isOutOfStock
                                ? AppTheme.neutral400
                                : isSelected
                                    ? Colors.white70
                                    : AppTheme.neutral400,
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

  // ── Step 4: Input Harga Jual ─────────────────────────────────

  Widget _buildPriceStep() {
    final variant = _selectedVariant!;
    final qty = int.tryParse(_qtyController.text) ?? 1;
    final sellPriceText =
        _sellPriceController.text.replaceAll('.', '');
    final sellPrice = double.tryParse(sellPriceText) ?? 0;
    final profit = (sellPrice - variant.costPrice) * qty;

    return _StepContainer(
      key: const ValueKey(3),
      title: 'Harga Jual',
      subtitle:
          '${_selectedProduct?.name} • Ukuran ${variant.size}',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: AppTheme.neutral50,
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusLg),
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
                        final v =
                            int.tryParse(_qtyController.text) ?? 1;
                        if (v > 1) {
                          setState(
                              () => _qtyController.text = '${v - 1}');
                        }
                      },
                    ),
                    SizedBox(
                      width: 50,
                      child: TextFormField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    _QtyButton(
                      icon: Icons.add_rounded,
                      onTap: () {
                        final v =
                            int.tryParse(_qtyController.text) ?? 1;
                        if (v < variant.stock) {
                          setState(
                              () => _qtyController.text = '${v + 1}');
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),

            // Input harga jual
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
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: false),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly
              ],
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
                hintStyle:
                    TextStyle(fontSize: 24, color: AppTheme.neutral200),
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),

            // Preview keuntungan
            if (sellPrice > 0) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: profit >= 0
                      ? AppTheme.success.withOpacity(0.08)
                      : AppTheme.error.withOpacity(0.08),
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: profit >= 0
                        ? AppTheme.success.withOpacity(0.3)
                        : AppTheme.error.withOpacity(0.3),
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
                          color: profit >= 0
                              ? AppTheme.success
                              : AppTheme.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          profit >= 0 ? 'Keuntungan' : 'Kerugian',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: profit >= 0
                                ? AppTheme.success
                                : AppTheme.error,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      CurrencyFormatter.format(profit.abs()),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: profit >= 0
                            ? AppTheme.success
                            : AppTheme.error,
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

// ── Helper Widgets ───────────────────────────────────────────────────────────

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

/// Card kategori yang menampilkan jumlah produk di dalam kategori tersebut
class _CategoryCard extends StatelessWidget {
  final String label;
  final int productCount;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.label,
    required this.productCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(color: AppTheme.neutral100),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Icon(Icons.category_rounded,
                    color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.neutral800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$productCount produk',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.neutral400),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.neutral300, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card produk (di step Produk) — tampilkan nama + total stok
class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final int totalStock;
  final VoidCallback onTap;

  const _ProductCard({
    required this.product,
    required this.totalStock,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(color: AppTheme.neutral100),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Icon(Icons.inventory_2_rounded,
                    color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.neutral800,
                      ),
                    ),
                    Text(
                      'Stok: $totalStock pcs',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.neutral400),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.neutral300, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip/card horizontal untuk Quick Access Terlaris
class _QuickAccessCard extends StatelessWidget {
  final ProductModel product;
  final VariantModel variant;
  final VoidCallback onTap;

  const _QuickAccessCard({
    required this.product,
    required this.variant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primary.withOpacity(0.12),
              AppTheme.primary.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
              color: AppTheme.primary.withOpacity(0.25), width: 1.2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded,
                    size: 12, color: AppTheme.primary),
                const SizedBox(width: 3),
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              'Ukuran ${variant.size}',
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.neutral500),
            ),
            Text(
              '${variant.stock} pcs',
              style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.neutral400,
                  fontWeight: FontWeight.w500),
            ),
          ],
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
              fontWeight:
                  bold ? FontWeight.w800 : FontWeight.w600,
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
