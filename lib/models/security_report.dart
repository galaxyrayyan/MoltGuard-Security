import 'package:flutter/material.dart';

class SecurityReport {
  final String id;
  final String query;
  final double overallRiskScore;
  final String riskLevel;
  final String summary;
  final String? recommendations;
  final List<Vulnerability> vulnerabilities;
  final DateTime timestamp;
  final String agentName;

  SecurityReport({
    required this.id,
    required this.query,
    required this.overallRiskScore,
    required this.riskLevel,
    required this.summary,
    this.recommendations,
    this.vulnerabilities = const [],
    required this.timestamp,
    this.agentName = 'Gemini 2.5 Flash',
  });

  Color get color => _calculateColor();
  Color get riskColor => _calculateColor(); 

  Color _calculateColor() {
    if (overallRiskScore >= 80) return Colors.redAccent;
    if (overallRiskScore >= 60) return Colors.orangeAccent;
    if (overallRiskScore >= 30) return Colors.yellowAccent;
    return Colors.greenAccent;
  }

  factory SecurityReport.fromJson(Map<String, dynamic> json) {
    final double score = (json['overallRiskScore'] as num?)?.toDouble() ?? 0.0;
    
    String? level = json['riskLevel'] ?? json['threat'] ?? json['threatLevel'];

    if (level == null || level.isEmpty || level.toUpperCase() == 'UNKNOWN') {
        if (score >= 80) {
        level = "CRITICAL";
      } else if (score >= 60) {
        level = "HIGH";
      } else if (score >= 30) {
        level = "MEDIUM";
      } else {
        level = "LOW";
      }
    }

    return SecurityReport(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      query: json['query'] ?? '',
      overallRiskScore: score,
      riskLevel: level.toUpperCase(),
      summary: json['summary'] ?? '',
      recommendations: json['recommendations'],
      vulnerabilities: (json['vulnerabilities'] as List?)
              ?.map((v) => Vulnerability.fromJson(v))
              .toList() ?? [],
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 
    'query': query, 
    'overallRiskScore': overallRiskScore,
    'riskLevel': riskLevel, 
    'summary': summary, 
    'recommendations': recommendations,
    'vulnerabilities': vulnerabilities.map((v) => v.toJson()).toList(),
    'timestamp': timestamp.toIso8601String(),
  };
}    

class Vulnerability {
  final String type;
  final String severity;
  final String description;

  Vulnerability({required this.type, required this.severity, required this.description});

  Color get severityColor {
    switch (severity.toUpperCase()) {
      case 'CRITICAL': return Colors.redAccent;
      case 'HIGH': return Colors.orangeAccent;
      case 'MEDIUM': return Colors.yellowAccent;
      default: return Colors.greenAccent;
    }
  }

  factory Vulnerability.fromJson(Map<String, dynamic> json) => Vulnerability(
    type: json['type'] ?? 'General',
    severity: json['severity'] ?? 'LOW',
    description: json['description'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'type': type, 
    'severity': severity, 
    'description': description
  };
}
