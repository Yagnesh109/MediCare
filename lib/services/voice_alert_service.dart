import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VoiceAlertService {
  VoiceAlertService._();
  static final VoiceAlertService instance = VoiceAlertService._();

  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  static const String _prefsKey = 'voice_alert_enabled';
  final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(true);

  bool get isEnabled => enabledNotifier.value;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await _loadPreference();
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
    } catch (e) {
      debugPrint('Voice alert init failed: $e');
    }
  }

  Future<void> _loadPreference() async {
    bool? resolved;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_prefsKey)) {
        resolved = prefs.getBool(_prefsKey);
      }
    } catch (_) {}

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      try {
        final doc =
            await FirebaseFirestore.instance.collection('patients').doc(uid).get();
        final remote = doc.data()?['voiceAlertsEnabled'];
        if (remote is bool) {
          resolved = remote;
        }
      } catch (_) {}
    }

    enabledNotifier.value = resolved ?? true;
  }

  Future<void> setEnabled(bool value) async {
    enabledNotifier.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (_) {}

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('patients').doc(uid).set(
          {
            'voiceAlertsEnabled': value,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } catch (_) {}
    }
  }

  Future<void> speakReminder({
    required String medicineName,
    required String time,
  }) async {
    if (!enabledNotifier.value) {
      return;
    }
    final name = medicineName.trim().isEmpty ? 'your medicine' : medicineName.trim();
    final spokenTime = time.trim().isEmpty ? 'now' : time.trim();
    final message = 'Hello, This is $name $spokenTime';
    try {
      await init();
      await _tts.stop();
      await _tts.speak(message);
    } catch (e) {
      debugPrint('Voice reminder failed: $e');
    }
  }
}
