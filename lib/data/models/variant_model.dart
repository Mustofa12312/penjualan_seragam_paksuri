import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/app_constants.dart';

/// Model varian produk (ukuran + harga modal + stok)
class VariantModel extends HiveObject {
  String id;
  String productId;
  String size;
  double costPrice;
  int stock;
  DateTime createdAt;
  DateTime updatedAt;

  VariantModel({
    required this.id,
    required this.productId,
    required this.size,
    required this.costPrice,
    required this.stock,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOutOfStock => stock <= 0;
  bool get isLowStock => stock > 0 && stock <= AppConstants.lowStockThreshold;

  VariantModel copyWith({
    String? id,
    String? productId,
    String? size,
    double? costPrice,
    int? stock,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VariantModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      size: size ?? this.size,
      costPrice: costPrice ?? this.costPrice,
      stock: stock ?? this.stock,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'VariantModel(id: $id, productId: $productId, size: $size, stock: $stock)';
}
