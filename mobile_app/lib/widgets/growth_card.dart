import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/advisor_response.dart';
import '../theme.dart';

class GrowthCard extends StatelessWidget {
  final AdvisorResponse result;

  const GrowthCard({
    super.key,
    required this.result,
  });

  Color _slopeColor(double? slope) {
    if (slope == null) return AppColors.textMuted;
    if (slope > 0.3) return AppColors.success;
    if (slope > 0.1) return const Color(0xFFFBBF24);
    return AppColors.textMuted;
  }

  String _r2Label(double? r2) {
    if (r2 == null) return '—';
    if (r2 >= 0.5) return 'Strong fit';
    if (r2 >= 0.25) return 'Moderate';
    return 'Weak';
  }

  @override
  Widget build(BuildContext context) {
    final predicted = result.allDomains.isNotEmpty
        ? result.allDomains
        : [result.domain, ...result.alternateDomains.map((a) => a.name)];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: appCardDecoration.copyWith(
        gradient: const LinearGradient(
          colors: [
            Color(0xE612141C),
            Color(0xE61C1F2A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Wrap(
        runSpacing: 14,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.successSoft,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              result.domainGrowthLabel.isEmpty ? 'Growth trends' : result.domainGrowthLabel,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ),
          ...predicted.map((domain) {
            final g = result.growthInfo[domain];
            final slope = g?.slope;
            final r2 = g?.r2;
            final slopeColor = _slopeColor(slope);
            final r2Value = (r2 ?? 0).clamp(0.0, 1.0);

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    domain,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: slopeColor.withValues(alpha: 0.13),
                          border: Border.all(
                            color: slopeColor.withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SLOPE',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              slope == null ? '—' : slope.toStringAsFixed(3),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: slopeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'R2 ${_r2Label(r2)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                minHeight: 6,
                                value: r2Value,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.08),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        r2 == null ? '—' : r2.toStringAsFixed(3),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
              children: [
                const TextSpan(text: 'Overall growth score: '),
                TextSpan(
                  text: '${(result.domainGrowthScore * 100).toStringAsFixed(1)}%',
                  style: GoogleFonts.jetBrainsMono(
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
