import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/advisor_response.dart';
import '../theme.dart';

class DomainCard extends StatefulWidget {
  final AdvisorResponse result;

  const DomainCard({
    super.key,
    required this.result,
  });

  @override
  State<DomainCard> createState() => _DomainCardState();
}

class _DomainCardState extends State<DomainCard> {
  bool _showLandscape = false;

  String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

  Color _growthColor(double? slope) {
    if (slope == null) return AppColors.textMuted;
    if (slope > 0.3) return AppColors.success;
    if (slope > 0.1) return const Color(0xFFFBBF24);
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final primary = result.domain.isEmpty ? 'Primary' : result.domain;
    final predicted = result.allDomains.isNotEmpty
        ? result.allDomains
        : [primary, ...result.alternateDomains.map((a) => a.name)];
    final allByConfidence = result.domainConfidenceMap.keys.toList()
      ..sort((a, b) => (result.domainConfidenceMap[b] ?? 0)
          .compareTo(result.domainConfidenceMap[a] ?? 0));

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 400;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: appCardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero (web: domain-hero ring + primary title)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: result.domainConfidence,
                          strokeWidth: 7,
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.accent),
                        ),
                        Center(
                          child: Text(
                            _pct(result.domainConfidence),
                            style: GoogleFonts.jetBrainsMono(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          primary,
                          style: GoogleFonts.syne(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.02 * 21,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'PRIMARY CLASSIFICATION',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.6,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              Text(
                'PREDICTED DOMAINS',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.08 * 11,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              ...predicted.map((domain) {
                final conf = result.domainConfidenceMap[domain] ?? 0;
                final slope = result.growthInfo[domain]?.slope;
                final isPrimary = domain == primary;
                final badge = Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _growthColor(slope).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _growthColor(slope).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    slope == null ? '—' : slope.toStringAsFixed(3),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: _growthColor(slope),
                    ),
                  ),
                );
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.fromLTRB(
                      isPrimary ? 10 : 0, 8, isPrimary ? 10 : 0, 8),
                  decoration: BoxDecoration(
                    color: isPrimary ? AppColors.accentSoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: narrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              domain,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.text,
                                fontWeight: isPrimary
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                minHeight: 6,
                                value: conf,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.08),
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                        AppColors.accent),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _pct(conf),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                badge,
                              ],
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Text(
                                domain,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.text,
                                  fontWeight: isPrimary
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 64,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  minHeight: 6,
                                  value: conf,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.08),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          AppColors.accent),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 44,
                              child: Text(
                                _pct(conf),
                                textAlign: TextAlign.right,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            badge,
                          ],
                        ),
                );
              }),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () =>
                    setState(() => _showLandscape = !_showLandscape),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                  foregroundColor: AppColors.accent,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _showLandscape ? 'Hide all domain scores' : 'All domain scores',
                  style:
                      const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              if (_showLandscape) ...[
                const SizedBox(height: 6),
                ...allByConfidence.map((domain) {
                  final conf = result.domainConfidenceMap[domain] ?? 0;
                  final predictedDomain = predicted.contains(domain);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: narrow
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                domain,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: predictedDomain
                                      ? AppColors.text
                                      : AppColors.textMuted,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  minHeight: 4,
                                  value: conf,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.06),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    predictedDomain
                                        ? AppColors.accent
                                        : AppColors.textMuted
                                            .withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _pct(conf),
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10.5,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: Text(
                                  domain,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: predictedDomain
                                        ? AppColors.text
                                        : AppColors.textMuted,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 72,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    minHeight: 4,
                                    value: conf,
                                    backgroundColor: Colors.white
                                        .withValues(alpha: 0.06),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      predictedDomain
                                          ? AppColors.accent
                                          : AppColors.textMuted
                                              .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 40,
                                child: Text(
                                  _pct(conf),
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10.5,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }
}
