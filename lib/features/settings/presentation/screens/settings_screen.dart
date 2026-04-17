import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/datasources/providers.dart';
import '../../../../data/models/product_model.dart';
import '../../../../data/models/variant_model.dart';
import '../../../../data/models/transaction_model.dart';

/// Layar pengaturan aplikasi
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isExporting = false;
  bool _isImporting = false;

  // ── Category Management ───────────────────────────────────────

  void _showAddCategoryDialog({String? existing}) {
    final controller = TextEditingController(text: existing ?? '');
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existing != null ? 'Edit Kategori' : 'Tambah Kategori'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Contoh: SD, SMP, SMA...',
            prefixIcon: Icon(Icons.category_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              if (existing != null) {
                await ref
                    .read(categoriesProvider.notifier)
                    .updateCategory(existing, text);
              } else {
                await ref
                    .read(categoriesProvider.notifier)
                    .addCategory(text);
              }
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                showSuccessSnackBar(
                  context,
                  existing != null
                      ? 'Kategori diperbarui'
                      : 'Kategori ditambahkan',
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showAddSizeDialog({String? existing}) {
    final controller = TextEditingController(text: existing ?? '');
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existing != null ? 'Edit Ukuran' : 'Tambah Ukuran'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'Contoh: 1, 2, S, M, XL...',
            prefixIcon: Icon(Icons.format_size_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              if (existing != null) {
                // Edit ukuran — hapus lama & tambah baru
                await ref.read(sizesProvider.notifier).deleteSize(existing);
                await ref.read(sizesProvider.notifier).addSize(text);
              } else {
                await ref.read(sizesProvider.notifier).addSize(text);
              }
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                showSuccessSnackBar(
                  context,
                  existing != null ? 'Ukuran diperbarui' : 'Ukuran ditambahkan',
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // ── Shop Settings ─────────────────────────────────────────────

  void _showShopNameDialog() {
    final shopName = ref.read(shopNameProvider);
    final controller = TextEditingController(text: shopName);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nama Toko'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Nama Toko Anda',
            prefixIcon: Icon(Icons.store_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              await ref.read(settingsRepositoryProvider).setShopName(name);
              ref.read(shopNameProvider.notifier).state = name;
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                showSuccessSnackBar(context, 'Nama toko diperbarui');
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // ── CSV Export (Backup) ───────────────────────────────────────

  Future<void> _exportData() async {
    setState(() => _isExporting = true);
    try {
      final productBox = Hive.box<ProductModel>(AppConstants.productBox);
      final variantBox = Hive.box<VariantModel>(AppConstants.variantBox);
      final transactionBox =
          Hive.box<TransactionModel>(AppConstants.transactionBox);

      final now = DateTime.now();
      final dateStr =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

      // ── Transaksi CSV (lengkap dengan semua field untuk restore) ──
      final txRows = <List<dynamic>>[AppConstants.transactionCsvHeaders];
      for (final t in transactionBox.values) {
        txRows.add([
          t.id,
          t.variantId,
          t.productId,
          t.productName,
          t.category,
          t.size,
          t.sellPrice,
          t.costPrice,
          t.quantity,
          t.profit,
          t.date.toIso8601String(),
        ]);
      }

      // ── Produk CSV ────────────────────────────────────────────
      final productRows = <List<dynamic>>[AppConstants.productCsvHeaders];
      for (final p in productBox.values) {
        productRows.add([p.id, p.name, p.category]);
      }

      // ── Varian CSV ────────────────────────────────────────────
      final variantRows = <List<dynamic>>[AppConstants.variantCsvHeaders];
      for (final v in variantBox.values) {
        variantRows.add([v.id, v.productId, v.size, v.costPrice, v.stock]);
      }

      // Tulis ke temp file
      final dir = await getTemporaryDirectory();

      final txFile = File('${dir.path}/transaksi_$dateStr.csv');
      await txFile
          .writeAsString(const ListToCsvConverter().convert(txRows));

      final prodFile = File('${dir.path}/produk_$dateStr.csv');
      await prodFile
          .writeAsString(const ListToCsvConverter().convert(productRows));

      final varFile = File('${dir.path}/varian_$dateStr.csv');
      await varFile
          .writeAsString(const ListToCsvConverter().convert(variantRows));

      // Share semua file
      await Share.shareXFiles(
        [
          XFile(txFile.path, mimeType: 'text/csv'),
          XFile(prodFile.path, mimeType: 'text/csv'),
          XFile(varFile.path, mimeType: 'text/csv'),
        ],
        subject: 'Backup Data Toko Seragam - $dateStr',
      );

      // Simpan timestamp backup terakhir
      await Hive.box(AppConstants.settingsBox)
          .put(AppConstants.lastBackupKey, now.toIso8601String());

      if (mounted) {
        showSuccessSnackBar(context, 'Backup berhasil — 3 file CSV dikirim');
        setState(() {}); // refresh tampilan tanggal backup
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Gagal backup: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ── CSV Import (Restore) ──────────────────────────────────────

  /// Tampilkan dialog pilih jenis import
  void _showImportDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
        ),
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Import dari CSV',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.neutral900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pilih jenis data yang ingin diimpor',
              style: TextStyle(fontSize: 13, color: AppTheme.neutral400),
            ),
            const SizedBox(height: 20),
            _ImportOption(
              icon: Icons.swap_horiz_rounded,
              label: 'Restore Lengkap',
              subtitle: 'Import produk, varian & transaksi sekaligus',
              color: AppTheme.primary,
              onTap: () {
                Navigator.pop(sheetCtx);
                _importFull();
              },
            ),
            const SizedBox(height: 10),
            _ImportOption(
              icon: Icons.receipt_long_rounded,
              label: 'Import Transaksi',
              subtitle: 'Hanya file transaksi_xxx.csv',
              color: AppTheme.success,
              onTap: () {
                Navigator.pop(sheetCtx);
                _importTransactions();
              },
            ),
            const SizedBox(height: 10),
            _ImportOption(
              icon: Icons.inventory_2_rounded,
              label: 'Import Produk & Varian',
              subtitle: 'File produk_xxx.csv dan varian_xxx.csv',
              color: AppTheme.accent,
              onTap: () {
                Navigator.pop(sheetCtx);
                _importProductsAndVariants();
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                    color: AppTheme.warning.withValues(alpha: 0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppTheme.warning, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Data yang sudah ada tidak akan tertimpa. Data duplikat otomatis dilewati.',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.neutral600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Restore lengkap: produk + varian + transaksi (3 file)
  Future<void> _importFull() async {
    setState(() => _isImporting = true);
    int prodCount = 0, varCount = 0, txCount = 0;

    try {
      // Produk
      final prodResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        dialogTitle: 'Pilih File Produk (produk_xxx.csv)',
      );
      if (prodResult?.files.single.path != null) {
        prodCount = await _processProdukCsv(prodResult!.files.single.path!);
      }

      // Varian
      final varResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        dialogTitle: 'Pilih File Varian (varian_xxx.csv)',
      );
      if (varResult?.files.single.path != null) {
        varCount = await _processVarianCsv(varResult!.files.single.path!);
      }

      // Transaksi
      final txResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        dialogTitle: 'Pilih File Transaksi (transaksi_xxx.csv)',
      );
      if (txResult?.files.single.path != null) {
        txCount = await _processTransaksiCsv(txResult!.files.single.path!);
      }

      _refreshAllProviders();

      if (mounted) {
        _showImportResultDialog(
          prodCount: prodCount,
          varCount: varCount,
          txCount: txCount,
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Gagal restore: $e');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  /// Import hanya transaksi
  Future<void> _importTransactions() async {
    setState(() => _isImporting = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        dialogTitle: 'Pilih File Transaksi CSV',
      );
      if (result?.files.single.path == null) return;

      final count = await _processTransaksiCsv(result!.files.single.path!);
      _refreshAllProviders();

      if (mounted) {
        showSuccessSnackBar(
          context,
          '$count transaksi berhasil diimpor',
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Gagal import: $e');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  /// Import produk & varian
  Future<void> _importProductsAndVariants() async {
    setState(() => _isImporting = true);
    int prodCount = 0, varCount = 0;

    try {
      final prodResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        dialogTitle: 'Pilih File Produk (produk_xxx.csv)',
      );
      if (prodResult?.files.single.path != null) {
        prodCount = await _processProdukCsv(prodResult!.files.single.path!);
      }

      final varResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        dialogTitle: 'Pilih File Varian (varian_xxx.csv)',
      );
      if (varResult?.files.single.path != null) {
        varCount = await _processVarianCsv(varResult!.files.single.path!);
      }

      _refreshAllProviders();

      if (mounted) {
        showSuccessSnackBar(
          context,
          '$prodCount produk & $varCount varian berhasil diimpor',
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Gagal import: $e');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  // ── CSV Processors ────────────────────────────────────────────

  Future<int> _processProdukCsv(String path) async {
    final content = await File(path).readAsString();
    final rows = const CsvToListConverter().convert(content, eol: '\n');
    if (rows.length < 2) return 0;

    final repo = ref.read(productRepositoryProvider);
    int count = 0;
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 3) continue;
      try {
        final ok = await repo.restoreProduct(
          id: row[AppConstants.csvProdId].toString().trim(),
          name: row[AppConstants.csvProdName].toString().trim(),
          category: row[AppConstants.csvProdCategory].toString().trim(),
        );
        if (ok) count++;
      } catch (_) {
        // skip baris tidak valid
      }
    }
    return count;
  }

  Future<int> _processVarianCsv(String path) async {
    final content = await File(path).readAsString();
    final rows = const CsvToListConverter().convert(content, eol: '\n');
    if (rows.length < 2) return 0;

    final repo = ref.read(productRepositoryProvider);
    int count = 0;
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 5) continue;
      try {
        final ok = await repo.restoreVariant(
          id: row[AppConstants.csvVarId].toString().trim(),
          productId: row[AppConstants.csvVarProductId].toString().trim(),
          size: row[AppConstants.csvVarSize].toString().trim(),
          costPrice: double.tryParse(
                  row[AppConstants.csvVarCostPrice].toString()) ??
              0,
          stock: int.tryParse(
                  row[AppConstants.csvVarStock].toString()) ??
              0,
        );
        if (ok) count++;
      } catch (_) {
        // skip baris tidak valid
      }
    }
    return count;
  }

  Future<int> _processTransaksiCsv(String path) async {
    final content = await File(path).readAsString();
    final rows = const CsvToListConverter().convert(content, eol: '\n');
    if (rows.length < 2) return 0;

    final repo = ref.read(transactionRepositoryProvider);
    int count = 0;
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < AppConstants.csvTxMinColumns) continue;
      try {
        final dateStr = row.length > AppConstants.csvTxDate
            ? row[AppConstants.csvTxDate].toString().trim()
            : '';
        final date = dateStr.isNotEmpty
            ? DateTime.tryParse(dateStr) ?? DateTime.now()
            : DateTime.now();

        final ok = await repo.restoreTransaction(
          id: row[AppConstants.csvTxId].toString().trim(),
          variantId: row[AppConstants.csvTxVariantId].toString().trim(),
          productId: row[AppConstants.csvTxProductId].toString().trim(),
          productName: row[AppConstants.csvTxProductName].toString().trim(),
          category: row[AppConstants.csvTxCategory].toString().trim(),
          size: row[AppConstants.csvTxSize].toString().trim(),
          sellPrice: double.tryParse(
                  row[AppConstants.csvTxSellPrice].toString()) ??
              0,
          costPrice: double.tryParse(
                  row[AppConstants.csvTxCostPrice].toString()) ??
              0,
          quantity: int.tryParse(
                  row[AppConstants.csvTxQuantity].toString()) ??
              1,
          date: date,
        );
        if (ok) count++;
      } catch (_) {
        // skip baris tidak valid
      }
    }
    return count;
  }

  void _refreshAllProviders() {
    ref.read(transactionsProvider.notifier).load();
    ref.read(productsProvider.notifier).load();
    ref.read(variantsProvider.notifier).load();
  }

  void _showImportResultDialog({
    required int prodCount,
    required int varCount,
    required int txCount,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded,
                color: AppTheme.success, size: 22),
            SizedBox(width: 8),
            Text('Restore Selesai'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ResultRow(
              icon: Icons.inventory_2_rounded,
              label: 'Produk',
              count: prodCount,
              color: AppTheme.accent,
            ),
            _ResultRow(
              icon: Icons.format_size_rounded,
              label: 'Varian',
              count: varCount,
              color: AppTheme.info,
            ),
            _ResultRow(
              icon: Icons.receipt_long_rounded,
              label: 'Transaksi',
              count: txCount,
              color: AppTheme.success,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.neutral50,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: const Text(
                'Data duplikat otomatis dilewati. Stok tidak diubah secara otomatis saat import transaksi.',
                style: TextStyle(
                    fontSize: 11, color: AppTheme.neutral500),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final shopName = ref.watch(shopNameProvider);
    final categories = ref.watch(categoriesProvider);
    final sizes = ref.watch(sizesProvider);

    // Cek tanggal backup terakhir
    final lastBackupRaw = Hive.box(AppConstants.settingsBox)
        .get(AppConstants.lastBackupKey, defaultValue: null) as String?;
    final lastBackup = lastBackupRaw != null
        ? DateTime.tryParse(lastBackupRaw)
        : null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          // ── Toko ─────────────────────────────────────────────
          _SectionCard(
            title: 'Informasi Toko',
            icon: Icons.store_rounded,
            iconColor: AppTheme.primary,
            children: [
              ListTile(
                title: const Text(
                  'Nama Toko',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  shopName,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppTheme.neutral400,
                ),
                onTap: _showShopNameDialog,
              ),
            ],
          ),

          // ── Kategori ─────────────────────────────────────────
          _SectionCard(
            title: 'Kategori Produk',
            icon: Icons.category_rounded,
            iconColor: AppTheme.success,
            action: TextButton.icon(
              onPressed: _showAddCategoryDialog,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Tambah'),
            ),
            children: [
              if (categories.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(AppTheme.spacingMd),
                  child: Center(
                    child: Text(
                      'Belum ada kategori',
                      style: TextStyle(
                          color: AppTheme.neutral400, fontSize: 13),
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.map((cat) {
                    return GestureDetector(
                      onLongPress: () =>
                          _showAddCategoryDialog(existing: cat),
                      child: Chip(
                        label: Text(cat),
                        backgroundColor:
                            AppTheme.success.withValues(alpha: 0.1),
                        labelStyle: const TextStyle(
                          color: AppTheme.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        deleteIcon:
                            const Icon(Icons.close_rounded, size: 14),
                        deleteIconColor: AppTheme.neutral400,
                        onDeleted: () async {
                          final confirm = await showDeleteConfirmDialog(
                            context,
                            title: 'Hapus Kategori',
                            content: 'Hapus kategori "$cat"?',
                          );
                          if (confirm == true) {
                            await ref
                                .read(categoriesProvider.notifier)
                                .deleteCategory(cat);
                            if (mounted) {
                              showSuccessSnackBar(
                                  context, 'Kategori dihapus');
                            }
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              Padding(
                padding: const EdgeInsets.only(
                    left: 16, right: 16, bottom: 8, top: 4),
                child: Text(
                  'Tips: tahan lama chip untuk edit nama kategori',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.neutral400,
                      fontStyle: FontStyle.italic),
                ),
              ),
            ],
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          ),

          // ── Ukuran ───────────────────────────────────────────
          _SectionCard(
            title: 'Ukuran / Nomor',
            icon: Icons.format_size_rounded,
            iconColor: AppTheme.accent,
            action: TextButton.icon(
              onPressed: _showAddSizeDialog,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Tambah'),
            ),
            children: [
              if (sizes.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(AppTheme.spacingMd),
                  child: Center(
                    child: Text(
                      'Belum ada ukuran',
                      style: TextStyle(
                          color: AppTheme.neutral400, fontSize: 13),
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: sizes.map((size) {
                    return GestureDetector(
                      onLongPress: () =>
                          _showAddSizeDialog(existing: size),
                      child: Chip(
                        label: Text(size),
                        backgroundColor:
                            AppTheme.accent.withValues(alpha: 0.1),
                        labelStyle: const TextStyle(
                          color: AppTheme.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        deleteIcon:
                            const Icon(Icons.close_rounded, size: 14),
                        deleteIconColor: AppTheme.neutral400,
                        onDeleted: () async {
                          final confirm = await showDeleteConfirmDialog(
                            context,
                            title: 'Hapus Ukuran',
                            content: 'Hapus ukuran "$size"?',
                          );
                          if (confirm == true) {
                            await ref
                                .read(sizesProvider.notifier)
                                .deleteSize(size);
                            if (mounted) {
                              showSuccessSnackBar(
                                  context, 'Ukuran dihapus');
                            }
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              Padding(
                padding: const EdgeInsets.only(
                    left: 16, right: 16, bottom: 8, top: 4),
                child: Text(
                  'Tips: tahan lama chip untuk edit ukuran',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.neutral400,
                      fontStyle: FontStyle.italic),
                ),
              ),
            ],
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          ),

          // ── Backup & Restore ──────────────────────────────────
          _SectionCard(
            title: 'Backup & Restore',
            icon: Icons.backup_rounded,
            iconColor: AppTheme.info,
            children: [
              // Info backup terakhir
              if (lastBackup != null)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                          color: AppTheme.success.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: AppTheme.success, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Backup terakhir: ${DateFormatter.relative(lastBackup)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.success,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Export
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.info.withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: const Icon(
                    Icons.cloud_upload_rounded,
                    color: AppTheme.info,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Backup ke CSV',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Export semua data: produk, varian & transaksi (3 file)',
                  style:
                      TextStyle(fontSize: 12, color: AppTheme.neutral400),
                ),
                trailing: _isExporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusFull),
                        ),
                        child: const Text(
                          'Export',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.info),
                        ),
                      ),
                onTap: _isExporting ? null : _exportData,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),

              // Import
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: const Icon(
                    Icons.cloud_download_rounded,
                    color: AppTheme.success,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Restore dari CSV',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Import data dari file backup. Duplikat dilewati otomatis.',
                  style:
                      TextStyle(fontSize: 12, color: AppTheme.neutral400),
                ),
                trailing: _isImporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color:
                              AppTheme.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusFull),
                        ),
                        child: const Text(
                          'Import',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.success),
                        ),
                      ),
                onTap: _isImporting ? null : _showImportDialog,
              ),

              // Panduan
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.neutral50,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.neutral200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lightbulb_outline_rounded,
                              size: 14, color: AppTheme.warning),
                          SizedBox(width: 6),
                          Text(
                            'Panduan Backup',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.neutral700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _GuideStep(
                          step: '1',
                          text:
                              'Tap "Backup" untuk mengunduh 3 file CSV'),
                      _GuideStep(
                          step: '2',
                          text:
                              'Simpan file di Google Drive / WhatsApp'),
                      _GuideStep(
                          step: '3',
                          text:
                              'Di HP baru, tap "Restore" dan pilih file yang sama'),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── About ─────────────────────────────────────────────
          _SectionCard(
            title: 'Tentang Aplikasi',
            icon: Icons.info_outline_rounded,
            iconColor: AppTheme.neutral400,
            children: [
              const ListTile(
                title: Text(
                  'Versi Aplikasi',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                trailing: Text(
                  '1.0.0',
                  style: TextStyle(
                      color: AppTheme.neutral400, fontSize: 13),
                ),
              ),
              const ListTile(
                title: Text(
                  'Teknologi',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                trailing: Text(
                  'Flutter + Hive + Riverpod',
                  style: TextStyle(
                      color: AppTheme.neutral400, fontSize: 12),
                ),
              ),
              const ListTile(
                title: Text(
                  'Pembuat',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                trailing: Text(
                  'Mustofa Hub 081359088246',
                  style: TextStyle(
                      color: AppTheme.neutral400, fontSize: 12),
                ),
              ),
            ],
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// ── Helper Widgets ───────────────────────────────────────────────────────────

class _GuideStep extends StatelessWidget {
  final String step;
  final String text;
  const _GuideStep({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.neutral500),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ImportOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.neutral400),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: color.withValues(alpha: 0.5), size: 18),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _ResultRow({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.neutral600),
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: Text(
              '$count data',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;
  final Widget? action;
  final EdgeInsetsGeometry? padding;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
    this.action,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        AppTheme.spacingMd,
        AppTheme.spacingMd,
        0,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(icon, color: iconColor, size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.neutral800,
                  ),
                ),
                const Spacer(),
                if (action != null) action!,
              ],
            ),
          ),
          const Divider(height: 1),
          if (padding != null)
            Padding(
              padding: padding!,
              child: Column(children: children),
            )
          else
            Column(children: children),
        ],
      ),
    );
  }
}
