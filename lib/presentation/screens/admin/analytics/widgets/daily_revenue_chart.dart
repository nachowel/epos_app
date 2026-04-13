import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../domain/models/analytics/daily_revenue_point.dart';

const Key dailyRevenueChartKey = Key('daily-revenue-chart');

class DailyRevenueChart extends StatelessWidget {
  const DailyRevenueChart({
    required this.points,
    super.key,
  });

  final List<DailyRevenuePoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox.shrink();
    }

    final int maxRevenueMinor = points.fold<int>(
      0,
      (int current, DailyRevenuePoint point) =>
          math.max(current, point.revenueMinor),
    );
    final DateFormat formatter = DateFormat(
      points.length > 14 ? 'd MMM' : 'EEE d',
    );

    return Container(
      key: dailyRevenueChartKey,
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double contentWidth = math.max(
            constraints.maxWidth,
            points.length * 40,
          ).toDouble();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Daily Revenue Trend',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSizes.spacingXs),
              const Text(
                'Paid revenue by day for the active preset.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSizes.spacingLg),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: contentWidth,
                  height: 240,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: points
                        .map(
                          (DailyRevenuePoint point) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: <Widget>[
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        width: double.infinity,
                                        height: maxRevenueMinor == 0
                                            ? 12
                                            : math.max(
                                                12,
                                                ((point.revenueMinor /
                                                            maxRevenueMinor) *
                                                        176)
                                                    .round(),
                                              ).toDouble(),
                                        decoration: BoxDecoration(
                                          color: point.revenueMinor > 0
                                              ? AppColors.primary
                                              : AppColors.primaryLight,
                                          borderRadius: BorderRadius.circular(
                                            AppSizes.radiusSm,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSizes.spacingSm),
                                  Text(
                                    formatter.format(point.date),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
