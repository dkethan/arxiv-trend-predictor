import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/advisor_response.dart';

class ApiService {
  static const String _baseUrl = 'https://eidon-api-001.onrender.com';

  static Future<AdvisorResponse> getAdvice({
    required String title,
    required String abstract_,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/advisor/advise');

    final response = await http
        .post(
          uri,
          headers: {
            'accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'title': title,
            'abstract': abstract_,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return AdvisorResponse.fromJson(json);
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Server returned ${response.statusCode}: ${response.body}',
      );
    }
  }

  /// Web: POST `/api/v1/advisor/compare` with `idea_a` / `idea_b`.
  static Future<CompareIdeasResult> compareIdeas({
    required String titleA,
    required String abstractA,
    required String titleB,
    required String abstractB,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/advisor/compare');

    final response = await http
        .post(
          uri,
          headers: {
            'accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'idea_a': {'title': titleA, 'abstract': abstractA},
            'idea_b': {'title': titleB, 'abstract': abstractB},
          }),
        )
        .timeout(const Duration(seconds: 90));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return CompareIdeasResult.fromJson(json);
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Server returned ${response.statusCode}: ${response.body}',
      );
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => message;
}
