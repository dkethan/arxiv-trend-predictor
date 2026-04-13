import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/advisor_response.dart';
import '../theme.dart';

class VizNumbersCard extends StatelessWidget {
  final AdvisorResponse result;

  const VizNumbersCard({super.key, required this.result});

  String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    final predicted = result.allDomains.isNotEmpty
        ? result.allDomains
        : [result.domain, ...result.alternateDomains.map((a) => a.name)];
    final growthByPredicted = predicted
        .map((d) => MapEntry(d, result.growthInfo[d]?.slope ?? -1))
        .toList();
    growthByPredicted.sort((a, b) => b.value.compareTo(a.value));
    final topGrowth = growthByPredicted.isNotEmpty && growthByPredicted.first.value >= 0
        ? growthByPredicted.first
        : null;
    final avgConfidence = predicted.isEmpty
        ? 0.0
        : predicted
                .map((d) => result.domainConfidenceMap[d] ?? 0)
                .reduce((a, b) => a + b) /
            predicted.length;
    final primaryCode = (result.domain.isEmpty ? 'Primary' : result.domain).toUpperCase();
    final bestR2ByPredicted = predicted
        .map((d) => MapEntry(d, result.growthInfo[d]?.r2 ?? -1))
        .toList();
    bestR2ByPredicted.sort((a, b) => b.value.compareTo(a.value));
    final bestR2Fit = bestR2ByPredicted.isNotEmpty && bestR2ByPredicted.first.value >= 0
        ? bestR2ByPredicted.first
        : null;
    final cardSurfaceColor = AppColors.surface.withValues(alpha: 0.85);

    Widget primaryTile({bool minHeight = false}) {
      return Container(
        width: double.infinity,
        constraints:
            minHeight ? const BoxConstraints(minHeight: 120) : null,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardSurfaceColor,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _StatLabel('PRIMARY'),
                const SizedBox(height: 8),
                _buildPrimaryCodeText(primaryCode),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'confidence',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _pct(result.domainConfidence),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget topGrowthTile({bool minHeight = false}) {
      return Container(
        width: double.infinity,
        constraints:
            minHeight ? const BoxConstraints(minHeight: 120) : null,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardSurfaceColor,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _StatLabel('TOP GROWTH'),
            const SizedBox(height: 6),
            Text(
              topGrowth == null ? '—' : topGrowth.key,
              style: GoogleFonts.syne(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.1,
                color: const Color(0xFF2ED8A8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'slope ${topGrowth == null ? '—' : topGrowth.value.toStringAsFixed(3)}',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    Widget domainsTile({bool minHeight = false}) {
      return Container(
        width: double.infinity,
        constraints:
            minHeight ? const BoxConstraints(minHeight: 120) : null,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardSurfaceColor,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _StatLabel('DOMAINS'),
            const SizedBox(height: 6),
            Text(
              '${predicted.length}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                height: 1,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'predicted',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    Widget summaryRow({required bool stack}) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardSurfaceColor,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: stack
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _StatLabel('BEST R² FIT'),
                  const SizedBox(height: 4),
                  Text(
                    '${bestR2Fit == null ? '—' : bestR2Fit.key} — ${bestR2Fit == null ? '—' : bestR2Fit.value.toStringAsFixed(3)}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _StatLabel('AVG CONFIDENCE'),
                  const SizedBox(height: 4),
                  Text(
                    _pct(avgConfidence),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _StatLabel('BEST R² FIT'),
                        const SizedBox(height: 4),
                        Text(
                          '${bestR2Fit == null ? '—' : bestR2Fit.key} — ${bestR2Fit == null ? '—' : bestR2Fit.value.toStringAsFixed(3)}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const _StatLabel('AVG CONFIDENCE'),
                      const SizedBox(height: 4),
                      Text(
                        _pct(avgConfidence),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Web: .viz-stat-layout stacks below 760px
        final stackGrid = constraints.maxWidth < 760;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: appCardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NUMBERS AT A GLANCE',
                style: GoogleFonts.outfit(
                  fontSize: 11.2,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.08 * 11.2,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              if (stackGrid) ...[
                primaryTile(minHeight: true),
                const SizedBox(height: 10),
                topGrowthTile(minHeight: true),
                const SizedBox(height: 10),
                domainsTile(minHeight: true),
              ] else
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: primaryTile()),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: topGrowthTile()),
                            const SizedBox(height: 10),
                            Expanded(child: domainsTile()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              summaryRow(stack: stackGrid),
            ],
          ),
        );
      },
    );
  }

  double _primaryCodeFontSize(String value) {
    final len = value.trim().length;
    final hasMultipleWords = value.trim().contains(RegExp(r'\s+'));

    if (hasMultipleWords) {
      if (len <= 12) return 28;
      if (len <= 18) return 22;
      if (len <= 24) return 18;
      return 16;
    }

    if (len <= 6) return 40;
    if (len <= 8) return 32;
    if (len <= 10) return 28;
    if (len <= 14) return 22;
    return 18;
  }

  Widget _buildPrimaryCodeText(String value) {
    final hasMultipleWords = value.trim().contains(RegExp(r'\s+'));
    final style = GoogleFonts.syne(
      fontSize: _primaryCodeFontSize(value),
      fontWeight: FontWeight.w700,
      height: 0.95,
      color: AppColors.text,
    );

    if (hasMultipleWords) {
      return Text(
        value,
        style: style,
        maxLines: 3,
        softWrap: true,
        overflow: TextOverflow.clip,
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: style.copyWith(fontSize: 52),
          maxLines: 1,
          softWrap: false,
        ),
      ),
    );
  }
}

class _StatLabel extends StatelessWidget {
  final String text;
  const _StatLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.06 * 10.5,
        color: AppColors.textMuted,
      ),
    );
  }
}
