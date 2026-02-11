class AdvisorResponse {
  final String domain;
  final double domainConfidence;
  final List<AlternateDomain> alternateDomains;
  final double domainGrowthScore;
  final String domainGrowthLabel;
  final String disclaimer;
  final List<String> suggestedKeywords;
  final String message;

  AdvisorResponse({
    required this.domain,
    required this.domainConfidence,
    required this.alternateDomains,
    required this.domainGrowthScore,
    required this.domainGrowthLabel,
    required this.disclaimer,
    required this.suggestedKeywords,
    required this.message,
  });

  factory AdvisorResponse.fromJson(Map<String, dynamic> json) {
    return AdvisorResponse(
      domain: json['domain'] as String,
      domainConfidence: (json['domain_confidence'] as num).toDouble(),
      alternateDomains: (json['alternate_domains'] as List)
          .map((e) => AlternateDomain(
                name: (e as List)[0] as String,
                confidence: (e[1] as num).toDouble(),
              ))
          .toList(),
      domainGrowthScore: (json['domain_growth_score'] as num).toDouble(),
      domainGrowthLabel: json['domain_growth_label'] as String,
      disclaimer: json['disclaimer'] as String,
      suggestedKeywords:
          (json['suggested_keywords'] as List).cast<String>(),
      message: json['message'] as String,
    );
  }

  String get confidencePercent =>
      '${(domainConfidence * 100).toStringAsFixed(1)}%';

  String get growthPercent =>
      '${(domainGrowthScore * 100).toStringAsFixed(0)}%';
}

class AlternateDomain {
  final String name;
  final double confidence;

  AlternateDomain({required this.name, required this.confidence});

  String get confidencePercent =>
      '${(confidence * 100).toStringAsFixed(1)}%';
}
