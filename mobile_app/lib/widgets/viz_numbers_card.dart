import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/advisor_response.dart';
import '../theme.dart';

/// Matches the web app's #viz-numbers: "Numbers at a glance" list.
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
    final primaryCode = _abbreviateDomain(result.domain.isEmpty ? 'Primary' : result.domain);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _tile(
                title: 'Primary',
                big: primaryCode,
                sub: result.domain,
                value: _pct(result.domainConfidence),
              ),
              _tile(
                title: 'Top growth',
                value: topGrowth == null
                    ? '—'
                    : '${topGrowth.key} (${topGrowth.value.toStringAsFixed(3)})',
              ),
              _tile(
                title: 'Domains',
                value: '${predicted.length} predicted',
              ),
              _tile(
                title: 'Avg confidence',
                value: _pct(avgConfidence),
                growth: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _abbreviateDomain(String domain) {
    final words = domain.split(RegExp(r'[\s/_-]+')).where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) {
      final letters = words.map((w) => w[0].toUpperCase()).join();
      final maxLen = letters.length < 5 ? letters.length : 5;
      return letters.substring(0, maxLen);
    }
    return domain.length <= 8 ? domain.toUpperCase() : domain.substring(0, 8).toUpperCase();
  }

  Widget _tile({
    required String title,
    String? big,
    String? sub,
    required String value,
    bool growth = false,
  }) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          if (big != null) ...[
            const SizedBox(height: 4),
            Text(
              big,
              style: GoogleFonts.syne(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ],
          if (sub != null && sub.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              sub,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              color: growth ? AppColors.success : AppColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
