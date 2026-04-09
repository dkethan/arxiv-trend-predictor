class AdvisorResponse {
  final String domain;
  final double domainConfidence;
  final List<AlternateDomain> alternateDomains;
  final List<String> allDomains;
  final Map<String, double> domainConfidenceMap;
  final Map<String, GrowthInfo> growthInfo;
  final Map<String, double> modelInfo;
  final double domainGrowthScore;
  final String domainGrowthLabel;
  final String disclaimer;
  final List<String> suggestedKeywords;
  final String message;

  /// From API `advisory` + root fields (matches web Overview / Insights / Similar).
  final double? opportunityScore;
  final String? signalType;
  final AdvisoryNarrative advisoryNarrative;
  final Map<String, ScoreBreakdownFactor> scoreBreakdown;
  final List<String> improvementTips;
  final List<SimilarPaper> similarPapers;
  final String similarityNote;

  AdvisorResponse({
    required this.domain,
    required this.domainConfidence,
    required this.alternateDomains,
    required this.allDomains,
    required this.domainConfidenceMap,
    required this.growthInfo,
    required this.modelInfo,
    required this.domainGrowthScore,
    required this.domainGrowthLabel,
    required this.disclaimer,
    required this.suggestedKeywords,
    required this.message,
    this.opportunityScore,
    this.signalType,
    this.advisoryNarrative = const AdvisoryNarrative(),
    this.scoreBreakdown = const {},
    this.improvementTips = const [],
    this.similarPapers = const [],
    this.similarityNote = '',
  });

  factory AdvisorResponse.fromJson(Map<String, dynamic> json) {
    final primaryDomain =
        _asString(json['primary_domain']) ?? _asString(json['domain']) ?? '';
    final confidenceMap = _asDoubleMap(json['domain_confidence']);
    final apiAllDomains = _asStringList(json['all_domains']);
    final allDomains = apiAllDomains.isNotEmpty
        ? apiAllDomains
        : _sortedDomainKeysByConfidence(confidenceMap, primaryDomain);

    final alternateDomains = <AlternateDomain>[];
    for (final name in allDomains) {
      if (name == primaryDomain) continue;
      alternateDomains.add(
        AlternateDomain(
          name: name,
          confidence: confidenceMap[name] ?? 0,
        ),
      );
    }

    // Keep old API compatibility by also supporting `alternate_domains` tuples.
    final legacyAlternates = json['alternate_domains'];
    if (alternateDomains.isEmpty && legacyAlternates is List) {
      for (final item in legacyAlternates) {
        if (item is List && item.length >= 2) {
          final altName = _asString(item[0]) ?? '';
          final altConfidence = _asDouble(item[1]) ?? 0;
          if (altName.isNotEmpty) {
            alternateDomains.add(
              AlternateDomain(name: altName, confidence: altConfidence),
            );
          }
        }
      }
    }

    final growthInfo = json['growth_info'];
    final growthMap = _asGrowthInfoMap(growthInfo);
    final primarySlope = growthMap[primaryDomain]?.slope ?? 0;

    final normalizedGrowth = ((_asDouble(json['domain_growth_score']) ??
                primarySlope)
            .clamp(0.0, 1.0))
        .toDouble();
    final growthLabel = _asString(json['domain_growth_label']) ??
        _growthLabelFromScore(normalizedGrowth);

    Map<String, dynamic>? adv;
    if (json['advisory'] is Map) {
      adv = Map<String, dynamic>.from(json['advisory'] as Map);
    }

    final opportunityScore = _asDouble(json['opportunity_score']) ??
        (adv != null ? _asDouble(adv['opportunity_score']) : null);
    final signalType =
        _asString(json['signal_type']) ?? (adv != null ? _asString(adv['signal_type']) : null);

    return AdvisorResponse(
      domain: primaryDomain,
      domainConfidence: confidenceMap[primaryDomain] ??
          _asDouble(json['domain_confidence']) ??
          0,
      alternateDomains: alternateDomains,
      allDomains: allDomains,
      domainConfidenceMap: confidenceMap,
      growthInfo: growthMap,
      modelInfo: _asDoubleMap(json['model_info']),
      domainGrowthScore: normalizedGrowth,
      domainGrowthLabel: growthLabel,
      disclaimer: _asString(json['disclaimer']) ??
          'Model-based estimate only. Use as directional guidance, not factual certainty.',
      suggestedKeywords: _asStringList(json['suggested_keywords']),
      message: _asString(json['message']) ?? '',
      opportunityScore: opportunityScore,
      signalType: signalType,
      advisoryNarrative: _parseAdvisoryNarrative(adv?['narrative']),
      scoreBreakdown: _parseScoreBreakdown(adv?['score_breakdown']),
      improvementTips: _parseStringList(adv?['improvement_tips']),
      similarPapers: _parseSimilarPapers(json['similar_papers']),
      similarityNote: _asString(json['similarity_note']) ?? '',
    );
  }

  String get confidencePercent =>
      '${(domainConfidence * 100).toStringAsFixed(1)}%';

  String get growthPercent =>
      '${(domainGrowthScore * 100).toStringAsFixed(0)}%';

  String get signalLabelDisplay {
    if (signalType == null || signalType!.isEmpty) return 'No signal';
    return signalType!.replaceAll('_', ' ');
  }

  String get opportunityScoreDisplay {
    final o = opportunityScore;
    if (o == null || o.isNaN) return '—';
    return '${o.toStringAsFixed(2)} / 10';
  }

  String get overviewGrowthPercentDisplay =>
      '${(domainGrowthScore * 100).toStringAsFixed(1)}%';
}

/// Response from `POST /api/v1/advisor/compare` (web compare flow).
class CompareIdeasResult {
  final AdvisorResponse ideaAResult;
  final AdvisorResponse ideaBResult;
  final String finalVerdict;

  CompareIdeasResult({
    required this.ideaAResult,
    required this.ideaBResult,
    required this.finalVerdict,
  });

  factory CompareIdeasResult.fromJson(Map<String, dynamic> json) {
    final a = json['idea_a_result'];
    final b = json['idea_b_result'];
    if (a is! Map || b is! Map) {
      throw FormatException('compare response missing idea_a_result / idea_b_result');
    }
    return CompareIdeasResult(
      ideaAResult: AdvisorResponse.fromJson(Map<String, dynamic>.from(a)),
      ideaBResult: AdvisorResponse.fromJson(Map<String, dynamic>.from(b)),
      finalVerdict: json['final_verdict'] is String ? json['final_verdict'] as String : '',
    );
  }
}

class ScoreBreakdownFactor {
  final String level;
  final String detail;

  const ScoreBreakdownFactor({this.level = '—', this.detail = ''});
}

class AdvisoryNarrative {
  final String? whyThisFits;
  final String? whereItStands;
  final String? whereItsGoing;
  final List<String> howToPosition;
  final String? supportingSignals;

  const AdvisoryNarrative({
    this.whyThisFits,
    this.whereItStands,
    this.whereItsGoing,
    this.howToPosition = const [],
    this.supportingSignals,
  });
}

class SimilarPaper {
  final String title;
  final String link;
  final String? year;
  final String? domain;
  final double similarityScore;

  const SimilarPaper({
    required this.title,
    required this.link,
    this.year,
    this.domain,
    this.similarityScore = 0,
  });
}

AdvisoryNarrative _parseAdvisoryNarrative(dynamic raw) {
  if (raw is! Map) return const AdvisoryNarrative();
  final m = Map<String, dynamic>.from(raw);
  List<String> position = const [];
  final h = m['how_to_position'];
  if (h is List) {
    position = h.whereType<String>().toList();
  }
  return AdvisoryNarrative(
    whyThisFits: _asString(m['why_this_fits']),
    whereItStands: _asString(m['where_it_stands']),
    whereItsGoing: _asString(m['where_its_going']),
    howToPosition: position,
    supportingSignals: _asString(m['supporting_signals']),
  );
}

Map<String, ScoreBreakdownFactor> _parseScoreBreakdown(dynamic raw) {
  if (raw is! Map) return const {};
  final keys = [
    'semantic_alignment',
    'growth_trajectory',
    'cluster_density',
    'cross_domain_potential',
  ];
  final out = <String, ScoreBreakdownFactor>{};
  for (final key in keys) {
    final v = raw[key];
    if (v is Map) {
      out[key] = ScoreBreakdownFactor(
        level: _asString(v['level']) ?? '—',
        detail: _asString(v['detail']) ?? '',
      );
    }
  }
  return out;
}

List<String> _parseStringList(dynamic raw) {
  if (raw is! List) return const [];
  return raw.whereType<String>().toList();
}

List<SimilarPaper> _parseSimilarPapers(dynamic raw) {
  if (raw is! List) return const [];
  final out = <SimilarPaper>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final m = Map<String, dynamic>.from(item);
    out.add(
      SimilarPaper(
        title: _asString(m['title']) ?? 'Untitled paper',
        link: _asString(m['link']) ?? '',
        year: _asString(m['year']),
        domain: _asString(m['domain']),
        similarityScore: _asDouble(m['similarity_score']) ?? 0,
      ),
    );
  }
  return out;
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String? _asString(dynamic value) {
  if (value is String) return value;
  return null;
}

List<String> _asStringList(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList();
}

Map<String, double> _asDoubleMap(dynamic value) {
  if (value is! Map) return const {};
  final out = <String, double>{};
  value.forEach((k, v) {
    final key = k is String ? k : null;
    final numValue = _asDouble(v);
    if (key != null && numValue != null) {
      out[key] = numValue;
    }
  });
  return out;
}

Map<String, GrowthInfo> _asGrowthInfoMap(dynamic value) {
  if (value is! Map) return const {};
  final out = <String, GrowthInfo>{};
  value.forEach((k, v) {
    if (k is! String || v is! Map) return;
    final slope = _asDouble(v['slope']);
    final r2 = _asDouble(v['r2']);
    out[k] = GrowthInfo(slope: slope, r2: r2);
  });
  return out;
}

List<String> _sortedDomainKeysByConfidence(
  Map<String, double> confidenceMap,
  String primary,
) {
  final keys = confidenceMap.keys.toList()
    ..sort((a, b) => (confidenceMap[b] ?? 0).compareTo(confidenceMap[a] ?? 0));
  if (primary.isEmpty || !keys.contains(primary)) return keys;
  return [primary, ...keys.where((k) => k != primary)];
}

String _growthLabelFromScore(double score) {
  if (score >= 0.7) return 'Strong growth';
  if (score >= 0.4) return 'Moderate growth';
  if (score > 0) return 'Early signals';
  return 'No clear growth signal';
}

class GrowthInfo {
  final double? slope;
  final double? r2;

  const GrowthInfo({this.slope, this.r2});
}

class AlternateDomain {
  final String name;
  final double confidence;

  AlternateDomain({required this.name, required this.confidence});

  String get confidencePercent =>
      '${(confidence * 100).toStringAsFixed(1)}%';
}
