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
    '1', '2', '3', '4', '5', '6', '7', '8', '9',
    '10', '11', '12', '13',
    'XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL',
  ];

  // Stock thresholds
  static const int lowStockThreshold = 3;

  // Settings keys
  static const String shopNameKey = 'shop_name';
  static const String ownerNameKey = 'owner_name';
  static const String defaultCurrencyKey = 'currency';
  static const String lastBackupKey = 'last_backup_date';

  static const String defaultShopName = 'Toko Seragam';
  static const String defaultCurrency = 'Rp';

  // ── CSV: Products ─────────────────────────────────────────────
  // Columns: 0=ID, 1=Nama, 2=Kategori
  static const List<String> productCsvHeaders = ['ID', 'Nama', 'Kategori'];
  static const int csvProdId = 0;
  static const int csvProdName = 1;
  static const int csvProdCategory = 2;

  // ── CSV: Variants ─────────────────────────────────────────────
  // Columns: 0=ID, 1=ProductID, 2=Ukuran, 3=HargaModal, 4=Stok
  static const List<String> variantCsvHeaders = [
    'ID', 'ProductID', 'Ukuran', 'Harga Modal', 'Stok',
  ];
  static const int csvVarId = 0;
  static const int csvVarProductId = 1;
  static const int csvVarSize = 2;
  static const int csvVarCostPrice = 3;
  static const int csvVarStock = 4;

  // ── CSV: Transactions (lengkap untuk full restore) ────────────
  // Columns: 0=ID,1=VariantID,2=ProductID,3=NamaProduk,4=Kategori,
  //          5=Ukuran,6=HargaJual,7=HargaModal,8=Jumlah,9=Keuntungan,10=Tanggal
  static const List<String> transactionCsvHeaders = [
    'ID', 'VariantID', 'ProductID', 'Nama Produk', 'Kategori',
    'Ukuran', 'Harga Jual', 'Harga Modal', 'Jumlah', 'Keuntungan', 'Tanggal',
  ];
  static const int csvTxId = 0;
  static const int csvTxVariantId = 1;
  static const int csvTxProductId = 2;
  static const int csvTxProductName = 3;
  static const int csvTxCategory = 4;
  static const int csvTxSize = 5;
  static const int csvTxSellPrice = 6;
  static const int csvTxCostPrice = 7;
  static const int csvTxQuantity = 8;
  static const int csvTxProfit = 9;
  static const int csvTxDate = 10;
  static const int csvTxMinColumns = 9; // minimum kolom wajib
}
