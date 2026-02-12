import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

/// Matches the web app's .growth-card:
/// green pill badge with label + "Growth score: XX%" text.
class GrowthCard extends StatelessWidget {
  final String label;
  final double score;

  const GrowthCard({
    super.key,
    required this.label,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    final pct = '${(score * 100).toStringAsFixed(1)}%';

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
        spacing: 16,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Green pill badge (web: .growth-label)
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
              label.isEmpty ? '—' : label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ),
          // Score text (web: .growth-score-wrap / .growth-score-value)
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textMuted,
              ),
              children: [
                const TextSpan(text: 'Growth score: '),
                TextSpan(
                  text: pct,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 19.2,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
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
