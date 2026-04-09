import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/advisor_response.dart';
import '../theme.dart';

String _capitalizeWords(String s) {
  return s.split(RegExp(r'\s+')).map((w) {
    if (w.isEmpty) return w;
    return w[0].toUpperCase() + w.substring(1).toLowerCase();
  }).join(' ');
}

String _formatSignalDisplay(String raw) {
  if (raw.isEmpty) return raw;
  return _capitalizeWords(raw.replaceAll('_', ' '));
}

const _breakdownMeta = <String, (String, String)>{
  'semantic_alignment': (
    'Semantic Alignment',
    'How well your idea aligns with existing research',
  ),
  'growth_trajectory': (
    'Growth Trajectory',
    'Growth momentum of the domain',
  ),
  'cluster_density': (
    'Competition Level',
    'How crowded the research cluster is',
  ),
  'cross_domain_potential': (
    'Cross-domain Reach',
    'How many research communities this touches',
  ),
};

Color _breakdownLevelColor(String level) {
  final l = level.toLowerCase();
  if (l.contains('high saturation') ||
      l.contains('weak') ||
      l.contains('slow')) {
    return const Color(0xFFF87171);
  }
  if (l.contains('strong') ||
      (l.contains('high') && !l.contains('saturation')) ||
      l.contains('low saturation')) {
    return const Color(0xFF34D399);
  }
  if (l.contains('emerging') ||
      l.contains('moderate') ||
      l.contains('narrow')) {
    return const Color(0xFFFBBF24);
  }
  return AppColors.textMuted;
}

/// Web: .overview-card — Overview tab.
class AdviceOverviewCard extends StatelessWidget {
  final AdvisorResponse result;

  const AdviceOverviewCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final breakdown = result.scoreBreakdown;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: appCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Overview',
            style: GoogleFonts.outfit(
              fontSize: 12.2,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.07 * 12.2,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          // Match web / design: full-width opportunity, then Signal | Growth in a row.
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _advisoryTile(
                'Opportunity score',
                result.opportunityScoreDisplay,
                emphasize: true,
              ),
              const SizedBox(height: 8),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _advisoryTile(
                        'Signal',
                        result.signalLabelDisplay,
                        signal: true,
                        expandVertically: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _advisoryTile(
                        'Growth score',
                        result.overviewGrowthPercentDisplay,
                        expandVertically: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (breakdown.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(height: 1, color: AppColors.border),
            const SizedBox(height: 16),
            Text(
              'Why this score',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.06 * 12,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, c) {
                final keys = _breakdownMeta.keys
                    .where((k) => breakdown.containsKey(k))
                    .toList();
                // Single column on typical phone / web .page width; 2-up on wider tablets.
                final twoCol = c.maxWidth >= 520;
                if (!twoCol) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: keys
                        .map((k) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _breakdownTile(k, breakdown[k]!),
                            ))
                        .toList(),
                  );
                }
                final half = ((c.maxWidth - 8) / 2).floorToDouble();
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.start,
                  children: keys
                      .map((k) => SizedBox(
                            width: half,
                            child: _breakdownTile(k, breakdown[k]!),
                          ))
                      .toList(),
                );
              },
            ),
          ],
          if (result.improvementTips.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What would improve this idea?',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'To increase your score:',
                    style: GoogleFonts.outfit(
                      fontSize: 12.8,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...result.improvementTips.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• ',
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 13.8,
                              height: 1.45,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              t,
                              style: GoogleFonts.outfit(
                                fontSize: 13.8,
                                height: 1.45,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _advisoryTile(
    String label,
    String value, {
    bool signal = false,
    bool emphasize = false,
    bool expandVertically = false,
  }) {
    final display = signal ? _formatSignalDisplay(value) : value;
    final valueStyle = GoogleFonts.jetBrainsMono(
      fontSize: emphasize ? 22 : 16,
      fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
      height: 1.15,
      color: AppColors.text,
    );
    return Container(
      width: double.infinity,
      height: expandVertically ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      alignment: expandVertically ? Alignment.topLeft : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: expandVertically ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 10.9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.05 * 10.9,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(display, style: valueStyle),
        ],
      ),
    );
  }

  Widget _breakdownTile(String key, ScoreBreakdownFactor f) {
    final meta = _breakdownMeta[key];
    final title = meta?.$1 ?? key;
    final color = _breakdownLevelColor(f.level);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.04 * 11.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            f.level,
            style: GoogleFonts.outfit(
              fontSize: 14.8,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (f.detail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              f.detail,
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                color: AppColors.textMuted,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Web: .advisory-card narrative — Insights tab.
class AdviceNarrativeCard extends StatelessWidget {
  final AdvisorResponse result;

  const AdviceNarrativeCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final n = result.advisoryNarrative;
    final sections = <Widget>[];

    void addSection(String label, String? body) {
      if (body == null || body.isEmpty) return;
      sections.add(_narrativeSection(label, body));
    }

    addSection('Why this fits', n.whyThisFits);
    addSection('Where it stands right now', n.whereItStands);
    addSection('Where it\'s going', n.whereItsGoing);
    if (n.howToPosition.isNotEmpty) {
      sections.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HOW TO POSITION IT',
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.07 * 11.5,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 8),
            ...n.howToPosition.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: AppColors.text, height: 1.65)),
                    Expanded(
                      child: Text(
                        item,
                        style: GoogleFonts.outfit(
                          fontSize: 14.8,
                          height: 1.65,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: AppColors.border),
            const SizedBox(height: 16),
          ],
        ),
      );
    }
    addSection('Supporting signals', n.supportingSignals);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: appCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Insights',
            style: GoogleFonts.outfit(
              fontSize: 12.2,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.07 * 12.2,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          if (sections.isEmpty)
            Text(
              'No narrative insights in this response.',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sections,
            ),
        ],
      ),
    );
  }

  Widget _narrativeSection(String label, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.07 * 11.5,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: GoogleFonts.outfit(
              fontSize: 14.8,
              height: 1.65,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// Web: .similar-card — Similar Papers tab.
class SimilarPapersCard extends StatelessWidget {
  final AdvisorResponse result;

  const SimilarPapersCard({super.key, required this.result});

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final papers = result.similarPapers;
    final note = result.similarityNote.isNotEmpty
        ? result.similarityNote
        : 'Pinecone similarity is not connected right now.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: appCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top similar papers',
            style: GoogleFonts.outfit(
              fontSize: 12.2,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.07 * 12.2,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          if (papers.isEmpty)
            Text(
              note,
              style: GoogleFonts.outfit(
                fontSize: 14.4,
                height: 1.55,
                color: AppColors.textMuted,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: papers.map((p) {
                final meta = [
                  p.year ?? 'year n/a',
                  p.domain ?? 'domain n/a',
                  'sim ${(p.similarityScore * 100).toStringAsFixed(1)}%',
                ].join(' • ');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: p.link.isNotEmpty ? () => _open(p.link) : null,
                          child: Text(
                            p.title,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.accent,
                              decoration: p.link.isNotEmpty
                                  ? TextDecoration.underline
                                  : null,
                              decorationColor: AppColors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          meta,
                          style: GoogleFonts.outfit(
                            fontSize: 13.2,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
