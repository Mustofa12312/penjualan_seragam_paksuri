// ignore: unused_import
import 'package:go_router/go_router.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/products/presentation/screens/products_screen.dart';
import '../features/products/presentation/screens/product_form_screen.dart';
import '../features/products/presentation/screens/product_detail_screen.dart';
import '../features/transactions/presentation/screens/new_transaction_screen.dart';
import '../features/transactions/presentation/screens/transactions_screen.dart';
import '../features/stock/presentation/screens/stock_screen.dart';
import '../features/reports/presentation/screens/reports_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import 'shell_screen.dart';

/// App router konfigurasi menggunakan go_router
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => ShellScreen(child: child),
      routes: [
        GoRoute(path: '/', builder: (ctx, state) => const DashboardScreen()),
        GoRoute(path: '/products', builder: (ctx, state) => const ProductsScreen()),
        GoRoute(path: '/transactions', builder: (ctx, state) => const TransactionsScreen()),
        GoRoute(path: '/stock', builder: (ctx, state) => const StockScreen()),
        GoRoute(path: '/reports', builder: (ctx, state) => const ReportsScreen()),
        GoRoute(path: '/settings', builder: (ctx, state) => const SettingsScreen()),
      ],
    ),
    // Full-screen routes (no bottom nav)
    GoRoute(
      path: '/products/add',
      builder: (ctx, state) => const ProductFormScreen(),
    ),
    GoRoute(
      path: '/products/edit/:id',
      builder: (ctx, state) {
        final id = state.pathParameters['id']!;
        return ProductFormScreen(productId: id);
      },
    ),
    GoRoute(
      path: '/products/:id',
      builder: (ctx, state) {
        final id = state.pathParameters['id']!;
        return ProductDetailScreen(productId: id);
      },
    ),
    GoRoute(
      path: '/transaction/new',
      builder: (ctx, state) => const NewTransactionScreen(),
    ),
  ],
);
