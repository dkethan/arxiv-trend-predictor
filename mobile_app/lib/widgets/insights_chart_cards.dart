import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/advisor_response.dart';
import '../theme.dart';

/// Web: .chart-wrap — 3 cards (confidence bar, growth bar, scatter) in Insights section.
/// Mobile: same card style, data shown as simple bars/text (no Chart.js).
const _chartCardPadding = 16.0;

/// Domain confidence bar chart card (web: chart-confidence).
class ChartConfidenceCard extends StatelessWidget {
  final AdvisorResponse result;

  const ChartConfidenceCard({
    super.key,
    required this.result,
  });

  String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    final primary = result.domain.isEmpty ? 'Primary' : result.domain;
    final labels = result.allDomains.isNotEmpty
        ? result.allDomains
        : [primary, ...result.alternateDomains.map((a) => a.name)];
    final values = labels
        .map((d) => result.domainConfidenceMap[d] ?? 0)
        .toList();

    return Container(
      padding: const EdgeInsets.all(_chartCardPadding),
      decoration: appCardDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confidence',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(labels.length, (i) {
            final isPrimary = i == 0;
            return Padding(
              padding: EdgeInsets.only(bottom: i == labels.length - 1 ? 0 : 8),
              child: SizedBox(
                height: 40,
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w400,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: values[i],
                          minHeight: 18,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isPrimary ? AppColors.accent : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _pct(values[i]),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Growth score gauge card (web: chart-growth).
class ChartGrowthCard extends StatelessWidget {
  final AdvisorResponse result;

  const ChartGrowthCard({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final value = result.domainGrowthScore;
    final pct = '${(value * 100).toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.all(_chartCardPadding),
      decoration: appCardDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Growth score',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 32,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            pct,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

/// Confidence vs growth scatter card (web: chart-scatter).
class ChartScatterCard extends StatelessWidget {
  final AdvisorResponse result;

  const ChartScatterCard({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final primary = result.domain.isEmpty ? 'Primary' : result.domain;
    final predicted = result.allDomains.isNotEmpty
        ? result.allDomains
        : [primary, ...result.alternateDomains.map((a) => a.name)];
    final predictedSet = predicted.toSet();
    final allDomains = result.domainConfidenceMap.keys.toList();

    final predictedSpots = <ScatterSpot>[];
    final otherSpots = <ScatterSpot>[];
    for (final domain in allDomains) {
      final confidence = (result.domainConfidenceMap[domain] ?? 0).clamp(0.0, 1.0).toDouble() * 100;
      final slope = (result.growthInfo[domain]?.slope ?? 0).clamp(0.0, 1.0).toDouble() * 100;
      final isPredicted = predictedSet.contains(domain);
      final spot = ScatterSpot(
        confidence,
        slope,
        dotPainter: FlDotCirclePainter(
          radius: isPredicted ? 10 : 7,
          color: isPredicted
              ? const Color(0xFF2ED8A8)
              : AppColors.textMuted.withValues(alpha: 0.5),
          strokeWidth: 0,
        ),
      );
      if (isPredicted) {
        predictedSpots.add(spot);
      } else {
        otherSpots.add(spot);
      }
    }

    return Container(
      padding: const EdgeInsets.all(_chartCardPadding),
      decoration: appCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confidence vs Growth',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _legendDot(const Color(0xFF2ED8A8), 9),
              const SizedBox(width: 6),
              Text(
                'Predicted',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 16),
              _legendDot(AppColors.textMuted.withValues(alpha: 0.5), 7),
              const SizedBox(width: 6),
              Text(
                'Other domains',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ScatterChart(
              ScatterChartData(
                minX: 0,
                maxX: 100,
                minY: 0,
                maxY: 100,
                scatterSpots: [...otherSpots, ...predictedSpots],
                scatterTouchData: ScatterTouchData(enabled: false),
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: true,
                  horizontalInterval: 20,
                  verticalInterval: 20,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withValues(alpha: 0.08),
                    strokeWidth: 1,
                  ),
                  getDrawingVerticalLine: (_) => FlLine(
                    color: Colors.white.withValues(alpha: 0.08),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: AppColors.border),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Confidence',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    axisNameSize: 28,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 20,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}%',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'Growth',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                    axisNameSize: 40,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: 20,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}%',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
