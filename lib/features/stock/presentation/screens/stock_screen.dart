import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/datasources/providers.dart';
import '../../../../data/models/variant_model.dart';

/// Layar manajemen stok
class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  String _filter = 'all'; // all, low, out
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final variants = ref.watch(variantsProvider);
    final products = ref.watch(productsProvider);

    // Build product name map
    final productMap = {for (final p in products) p.id: p.name};
    final productCategoryMap = {for (final p in products) p.id: p.category};

    // Filter
    List<VariantModel> filtered = variants.where((v) {
      final productName = productMap[v.productId] ?? '';
      final matchSearch = _searchQuery.isEmpty ||
          productName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          v.size.toLowerCase().contains(_searchQuery.toLowerCase());
      if (!matchSearch) return false;
      switch (_filter) {
        case 'low':
          return v.isLowStock;
        case 'out':
          return v.isOutOfStock;
        default:
          return true;
      }
    }).toList();

    // Sort: out of stock first, then low stock, then normal
    filtered.sort((a, b) {
      if (a.isOutOfStock && !b.isOutOfStock) return -1;
      if (!a.isOutOfStock && b.isOutOfStock) return 1;
      if (a.isLowStock && !b.isLowStock) return -1;
      if (!a.isLowStock && b.isLowStock) return 1;
      return a.stock.compareTo(b.stock);
    });

    final outOfStockCount = variants.where((v) => v.isOutOfStock).length;
    final lowStockCount = variants.where((v) => v.isLowStock).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Manajemen Stok'),
      ),
      body: Column(
        children: [
          // Alert banners
          if (outOfStockCount > 0 || lowStockCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  if (outOfStockCount > 0)
                    _AlertBanner(
                      icon: Icons.error_rounded,
                      message:
                          '$outOfStockCount varian stok habis! Segera restok.',
                      color: AppTheme.error,
                    ),
                  if (lowStockCount > 0) ...[
                    const SizedBox(height: 8),
                    _AlertBanner(
                      icon: Icons.warning_amber_rounded,
                      message:
                          '$lowStockCount varian stok menipis (< 3 item).',
                      color: AppTheme.warning,
                    ),
                  ],
                ],
              ),
            ),

          // Search
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: AppSearchBar(
              controller: _searchController,
              hintText: 'Cari produk atau ukuran...',
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // Filter tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
            child: Row(
              children: [
                _FilterTab(
                  label: 'Semua (${variants.length})',
                  selected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterTab(
                  label: 'Menipis ($lowStockCount)',
                  selected: _filter == 'low',
                  color: AppTheme.warning,
                  onTap: () => setState(() => _filter = 'low'),
                ),
                const SizedBox(width: 8),
                _FilterTab(
                  label: 'Habis ($outOfStockCount)',
                  selected: _filter == 'out',
                  color: AppTheme.error,
                  onTap: () => setState(() => _filter = 'out'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Stock list
          Expanded(
            child: filtered.isEmpty
                ? EmptyState(
                    icon: Icons.warehouse_outlined,
                    title: 'Tidak ada data stok',
                    message: 'Tambahkan produk dan varian terlebih dahulu',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingMd),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final variant = filtered[index];
                      final productName =
                          productMap[variant.productId] ?? 'Produk Tidak Dikenal';
                      final category =
                          productCategoryMap[variant.productId] ?? '';
                      return _StockCard(
                        variant: variant,
                        productName: productName,
                        category: category,
                        onUpdate: (newStock) async {
                          await ref
                              .read(variantsProvider.notifier)
                              .updateStock(variant.id, newStock);
                          if (context.mounted) {
                            showSuccessSnackBar(context, 'Stok diperbarui');
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const _AlertBanner({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? activeColor : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: selected ? activeColor : AppTheme.neutral200,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppTheme.neutral500,
          ),
        ),
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  final VariantModel variant;
  final String productName;
  final String category;
  final ValueChanged<int> onUpdate;

  const _StockCard({
    required this.variant,
    required this.productName,
    required this.category,
    required this.onUpdate,
  });

  void _showUpdateDialog(BuildContext context) {
    final controller = TextEditingController(text: variant.stock.toString());
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Update Stok - ${variant.size}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$productName • Ukuran ${variant.size}',
                style: const TextStyle(color: AppTheme.neutral500, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Stok Baru',
                prefixIcon: Icon(Icons.inventory_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final newStock = int.tryParse(controller.text);
              if (newStock != null && newStock >= 0) {
                onUpdate(newStock);
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

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
              ? Border.all(color: AppTheme.error.withValues(alpha: 0.4))
              : variant.isLowStock
                  ? Border.all(color: AppTheme.warning.withValues(alpha: 0.4))
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
                  color: variant.isOutOfStock
                      ? AppTheme.error.withValues(alpha: 0.1)
                      : variant.isLowStock
                          ? AppTheme.warning.withValues(alpha: 0.1)
                          : AppTheme.neutral100,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Center(
                  child: Text(
                    variant.size,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: variant.isOutOfStock
                          ? AppTheme.error
                          : variant.isLowStock
                              ? AppTheme.warning
                              : AppTheme.neutral700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Product info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.neutral900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusFull),
                          ),
                          child: Text(
                            category,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Modal: ${CurrencyFormatter.format(variant.costPrice)}',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.neutral400),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Stock & update button
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StockBadge(stock: variant.stock),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _showUpdateDialog(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: const Text(
                        'Update',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
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
