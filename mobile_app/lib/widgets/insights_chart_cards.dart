import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/advisor_response.dart';
import '../theme.dart';

/// Web: .chart-wrap — 3 cards (confidence bar, growth bar, scatter) in Insights section.
/// Mobile: same card style, data shown as simple bars/text (no Chart.js).
const _chartCardPadding = 16.0;
const _chartWrapTallHeight = 240.0;
const _chartWrapHeight = 200.0;
const _chartScatterHeight = 220.0;

/// Domain confidence bar chart card (web: chart-confidence).
class ChartConfidenceCard extends StatelessWidget {
  final AdvisorResponse result;

  const ChartConfidenceCard({super.key, required this.result});

  String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    final primary = result.domain.isEmpty ? 'Primary' : result.domain;
    final primaryConf = result.domainConfidence;
    final alts = result.alternateDomains;
    final labels = [primary]..addAll(alts.map((a) => a.name));
    final values = [primaryConf]..addAll(alts.map((a) => a.confidence));

    return Container(
      height: _chartWrapTallHeight,
      padding: const EdgeInsets.all(_chartCardPadding),
      decoration: appCardDecoration,
      child: Column(
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
          Expanded(
            child: ListView.builder(
              itemCount: labels.length,
              itemBuilder: (context, i) {
                final isPrimary = i == 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
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
                            minHeight: 20,
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Growth score gauge card (web: chart-growth).
class ChartGrowthCard extends StatelessWidget {
  final AdvisorResponse result;

  const ChartGrowthCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final value = result.domainGrowthScore;
    final pct = '${(value * 100).toStringAsFixed(1)}%';

    return Container(
      height: _chartWrapTallHeight,
      padding: const EdgeInsets.all(_chartCardPadding),
      decoration: appCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
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

  const ChartScatterCard({super.key, required this.result});

  String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    final primary = result.domain.isEmpty ? 'Primary' : result.domain;
    final conf = result.domainConfidence;
    final growth = result.domainGrowthScore;
    final alts = result.alternateDomains;

    return Container(
      height: _chartScatterHeight,
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
          const SizedBox(height: 12),
          _pointRow(primary, conf, growth, isPrimary: true),
          ...alts.map((a) => _pointRow(a.name, a.confidence, 0, isPrimary: false)),
        ],
      ),
    );
  }

  Widget _pointRow(String label, double confidence, double growth, {required bool isPrimary}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPrimary ? AppColors.accent : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.text,
                fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${_pct(confidence)} / ${_pct(growth)}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
