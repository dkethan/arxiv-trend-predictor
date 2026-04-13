import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/advisor_response.dart';
import '../theme.dart';

String _signalPretty(String raw) {
  if (raw.isEmpty) return raw;
  final s = raw.replaceAll('_', ' ');
  return s.split(RegExp(r'\s+')).map((w) {
    if (w.isEmpty) return w;
    return w[0].toUpperCase() + w.substring(1).toLowerCase();
  }).join(' ');
}

/// Web: .compare-card / compare-cards-grid — shown on Overview when comparing.
class IdeaComparisonCard extends StatelessWidget {
  final AdvisorResponse ideaA;
  final AdvisorResponse ideaB;
  final String finalVerdict;

  const IdeaComparisonCard({
    super.key,
    required this.ideaA,
    required this.ideaB,
    required this.finalVerdict,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: appCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'IDEA COMPARISON',
            style: GoogleFonts.outfit(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1 * 11.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final stack = c.maxWidth < 420;
              final ideaACard = _ideaMiniCard('Idea A', ideaA);
              final ideaBCard = _ideaMiniCard('Idea B', ideaB);
              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ideaACard,
                    const SizedBox(height: 10),
                    ideaBCard,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: ideaACard),
                  const SizedBox(width: 10),
                  Expanded(child: ideaBCard),
                ],
              );
            },
          ),
          if (finalVerdict.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(height: 1, color: AppColors.border),
            const SizedBox(height: 14),
            Text(
              finalVerdict,
              style: GoogleFonts.outfit(
                fontSize: 16.8,
                fontWeight: FontWeight.w600,
                height: 1.45,
                color: AppColors.text,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ideaMiniCard(String label, AdvisorResponse r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.syne(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 14),
          _metricRow('Opportunity', r.opportunityScoreDisplay),
          const SizedBox(height: 10),
          _metricRow('Signal', _signalPretty(r.signalLabelDisplay)),
          const SizedBox(height: 10),
          _metricRow('Growth', r.overviewGrowthPercentDisplay),
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.08 * 11,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }
}
