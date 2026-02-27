import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguageController {
  AppLanguageController._();
  static final AppLanguageController instance = AppLanguageController._();

  static const String _prefsKey = 'preferred_language_code';
  static const List<String> supportedCodes = <String>['en', 'hi', 'mr'];
  final ValueNotifier<Locale> localeNotifier =
      ValueNotifier<Locale>(const Locale('en'));

  bool _initialized = false;

  bool isSupported(String code) => supportedCodes.contains(code);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    String? resolvedCode;
    final prefs = await SharedPreferences.getInstance();
    final localCode = (prefs.getString(_prefsKey) ?? '').trim();
    if (isSupported(localCode)) {
      resolvedCode = localCode;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      try {
        final doc =
            await FirebaseFirestore.instance.collection('patients').doc(uid).get();
        final remoteCode = (doc.data()?['languageCode'] ?? '').toString().trim();
        if (isSupported(remoteCode)) {
          resolvedCode = remoteCode;
        }
      } catch (_) {}
    }

    if (resolvedCode != null && isSupported(resolvedCode)) {
      localeNotifier.value = Locale(resolvedCode);
    }
  }

  Future<void> setLanguageCode(String code) async {
    if (!isSupported(code)) {
      return;
    }
    localeNotifier.value = Locale(code);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, code);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('patients').doc(uid).set(
          {
            'languageCode': code,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } catch (_) {}
    }
  }
}
