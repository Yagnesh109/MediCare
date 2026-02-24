import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:medicare_app/app.dart';
import 'package:medicare_app/services/side_effect_ai_service.dart';
import 'package:medicare_app/widgets/app_bar_pulse_indicator.dart';
import 'package:medicare_app/widgets/app_navigation_drawer.dart';

class SideEffectCheckerScreen extends StatefulWidget {
  const SideEffectCheckerScreen({super.key});

  @override
  State<SideEffectCheckerScreen> createState() =>
      _SideEffectCheckerScreenState();
}

class _SideEffectCheckerScreenState extends State<SideEffectCheckerScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _medicineController = TextEditingController();
  final TextEditingController _doseController = TextEditingController();
  final TextEditingController _symptomsController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _conditionsController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isLoading = false;
  SideEffectAnalysisResult? _result;
  String? _error;
  String _selectedGender = '';

  @override
  void initState() {
    super.initState();
    _prefillProfileDetails();
  }

  @override
  void dispose() {
    _medicineController.dispose();
    _doseController.dispose();
    _symptomsController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    _conditionsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _prefillProfileDetails() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(uid)
          .get();
      final data = doc.data();
      if (data == null || !mounted) {
        return;
      }

      final gender = (data['gender'] ?? '').toString().trim();
      final ageFromProfile = (data['age'] ?? '').toString().trim();
      final dobRaw = (data['dateOfBirth'] ?? '').toString().trim();

      var resolvedAge = ageFromProfile;
      if (resolvedAge.isEmpty && dobRaw.isNotEmpty) {
        final dob = DateTime.tryParse(dobRaw);
        if (dob != null) {
          final now = DateTime.now();
          var years = now.year - dob.year;
          final birthdayThisYear = DateTime(now.year, dob.month, dob.day);
          if (now.isBefore(birthdayThisYear)) {
            years -= 1;
          }
          resolvedAge = years < 0 ? '' : years.toString();
        }
      }

      setState(() {
        if (_ageController.text.trim().isEmpty && resolvedAge.isNotEmpty) {
          _ageController.text = resolvedAge;
        }
        if (_genderController.text.trim().isEmpty && gender.isNotEmpty) {
          _genderController.text = gender;
          _selectedGender = gender;
        }
      });
    } catch (_) {
      // Keep side-effect checker usable even if profile fetch fails.
    }
  }

  Future<void> _analyze() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final symptoms = _splitCommaSeparated(_symptomsController.text);
    if (symptoms.isEmpty) {
      setState(() {
        _error = 'Please enter at least one symptom.';
      });
      return;
    }

    final ageRaw = _ageController.text.trim();
    final age = ageRaw.isEmpty ? null : int.tryParse(ageRaw);

    setState(() {
      _isLoading = true;
      _result = null;
      _error = null;
    });

    try {
      final result = await SideEffectAiService.instance.analyze(
        SideEffectAnalysisRequest(
          medicineName: _medicineController.text.trim(),
          dose: _doseController.text.trim(),
          symptoms: symptoms,
          patientAge: age,
          patientGender: _genderController.text.trim(),
          knownConditions: _splitCommaSeparated(_conditionsController.text),
          extraNotes: _notesController.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _result = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<String> _splitCommaSeparated(String input) {
    return input
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.deepOrange;
      case 'emergency':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _bulletList(String title, List<String> items) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('- $item'),
            )),
        const SizedBox(height: 10),
      ],
    );
  }

  InputDecoration _pillInputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 20,
        color: Color(0xFF374151),
      ),
      prefixIcon: Icon(icon, size: 34, color: const Color(0xFF374151)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFFC9DBEE)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFFC9DBEE)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const AppBarPulseBackground(),
        title: const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text('Side Effect Checker'),
        ),
      ),
      drawer: const AppNavigationDrawer(
        currentRoute: MyApp.routeSideEffects,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FC),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFFDEE6F2)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x150F172A),
                    blurRadius: 14,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.medical_information_rounded,
                              color: Color(0xFF1E5E9F), size: 34),
                          SizedBox(width: 10),
                          Text(
                            'Check Symptoms After Medicine',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F2A59),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _medicineController,
                        decoration: _pillInputDecoration(
                          hint: 'Medicine Name',
                          icon: Icons.medication_outlined,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Medicine name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _doseController,
                        decoration: _pillInputDecoration(
                          hint: 'Dose (optional)',
                          icon: Icons.hourglass_empty_rounded,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _symptomsController,
                        minLines: 1,
                        maxLines: 3,
                        decoration: _pillInputDecoration(
                          hint: 'Symptoms (comma separated)',
                          icon: Icons.sick_outlined,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter at least one symptom';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Age (optional)',
                        style:
                            TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        decoration: _pillInputDecoration(
                          hint: 'Age',
                          icon: Icons.calendar_month_outlined,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Gender (optional)',
                        style:
                            TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        initialValue:
                            _selectedGender.isEmpty ? null : _selectedGender,
                        decoration: _pillInputDecoration(
                          hint: 'Select gender',
                          icon: Icons.person_outline,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(
                              value: 'Female', child: Text('Female')),
                          DropdownMenuItem(
                              value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (value) {
                          final selected = value ?? '';
                          setState(() => _selectedGender = selected);
                          _genderController.text = selected;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _conditionsController,
                        decoration: _pillInputDecoration(
                          hint: 'Known conditions (comma separated)',
                          icon: Icons.medical_services_outlined,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _notesController,
                        minLines: 1,
                        maxLines: 3,
                        decoration: _pillInputDecoration(
                          hint: 'Extra notes (optional)',
                          icon: Icons.note_alt_outlined,
                        ),
                      ),
                      const SizedBox(height: 14),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2E84F3), Color(0xFF63C6FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _analyze,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.analytics_outlined),
                            label: Text(_isLoading
                                ? 'Analyzing...'
                                : 'Analyze Side Effects'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Analysis Result',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          Chip(
                            label: Text(_result!.severity.toUpperCase()),
                            backgroundColor: _severityColor(_result!.severity)
                                .withValues(alpha: 0.12),
                            labelStyle: TextStyle(
                              color: _severityColor(_result!.severity),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Urgency: ${_result!.urgency}'),
                      Text(
                        'Doctor consultation needed: '
                        '${_result!.doctorConsultationNeeded ? 'Yes' : 'No'}',
                      ),
                      Text(
                          'Confidence: ${(_result!.confidence * 100).toStringAsFixed(0)}%'),
                      Text('Source: ${_result!.source}'),
                      const SizedBox(height: 10),
                      if (_result!.recommendation.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            _result!.recommendation,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      _bulletList('Possible Reasons', _result!.possibleReasons),
                      _bulletList(
                          'Immediate Actions', _result!.immediateActions),
                      _bulletList('Warning Signs', _result!.warningSigns),
                      const Divider(),
                      const Text(
                        'This is guidance only, not a medical diagnosis.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
