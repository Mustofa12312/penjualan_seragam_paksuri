import 'package:hive_flutter/hive_flutter.dart';

/// Model produk (baju seragam)
class ProductModel extends HiveObject {
  String id;
  String name;
  String category;
  DateTime createdAt;
  DateTime updatedAt;

  ProductModel({
    required this.id,
    required this.name,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
  });

  ProductModel copyWith({
    String? id,
    String? name,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'ProductModel(id: $id, name: $name, category: $category)';
}
