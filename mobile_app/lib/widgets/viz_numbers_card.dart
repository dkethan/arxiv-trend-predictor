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
    final alts = result.alternateDomains;
    final growthPct = '${(result.domainGrowthScore * 100).toStringAsFixed(1)}%';

    // Web: .viz-numbers padding 1rem 1.25rem
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
          _line(
            result.domain.isEmpty ? 'Primary' : result.domain,
            _pct(result.domainConfidence),
            bold: true,
          ),
          ...alts.map((a) => _line(a.name, _pct(a.confidence))),
          _line('Growth score:', growthPct, growth: true),
        ],
      ),
    );
  }

  Widget _line(String label, String value, {bool bold = false, bool growth = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 14.4,
            color: AppColors.text,
            height: 1.6,
          ),
          children: [
            TextSpan(
              text: label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            const TextSpan(text: ' '),
            TextSpan(
              text: value,
              style: TextStyle(
                fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                fontWeight: FontWeight.w600,
                color: growth ? AppColors.success : AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
