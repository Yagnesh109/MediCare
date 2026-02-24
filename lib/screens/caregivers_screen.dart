import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:medicare_app/app.dart';
import 'package:medicare_app/widgets/app_bar_pulse_indicator.dart';
import 'package:medicare_app/widgets/app_navigation_drawer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class CaregiversScreen extends StatelessWidget {
  const CaregiversScreen({super.key});

  String _initialsFromName(String name, String email) {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) {
      final parts =
          trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
      if (parts.length > 1) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    final local = email.split('@').first.trim();
    if (local.isEmpty) return 'CG';
    return local.substring(0, local.length >= 2 ? 2 : 1).toUpperCase();
  }

  String _googlePhotoUrlFromEmail(String email) {
    final normalized = email.trim();
    if (normalized.isEmpty) {
      return '';
    }
    return 'https://www.google.com/s2/photos/profile/${Uri.encodeComponent(normalized)}';
  }

  String _resolveCaregiverPhotoUrl(Map<String, dynamic> data, String email) {
    final stored = (data['profileImageUrl'] ?? '').toString().trim();
    if (stored.isNotEmpty) {
      return stored;
    }
    return _googlePhotoUrlFromEmail(email);
  }

  Future<void> _callCaregiver(BuildContext context, String rawPhone) async {
    final digits = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone not available')),
      );
      return;
    }

    // Android: request runtime phone permission and place the call using ACTION_CALL.
    if (Platform.isAndroid) {
      final permission = await Permission.phone.request();
      if (permission.isGranted) {
        final intent = AndroidIntent(
          action: 'android.intent.action.CALL',
          data: 'tel:$digits',
        );
        await intent.launch();
        if (context.mounted) {
          return;
        }
      }
    }

    // Fallback: open dialer with number pre-filled.
    final uri = Uri(scheme: 'tel', path: digits);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to place call')),
      );
    }
  }

  Future<void> _openCaregiverForm(
    BuildContext context, {
    DocumentSnapshot<Map<String, dynamic>>? caregiverDoc,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _CaregiverFormDialog(caregiverDoc: caregiverDoc),
    );
  }

  Future<void> _deleteCaregiver(
    BuildContext context,
    String docId,
  ) async {
    await FirebaseFirestore.instance
        .collection('caregivers')
        .doc(docId)
        .delete();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Caregiver removed')),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: highlight ? const Color(0xFFE6F1FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF2E63C5), size: 28),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF1F3A70),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final compact = screenWidth < 380;
    final user = FirebaseAuth.instance.currentUser;
    final patientId = user?.uid;

    if (patientId == null || patientId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Please login again to manage caregivers.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        flexibleSpace: const AppBarPulseBackground(),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text('Caregivers'),
        ),
      ),
      drawer: const AppNavigationDrawer(
        currentRoute: MyApp.routeCaregivers,
      ),
      floatingActionButton: SizedBox(
        width: compact ? 152 : 188,
        height: compact ? 80 : 96,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFDCE9FF),
            borderRadius: BorderRadius.circular(32),
            boxShadow: const [
              BoxShadow(
                color: Color(0x332E84F3),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(32),
              onTap: () => _openCaregiverForm(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_add_alt_1,
                      color: Color(0xFF1F3A70), size: 34),
                  const SizedBox(width: 12),
                  Text(
                    'Add',
                    style: TextStyle(
                      color: const Color(0xFF1F3A70),
                      fontSize: compact ? 20 : 24,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('caregivers')
            .where('patientId', isEqualTo: patientId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load caregivers'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text('No caregivers added yet'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final name = (data['name'] ?? '').toString();
              final email = (data['email'] ?? '').toString();
              final phone = (data['phone'] ?? '').toString();
              final photoUrl = _resolveCaregiverPhotoUrl(data, email);
              final initials = _initialsFromName(name, email);

              return Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FF),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFFDCE5F2)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x180F172A),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 92,
                          height: 92,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF2E84F3), Color(0xFF2D5FB8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: ClipOval(
                            child: photoUrl.isEmpty
                                ? Center(
                                    child: Text(
                                      initials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 40,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  )
                                : Image.network(
                                    photoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, _, __) => Center(
                                      child: Text(
                                        initials,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 40,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.isEmpty ? 'Unnamed caregiver' : name,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (email.isNotEmpty)
                                Text(
                                  email,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                              if (phone.isNotEmpty)
                                Text(
                                  phone,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFDDE5F3)),
                      ),
                      child: Row(
                        children: [
                          _actionButton(
                            icon: Icons.call,
                            label: 'Call',
                            highlight: true,
                            onTap: () => _callCaregiver(context, phone),
                          ),
                          const SizedBox(
                            height: 42,
                            child: VerticalDivider(color: Color(0xFFD8E0EE)),
                          ),
                          _actionButton(
                            icon: Icons.edit_outlined,
                            label: 'Edit',
                            onTap: () => _openCaregiverForm(
                              context,
                              caregiverDoc: doc,
                            ),
                          ),
                          const SizedBox(
                            height: 42,
                            child: VerticalDivider(color: Color(0xFFD8E0EE)),
                          ),
                          _actionButton(
                            icon: Icons.delete_outline,
                            label: 'Delete',
                            onTap: () => _deleteCaregiver(context, doc.id),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CaregiverFormDialog extends StatefulWidget {
  const _CaregiverFormDialog({this.caregiverDoc});

  final DocumentSnapshot<Map<String, dynamic>>? caregiverDoc;

  @override
  State<_CaregiverFormDialog> createState() => _CaregiverFormDialogState();
}

class _CaregiverFormDialogState extends State<_CaregiverFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isSaving = false;

  String _googlePhotoUrlFromEmail(String email) {
    final normalized = email.trim();
    if (normalized.isEmpty) {
      return '';
    }
    return 'https://www.google.com/s2/photos/profile/${Uri.encodeComponent(normalized)}';
  }

  @override
  void initState() {
    super.initState();
    final data = widget.caregiverDoc?.data();
    if (data != null) {
      _nameController.text = (data['name'] ?? '').toString();
      _emailController.text = (data['email'] ?? '').toString();
      _phoneController.text = (data['phone'] ?? '').toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login again and retry.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'profileImageUrl': _googlePhotoUrlFromEmail(_emailController.text.trim()),
      'patientId': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      final doc = widget.caregiverDoc;
      if (doc == null) {
        payload['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('caregivers').add(payload);
      } else {
        await FirebaseFirestore.instance
            .collection('caregivers')
            .doc(doc.id)
            .set(payload, SetOptions(merge: true));
      }

      if (!mounted) {
        return;
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(doc == null ? 'Caregiver added' : 'Caregiver updated'),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save caregiver: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.caregiverDoc != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Caregiver' : 'Add Caregiver'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter caregiver name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter caregiver email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter caregiver phone';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
