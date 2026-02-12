import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/advisor_response.dart';
import '../theme.dart';

/// Matches the web app's .domain-card exactly:
/// domain name (teal, Syne) + confidence (mono) on one row,
/// then "Also close (compare all four)" and alternate domains table.
class DomainCard extends StatelessWidget {
  final String domain;
  final double confidence;
  final List<AlternateDomain> alternateDomains;

  const DomainCard({
    super.key,
    required this.domain,
    required this.confidence,
    required this.alternateDomains,
  });

  String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: appCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main row: domain name + confidence (web: .domain-main-row)
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  domain.isEmpty ? '—' : domain,
                  style: GoogleFonts.syne(
                    fontSize: 21.6,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.02 * 21.6,
                    color: AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                _pct(confidence),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ],
          ),

          // Alternates (web: .alternates, "Also close (compare all four)")
          if (alternateDomains.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 1,
              color: AppColors.border,
            ),
            const SizedBox(height: 16),
            Text(
              'ALSO CLOSE (COMPARE ALL FOUR)',
              style: GoogleFonts.outfit(
                fontSize: 11.2,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.08 * 11.2,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            // Header row (web: .alternate-list-header)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Domain',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  const Text(
                    'Confidence',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.border),
            const SizedBox(height: 6),
            // Data rows
            ...alternateDomains.map((alt) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          alt.name,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      Text(
                        _pct(alt.confidence),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 14.4,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
