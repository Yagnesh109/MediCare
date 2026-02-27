import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class MedicalChatRequest {
  MedicalChatRequest({
    required this.userMessage,
    this.prescriptionImageBase64 = '',
    this.prescriptionImageMimeType = '',
    this.history = const <String>[],
  });

  final String userMessage;
  final String prescriptionImageBase64;
  final String prescriptionImageMimeType;
  final List<String> history;

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'user_message': userMessage,
      'history': history,
    };
    final imageData = prescriptionImageBase64.trim();
    if (imageData.isNotEmpty) {
      final mime = prescriptionImageMimeType.trim().isEmpty
          ? 'image/jpeg'
          : prescriptionImageMimeType.trim();
      payload['prescription_image_base64'] = imageData;
      payload['prescription_image_mime_type'] = mime;
    }
    return payload;
  }
}

class MedicalChatResult {
  MedicalChatResult({
    required this.reply,
    required this.medicineUses,
    required this.healthGuidance,
    required this.dietGuidance,
    required this.exerciseGuidance,
    required this.precautions,
    required this.emergency,
    required this.source,
  });

  final String reply;
  final List<String> medicineUses;
  final List<String> healthGuidance;
  final List<String> dietGuidance;
  final List<String> exerciseGuidance;
  final List<String> precautions;
  final bool emergency;
  final String source;

  factory MedicalChatResult.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
    return MedicalChatResult(
      reply: (data['reply'] ?? '').toString(),
      medicineUses: _toStringList(data['medicine_uses']),
      healthGuidance: _toStringList(data['health_guidance']),
      dietGuidance: _toStringList(data['diet_guidance']),
      exerciseGuidance: _toStringList(data['exercise_guidance']),
      precautions: _toStringList(data['precautions']),
      emergency: data['emergency'] == true,
      source: (json['source'] ?? '').toString(),
    );
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }
    return const <String>[];
  }
}

class MedicalChatService {
  MedicalChatService._();
  static final MedicalChatService instance = MedicalChatService._();

  static const String _fallbackBaseUrl =
      'https://backend-medicare-ai-agent.onrender.com';

  String get _baseUrl {
    try {
      final direct = dotenv.env['AI_CHAT_API_BASE_URL']?.trim() ?? '';
      if (direct.isNotEmpty) {
        return direct;
      }
      final shared = dotenv.env['SIDE_EFFECT_API_BASE_URL']?.trim() ?? '';
      if (shared.isNotEmpty) {
        return shared;
      }
    } catch (_) {}
    return _fallbackBaseUrl;
  }

  Uri get _endpointUri => Uri.parse(
      '${_baseUrl.replaceAll(RegExp(r'/+$'), '')}/api/v1/assistant/chat');

  Future<MedicalChatResult> chat(MedicalChatRequest request) async {
    final response = await http.post(
      _endpointUri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('AI chat failed (${response.statusCode}): ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid response format from AI chat API');
    }
    return MedicalChatResult.fromJson(decoded);
  }
}
