import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/repositories.dart';
import '../models/product_model.dart';
import '../models/variant_model.dart';
import '../models/transaction_model.dart';

// ── Repository Providers ──────────────────────────────────────

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(),
);

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(),
);

// ── Product Providers ─────────────────────────────────────────

final productsProvider =
    StateNotifierProvider<ProductsNotifier, List<ProductModel>>(
      (ref) => ProductsNotifier(ref.read(productRepositoryProvider)),
    );

final selectedCategoryProvider = StateProvider<String?>((ref) => null);

final filteredProductsProvider = Provider<List<ProductModel>>((ref) {
  final products = ref.watch(productsProvider);
  final category = ref.watch(selectedCategoryProvider);
  if (category == null || category.isEmpty) return products;
  return products.where((p) => p.category == category).toList();
});

// ── Variant Providers ─────────────────────────────────────────

final variantsProvider =
    StateNotifierProvider<VariantsNotifier, List<VariantModel>>(
      (ref) => VariantsNotifier(ref.read(productRepositoryProvider)),
    );

final variantsByProductProvider = Provider.family<List<VariantModel>, String?>((
  ref,
  productId,
) {
  if (productId == null) return [];
  // Watch the variants state to get reactive updates
  final allVariants = ref.watch(variantsProvider);
  return allVariants.where((v) => v.productId == productId).toList();
});

// ── Transaction Providers ─────────────────────────────────────

final transactionsProvider =
    StateNotifierProvider<TransactionsNotifier, List<TransactionModel>>(
      (ref) => TransactionsNotifier(
        ref.read(transactionRepositoryProvider),
        ref.read(productRepositoryProvider),
      ),
    );

// ── Settings Providers ────────────────────────────────────────

final categoriesProvider =
    StateNotifierProvider<CategoriesNotifier, List<String>>(
      (ref) => CategoriesNotifier(ref.read(settingsRepositoryProvider)),
    );

final sizesProvider = StateNotifierProvider<SizesNotifier, List<String>>(
  (ref) => SizesNotifier(ref.read(settingsRepositoryProvider)),
);

final shopNameProvider = StateProvider<String>((ref) {
  return ref.read(settingsRepositoryProvider).getShopName();
});

// ── Dashboard Providers ───────────────────────────────────────

final dashboardPeriodProvider = StateProvider<DashboardPeriod>(
  (ref) => DashboardPeriod.today,
);

enum DashboardPeriod { today, week, month, all }

/// Provider transaksi dashboard — reaktif terhadap transactionsProvider
/// sehingga dashboard & laporan otomatis ter-update saat ada transaksi baru.
final dashboardTransactionsProvider = Provider<List<TransactionModel>>((ref) {
  final period = ref.watch(dashboardPeriodProvider);
  // Watch transactionsProvider agar reaktif saat ada transaksi baru/hapus
  final allTransactions = ref.watch(transactionsProvider);

  final now = DateTime.now();
  switch (period) {
    case DashboardPeriod.today:
      final startOfDay = DateTime(now.year, now.month, now.day);
      return allTransactions
          .where(
            (t) =>
                t.date.isAfter(startOfDay.subtract(const Duration(seconds: 1))),
          )
          .toList();
    case DashboardPeriod.week:
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final weekStart = DateTime(
        startOfWeek.year,
        startOfWeek.month,
        startOfWeek.day,
      );
      return allTransactions
          .where(
            (t) =>
                t.date.isAfter(weekStart.subtract(const Duration(seconds: 1))),
          )
          .toList();
    case DashboardPeriod.month:
      final monthStart = DateTime(now.year, now.month, 1);
      return allTransactions
          .where(
            (t) =>
                t.date.isAfter(monthStart.subtract(const Duration(seconds: 1))),
          )
          .toList();
    case DashboardPeriod.all:
      return allTransactions;
  }
});

/// Provider untuk grafik harian di laporan — reaktif terhadap transactionsProvider
final chartDaysProvider = StateProvider<int>((ref) => 7);

final dailyRevenueProvider = Provider<Map<DateTime, double>>((ref) {
  final days = ref.watch(chartDaysProvider);
  // Watch transactionsProvider agar grafik ikut update
  final allTransactions = ref.watch(transactionsProvider);

  final now = DateTime.now();
  final result = <DateTime, double>{};
  // Inisialisasi semua hari dengan nilai 0
  for (int i = days - 1; i >= 0; i--) {
    final date = DateTime(now.year, now.month, now.day - i);
    result[date] = 0;
  }
  // Isi dengan data transaksi yang ada
  final cutoff = DateTime(now.year, now.month, now.day - days + 1);
  for (final t in allTransactions) {
    final date = DateTime(t.date.year, t.date.month, t.date.day);
    if (!date.isBefore(cutoff) && result.containsKey(date)) {
      result[date] = (result[date] ?? 0) + t.totalSell;
    }
  }
  return result;
});

// ── Low Stock Provider ────────────────────────────────────────

final lowStockVariantsProvider = Provider<List<VariantModel>>((ref) {
  final variants = ref.watch(variantsProvider);
  return variants.where((v) => v.isLowStock || v.isOutOfStock).toList();
});

// ── Quick Access: Produk Terlaris Provider ────────────────────

/// Mengembalikan pasangan (VariantModel, ProductModel) untuk 5 produk
/// yang paling sering muncul di riwayat transaksi (berdasarkan frekuensi).
/// Digunakan untuk fitur Quick Access di step pertama transaksi.
final topVariantsProvider =
    Provider<List<({VariantModel variant, ProductModel product})>>((ref) {
  final transactions = ref.watch(transactionsProvider);
  final allVariants = ref.watch(variantsProvider);
  final allProducts = ref.watch(productsProvider);

  // Hitung frekuensi penjualan per variantId
  final freq = <String, int>{};
  for (final t in transactions) {
    freq[t.variantId] = (freq[t.variantId] ?? 0) + 1;
  }

  if (freq.isEmpty) return [];

  // Urutkan berdasarkan frekuensi tertinggi
  final sortedIds = freq.keys.toList()
    ..sort((a, b) => (freq[b] ?? 0).compareTo(freq[a] ?? 0));

  final result = <({VariantModel variant, ProductModel product})>[];
  for (final variantId in sortedIds.take(5)) {
    final variant = allVariants.where((v) => v.id == variantId).firstOrNull;
    if (variant == null || variant.isOutOfStock) continue;
    final product =
        allProducts.where((p) => p.id == variant.productId).firstOrNull;
    if (product == null) continue;
    result.add((variant: variant, product: product));
  }
  return result;
});

/// Mengembalikan semua produk dalam satu kategori tertentu.
final productsByCategoryProvider =
    Provider.family<List<ProductModel>, String>((ref, category) {
  final products = ref.watch(productsProvider);
  return products.where((p) => p.category == category).toList();
});

// ── Notifiers ─────────────────────────────────────────────────

class ProductsNotifier extends StateNotifier<List<ProductModel>> {
  final ProductRepository _repo;
  ProductsNotifier(this._repo) : super([]) {
    load();
  }

  void load() => state = _repo.getAllProducts();

  Future<void> addProduct({
    required String name,
    required String category,
  }) async {
    await _repo.addProduct(name: name, category: category);
    load();
  }

  Future<void> updateProduct(ProductModel product) async {
    await _repo.updateProduct(product);
    load();
  }

  Future<void> deleteProduct(String productId) async {
    await _repo.deleteProduct(productId);
    load();
  }
}

class VariantsNotifier extends StateNotifier<List<VariantModel>> {
  final ProductRepository _repo;
  VariantsNotifier(this._repo) : super([]) {
    load();
  }

  void load() => state = _repo.getAllVariants();

  Future<void> addVariant({
    required String productId,
    required String size,
    required double costPrice,
    required int stock,
  }) async {
    await _repo.addVariant(
      productId: productId,
      size: size,
      costPrice: costPrice,
      stock: stock,
    );
    load();
  }

  Future<void> updateVariant(VariantModel variant) async {
    await _repo.updateVariant(variant);
    load();
  }

  Future<void> deleteVariant(String variantId) async {
    await _repo.deleteVariant(variantId);
    load();
  }

  Future<void> updateStock(String variantId, int newStock) async {
    await _repo.updateStock(variantId, newStock);
    load();
  }
}

class TransactionsNotifier extends StateNotifier<List<TransactionModel>> {
  final TransactionRepository _transactionRepo;
  final ProductRepository _productRepo;

  TransactionsNotifier(this._transactionRepo, this._productRepo) : super([]) {
    load();
  }

  void load() => state = _transactionRepo.getAllTransactions();

  Future<bool> addTransaction({
    required String variantId,
    required String productId,
    required String productName,
    required String size,
    required double sellPrice,
    required double costPrice,
    required String category,
    int quantity = 1,
  }) async {
    // Decrease stock first
    final success = await _productRepo.decreaseStock(variantId, quantity);
    if (!success) return false;

    await _transactionRepo.addTransaction(
      variantId: variantId,
      productId: productId,
      productName: productName,
      size: size,
      sellPrice: sellPrice,
      costPrice: costPrice,
      category: category,
      quantity: quantity,
    );
    load();
    return true;
  }

  Future<void> deleteTransaction(String id) async {
    await _transactionRepo.deleteTransaction(id);
    load();
  }
}

class CategoriesNotifier extends StateNotifier<List<String>> {
  final SettingsRepository _repo;
  CategoriesNotifier(this._repo) : super([]) {
    load();
  }

  void load() => state = _repo.getCategories();

  Future<void> addCategory(String category) async {
    await _repo.addCategory(category);
    load();
  }

  Future<void> deleteCategory(String category) async {
    await _repo.deleteCategory(category);
    load();
  }

  Future<void> updateCategory(String oldCategory, String newCategory) async {
    await _repo.updateCategory(oldCategory, newCategory);
    load();
  }
}

class SizesNotifier extends StateNotifier<List<String>> {
  final SettingsRepository _repo;
  SizesNotifier(this._repo) : super([]) {
    load();
  }

  void load() => state = _repo.getSizes();

  Future<void> addSize(String size) async {
    await _repo.addSize(size);
    load();
  }

  Future<void> deleteSize(String size) async {
    await _repo.deleteSize(size);
    load();
  }
}
