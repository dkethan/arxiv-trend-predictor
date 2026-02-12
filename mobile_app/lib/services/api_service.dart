import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/advisor_response.dart';

class ApiService {
  static const String _baseUrl =
      'https://arxiv-trend-predictor-api.onrender.com';

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
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => message;
}
