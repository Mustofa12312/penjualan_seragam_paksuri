// GENERATED CODE - Written manually (hive_generator removed due to analyzer conflict)

import 'package:hive_flutter/hive_flutter.dart';
import 'transaction_model.dart';

/// Hive TypeAdapter for TransactionModel
class TransactionModelAdapter extends TypeAdapter<TransactionModel> {
  @override
  final int typeId = 2;

  @override
  TransactionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TransactionModel(
      id: fields[0] as String,
      variantId: fields[1] as String,
      productId: fields[2] as String,
      productName: fields[3] as String,
      size: fields[4] as String,
      sellPrice: fields[5] as double,
      costPrice: fields[6] as double,
      date: fields[7] as DateTime,
      category: fields[8] as String,
      quantity: fields[9] as int,
    );
  }

  @override
  void write(BinaryWriter writer, TransactionModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.variantId)
      ..writeByte(2)
      ..write(obj.productId)
      ..writeByte(3)
      ..write(obj.productName)
      ..writeByte(4)
      ..write(obj.size)
      ..writeByte(5)
      ..write(obj.sellPrice)
      ..writeByte(6)
      ..write(obj.costPrice)
      ..writeByte(7)
      ..write(obj.date)
      ..writeByte(8)
      ..write(obj.category)
      ..writeByte(9)
      ..write(obj.quantity);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
