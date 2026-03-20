import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/security_report.dart';

class AIService {
  Future<SecurityReport> analyzeThreat(String text) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey!);

    final prompt = """
      Analyze the following input for cyber security threats: '$text'
      
      Return ONLY a JSON object with this exact structure:
      {
        "overallRiskScore": (number 0-100),
        "riskLevel": "CRITICAL" | "HIGH" | "MEDIUM" | "LOW",
        "summary": "Short technical summary",
        "recommendations": "Actionable advice",
        "vulnerabilities": [
          {
            "type": "type of threat",
            "severity": "HIGH" | "MEDIUM" | "LOW",
            "description": "details"
          }
        ]
      }
    """;

    final response = await model.generateContent([Content.text(prompt)]);
    String responseText = response.text ?? "{}";
    String cleanJson = responseText.replaceAll('```json', '').replaceAll('```', '').trim();

    try {
      final Map<String, dynamic> rawData = jsonDecode(cleanJson);
      return SecurityReport.fromJson({
        ...rawData,
        'query': text,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception("Format Error");
    }
  }
}
