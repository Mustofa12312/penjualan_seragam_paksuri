import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/product_model.dart';
import '../../data/models/product_model.g.dart';
import '../../data/models/variant_model.dart';
import '../../data/models/variant_model.g.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/transaction_model.g.dart';
import '../constants/app_constants.dart';

/// Inisialisasi Hive dan registrasi adapter
class HiveService {
  HiveService._();

  static Future<void> initialize() async {
    await Hive.initFlutter();

    // Register adapters
    if (!Hive.isAdapterRegistered(AppConstants.productTypeId)) {
      Hive.registerAdapter(ProductModelAdapter());
    }
    if (!Hive.isAdapterRegistered(AppConstants.variantTypeId)) {
      Hive.registerAdapter(VariantModelAdapter());
    }
    if (!Hive.isAdapterRegistered(AppConstants.transactionTypeId)) {
      Hive.registerAdapter(TransactionModelAdapter());
    }

    // Open boxes
    await Hive.openBox<ProductModel>(AppConstants.productBox);
    await Hive.openBox<VariantModel>(AppConstants.variantBox);
    await Hive.openBox<TransactionModel>(AppConstants.transactionBox);
    await Hive.openBox<String>(AppConstants.categoryBox);
    await Hive.openBox<String>(AppConstants.sizeBox);
    await Hive.openBox(AppConstants.settingsBox);

    // Seed default data if empty
    await _seedDefaults();
  }

  static Future<void> _seedDefaults() async {
    final categoryBox = Hive.box<String>(AppConstants.categoryBox);
    if (categoryBox.isEmpty) {
      await categoryBox.addAll(AppConstants.defaultCategories);
    }

    final sizeBox = Hive.box<String>(AppConstants.sizeBox);
    if (sizeBox.isEmpty) {
      await sizeBox.addAll(AppConstants.defaultSizes);
    }

    final settingsBox = Hive.box(AppConstants.settingsBox);
    if (!settingsBox.containsKey(AppConstants.shopNameKey)) {
      await settingsBox.put(AppConstants.shopNameKey, AppConstants.defaultShopName);
    }
  }
}
