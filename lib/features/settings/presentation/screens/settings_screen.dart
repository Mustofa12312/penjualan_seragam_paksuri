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
                await ref.read(categoriesProvider.notifier).addCategory(text);
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
              await ref.read(sizesProvider.notifier).addSize(text);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                showSuccessSnackBar(context, 'Ukuran ditambahkan');
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

  // ── CSV Export ────────────────────────────────────────────────

  Future<void> _exportData() async {
    setState(() => _isExporting = true);
    try {
      final productBox = Hive.box<ProductModel>(AppConstants.productBox);
      final variantBox = Hive.box<VariantModel>(AppConstants.variantBox);
      final transactionBox = Hive.box<TransactionModel>(
        AppConstants.transactionBox,
      );

      // Build CSV for transactions (most useful export)
      final rows = <List<dynamic>>[AppConstants.transactionCsvHeaders];
      for (final t in transactionBox.values) {
        rows.add([
          t.id,
          t.variantId,
          t.productName,
          t.size,
          t.sellPrice,
          t.costPrice,
          t.profit,
          DateFormatter.full(t.date),
        ]);
      }

      // Also export products + variants
      final productRows = <List<dynamic>>[AppConstants.productCsvHeaders];
      for (final p in productBox.values) {
        productRows.add([p.id, p.name, p.category]);
      }

      final variantRows = <List<dynamic>>[AppConstants.variantCsvHeaders];
      for (final v in variantBox.values) {
        variantRows.add([v.id, v.productId, v.size, v.costPrice, v.stock]);
      }

      // Write to temp files
      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final dateStr =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

      final transFile = File('${dir.path}/transaksi_$dateStr.csv');
      await transFile.writeAsString(const ListToCsvConverter().convert(rows));

      final prodFile = File('${dir.path}/produk_$dateStr.csv');
      await prodFile.writeAsString(
        const ListToCsvConverter().convert(productRows),
      );

      final varFile = File('${dir.path}/varian_$dateStr.csv');
      await varFile.writeAsString(
        const ListToCsvConverter().convert(variantRows),
      );

      // Share all files
      await Share.shareXFiles([
        XFile(transFile.path, mimeType: 'text/csv'),
        XFile(prodFile.path, mimeType: 'text/csv'),
        XFile(varFile.path, mimeType: 'text/csv'),
      ], subject: 'Backup Data Toko Seragam - $dateStr');

      if (mounted) showSuccessSnackBar(context, 'Data berhasil diekspor');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Gagal ekspor: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importTransactions() async {
    setState(() => _isImporting = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        dialogTitle: 'Pilih File Transaksi CSV',
      );

      if (result == null || result.files.single.path == null) {
        if (mounted) setState(() => _isImporting = false);
        return;
      }

      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final rows = const CsvToListConverter().convert(content, eol: '\n');

      if (rows.isEmpty) {
        if (mounted) showErrorSnackBar(context, 'File CSV kosong');
        return;
      }

      // Skip header row
      int imported = 0;
      final transactionRepo = ref.read(transactionRepositoryProvider);
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 8) continue;
        try {
          await transactionRepo.addTransaction(
            variantId: row[1].toString(),
            productId: '',
            productName: row[2].toString(),
            size: row[3].toString(),
            sellPrice: double.tryParse(row[4].toString()) ?? 0,
            costPrice: double.tryParse(row[5].toString()) ?? 0,
            category: '',
          );
          imported++;
        } catch (e) {
          // Skip invalid rows
        }
      }

      ref.read(transactionsProvider.notifier).load();
      if (mounted) {
        showSuccessSnackBar(context, '$imported transaksi berhasil diimpor');
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Gagal impor: $e');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final shopName = ref.watch(shopNameProvider);
    final categories = ref.watch(categoriesProvider);
    final sizes = ref.watch(sizesProvider);

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
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
                        color: AppTheme.neutral400,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.map((cat) {
                    return Chip(
                      label: Text(cat),
                      backgroundColor: AppTheme.success.withValues(alpha: 0.1),
                      labelStyle: const TextStyle(
                        color: AppTheme.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      deleteIcon: const Icon(Icons.close_rounded, size: 14),
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
                            showSuccessSnackBar(context, 'Kategori dihapus');
                          }
                        }
                      },
                    );
                  }).toList(),
                ),
            ],
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                        color: AppTheme.neutral400,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: sizes.map((size) {
                    return Chip(
                      label: Text(size),
                      backgroundColor: AppTheme.accent.withValues(alpha: 0.1),
                      labelStyle: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      deleteIcon: const Icon(Icons.close_rounded, size: 14),
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
                            showSuccessSnackBar(context, 'Ukuran dihapus');
                          }
                        }
                      },
                    );
                  }).toList(),
                ),
            ],
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),

          // ── Backup & Restore ──────────────────────────────────
          _SectionCard(
            title: 'Backup & Restore',
            icon: Icons.backup_rounded,
            iconColor: AppTheme.info,
            children: [
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: const Icon(
                    Icons.upload_rounded,
                    color: AppTheme.info,
                    size: 18,
                  ),
                ),
                title: const Text(
                  'Export ke CSV',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Download data produk, varian & transaksi',
                  style: TextStyle(fontSize: 12, color: AppTheme.neutral400),
                ),
                trailing: _isExporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.neutral400,
                      ),
                onTap: _isExporting ? null : _exportData,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: const Icon(
                    Icons.download_rounded,
                    color: AppTheme.success,
                    size: 18,
                  ),
                ),
                title: const Text(
                  'Import dari CSV',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Impor data transaksi dari file CSV',
                  style: TextStyle(fontSize: 12, color: AppTheme.neutral400),
                ),
                trailing: _isImporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.neutral400,
                      ),
                onTap: _isImporting ? null : _importTransactions,
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
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                trailing: Text(
                  '1.0.0',
                  style: TextStyle(color: AppTheme.neutral400, fontSize: 13),
                ),
              ),
              const ListTile(
                title: Text(
                  'Teknologi',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                trailing: Text(
                  'Flutter + Hive + Riverpod',
                  style: TextStyle(color: AppTheme.neutral400, fontSize: 12),
                ),
              ),
              const ListTile(
                title: Text(
                  'Pembuat',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                trailing: Text(
                  'Mustofa Hub 081359088246',
                  style: TextStyle(color: AppTheme.neutral400, fontSize: 12),
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
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
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
