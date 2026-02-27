import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:medicare_app/l10n/app_localizations.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:medicare_app/app.dart';
import 'package:medicare_app/models/patient_profile.dart';
import 'package:medicare_app/services/phi_e2ee_service.dart';
import 'package:medicare_app/widgets/app_bar_pulse_indicator.dart';
import 'package:medicare_app/widgets/app_navigation_drawer.dart';
import 'package:medicare_app/widgets/chatbot_fab.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bloodGroupController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _allergiesController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  DateTime? _dob;
  String _gender = '';
  String _profileImageBase64 = '';
  bool _loading = true;
  bool _saving = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bloodGroupController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _allergiesController.dispose();
    super.dispose();
  }

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _logout(BuildContext context) async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}

    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      MyApp.routeLogin,
      (route) => false,
    );
  }

  int? _calculateAge(DateTime? dob) {
    if (dob == null) return null;
    final now = DateTime.now();
    var age = now.year - dob.year;
    final birthdayThisYear = DateTime(now.year, dob.month, dob.day);
    if (now.isBefore(birthdayThisYear)) {
      age -= 1;
    }
    return age < 0 ? null : age;
  }

  double? _calculateBmi() {
    final weight = double.tryParse(_weightController.text.trim());
    final heightCm = double.tryParse(_heightController.text.trim());
    if (weight == null || heightCm == null || weight <= 0 || heightCm <= 0) {
      return null;
    }
    final heightM = heightCm / 100;
    return weight / (heightM * heightM);
  }

  String _bmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  Color _bmiColor(double bmi) {
    if (bmi < 18.5) return const Color(0xFF42A5F5);
    if (bmi < 25) return const Color(0xFF43A047);
    if (bmi < 30) return const Color(0xFFF9A825);
    return const Color(0xFFE53935);
  }

  double _bmiProgress(double bmi) {
    final normalized = (bmi - 10) / 30;
    return normalized.clamp(0.0, 1.0);
  }

  Uint8List? _profileImageBytes() {
    if (_profileImageBase64.isEmpty) return null;
    try {
      return base64Decode(_profileImageBase64);
    } catch (_) {
      return null;
    }
  }

  ImageProvider<Object>? _profileImageProvider(User? user) {
    final bytes = _profileImageBytes();
    if (bytes != null) {
      return MemoryImage(bytes);
    }
    final photoUrl = (user?.photoURL ?? '').trim();
    if (photoUrl.isNotEmpty) {
      return NetworkImage(photoUrl);
    }
    return null;
  }

  Future<void> _pickProfileImage() async {
    if (!_isEditing) {
      setState(() => _isEditing = true);
    }
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 600,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _profileImageBase64 = base64Encode(bytes);
    });
  }

  Future<void> _loadProfile() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    final doc =
        await FirebaseFirestore.instance.collection('patients').doc(uid).get();
    final stored = doc.data() ?? <String, dynamic>{};
    final data = await PhiE2eeService.instance.decryptPhiMap(
      stored: stored,
      domain: 'patient_profile',
    );
    final profile = PatientProfile.fromMap(data);
    final user = FirebaseAuth.instance.currentUser;

    _nameController.text = profile.name.isEmpty
        ? (user?.displayName ?? '').toString()
        : profile.name;
    _bloodGroupController.text = profile.bloodGroup;
    _weightController.text = profile.weightKg;
    _heightController.text = profile.heightCm;
    _allergiesController.text = profile.allergies;
    _gender = profile.gender;
    _profileImageBase64 = profile.profileImageBase64;

    final rawDob = profile.dateOfBirth;
    if (rawDob.isNotEmpty) {
      _dob = DateTime.tryParse(rawDob);
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
    );
    if (selected == null) return;
    setState(() {
      _dob = DateTime(selected.year, selected.month, selected.day);
    });
  }

  String _formatDate(DateTime? date) {
    final l10n = AppLocalizations.of(context)!;
    if (date == null) return l10n.notSet;
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    return '$dd/$mm/${date.year}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;
    final allergies = _allergiesController.text.trim();
    if (allergies.length > 300) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Allergies must be 300 characters or less')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final profile = PatientProfile(
        name: _nameController.text.trim(),
        bloodGroup: _bloodGroupController.text.trim(),
        gender: _gender,
        dateOfBirth: _dob == null
            ? ''
            : '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}',
        age: _calculateAge(_dob),
        weightKg: _weightController.text.trim(),
        heightCm: _heightController.text.trim(),
        profileImageBase64: _profileImageBase64,
        allergies: allergies,
      );
      final encrypted = await PhiE2eeService.instance.encryptPhiMap(
        plain: profile.toMap(),
        domain: 'patient_profile',
      );
      await FirebaseFirestore.instance.collection('patients').doc(uid).set(
        {
          ...encrypted,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final user = FirebaseAuth.instance.currentUser;
      final name = _nameController.text.trim();
      if (user != null && name.isNotEmpty && user.displayName != name) {
        await user.updateDisplayName(name);
      }

      if (!mounted) return;
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.profileSaved)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    final email = (user?.email ?? '').trim();
    final age = _calculateAge(_dob);
    final bmi = _calculateBmi();
    final bmiColor = bmi == null ? Colors.blueGrey : _bmiColor(bmi);
    final avatarImage = _profileImageProvider(user);

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
        title: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(l10n.profile),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              tooltip: 'Edit',
              onPressed:
                  _loading ? null : () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit),
            )
          else
            IconButton(
              tooltip: 'Save',
              onPressed: (_saving || _loading) ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
            ),
        ],
      ),
      drawer: const AppNavigationDrawer(
        currentRoute: MyApp.routeProfile,
      ),
      floatingActionButton: const ChatbotFab(heroTag: 'chatbot_profile'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundColor: const Color(0x221565C0),
                                  backgroundImage: avatarImage,
                                  child: avatarImage == null
                                      ? const Icon(
                                          Icons.person,
                                          size: 44,
                                          color: Color(0xFF1565C0),
                                        )
                                      : null,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _pickProfileImage,
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1565C0),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                              color: Colors.white, width: 2),
                                        ),
                                        child: const Icon(
                                          Icons.edit,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _nameController,
                            enabled: _isEditing,
                            decoration: InputDecoration(
                              labelText: l10n.patientName,
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter patient name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            initialValue: email,
                            enabled: false,
                            decoration: InputDecoration(
                              labelText: l10n.email,
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _gender.isEmpty ? null : _gender,
                            decoration: InputDecoration(
                              labelText: l10n.gender,
                              prefixIcon: Icon(Icons.wc_outlined),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'Male', child: Text('Male')),
                              DropdownMenuItem(
                                  value: 'Female', child: Text('Female')),
                              DropdownMenuItem(
                                  value: 'Other', child: Text('Other')),
                            ],
                            onChanged: !_isEditing
                                ? null
                                : (value) {
                                    setState(() {
                                      _gender = value ?? '';
                                    });
                                  },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _bloodGroupController,
                            enabled: _isEditing,
                            decoration: InputDecoration(
                              labelText: l10n.bloodGroup,
                              prefixIcon: Icon(Icons.bloodtype_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: _isEditing ? _pickDob : null,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: l10n.dateOfBirth,
                                prefixIcon: Icon(Icons.cake_outlined),
                              ),
                              child: Text(_formatDate(_dob)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          InputDecorator(
                            decoration: InputDecoration(
                              labelText: l10n.ageCalculated,
                              prefixIcon: Icon(Icons.calendar_today_outlined),
                            ),
                            child: Text(age?.toString() ?? 'Not available'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _weightController,
                            enabled: _isEditing,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: l10n.weightKg,
                              prefixIcon: Icon(Icons.monitor_weight_outlined),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _heightController,
                            enabled: _isEditing,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: l10n.heightCm,
                              prefixIcon: Icon(Icons.height_outlined),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _allergiesController,
                            enabled: _isEditing,
                            minLines: 2,
                            maxLines: 4,
                            maxLength: 300,
                            decoration: InputDecoration(
                              labelText: l10n.allergies,
                              alignLabelWithHint: true,
                              prefixIcon: Icon(Icons.warning_amber_outlined),
                              hintText: 'e.g. Penicillin, peanuts, dust',
                            ),
                            validator: (value) {
                              final trimmed = (value ?? '').trim();
                              if (trimmed.length > 300) {
                                return 'Allergies must be 300 characters or less';
                              }
                              return null;
                            },
                          ),
                          if (!_isEditing)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                l10n.allergiesDisplay(
                                  _allergiesController.text.trim().isEmpty
                                      ? l10n.notSet
                                      : _allergiesController.text.trim(),
                                ),
                                style: const TextStyle(
                                  color: Color(0xFF374151),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                colors: [
                                  bmiColor.withValues(alpha: 0.15),
                                  bmiColor.withValues(alpha: 0.05),
                                ],
                              ),
                              border: Border.all(
                                  color: bmiColor.withValues(alpha: 0.45)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.bmi,
                                  style: TextStyle(
                                    color: bmiColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  bmi == null
                                      ? 'Enter weight and height to calculate BMI'
                                      : '${bmi.toStringAsFixed(1)} (${_bmiCategory(bmi)})',
                                  style: TextStyle(
                                    color: bmiColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (bmi != null) ...[
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      minHeight: 10,
                                      value: _bmiProgress(bmi),
                                      backgroundColor: Colors.grey.shade300,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          bmiColor),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Under',
                                          style: TextStyle(fontSize: 11)),
                                      Text('Normal',
                                          style: TextStyle(fontSize: 11)),
                                      Text('Over',
                                          style: TextStyle(fontSize: 11)),
                                      Text('Obese',
                                          style: TextStyle(fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout),
                  label: Text(l10n.logout),
                ),
              ],
            ),
    );
  }
}
