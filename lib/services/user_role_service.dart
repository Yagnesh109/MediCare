import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AppUserRole {
  patient,
  caregiver,
}

class UserRoleService {
  UserRoleService._();
  static final UserRoleService instance = UserRoleService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _roleToString(AppUserRole role) {
    switch (role) {
      case AppUserRole.patient:
        return 'patient';
      case AppUserRole.caregiver:
        return 'caregiver';
    }
  }

  AppUserRole? _roleFromString(String raw) {
    switch (raw) {
      case 'patient':
        return AppUserRole.patient;
      case 'caregiver':
        return AppUserRole.caregiver;
      default:
        return null;
    }
  }

  Future<void> ensureUserDoc() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = _firestore.collection('users').doc(user.uid);
    await doc.set(
      <String, dynamic>{
        'uid': user.uid,
        'email': user.email ?? '',
        'displayName': user.displayName ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<AppUserRole?> getCurrentRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final snap = await _firestore.collection('users').doc(user.uid).get();
    final roleRaw = (snap.data()?['selectedRole'] ?? '').toString();
    return _roleFromString(roleRaw);
  }

  Stream<AppUserRole?> roleStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream<AppUserRole?>.empty();
    }

    return _firestore.collection('users').doc(user.uid).snapshots().map((doc) {
      final raw = (doc.data()?['selectedRole'] ?? '').toString();
      return _roleFromString(raw);
    });
  }

  Future<void> setCurrentRole(AppUserRole role) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).set(
      <String, dynamic>{
        'selectedRole': _roleToString(role),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
