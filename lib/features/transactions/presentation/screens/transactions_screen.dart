import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/datasources/providers.dart';
import '../../../../data/models/transaction_model.dart';

/// Layar riwayat transaksi
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  DateTimeRange? _dateRange;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TransactionModel> _filter(List<TransactionModel> transactions) {
    return transactions.where((t) {
      final matchSearch = _searchQuery.isEmpty ||
          t.productName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.size.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchDate = _dateRange == null ||
          (t.date.isAfter(_dateRange!.start.subtract(const Duration(days: 1))) &&
              t.date.isBefore(_dateRange!.end.add(const Duration(days: 1))));
      return matchSearch && matchDate;
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (range != null) setState(() => _dateRange = range);
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider);
    final filtered = _filter(transactions);
    final totalRevenue = filtered.fold<double>(0, (s, t) => s + t.totalSell);
    final totalProfit = filtered.fold<double>(0, (s, t) => s + t.profit);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        actions: [
          IconButton(
            onPressed: _pickDateRange,
            icon: Icon(
              Icons.date_range_rounded,
              color:
                  _dateRange != null ? AppTheme.primary : AppTheme.neutral500,
            ),
            tooltip: 'Filter Tanggal',
          ),
          if (_dateRange != null)
            IconButton(
              onPressed: () => setState(() => _dateRange = null),
              icon: const Icon(Icons.clear_rounded),
              tooltip: 'Reset Filter',
            ),
        ],
      ),
      body: Column(
        children: [
          // Date filter info
          if (_dateRange != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt_rounded,
                      size: 14, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    '${DateFormatter.dateOnly(_dateRange!.start)} – ${DateFormatter.dateOnly(_dateRange!.end)}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

          // Search
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: AppSearchBar(
              controller: _searchController,
              hintText: 'Cari transaksi...',
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // Summary banner
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryChip(
                    label: '${filtered.length} transaksi',
                    value: CurrencyFormatter.compact(totalRevenue),
                    color: AppTheme.primary,
                    icon: Icons.receipt_long_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryChip(
                    label: 'Keuntungan',
                    value: CurrencyFormatter.compact(totalProfit),
                    color: AppTheme.success,
                    icon: Icons.trending_up_rounded,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Transaction list
          Expanded(
            child: filtered.isEmpty
                ? EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Tidak ada transaksi',
                    message: 'Coba ubah filter pencarian',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingMd),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final t = filtered[index];
                      return _TransactionCard(
                        transaction: t,
                        onDelete: () async {
                          final confirm = await showDeleteConfirmDialog(
                            context,
                            title: 'Hapus Transaksi',
                            content: 'Hapus transaksi ini?',
                          );
                          if (confirm == true) {
                            await ref
                                .read(transactionsProvider.notifier)
                                .deleteTransaction(t.id);
                            if (context.mounted) {
                              showSuccessSnackBar(context, 'Transaksi dihapus');
                            }
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback onDelete;

  const _TransactionCard({required this.transaction, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Icon(Icons.shopping_bag_rounded,
                    color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            transaction.productName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.neutral900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(transaction.totalSell),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.neutral900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.neutral100,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusFull),
                          ),
                          child: Text(
                            'Uk. ${transaction.size}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.neutral600,
                            ),
                          ),
                        ),
                        if (transaction.quantity > 1) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusFull),
                            ),
                            child: Text(
                              'x${transaction.quantity}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accent,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          '+${CurrencyFormatter.format(transaction.profit)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 12, color: AppTheme.neutral400),
                        const SizedBox(width: 4),
                        Text(
                          DateFormatter.full(transaction.date),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.neutral400,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: onDelete,
                          child: const Icon(Icons.delete_outline_rounded,
                              size: 16, color: AppTheme.error),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color,
                  )),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.neutral500)),
            ],
          ),
        ],
      ),
    );
  }
}
