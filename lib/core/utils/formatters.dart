import 'package:intl/intl.dart';

/// Utility functions for currency formatting
class CurrencyFormatter {
  CurrencyFormatter._();

  static final _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static String format(num amount) => _formatter.format(amount);

  static String compact(num amount) {
    if (amount >= 1000000) {
      return 'Rp ${(amount / 1000000).toStringAsFixed(1)}jt';
    } else if (amount >= 1000) {
      return 'Rp ${(amount / 1000).toStringAsFixed(0)}rb';
    }
    return format(amount);
  }

  static num? parse(String text) {
    final cleaned = text
        .replaceAll('Rp', '')
        .replaceAll('.', '')
        .replaceAll(',', '')
        .trim();
    return num.tryParse(cleaned);
  }
}

/// Utility functions for date formatting
class DateFormatter {
  DateFormatter._();

  static final _fullFormatter = DateFormat('dd MMMM yyyy, HH:mm', 'id_ID');
  static final _shortFormatter = DateFormat('dd MMM yyyy', 'id_ID');
  static final _dateOnlyFormatter = DateFormat('dd/MM/yyyy', 'id_ID');
  static final _timeFormatter = DateFormat('HH:mm', 'id_ID');

  static String full(DateTime date) => _fullFormatter.format(date);
  static String short(DateTime date) => _shortFormatter.format(date);
  static String dateOnly(DateTime date) => _dateOnlyFormatter.format(date);
  static String time(DateTime date) => _timeFormatter.format(date);

  static String relative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      if (diff.inHours == 0) return '${diff.inMinutes} menit lalu';
      return '${diff.inHours} jam lalu';
    } else if (diff.inDays == 1) {
      return 'Kemarin';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} hari lalu';
    }
    return short(date);
  }
}
