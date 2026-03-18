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
    );
  }

  String get confidencePercent =>
      '${(domainConfidence * 100).toStringAsFixed(1)}%';

  String get growthPercent =>
      '${(domainGrowthScore * 100).toStringAsFixed(0)}%';
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
