import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/datasources/providers.dart';
import '../../../../data/models/product_model.dart';

/// Layar daftar produk
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ProductModel> _filterProducts(List<ProductModel> products) {
    if (_searchQuery.isEmpty) return products;
    return products
        .where((p) =>
            p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            p.category.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final allProducts = ref.watch(productsProvider);
    final categories = ref.watch(categoriesProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final filteredProducts = ref.watch(filteredProductsProvider);
    final displayProducts = _filterProducts(filteredProducts);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Produk'),
        actions: [
          IconButton(
            onPressed: () => context.push('/products/add'),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Tambah Produk',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: AppSearchBar(
              controller: _searchController,
              hintText: 'Cari produk...',
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Category filter
          CategoryFilterChips(
            categories: categories,
            selected: selectedCategory,
            onSelected: (cat) =>
                ref.read(selectedCategoryProvider.notifier).state = cat,
          ),
          const SizedBox(height: 8),

          // Product count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
            child: Row(
              children: [
                Text(
                  '${displayProducts.length} produk',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.neutral500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  '${allProducts.length} total',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.neutral400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Product list
          Expanded(
            child: displayProducts.isEmpty
                ? EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'Belum ada produk',
                    message: 'Tambahkan produk untuk mulai berjualan',
                    action: ElevatedButton.icon(
                      onPressed: () => context.push('/products/add'),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Tambah Produk'),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingMd),
                    itemCount: displayProducts.length,
                    itemBuilder: (context, index) {
                      final product = displayProducts[index];
                      return _ProductCard(product: product, index: index);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final ProductModel product;
  final int index;

  const _ProductCard({required this.product, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variants =
        ref.watch(variantsByProductProvider(product.id));
    final totalStock = variants.fold<int>(0, (sum, v) => sum + v.stock);
    final lowStock = variants.any((v) => v.isLowStock || v.isOutOfStock);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => context.push('/products/${product.id}'),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Row(
              children: [
                // Thumbnail
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Center(
                    child: Text(
                      product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
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
                        product.name,
                        style: const TextStyle(
                          fontSize: 15,
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
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusFull),
                            ),
                            child: Text(
                              product.category,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${variants.length} ukuran',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.neutral500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Stock info
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StockBadge(stock: totalStock),
                    const SizedBox(height: 4),
                    if (lowStock)
                      const Icon(Icons.warning_amber_rounded,
                          color: AppTheme.warning, size: 14),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppTheme.neutral400, size: 16),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 50 * index))
        .slideX(begin: 0.1);
  }
}
