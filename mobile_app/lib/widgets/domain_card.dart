import 'package:flutter/material.dart';
import '../models/advisor_response.dart';
import '../theme.dart';

/// Matches the web app's .domain-card exactly:
/// domain name (teal) + confidence (mono) on one row,
/// then a divider and alternate domains table.
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
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main row: domain name + confidence
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  domain,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _pct(confidence),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                  color: AppColors.text,
                ),
              ),
            ],
          ),

          // Alternates
          if (alternateDomains.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              height: 1,
              color: AppColors.border,
            ),
            const SizedBox(height: 14),
            const Text(
              'ALSO CLOSE (COMPARE ALL FOUR)',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            // Header row
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Domain',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  Text(
                    'Confidence',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.border),
            const SizedBox(height: 4),
            // Data rows
            ...alternateDomains.map((alt) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
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
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'monospace',
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
