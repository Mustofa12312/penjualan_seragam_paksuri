/// Konstanta global aplikasi
class AppConstants {
  AppConstants._();

  // Hive Box Names
  static const String productBox = 'products';
  static const String variantBox = 'variants';
  static const String transactionBox = 'transactions';
  static const String categoryBox = 'categories';
  static const String sizeBox = 'sizes';
  static const String settingsBox = 'settings';

  // Hive Type IDs
  static const int productTypeId = 0;
  static const int variantTypeId = 1;
  static const int transactionTypeId = 2;

  // Default categories
  static const List<String> defaultCategories = [
    'SD',
    'SMP',
    'SMA',
    'SMK',
    'Pramuka',
    'Olahraga',
    'Batik',
    'Lainnya',
  ];

  // Default sizes
  static const List<String> defaultSizes = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    '11',
    '12',
    '13',
    'XS',
    'S',
    'M',
    'L',
    'XL',
    'XXL',
    'XXXL',
  ];

  // Stock thresholds
  static const int lowStockThreshold = 3;

  // Settings keys
  static const String shopNameKey = 'shop_name';
  static const String ownerNameKey = 'owner_name';
  static const String defaultCurrencyKey = 'currency';

  static const String defaultShopName = 'Toko Seragam';
  static const String defaultCurrency = 'Rp';

  // CSV Headers
  static const List<String> productCsvHeaders = [
    'ID',
    'Nama',
    'Kategori',
  ];

  static const List<String> variantCsvHeaders = [
    'ID',
    'ProductID',
    'Ukuran',
    'Harga Modal',
    'Stok',
  ];

  static const List<String> transactionCsvHeaders = [
    'ID',
    'VariantID',
    'Nama Produk',
    'Ukuran',
    'Harga Jual',
    'Harga Modal',
    'Keuntungan',
    'Tanggal',
  ];
}
