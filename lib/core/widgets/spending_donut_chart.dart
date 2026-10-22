import 'dart:math';
import 'package:flutter/material.dart';
import '../../features/expenses/models/expense_category.dart';
import '../constants/app_colors.dart';
import '../utils/currency_formatter.dart';

class SpendingDonutChart extends StatelessWidget {
  final Map<ExpenseCategoryType, double> breakdown;
  final String currencyCode;

  const SpendingDonutChart({
    super.key,
    required this.breakdown,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final total = breakdown.values.fold(0.0, (sum, val) => sum + val);

    if (total <= 0.0) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Text(
          'No expense data to analyze yet',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    // Sort categories descending by spend
    final sortedEntries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart_outline, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Spending by Category',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                // Custom Donut Canvas
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(120, 120),
                        painter: _DonutChartPainter(
                          breakdown: breakdown,
                          total: total,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(total, currencyCode: currencyCode, compact: true),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Legend
                Expanded(
                  child: Column(
                    children: sortedEntries.take(4).map((entry) {
                      final category = ExpenseCategory.fromType(entry.key);
                      final percentage = (entry.value / total) * 100;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: category.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                category.label,
                                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${percentage.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final Map<ExpenseCategoryType, double> breakdown;
  final double total;

  _DonutChartPainter({
    required this.breakdown,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    const strokeWidth = 16.0;

    final rect = Rect.fromCircle(center: center, radius: radius - (strokeWidth / 2));

    double startAngle = -pi / 2;

    for (final entry in breakdown.entries) {
      if (entry.value <= 0) continue;
      final sweepAngle = (entry.value / total) * 2 * pi;
      final category = ExpenseCategory.fromType(entry.key);

      final paint = Paint()
        ..color = category.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.total != total || oldDelegate.breakdown != breakdown;
  }
}
