import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class SideEffectAnalysisRequest {
  SideEffectAnalysisRequest({
    required this.medicineName,
    required this.dose,
    required this.symptoms,
    this.patientAge,
    this.patientGender = '',
    this.knownConditions = const <String>[],
    this.extraNotes = '',
  });

  final String medicineName;
  final String dose;
  final List<String> symptoms;
  final int? patientAge;
  final String patientGender;
  final List<String> knownConditions;
  final String extraNotes;

  Map<String, dynamic> toJson() {
    return {
      'medicine_name': medicineName,
      'dose': dose,
      'symptoms': symptoms,
      'patient_age': patientAge,
      'patient_gender': patientGender,
      'known_conditions': knownConditions,
      'extra_notes': extraNotes,
    };
  }
}

class SideEffectAnalysisResult {
  SideEffectAnalysisResult({
    required this.severity,
    required this.doctorConsultationNeeded,
    required this.urgency,
    required this.possibleReasons,
    required this.immediateActions,
    required this.warningSigns,
    required this.recommendation,
    required this.confidence,
    required this.source,
  });

  final String severity;
  final bool doctorConsultationNeeded;
  final String urgency;
  final List<String> possibleReasons;
  final List<String> immediateActions;
  final List<String> warningSigns;
  final String recommendation;
  final double confidence;
  final String source;

  factory SideEffectAnalysisResult.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
    return SideEffectAnalysisResult(
      severity: (data['severity'] ?? '').toString(),
      doctorConsultationNeeded: data['doctor_consultation_needed'] == true,
      urgency: (data['urgency'] ?? '').toString(),
      possibleReasons: _toStringList(data['possible_reasons']),
      immediateActions: _toStringList(data['immediate_actions']),
      warningSigns: _toStringList(data['warning_signs']),
      recommendation: (data['recommendation'] ?? '').toString(),
      confidence: (data['confidence'] is num)
          ? (data['confidence'] as num).toDouble()
          : 0.0,
      source: (json['source'] ?? '').toString(),
    );
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    }
    return const <String>[];
  }
}

class SideEffectAiService {
  SideEffectAiService._();
  static final SideEffectAiService instance = SideEffectAiService._();

  static const String _fallbackBaseUrl =
      'https://backend-medicare-ai-agent.onrender.com';

  String get _baseUrl {
    try {
      final configured = dotenv.env['SIDE_EFFECT_API_BASE_URL']?.trim() ?? '';
      if (configured.isNotEmpty) {
        return configured;
      }
    } catch (_) {}
    return _fallbackBaseUrl;
  }

  Uri get _endpointUri =>
      Uri.parse('${_baseUrl.replaceAll(RegExp(r'/+$'), '')}/api/v1/side-effects/analyze');

  Future<SideEffectAnalysisResult> analyze(SideEffectAnalysisRequest request) async {
    final response = await http.post(
      _endpointUri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('AI API failed (${response.statusCode}): ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid response format from AI API');
    }
    return SideEffectAnalysisResult.fromJson(decoded);
  }
}

