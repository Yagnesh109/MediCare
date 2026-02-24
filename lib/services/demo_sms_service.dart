import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class DemoSmsService {
  DemoSmsService._();
  static final DemoSmsService instance = DemoSmsService._();

  String get _accountSid => _readEnv('TWILIO_ACCOUNT_SID');
  String get _authToken => _readEnv('TWILIO_AUTH_TOKEN');
  String get _fromNumber => _readEnv('TWILIO_FROM_NUMBER');

  bool get isConfigured =>
      _accountSid.isNotEmpty && _authToken.isNotEmpty && _fromNumber.isNotEmpty;

  Future<void> sendMissedDoseSms({
    required String toPhone,
    required String patientIdentifier,
    required String medicineName,
    required String dosage,
    required String scheduledTime,
    required String dateKey,
  }) async {
    await _ensureDotEnvLoaded();

    if (!isConfigured) {
      throw Exception(
        'Twilio SMS is not configured. Set TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, and TWILIO_FROM_NUMBER in .env',
      );
    }

    final toNormalized = _normalizePhone(toPhone);
    if (toNormalized.isEmpty) {
      throw Exception('Invalid caregiver phone number: $toPhone');
    }

    final uri = Uri.parse(
      'https://api.twilio.com/2010-04-01/Accounts/$_accountSid/Messages.json',
    );

    final body =
        'Medicare Alert: Patient $patientIdentifier may have missed a dose. '
        'Medicine: $medicineName ($dosage), scheduled at $scheduledTime on $dateKey.';

    final auth = base64Encode(utf8.encode('$_accountSid:$_authToken'));

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Basic $auth',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'From': _fromNumber,
        'To': toNormalized,
        'Body': body,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Twilio SMS failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  String _readEnv(String key) {
    try {
      return dotenv.env[key]?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _ensureDotEnvLoaded() async {
    try {
      if (!dotenv.isInitialized) {
        await dotenv.load(fileName: '.env');
      }
    } catch (_) {}
  }

  String _normalizePhone(String input) {
    var value = input.trim();
    if (value.isEmpty) return '';

    // Keep leading '+' and digits only.
    if (value.startsWith('+')) {
      value = '+${value.substring(1).replaceAll(RegExp(r'[^0-9]'), '')}';
      return value.length > 1 ? value : '';
    }

    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    // Default India country code for local 10-digit numbers.
    if (digits.length == 10) {
      return '+91$digits';
    }
    if (digits.startsWith('91') && digits.length == 12) {
      return '+$digits';
    }
    return '+$digits';
  }
}
