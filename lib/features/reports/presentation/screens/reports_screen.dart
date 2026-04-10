import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/datasources/providers.dart';
import '../../../../data/models/transaction_model.dart';

/// Layar laporan & analisis penjualan
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allTransactions = ref.watch(transactionsProvider);
    final period = ref.watch(dashboardPeriodProvider);
    final transactions = ref.watch(dashboardTransactionsProvider);
    final transactionRepo = ref.read(transactionRepositoryProvider);
    // Gunakan dailyRevenueProvider yang reaktif (otomatis update saat transaksi baru)
    final dailyData = ref.watch(dailyRevenueProvider);
    final chartDays = ref.watch(chartDaysProvider);

    final totalRevenue = transactionRepo.getTotalRevenue(transactions);
    final totalProfit = transactionRepo.getTotalProfit(transactions);
    final productSales = transactionRepo.getProductSalesCount(transactions);
    final categoryRevenue = transactionRepo.getCategoryRevenue(transactions);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Laporan & Analisis'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Ringkasan'),
            Tab(text: 'Grafik'),
            Tab(text: 'Produk'),
          ],
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.neutral400,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SummaryTab(
            transactions: transactions,
            totalRevenue: totalRevenue,
            totalProfit: totalProfit,
            period: period,
            allCount: allTransactions.length,
          ),
          _ChartTab(
            dailyData: dailyData,
            chartDays: chartDays,
            onDaysChanged: (days) =>
                ref.read(chartDaysProvider.notifier).state = days,
            categoryRevenue: categoryRevenue,
          ),
          _ProductsTab(
            productSales: productSales,
            transactions: transactions,
          ),
        ],
      ),
    );
  }
}

class _SummaryTab extends ConsumerWidget {
  final List<TransactionModel> transactions;
  final double totalRevenue;
  final double totalProfit;
  final DashboardPeriod period;
  final int allCount;

  const _SummaryTab({
    required this.transactions,
    required this.totalRevenue,
    required this.totalProfit,
    required this.period,
    required this.allCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profitMargin =
        totalRevenue > 0 ? (totalProfit / totalRevenue * 100) : 0;
    final avgTransaction =
        transactions.isEmpty ? 0 : totalRevenue / transactions.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        children: [
          // Period selector
          Row(
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
                  onTap: () =>
                      ref.read(dashboardPeriodProvider.notifier).state = p,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary : AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Text(
                      labels[p]!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppTheme.neutral500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Main stats
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              StatCard(
                label: 'Total Penjualan',
                value: CurrencyFormatter.compact(totalRevenue),
                icon: Icons.attach_money_rounded,
                color: AppTheme.primary,
              ),
              StatCard(
                label: 'Total Keuntungan',
                value: CurrencyFormatter.compact(totalProfit),
                icon: Icons.trending_up_rounded,
                color: AppTheme.success,
              ),
              StatCard(
                label: 'Margin Keuntungan',
                value: '${profitMargin.toStringAsFixed(1)}%',
                icon: Icons.pie_chart_rounded,
                color: AppTheme.accent,
              ),
              StatCard(
                label: 'Rata-rata/Transaksi',
                value: CurrencyFormatter.compact(avgTransaction),
                icon: Icons.receipt_rounded,
                color: AppTheme.info,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Additional stats
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Detail Periode',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.neutral800)),
                const SizedBox(height: 12),
                _DetailRow(
                  label: 'Jumlah Transaksi',
                  value: '${transactions.length}',
                  icon: Icons.receipt_long_rounded,
                  iconColor: AppTheme.primary,
                ),
                const Divider(height: 16),
                _DetailRow(
                  label: 'Total Item Terjual',
                  value: '${transactions.fold<int>(0, (s, t) => s + t.quantity)} pcs',
                  icon: Icons.shopping_bag_rounded,
                  iconColor: AppTheme.accent,
                ),
                const Divider(height: 16),
                _DetailRow(
                  label: 'Total Data Transaksi',
                  value: '$allCount transaksi',
                  icon: Icons.history_rounded,
                  iconColor: AppTheme.neutral400,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 13, color: AppTheme.neutral600)),
        ),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.neutral800)),
      ],
    );
  }
}

class _ChartTab extends StatelessWidget {
  final Map<DateTime, double> dailyData;
  final int chartDays;
  final ValueChanged<int> onDaysChanged;
  final Map<String, double> categoryRevenue;

  const _ChartTab({
    required this.dailyData,
    required this.chartDays,
    required this.onDaysChanged,
    required this.categoryRevenue,
  });

  @override
  Widget build(BuildContext context) {
    final spots = dailyData.entries.map((e) {
      final index = dailyData.keys.toList().indexOf(e.key);
      return FlSpot(index.toDouble(), e.value);
    }).toList();

    final maxY = dailyData.values.isNotEmpty
        ? dailyData.values.reduce((a, b) => a > b ? a : b)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Days filter
          Row(
            children: [7, 14, 30].map((days) {
              final selected = chartDays == days;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onDaysChanged(days),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.primary : AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Text(
                      '$days Hari',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : AppTheme.neutral500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          const Text('Tren Penjualan',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.neutral800)),
          const SizedBox(height: 12),

          // Line chart
          Container(
            height: 220,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              boxShadow: AppTheme.cardShadow,
            ),
            child: spots.isEmpty || maxY == 0
                ? const Center(
                    child: Text('Belum ada data',
                        style: TextStyle(color: AppTheme.neutral400)))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (val) => FlLine(
                          color: AppTheme.neutral100,
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: (chartDays / 6).ceilToDouble(),
                            getTitlesWidget: (value, _) {
                              final index = value.toInt();
                              if (index < 0 || index >= dailyData.length) {
                                return const SizedBox();
                              }
                              final date = dailyData.keys.toList()[index];
                              return Text(
                                '${date.day}/${date.month}',
                                style: const TextStyle(
                                    fontSize: 9, color: AppTheme.neutral400),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, _) => Text(
                              CurrencyFormatter.compact(val),
                              style: const TextStyle(
                                  fontSize: 8, color: AppTheme.neutral400),
                            ),
                            reservedSize: 50,
                          ),
                        ),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: AppTheme.primary,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primary.withValues(alpha: 0.3),
                                AppTheme.primary.withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                      minY: 0,
                      maxY: maxY * 1.2,
                    ),
                  ),
          ),

          const SizedBox(height: 20),

          // Category pie chart
          if (categoryRevenue.isNotEmpty) ...[
            const Text('Penjualan per Kategori',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.neutral800)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 180,
                    child: PieChart(
                      PieChartData(
                        sections: _buildPieSections(categoryRevenue),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: categoryRevenue.entries
                        .toList()
                        .asMap()
                        .entries
                        .map((e) {
                      final color = _chartColors[e.key % _chartColors.length];
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 4),
                          Text(e.value.key,
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.neutral600)),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static const _chartColors = [
    AppTheme.primary,
    AppTheme.success,
    AppTheme.accent,
    AppTheme.warning,
    AppTheme.info,
    AppTheme.error,
  ];

  List<PieChartSectionData> _buildPieSections(Map<String, double> data) {
    final total = data.values.fold(0.0, (a, b) => a + b);
    final entries = data.entries.toList();
    return entries.asMap().entries.map((e) {
      final index = e.key;
      final entry = e.value;
      final pct = total > 0 ? (entry.value / total * 100) : 0;
      return PieChartSectionData(
        value: entry.value,
        color: _chartColors[index % _chartColors.length],
        title: '${pct.toStringAsFixed(0)}%',
        radius: 55,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      );
    }).toList();
  }
}

class _ProductsTab extends StatelessWidget {
  final Map<String, int> productSales;
  final List<TransactionModel> transactions;

  const _ProductsTab({
    required this.productSales,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    if (productSales.isEmpty) {
      return const EmptyState(
        icon: Icons.bar_chart_outlined,
        title: 'Belum ada data',
        message: 'Mulai transaksi untuk melihat analisis produk',
      );
    }

    final sorted = productSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxVal = sorted.first.value.toDouble();

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      children: [
        const Text('Produk Paling Laku',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.neutral800)),
        const SizedBox(height: 12),
        ...sorted.asMap().entries.map((e) {
          final index = e.key;
          final name = e.value.key;
          final qty = e.value.value;
          final pct = maxVal > 0 ? qty / maxVal : 0;

          final revenue = transactions
              .where((t) => t.productName == name)
              .fold<double>(0, (sum, t) => sum + t.totalSell);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: index < 3
                              ? [
                                  const Color(0xFFFFD700),
                                  const Color(0xFFC0C0C0),
                                  const Color(0xFFCD7F32),
                                ][index]
                              : AppTheme.neutral100,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '#${index + 1}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color:
                                  index < 3 ? Colors.white : AppTheme.neutral500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.neutral900,
                          ),
                        ),
                      ),
                      Text(
                        '$qty pcs',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    child: LinearProgressIndicator(
                      value: pct.toDouble(),
                      backgroundColor: AppTheme.neutral100,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        index == 0
                            ? AppTheme.primary
                            : index == 1
                                ? AppTheme.success
                                : AppTheme.accent,
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Revenue: ${CurrencyFormatter.format(revenue)}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.neutral400),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
