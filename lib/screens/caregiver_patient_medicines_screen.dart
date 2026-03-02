import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:medicare_app/app.dart';
import 'package:medicare_app/models/medicine.dart';
import 'package:medicare_app/services/dose_tracking_service.dart';
import 'package:medicare_app/services/notification_service.dart';
import 'package:medicare_app/services/phi_e2ee_service.dart';
import 'package:medicare_app/widgets/app_bar_pulse_indicator.dart';
import 'package:medicare_app/widgets/app_navigation_drawer.dart';

class CaregiverPatientMedicinesScreen extends StatefulWidget {
  const CaregiverPatientMedicinesScreen({super.key});

  @override
  State<CaregiverPatientMedicinesScreen> createState() =>
      _CaregiverPatientMedicinesScreenState();
}

class _CaregiverPatientMedicinesScreenState
    extends State<CaregiverPatientMedicinesScreen> {
  bool _didLoadArgs = false;
  String _patientRecordId = '';
  String _patientName = '';
  String _patientEmail = '';
  String _patientPhone = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadArgs) {
      return;
    }
    _didLoadArgs = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _patientRecordId = (args['patientRecordId'] ?? '').toString().trim();
      _patientName = (args['patientName'] ?? '').toString().trim();
      _patientEmail = (args['patientEmail'] ?? '').toString().trim();
      _patientPhone = (args['patientPhone'] ?? '').toString().trim();
    }
  }

  String _dateKey(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  DateTime? _tryParseDate(String rawDate) {
    try {
      return DateTime.parse(rawDate);
    } catch (_) {
      return null;
    }
  }

  List<DoseSchedule> _effectiveDoses(Medicine medicine) {
    if (medicine.doses.isNotEmpty) {
      return medicine.doses;
    }
    if (medicine.time.trim().isEmpty) {
      return const <DoseSchedule>[];
    }
    return <DoseSchedule>[
      DoseSchedule(
        time: medicine.time,
        mealRelation: 'anytime',
      ),
    ];
  }

  String _patientLogIdentity() {
    if (_patientRecordId.isEmpty) {
      return '';
    }
    return 'caregiver_patient:$_patientRecordId';
  }

  bool _isActiveToday(Medicine medicine, DateTime now) {
    final start = _tryParseDate(medicine.startDate);
    final end = _tryParseDate(medicine.endDate);
    if (start == null || end == null) {
      return false;
    }
    final day = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    return !day.isBefore(startDay) && !day.isAfter(endDay);
  }

  Future<void> _openAddMedicine() async {
    final result = await Navigator.pushNamed(
      context,
      MyApp.routeAddMedicine,
      arguments: <String, dynamic>{
        'targetPatient': <String, dynamic>{
          'recordId': _patientRecordId,
          'name': _patientName,
          'email': _patientEmail,
          'phone': _patientPhone,
        },
      },
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medicine saved')),
      );
    }
  }

  Future<void> _openEditMedicine(Medicine medicine) async {
    final result = await Navigator.pushNamed(
      context,
      MyApp.routeAddMedicine,
      arguments: <String, dynamic>{
        'targetPatient': <String, dynamic>{
          'recordId': _patientRecordId,
          'name': _patientName,
          'email': _patientEmail,
          'phone': _patientPhone,
        },
        'medicineId': medicine.id,
        'name': medicine.name,
        'dosage': medicine.dosage,
        'time': medicine.time,
        'doses': medicine.doses.map((d) => d.toMap()).toList(),
        'startDate': medicine.startDate,
        'endDate': medicine.endDate,
      },
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medicine updated')),
      );
    }
  }

  Future<void> _deleteMedicine(Medicine medicine) async {
    final medicineId = medicine.id;
    if (medicineId == null || medicineId.isEmpty) {
      return;
    }
    await FirebaseFirestore.instance.collection('medicines').doc(medicineId).delete();
    await NotificationService.instance.cancelMedicineReminders(
      id: medicineId.hashCode,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${medicine.name} deleted')),
    );
  }

  Future<void> _markTakenByCaregiver(Medicine medicine) async {
    final medicineId = medicine.id ?? '';
    if (medicineId.isEmpty) {
      return;
    }
    final todayKey = _dateKey(DateTime.now());
    final logs = await FirebaseFirestore.instance
        .collection('dose_logs')
        .where('medicineId', isEqualTo: medicineId)
        .where('dateKey', isEqualTo: todayKey)
        .get();
    final byDose = <String, String>{};
    for (final doc in logs.docs) {
      final data = doc.data();
      final key = (data['doseKey'] ?? '').toString();
      final status = (data['status'] ?? '').toString();
      if (key.isEmpty) continue;
      byDose[key] = status;
    }

    final doses = _effectiveDoses(medicine);
    if (doses.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No dose schedule configured')),
      );
      return;
    }

    DoseSchedule targetDose = doses.first;
    for (final dose in doses) {
      final status = byDose[dose.doseKey] ?? 'pending';
      if (status != 'taken' && status != 'missed') {
        targetDose = dose;
        break;
      }
    }

    await DoseTrackingService.instance.setDoseStatusFromNotification(
      medicineId: medicineId,
      medicineName: medicine.name,
      dosage: medicine.dosage,
      scheduledTime: targetDose.time,
      dateKey: todayKey,
      doseKey: targetDose.doseKey,
      mealRelation: targetDose.mealRelation,
      mealType: targetDose.mealType,
      status: 'taken',
      patientId: _patientLogIdentity(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Marked taken: ${medicine.name} (${targetDose.time})',
        ),
      ),
    );
    setState(() {});
  }

  Future<List<Medicine>> _decryptMedicines(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final result = <Medicine>[];
    for (final doc in docs) {
      try {
        final plain = await PhiE2eeService.instance.decryptPhiMap(
          stored: doc.data(),
          domain: 'medicine',
        );
        final targetRecordId = (plain['targetPatientRecordId'] ?? '').toString();
        if (_patientRecordId.isNotEmpty && targetRecordId != _patientRecordId) {
          continue;
        }
        result.add(Medicine.fromMap(plain, id: doc.id));
      } catch (_) {}
    }
    return result;
  }

  Future<Map<String, Set<String>>> _loadTodayResolvedDoseKeysByMedicine() async {
    final todayKey = _dateKey(DateTime.now());
    final snapshot = await FirebaseFirestore.instance
        .collection('dose_logs')
        .where('dateKey', isEqualTo: todayKey)
        .get();
    final byMedicine = <String, Set<String>>{};
    for (final doc in snapshot.docs) {
      final status = (doc.data()['status'] ?? '').toString();
      if (status != 'taken' && status != 'missed') {
        continue;
      }
      final medicineId = (doc.data()['medicineId'] ?? '').toString();
      final doseKey = (doc.data()['doseKey'] ?? '').toString();
      if (medicineId.isEmpty) {
        continue;
      }
      if (doseKey.isEmpty) {
        continue;
      }
      byMedicine.putIfAbsent(medicineId, () => <String>{}).add(doseKey);
    }
    return byMedicine;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Please login again')),
      );
    }
    if (_patientRecordId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Invalid patient selection')),
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
        title: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(_patientName.isEmpty ? 'Patient Medicines' : _patientName),
        ),
      ),
      drawer: const AppNavigationDrawer(
        currentRoute: MyApp.routeCaregiverPatientMedicines,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('medicines')
            .where('userId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load medicines'));
          }
          final docs = snapshot.data?.docs ?? const [];
          return FutureBuilder<List<Medicine>>(
            future: _decryptMedicines(docs),
            builder: (context, medicineSnapshot) {
              if (medicineSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final medicines = medicineSnapshot.data ?? const <Medicine>[];
              final now = DateTime.now();
              final activeToday = medicines
                  .where((medicine) => _isActiveToday(medicine, now))
                  .toList();

              return FutureBuilder<Map<String, Set<String>>>(
                future: _loadTodayResolvedDoseKeysByMedicine(),
                builder: (context, statusSnapshot) {
                  if (statusSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final resolvedByDose =
                      statusSnapshot.data ?? const <String, Set<String>>{};
                  final pending = activeToday.where((medicine) {
                    final id = medicine.id;
                    if (id == null || id.isEmpty) return true;
                    final doses = _effectiveDoses(medicine);
                    if (doses.isEmpty) return true;
                    final resolved = resolvedByDose[id] ?? const <String>{};
                    return doses.any((dose) => !resolved.contains(dose.doseKey));
                  }).toList();

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _patientName.isEmpty ? 'Patient' : _patientName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(_patientEmail.isEmpty ? '-' : _patientEmail),
                            Text(_patientPhone.isEmpty ? '-' : _patientPhone),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openAddMedicine,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Medicine'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Pending Medicines',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      if (pending.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('No pending medicines for today'),
                          ),
                        )
                      else
                        ...pending.map((medicine) {
                          return Card(
                            child: ListTile(
                              title: Text(
                                medicine.name.isEmpty
                                    ? 'Unnamed medicine'
                                    : medicine.name,
                              ),
                              subtitle: Text(
                                'Dosage: ${medicine.dosage}\n'
                                'Time: ${medicine.time}\n'
                                'Range: ${medicine.startDate} to ${medicine.endDate}',
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () => _markTakenByCaregiver(medicine),
                                    icon: const Icon(Icons.check_circle_outline),
                                    tooltip: 'Mark Taken',
                                  ),
                                  IconButton(
                                    onPressed: () => _openEditMedicine(medicine),
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: 'Edit',
                                  ),
                                  IconButton(
                                    onPressed: () => _deleteMedicine(medicine),
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: 'Delete',
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
