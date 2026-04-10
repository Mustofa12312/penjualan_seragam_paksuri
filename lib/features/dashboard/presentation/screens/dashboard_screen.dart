import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/datasources/providers.dart';

/// Dashboard utama aplikasi
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopName = ref.watch(shopNameProvider);
    final period = ref.watch(dashboardPeriodProvider);
    final transactions = ref.watch(dashboardTransactionsProvider);
    final repo = ref.read(transactionRepositoryProvider);
    final allVariants = ref.watch(variantsProvider);

    final totalRevenue = repo.getTotalRevenue(transactions);
    final totalProfit = repo.getTotalProfit(transactions);
    final totalTransactions = transactions.length;
    final lowStockCount = allVariants.where((v) => v.isLowStock || v.isOutOfStock).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // ── Header ───────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.cardGradient,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selamat Datang! 👋',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  shopName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () => context.push('/settings'),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                ),
                                child: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingMd),
                        Text(
                          DateFormatter.full(DateTime.now()),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Period Selector ───────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: DashboardPeriod.values.map((p) {
                  final isSelected = period == p;
                  final labels = {
                    DashboardPeriod.today: 'Hari Ini',
                    DashboardPeriod.week: 'Minggu',
                    DashboardPeriod.month: 'Bulan',
                    DashboardPeriod.all: 'Semua',
                  };
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => ref.read(dashboardPeriodProvider.notifier).state = p,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary : AppTheme.surface,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          boxShadow: isSelected ? AppTheme.elevatedShadow : AppTheme.cardShadow,
                        ),
                        child: Text(
                          labels[p]!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : AppTheme.neutral500,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Stats Grid ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  StatCard(
                    label: 'Total Penjualan',
                    value: CurrencyFormatter.compact(totalRevenue),
                    icon: Icons.trending_up_rounded,
                    color: AppTheme.primary,
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),
                  StatCard(
                    label: 'Total Keuntungan',
                    value: CurrencyFormatter.compact(totalProfit),
                    icon: Icons.monetization_on_rounded,
                    color: AppTheme.success,
                  ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.2),
                  StatCard(
                    label: 'Transaksi',
                    value: '$totalTransactions',
                    icon: Icons.receipt_long_rounded,
                    color: AppTheme.accent,
                    onTap: () => context.go('/transactions'),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                  StatCard(
                    label: 'Stok Menipis',
                    value: '$lowStockCount',
                    icon: Icons.warning_amber_rounded,
                    color: AppTheme.warning,
                    onTap: () => context.go('/stock'),
                  ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.2),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Quick Actions ─────────────────────────────────────
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Aksi Cepat',
              action: null,
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
              child: Row(
                children: [
                  _QuickAction(
                    icon: Icons.add_shopping_cart_rounded,
                    label: 'Jual Sekarang',
                    color: AppTheme.primary,
                    onTap: () => context.push('/transaction/new'),
                  ),
                  const SizedBox(width: 12),
                  _QuickAction(
                    icon: Icons.add_box_rounded,
                    label: 'Tambah Produk',
                    color: AppTheme.success,
                    onTap: () => context.push('/products/add'),
                  ),
                  const SizedBox(width: 12),
                  _QuickAction(
                    icon: Icons.bar_chart_rounded,
                    label: 'Lihat Laporan',
                    color: AppTheme.accent,
                    onTap: () => context.go('/reports'),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Recent Transactions ───────────────────────────────
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Transaksi Terbaru',
              action: TextButton(
                onPressed: () => context.go('/transactions'),
                child: const Text('Lihat Semua'),
              ),
            ),
          ),

          if (transactions.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Belum ada transaksi',
                message: 'Mulai jual sekarang!',
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final t = transactions.take(5).toList()[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingMd,
                      vertical: 4,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(AppTheme.spacingMd),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            ),
                            child: const Icon(Icons.shopping_bag_rounded,
                                color: AppTheme.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${t.productName} - ${t.size}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.neutral800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  DateFormatter.relative(t.date),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.neutral400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                CurrencyFormatter.format(t.totalSell),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.neutral900,
                                ),
                              ),
                              Text(
                                '+${CurrencyFormatter.compact(t.profit)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.success,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: transactions.take(5).length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
