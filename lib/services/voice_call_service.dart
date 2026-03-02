import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class VoiceCallService {
  VoiceCallService._();
  static final VoiceCallService instance = VoiceCallService._();

  static const String _fallbackBaseUrl =
      'https://backend-medicare-ai-agent.onrender.com';

  String get _baseUrl {
    try {
      final direct = dotenv.env['VOICE_CALL_API_BASE_URL']?.trim() ?? '';
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
      '${_baseUrl.replaceAll(RegExp(r'/+$'), '')}/api/v1/voice/reminder/call');

  Future<void> triggerReminderCall({
    required String toPhone,
    required String patientName,
    required String caregiverName,
    required String medicineName,
    required String dosage,
    required String scheduledTime,
    required String dateKey,
    required bool selfMode,
  }) async {
    final payload = <String, dynamic>{
      'to_phone': toPhone,
      'patient_name': patientName,
      'caregiver_name': caregiverName,
      'medicine_name': medicineName,
      'dosage': dosage,
      'scheduled_time': scheduledTime,
      'date_key': dateKey,
      'mode': selfMode ? 'self_patient' : 'caregiver_patient',
    };

    final response = await http.post(
      _endpointUri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Voice reminder call failed (${response.statusCode}): ${response.body}',
      );
    }
  }
}
