import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:medicare_app/models/medicine.dart';
import 'package:medicare_app/services/demo_email_service.dart';
import 'package:medicare_app/services/demo_sms_service.dart';

class DoseTrackingService {
  DoseTrackingService._();
  static final DoseTrackingService instance = DoseTrackingService._();

  static const String _doseLogsCollection = 'dose_logs';
  static const String _medicinesCollection = 'medicines';
  static const String _caregiversCollection = 'caregivers';
  static const String _caregiverAlertsCollection = 'caregiver_alerts';
  static const Duration _missedGrace = Duration(minutes: 30);

  Future<void> deleteMedicineAndRelatedData({
    required String medicineId,
  }) async {
    final patientId = FirebaseAuth.instance.currentUser?.uid;
    if (patientId == null || patientId.isEmpty || medicineId.isEmpty) {
      return;
    }

    await _deleteQueryDocsInChunks(
      FirebaseFirestore.instance
          .collection(_doseLogsCollection)
          .where('patientId', isEqualTo: patientId),
      shouldDelete: (data) => (data['medicineId'] ?? '').toString() == medicineId,
    );

    await _deleteQueryDocsInChunks(
      FirebaseFirestore.instance
          .collection(_caregiverAlertsCollection)
          .where('patientId', isEqualTo: patientId),
      shouldDelete: (data) => (data['medicineId'] ?? '').toString() == medicineId,
    );

    await FirebaseFirestore.instance
        .collection(_medicinesCollection)
        .doc(medicineId)
        .delete();
  }

  Future<void> checkAndRecordMissedDoses(List<Medicine> medicines) async {
    final patientId = FirebaseAuth.instance.currentUser?.uid;
    if (patientId == null || patientId.isEmpty) {
      return;
    }
    final now = DateTime.now();
    final todayKey = _dateKey(now);

    for (final medicine in medicines) {
      if (medicine.id == null || medicine.id!.isEmpty) {
        continue;
      }
      if (!_isMedicineActiveForDate(medicine, now)) {
        continue;
      }

      for (final dose in _effectiveDoses(medicine)) {
        final scheduledAt = _parseTimeOnDate(dose.time, now);
        if (scheduledAt == null) {
          continue;
        }

        final shouldBeMarkedMissed = now.isAfter(scheduledAt.add(_missedGrace));
        if (!shouldBeMarkedMissed) {
          continue;
        }

        final docId = _doseDocId(patientId, medicine.id!, todayKey, dose.doseKey);
        final docRef =
            FirebaseFirestore.instance.collection(_doseLogsCollection).doc(docId);
        final snapshot = await docRef.get();

        if (snapshot.exists) {
          final status = (snapshot.data()?['status'] ?? '').toString();
          if (status == 'taken' || status == 'missed') {
            continue;
          }
        }

        await docRef.set({
          'medicineId': medicine.id,
          'medicineName': medicine.name,
          'dosage': medicine.dosage,
          'patientId': patientId,
          'scheduledTime': dose.time,
          'dateKey': todayKey,
          'doseKey': dose.doseKey,
          'mealRelation': dose.mealRelation,
          'mealType': dose.mealType,
          'status': 'missed',
          'missedAt': Timestamp.fromDate(now),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await _createCaregiverAlerts(
          medicineId: medicine.id!,
          medicineName: medicine.name,
          dosage: medicine.dosage,
          scheduledTime: dose.time,
          dateKey: todayKey,
          doseKey: dose.doseKey,
          mealRelation: dose.mealRelation,
          mealType: dose.mealType,
          reason: 'auto_missed_after_grace',
        );
      }
    }
  }

  Future<void> markDoseTaken(Medicine medicine, {DoseSchedule? dose}) async {
    if (medicine.id == null || medicine.id!.isEmpty) {
      return;
    }
    final patientId = FirebaseAuth.instance.currentUser?.uid;
    if (patientId == null || patientId.isEmpty) {
      return;
    }
    final now = DateTime.now();
    final todayKey = _dateKey(now);
    final targetDose = dose ??
        await _pickNextPendingDose(
          medicine: medicine,
          patientId: patientId,
          dateKey: todayKey,
          now: now,
        );
    if (targetDose == null) {
      return;
    }
    final docId =
        _doseDocId(patientId, medicine.id!, todayKey, targetDose.doseKey);

    await FirebaseFirestore.instance
        .collection(_doseLogsCollection)
        .doc(docId)
        .set({
      'medicineId': medicine.id,
      'medicineName': medicine.name,
      'dosage': medicine.dosage,
      'patientId': patientId,
      'scheduledTime': targetDose.time,
      'dateKey': todayKey,
      'doseKey': targetDose.doseKey,
      'mealRelation': targetDose.mealRelation,
      'mealType': targetDose.mealType,
      'status': 'taken',
      'takenAt': Timestamp.fromDate(now),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setDoseStatusFromNotification({
    required String medicineId,
    required String medicineName,
    required String dosage,
    required String scheduledTime,
    required String dateKey,
    String doseKey = '',
    String mealRelation = 'anytime',
    String mealType = '',
    required String status,
    String? patientId,
  }) async {
    if (medicineId.isEmpty) {
      return;
    }
    final resolvedPatientId =
        patientId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    if (resolvedPatientId.isEmpty) {
      return;
    }
    final now = DateTime.now();
    final resolvedDoseKey = doseKey.isNotEmpty
        ? doseKey
        : '${scheduledTime.trim().toUpperCase()}|${mealRelation.trim()}|${mealType.trim().toLowerCase()}';
    final docId = _doseDocId(resolvedPatientId, medicineId, dateKey, resolvedDoseKey);
    final data = <String, dynamic>{
      'medicineId': medicineId,
      'medicineName': medicineName,
      'dosage': dosage,
      'patientId': resolvedPatientId,
      'scheduledTime': scheduledTime,
      'dateKey': dateKey,
      'doseKey': resolvedDoseKey,
      'mealRelation': mealRelation,
      'mealType': mealType,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (status == 'taken') {
      data['takenAt'] = Timestamp.fromDate(now);
    } else if (status == 'missed') {
      data['missedAt'] = Timestamp.fromDate(now);
      data['missedReason'] = 'marked_not_taken_from_notification';
    }

    await FirebaseFirestore.instance
        .collection(_doseLogsCollection)
        .doc(docId)
        .set(data, SetOptions(merge: true));

    if (status == 'missed') {
      await _createCaregiverAlerts(
        medicineId: medicineId,
        medicineName: medicineName,
        dosage: dosage,
        scheduledTime: scheduledTime,
        dateKey: dateKey,
        doseKey: resolvedDoseKey,
        mealRelation: mealRelation,
        mealType: mealType,
        reason: 'not_taken_from_notification',
        explicitPatientId: resolvedPatientId,
      );
    }
  }

  Future<String> getTodayDoseStatusForMedicine(Medicine medicine) async {
    final medicineId = medicine.id;
    if (medicineId == null || medicineId.isEmpty) {
      return 'pending';
    }
    final patientId = FirebaseAuth.instance.currentUser?.uid;
    if (patientId == null || patientId.isEmpty) {
      return 'pending';
    }
    final now = DateTime.now();
    if (!_isMedicineActiveForDate(medicine, now)) {
      return 'pending';
    }

    final expectedDoses = _effectiveDoses(medicine);
    if (expectedDoses.isEmpty) {
      return 'pending';
    }

    final todayKey = _dateKey(now);
    final snapshot = await FirebaseFirestore.instance
        .collection(_doseLogsCollection)
        .where('patientId', isEqualTo: patientId)
        .where('medicineId', isEqualTo: medicineId)
        .where('dateKey', isEqualTo: todayKey)
        .get();

    final byDose = <String, String>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final key = (data['doseKey'] ?? '').toString();
      final status = (data['status'] ?? '').toString();
      if (key.isEmpty) continue;
      byDose[key] = status;
    }

    var takenCount = 0;
    var missedCount = 0;
    for (final dose in expectedDoses) {
      final status = byDose[dose.doseKey] ?? 'pending';
      if (status == 'taken') takenCount += 1;
      if (status == 'missed') missedCount += 1;
    }

    if (takenCount == expectedDoses.length) {
      return 'taken';
    }
    if (missedCount == expectedDoses.length) {
      return 'missed';
    }
    return 'pending';
  }

  Future<String> getTodayDoseStatus(String medicineId) async {
    final patientId = FirebaseAuth.instance.currentUser?.uid;
    if (patientId == null || patientId.isEmpty) {
      return 'pending';
    }
    final todayKey = _dateKey(DateTime.now());
    final snapshot = await FirebaseFirestore.instance
        .collection(_doseLogsCollection)
        .where('patientId', isEqualTo: patientId)
        .where('medicineId', isEqualTo: medicineId)
        .where('dateKey', isEqualTo: todayKey)
        .get();
    if (snapshot.docs.isEmpty) return 'pending';
    final statuses = snapshot.docs
        .map((d) => (d.data()['status'] ?? '').toString())
        .toSet();
    if (statuses.length == 1 && statuses.contains('taken')) return 'taken';
    if (statuses.length == 1 && statuses.contains('missed')) return 'missed';
    return 'pending';
  }

  String _doseDocId(
    String patientId,
    String medicineId,
    String dayKey, [
    String doseKey = '',
  ]) {
    if (doseKey.isEmpty) {
      return '${patientId}_${medicineId}_$dayKey';
    }
    final suffix = doseKey.hashCode.abs();
    return '${patientId}_${medicineId}_${dayKey}_$suffix';
  }

  String _dateKey(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  bool _isMedicineActiveForDate(Medicine medicine, DateTime date) {
    final start = _tryParseDate(medicine.startDate);
    final end = _tryParseDate(medicine.endDate);
    if (start == null || end == null) {
      return true;
    }

    final current = DateTime(date.year, date.month, date.day);
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    return !current.isBefore(startDay) && !current.isAfter(endDay);
  }

  DateTime? _tryParseDate(String raw) {
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseTimeOnDate(String rawTime, DateTime date) {
    final input = rawTime.trim().toUpperCase();
    final regex = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$');
    final match = regex.firstMatch(input);
    if (match == null) {
      return null;
    }

    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final meridiem = match.group(3)!;

    if (meridiem == 'PM' && hour != 12) hour += 12;
    if (meridiem == 'AM' && hour == 12) hour = 0;

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  List<DoseSchedule> _effectiveDoses(Medicine medicine) {
    if (medicine.doses.isNotEmpty) {
      return medicine.doses;
    }
    final raw = medicine.time.trim();
    if (raw.isEmpty) {
      return const <DoseSchedule>[];
    }
    return <DoseSchedule>[
      DoseSchedule(
        time: raw,
        mealRelation: 'anytime',
      ),
    ];
  }

  Future<DoseSchedule?> _pickNextPendingDose({
    required Medicine medicine,
    required String patientId,
    required String dateKey,
    required DateTime now,
  }) async {
    final doses = _effectiveDoses(medicine);
    if (doses.isEmpty || medicine.id == null || medicine.id!.isEmpty) {
      return null;
    }

    doses.sort((a, b) {
      final ad = _parseTimeOnDate(a.time, now);
      final bd = _parseTimeOnDate(b.time, now);
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });

    final snapshot = await FirebaseFirestore.instance
        .collection(_doseLogsCollection)
        .where('patientId', isEqualTo: patientId)
        .where('medicineId', isEqualTo: medicine.id)
        .where('dateKey', isEqualTo: dateKey)
        .get();
    final byDose = <String, String>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final key = (data['doseKey'] ?? '').toString();
      final status = (data['status'] ?? '').toString();
      if (key.isNotEmpty) {
        byDose[key] = status;
      }
    }

    for (final row in doses) {
      final status = byDose[row.doseKey] ?? 'pending';
      if (status != 'taken') {
        return row;
      }
    }
    return doses.isEmpty ? null : doses.first;
  }

  Future<void> _createCaregiverAlerts({
    required String medicineId,
    required String medicineName,
    required String dosage,
    required String scheduledTime,
    required String dateKey,
    required String doseKey,
    required String mealRelation,
    required String mealType,
    required String reason,
    String? explicitPatientId,
  }) async {
    final patientId = explicitPatientId ?? FirebaseAuth.instance.currentUser?.uid;
    if (patientId == null || patientId.isEmpty) {
      return;
    }

    final caregiverSnapshots = await FirebaseFirestore.instance
        .collection(_caregiversCollection)
        .where('patientId', isEqualTo: patientId)
        .get();

    if (caregiverSnapshots.docs.isEmpty) {
      final fallbackId = '${patientId}_${medicineId}_$dateKey';
      await FirebaseFirestore.instance
          .collection(_caregiverAlertsCollection)
          .doc(fallbackId)
          .set({
        'patientId': patientId,
        'caregiverId': null,
        'medicineId': medicineId,
        'medicineName': medicineName,
        'dosage': dosage,
        'scheduledTime': scheduledTime,
        'dateKey': dateKey,
        'doseKey': doseKey,
        'mealRelation': mealRelation,
        'mealType': mealType,
        'type': 'missed_dose',
        'reason': reason,
        'acknowledged': false,
        'delivery': {
          'email': {
            'attempted': false,
            'sent': false,
            'provider': 'mobile_app',
          },
          'sms': {
            'attempted': false,
            'sent': false,
            'provider': 'mobile_app',
          },
        },
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    for (final caregiver in caregiverSnapshots.docs) {
      final caregiverId = caregiver.id;
      final alertId =
          '${patientId}_${caregiverId}_${medicineId}_${dateKey}_${doseKey.hashCode.abs()}';
      final caregiverName = (caregiver.data()['name'] ?? '').toString();
      final caregiverEmail = (caregiver.data()['email'] ?? '').toString();
      final caregiverPhone = (caregiver.data()['phone'] ?? '').toString();
      await FirebaseFirestore.instance
          .collection(_caregiverAlertsCollection)
          .doc(alertId)
          .set({
        'patientId': patientId,
        'caregiverId': caregiverId,
        'caregiverName': caregiverName,
        'caregiverEmail': caregiverEmail,
        'caregiverPhone': caregiverPhone,
        'medicineId': medicineId,
        'medicineName': medicineName,
        'dosage': dosage,
        'scheduledTime': scheduledTime,
        'dateKey': dateKey,
        'doseKey': doseKey,
        'mealRelation': mealRelation,
        'mealType': mealType,
        'type': 'missed_dose',
        'reason': reason,
        'acknowledged': false,
        'delivery': {
          'email': {
            'attempted': false,
            'sent': false,
            'provider': 'mobile_app',
          },
          'sms': {
            'attempted': false,
            'sent': false,
            'provider': 'mobile_app',
          },
        },
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (caregiverEmail.isNotEmpty) {
        try {
          debugPrint('Sending demo email to caregiver: $caregiverEmail');
          await DemoEmailService.instance.sendMissedDoseEmail(
            toEmail: caregiverEmail,
            caregiverName: caregiverName.isNotEmpty ? caregiverName : 'Caregiver',
            patientIdentifier: patientId,
            medicineName: medicineName,
            dosage: dosage,
            scheduledTime: scheduledTime,
            dateKey: dateKey,
          );
          debugPrint('Demo email sent successfully to $caregiverEmail');
          await FirebaseFirestore.instance
              .collection(_caregiverAlertsCollection)
              .doc(alertId)
              .set({
            'delivery.email.attempted': true,
            'delivery.email.sent': true,
            'delivery.email.sentAt': FieldValue.serverTimestamp(),
            'delivery.email.error': null,
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Demo email send failed for $caregiverEmail: $e');
          await FirebaseFirestore.instance
              .collection(_caregiverAlertsCollection)
              .doc(alertId)
              .set({
            'delivery.email.attempted': true,
            'delivery.email.sent': false,
            'delivery.email.error': e.toString(),
          }, SetOptions(merge: true));
        }
      }

      if (caregiverPhone.isNotEmpty) {
        try {
          debugPrint('Sending demo SMS to caregiver: $caregiverPhone');
          await DemoSmsService.instance.sendMissedDoseSms(
            toPhone: caregiverPhone,
            patientIdentifier: patientId,
            medicineName: medicineName,
            dosage: dosage,
            scheduledTime: scheduledTime,
            dateKey: dateKey,
          );
          debugPrint('Demo SMS sent successfully to $caregiverPhone');
          await FirebaseFirestore.instance
              .collection(_caregiverAlertsCollection)
              .doc(alertId)
              .set({
            'delivery.sms.attempted': true,
            'delivery.sms.sent': true,
            'delivery.sms.sentAt': FieldValue.serverTimestamp(),
            'delivery.sms.error': null,
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Demo SMS send failed for $caregiverPhone: $e');
          await FirebaseFirestore.instance
              .collection(_caregiverAlertsCollection)
              .doc(alertId)
              .set({
            'delivery.sms.attempted': true,
            'delivery.sms.sent': false,
            'delivery.sms.error': e.toString(),
          }, SetOptions(merge: true));
        }
      }
    }
  }

  Future<void> _deleteQueryDocsInChunks(
    Query<Map<String, dynamic>> query, {
    required bool Function(Map<String, dynamic> data) shouldDelete,
  }) async {
    while (true) {
      final snapshot = await query.limit(300).get();
      if (snapshot.docs.isEmpty) {
        break;
      }

      final batch = FirebaseFirestore.instance.batch();
      var deleteCount = 0;
      for (final doc in snapshot.docs) {
        if (!shouldDelete(doc.data())) {
          continue;
        }
        batch.delete(doc.reference);
        deleteCount += 1;
      }

      if (deleteCount == 0) {
        break;
      }

      await batch.commit();
    }
  }
}
