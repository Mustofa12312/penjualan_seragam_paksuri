import 'package:hive_flutter/hive_flutter.dart';

/// Model transaksi penjualan
class TransactionModel extends HiveObject {
  String id;
  String variantId;
  String productId;
  String productName;
  String size;
  double sellPrice;
  double costPrice;
  DateTime date;
  String category;
  int quantity;

  TransactionModel({
    required this.id,
    required this.variantId,
    required this.productId,
    required this.productName,
    required this.size,
    required this.sellPrice,
    required this.costPrice,
    required this.date,
    required this.category,
    this.quantity = 1,
  });

  double get profit => (sellPrice - costPrice) * quantity;
  double get totalSell => sellPrice * quantity;
  double get totalCost => costPrice * quantity;

  @override
  String toString() =>
      'TransactionModel(id: $id, product: $productName, size: $size, profit: $profit)';
}
