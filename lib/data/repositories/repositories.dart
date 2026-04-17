import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../models/product_model.dart';
import '../models/variant_model.dart';
import '../models/transaction_model.dart';

/// Repository untuk manajemen produk dan varian
class ProductRepository {
  final _uuid = const Uuid();

  Box<ProductModel> get _productBox => Hive.box<ProductModel>(AppConstants.productBox);
  Box<VariantModel> get _variantBox => Hive.box<VariantModel>(AppConstants.variantBox);

  // ── Products ──────────────────────────────────────────────────

  List<ProductModel> getAllProducts() => _productBox.values.toList();

  List<ProductModel> getProductsByCategory(String category) =>
      _productBox.values.where((p) => p.category == category).toList();

  ProductModel? getProductById(String id) {
    try {
      return _productBox.values.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addProduct({
    required String name,
    required String category,
  }) async {
    final now = DateTime.now();
    final product = ProductModel(
      id: _uuid.v4(),
      name: name,
      category: category,
      createdAt: now,
      updatedAt: now,
    );
    await _productBox.put(product.id, product);
  }

  Future<void> updateProduct(ProductModel product) async {
    final updated = product.copyWith(updatedAt: DateTime.now());
    await _productBox.put(updated.id, updated);
  }

  Future<void> deleteProduct(String productId) async {
    await _productBox.delete(productId);
    // Also delete all variants of this product
    final variantKeys = _variantBox.values
        .where((v) => v.productId == productId)
        .map((v) => v.id)
        .toList();
    await _variantBox.deleteAll(variantKeys);
  }

  // ── Variants ──────────────────────────────────────────────────

  List<VariantModel> getVariantsByProduct(String productId) =>
      _variantBox.values.where((v) => v.productId == productId).toList();

  List<VariantModel> getAllVariants() => _variantBox.values.toList();

  VariantModel? getVariantById(String id) {
    try {
      return _variantBox.values.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Restore produk dari backup CSV — skip jika ID sudah ada
  Future<bool> restoreProduct({
    required String id,
    required String name,
    required String category,
  }) async {
    if (_productBox.containsKey(id)) return false; // sudah ada, skip
    final now = DateTime.now();
    final product = ProductModel(
      id: id,
      name: name,
      category: category,
      createdAt: now,
      updatedAt: now,
    );
    await _productBox.put(product.id, product);
    return true;
  }

  /// Restore varian dari backup CSV — skip jika ID sudah ada
  Future<bool> restoreVariant({
    required String id,
    required String productId,
    required String size,
    required double costPrice,
    required int stock,
  }) async {
    if (_variantBox.containsKey(id)) return false; // sudah ada, skip
    final now = DateTime.now();
    final variant = VariantModel(
      id: id,
      productId: productId,
      size: size,
      costPrice: costPrice,
      stock: stock,
      createdAt: now,
      updatedAt: now,
    );
    await _variantBox.put(variant.id, variant);
    return true;
  }

  Future<void> addVariant({
    required String productId,
    required String size,
    required double costPrice,
    required int stock,
  }) async {
    final now = DateTime.now();
    final variant = VariantModel(
      id: _uuid.v4(),
      productId: productId,
      size: size,
      costPrice: costPrice,
      stock: stock,
      createdAt: now,
      updatedAt: now,
    );
    await _variantBox.put(variant.id, variant);
  }

  Future<void> updateVariant(VariantModel variant) async {
    final updated = variant.copyWith(updatedAt: DateTime.now());
    await _variantBox.put(updated.id, updated);
  }

  Future<void> deleteVariant(String variantId) async {
    await _variantBox.delete(variantId);
  }

  Future<void> updateStock(String variantId, int newStock) async {
    final variant = _variantBox.get(variantId);
    if (variant != null) {
      await _variantBox.put(variantId, variant.copyWith(stock: newStock, updatedAt: DateTime.now()));
    }
  }

  /// Mengurangi stok saat transaksi
  Future<bool> decreaseStock(String variantId, int quantity) async {
    final variant = _variantBox.get(variantId);
    if (variant == null || variant.stock < quantity) return false;
    await updateStock(variantId, variant.stock - quantity);
    return true;
  }
}

/// Repository untuk manajemen transaksi
class TransactionRepository {
  final _uuid = const Uuid();

  Box<TransactionModel> get _transactionBox =>
      Hive.box<TransactionModel>(AppConstants.transactionBox);

  List<TransactionModel> getAllTransactions() {
    final list = _transactionBox.values.toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<TransactionModel> getTransactionsByDateRange(DateTime start, DateTime end) {
    return _transactionBox.values
        .where((t) => t.date.isAfter(start.subtract(const Duration(days: 1))) &&
            t.date.isBefore(end.add(const Duration(days: 1))))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<TransactionModel> getTodayTransactions() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getTransactionsByDateRange(startOfDay, endOfDay);
  }

  List<TransactionModel> getThisWeekTransactions() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return getTransactionsByDateRange(
      DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
      now,
    );
  }

  List<TransactionModel> getThisMonthTransactions() {
    final now = DateTime.now();
    return getTransactionsByDateRange(
      DateTime(now.year, now.month, 1),
      now,
    );
  }

  Future<TransactionModel> addTransaction({
    required String variantId,
    required String productId,
    required String productName,
    required String size,
    required double sellPrice,
    required double costPrice,
    required String category,
    int quantity = 1,
  }) async {
    final transaction = TransactionModel(
      id: _uuid.v4(),
      variantId: variantId,
      productId: productId,
      productName: productName,
      size: size,
      sellPrice: sellPrice,
      costPrice: costPrice,
      date: DateTime.now(),
      category: category,
      quantity: quantity,
    );
    await _transactionBox.put(transaction.id, transaction);
    return transaction;
  }

  Future<void> deleteTransaction(String id) async {
    await _transactionBox.delete(id);
  }

  /// Restore transaksi dari backup CSV — skip jika ID sudah ada (anti-duplikat)
  Future<bool> restoreTransaction({
    required String id,
    required String variantId,
    required String productId,
    required String productName,
    required String size,
    required double sellPrice,
    required double costPrice,
    required String category,
    required int quantity,
    required DateTime date,
  }) async {
    if (_transactionBox.containsKey(id)) return false;
    final transaction = TransactionModel(
      id: id,
      variantId: variantId,
      productId: productId,
      productName: productName,
      size: size,
      sellPrice: sellPrice,
      costPrice: costPrice,
      date: date,
      category: category,
      quantity: quantity,
    );
    await _transactionBox.put(transaction.id, transaction);
    return true;
  }

  // ── Analytics ─────────────────────────────────────────────────

  double getTotalRevenue(List<TransactionModel> transactions) =>
      transactions.fold(0, (sum, t) => sum + t.totalSell);

  double getTotalProfit(List<TransactionModel> transactions) =>
      transactions.fold(0, (sum, t) => sum + t.profit);

  Map<String, int> getProductSalesCount(List<TransactionModel> transactions) {
    final map = <String, int>{};
    for (final t in transactions) {
      map[t.productName] = (map[t.productName] ?? 0) + t.quantity;
    }
    return map;
  }

  Map<String, double> getCategoryRevenue(List<TransactionModel> transactions) {
    final map = <String, double>{};
    for (final t in transactions) {
      map[t.category] = (map[t.category] ?? 0) + t.totalSell;
    }
    return map;
  }

  /// Get daily revenue for the last N days
  Map<DateTime, double> getDailyRevenue(int days) {
    final now = DateTime.now();
    final result = <DateTime, double>{};
    for (int i = days - 1; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      result[date] = 0;
    }
    final start = now.subtract(Duration(days: days));
    final transactions = getTransactionsByDateRange(start, now);
    for (final t in transactions) {
      final date = DateTime(t.date.year, t.date.month, t.date.day);
      if (result.containsKey(date)) {
        result[date] = (result[date] ?? 0) + t.totalSell;
      }
    }
    return result;
  }
}

/// Repository untuk pengaturan dan kategori
class SettingsRepository {
  Box<String> get _categoryBox => Hive.box<String>(AppConstants.categoryBox);
  Box<String> get _sizeBox => Hive.box<String>(AppConstants.sizeBox);

  // ── Categories ────────────────────────────────────────────────

  List<String> getCategories() => _categoryBox.values.toList();

  Future<void> addCategory(String category) async {
    if (!_categoryBox.values.contains(category)) {
      await _categoryBox.add(category);
    }
  }

  Future<void> deleteCategory(String category) async {
    final key = _categoryBox.keys.firstWhere(
      (k) => _categoryBox.get(k) == category,
      orElse: () => null,
    );
    if (key != null) await _categoryBox.delete(key);
  }

  Future<void> updateCategory(String oldCategory, String newCategory) async {
    final key = _categoryBox.keys.firstWhere(
      (k) => _categoryBox.get(k) == oldCategory,
      orElse: () => null,
    );
    if (key != null) await _categoryBox.put(key, newCategory);
  }

  // ── Sizes ─────────────────────────────────────────────────────

  List<String> getSizes() => _sizeBox.values.toList();

  Future<void> addSize(String size) async {
    if (!_sizeBox.values.contains(size)) {
      await _sizeBox.add(size);
    }
  }

  Future<void> deleteSize(String size) async {
    final key = _sizeBox.keys.firstWhere(
      (k) => _sizeBox.get(k) == size,
      orElse: () => null,
    );
    if (key != null) await _sizeBox.delete(key);
  }

  // ── Settings ──────────────────────────────────────────────────

  String getShopName() =>
      Hive.box(AppConstants.settingsBox).get(AppConstants.shopNameKey, defaultValue: AppConstants.defaultShopName);

  Future<void> setShopName(String name) =>
      Hive.box(AppConstants.settingsBox).put(AppConstants.shopNameKey, name);

  String getOwnerName() =>
      Hive.box(AppConstants.settingsBox).get(AppConstants.ownerNameKey, defaultValue: '');

  Future<void> setOwnerName(String name) =>
      Hive.box(AppConstants.settingsBox).put(AppConstants.ownerNameKey, name);
}
