import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PhiE2eeService {
  PhiE2eeService._();
  static final PhiE2eeService instance = PhiE2eeService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static final _alg = AesGcm.with256bits();
  static const _schemaVersion = 1;

  String _keyStorageName(String uid) => 'phi_master_key_v1_$uid';

  Future<SecretKey> _getOrCreateMasterKey() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      throw StateError('User is not authenticated for E2EE key access.');
    }

    final keyName = _keyStorageName(uid);
    final stored = await _storage.read(key: keyName);
    if (stored != null && stored.isNotEmpty) {
      return SecretKey(base64Decode(stored));
    }

    final random = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    final encoded = base64Encode(bytes);
    await _storage.write(key: keyName, value: encoded);
    return SecretKey(bytes);
  }

  Future<Map<String, dynamic>> encryptPhiMap({
    required Map<String, dynamic> plain,
    required String domain,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      throw StateError('User is not authenticated for E2EE encryption.');
    }

    final key = await _getOrCreateMasterKey();
    final aad = utf8.encode('uid=$uid|domain=$domain|v=$_schemaVersion');
    final nonce = _alg.newNonce();
    final clearBytes = utf8.encode(jsonEncode(plain));
    final box = await _alg.encrypt(
      clearBytes,
      secretKey: key,
      nonce: nonce,
      aad: aad,
    );

    return {
      'ownerUid': uid,
      'phiEnc': {
        'v': _schemaVersion,
        'alg': 'AES-256-GCM',
        'domain': domain,
        'nonce': base64Encode(box.nonce),
        'cipherText': base64Encode(box.cipherText),
        'mac': base64Encode(box.mac.bytes),
      },
    };
  }

  Future<Map<String, dynamic>> decryptPhiMap({
    required Map<String, dynamic> stored,
    required String domain,
  }) async {
    final wrapped = stored['phiEnc'];
    if (wrapped is! Map<String, dynamic>) {
      return stored;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      throw StateError('User is not authenticated for E2EE decryption.');
    }

    final nonce = (wrapped['nonce'] ?? '').toString();
    final cipherText = (wrapped['cipherText'] ?? '').toString();
    final mac = (wrapped['mac'] ?? '').toString();
    final encDomain = (wrapped['domain'] ?? '').toString();
    if (nonce.isEmpty || cipherText.isEmpty || mac.isEmpty) {
      throw StateError('Encrypted payload is malformed.');
    }
    if (encDomain.isNotEmpty && encDomain != domain) {
      throw StateError('Encrypted payload domain mismatch.');
    }

    final key = await _getOrCreateMasterKey();
    final aad = utf8.encode('uid=$uid|domain=$domain|v=$_schemaVersion');
    final box = SecretBox(
      base64Decode(cipherText),
      nonce: base64Decode(nonce),
      mac: Mac(base64Decode(mac)),
    );
    final clear = await _alg.decrypt(
      box,
      secretKey: key,
      aad: aad,
    );
    final decoded = jsonDecode(utf8.decode(clear));
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Decrypted payload is not a map.');
    }
    return decoded;
  }
}
