import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static String format(
    double amount, {
    String currencyCode = 'USD',
    bool showSign = false,
    bool compact = false,
  }) {
    final currency = AppConstants.getCurrency(currencyCode);
    final absAmount = amount.abs();

    String formattedNumber;
    if (compact && absAmount >= 10000) {
      formattedNumber = NumberFormat.compact().format(absAmount);
    } else {
      formattedNumber = NumberFormat('#,##0.00').format(absAmount);
    }

    final sign = showSign
        ? (amount > 0.005 ? '+' : (amount < -0.005 ? '-' : ''))
        : (amount < -0.005 ? '-' : '');

    return '$sign${currency.symbol}$formattedNumber';
  }

  /// Converts an amount from one currency to another using their USD baselines or a custom rate.
  static double convert({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
    double? customExchangeRate,
  }) {
    if (fromCurrency.toUpperCase() == toCurrency.toUpperCase()) {
      return amount;
    }

    if (customExchangeRate != null && customExchangeRate > 0) {
      return amount * customExchangeRate;
    }

    final fromInfo = AppConstants.getCurrency(fromCurrency);
    final toInfo = AppConstants.getCurrency(toCurrency);

    // amount in USD = amount * fromInfo.defaultRateToUSD
    // amount in Target = amountInUSD / toInfo.defaultRateToUSD
    final amountInUSD = amount * fromInfo.defaultRateToUSD;
    return amountInUSD / toInfo.defaultRateToUSD;
  }
}
