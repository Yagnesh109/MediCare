import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:medicare_app/app.dart';
import 'package:medicare_app/models/medicine.dart';
import 'package:medicare_app/services/dose_tracking_service.dart';
import 'package:medicare_app/services/notification_service.dart';
import 'package:medicare_app/widgets/app_bar_pulse_indicator.dart';
import 'package:medicare_app/widgets/app_navigation_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  DateTime? _lastMissedCheckAt;
  DateTime? _lastExpiryCleanupAt;
  final Set<String> _expiryDeleteInProgress = <String>{};
  final DoseTrackingService _doseTrackingService = DoseTrackingService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
    }
  }

  Future<void> _openAddMedicine(BuildContext context) async {
    final result = await Navigator.pushNamed(context, '/add_medicine');
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medicine saved successfully')),
      );
      setState(() {});
    }
  }

  Future<void> _openEditMedicine(Medicine medicine) async {
    final result = await Navigator.pushNamed(
      context,
      '/add_medicine',
      arguments: {
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
        const SnackBar(content: Text('Medicine updated successfully')),
      );
      setState(() {});
    }
  }

  Future<void> _deleteMedicine(Medicine medicine) async {
    final medicineId = medicine.id;
    if (medicineId == null || medicineId.isEmpty) {
      return;
    }
    try {
      await NotificationService.instance.cancelMedicineReminders(
        id: medicineId.hashCode,
      );
      await _doseTrackingService.deleteMedicineAndRelatedData(
        medicineId: medicineId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete ${medicine.name}: $e')),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${medicine.name} deleted')),
    );
  }

  DateTime? _tryParseDate(String rawDate) {
    try {
      return DateTime.parse(rawDate);
    } catch (_) {
      return null;
    }
  }

  TimeOfDay? _parseTimeOfDay(String raw) {
    final input = raw.trim().toUpperCase();
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
    return TimeOfDay(hour: hour, minute: minute);
  }

  DateTime? _nextReminderAt(Medicine medicine, DateTime now) {
    final start = _tryParseDate(medicine.startDate);
    final end = _tryParseDate(medicine.endDate);
    if (start == null || end == null) {
      return null;
    }

    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    if (endDay.isBefore(startDay)) {
      return null;
    }

    final today = DateTime(now.year, now.month, now.day);
    final sortedDoses = [...medicine.doses];
    sortedDoses.sort((a, b) {
      final at = _parseTimeOfDay(a.time);
      final bt = _parseTimeOfDay(b.time);
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      if (at.hour != bt.hour) return at.hour.compareTo(bt.hour);
      return at.minute.compareTo(bt.minute);
    });

    var day = startDay.isAfter(today) ? startDay : today;
    while (!day.isAfter(endDay)) {
      for (final dose in sortedDoses) {
        final parsed = _parseTimeOfDay(dose.time);
        if (parsed == null) {
          continue;
        }
        final candidate = DateTime(
          day.year,
          day.month,
          day.day,
          parsed.hour,
          parsed.minute,
        );
        if (candidate.isAfter(now)) {
          return candidate;
        }
      }
      day = day.add(const Duration(days: 1));
    }
    return null;
  }

  String _formatReminderDateTime(DateTime dateTime) {
    final mm = dateTime.month.toString().padLeft(2, '0');
    final dd = dateTime.day.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final hour12 = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final suffix = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '${dateTime.year}-$mm-$dd $hour12:$minute $suffix';
  }

  Future<void> _cleanupExpiredMedicines(List<Medicine> medicines) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_lastExpiryCleanupAt != null &&
        now.difference(_lastExpiryCleanupAt!).inMinutes < 1) {
      return;
    }
    _lastExpiryCleanupAt = now;

    for (final medicine in medicines) {
      final id = medicine.id;
      if (id == null || id.isEmpty || _expiryDeleteInProgress.contains(id)) {
        continue;
      }
      final end = _tryParseDate(medicine.endDate);
      if (end == null) {
        continue;
      }
      final endDay = DateTime(end.year, end.month, end.day);
      if (!today.isAfter(endDay)) {
        continue;
      }

      _expiryDeleteInProgress.add(id);
      try {
        await NotificationService.instance
            .cancelMedicineReminders(id: id.hashCode);
        await _doseTrackingService.deleteMedicineAndRelatedData(
          medicineId: id,
        );
      } catch (_) {
        // Avoid blocking UI on cleanup errors.
      } finally {
        _expiryDeleteInProgress.remove(id);
      }
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _medicinesStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('medicines')
        .where('userId', isEqualTo: user.uid)
        .snapshots();
  }

  Future<void> _runMissedCheckIfNeeded(List<Medicine> medicines) async {
    final now = DateTime.now();
    if (_lastMissedCheckAt != null &&
        now.difference(_lastMissedCheckAt!).inSeconds < 45) {
      return;
    }
    _lastMissedCheckAt = now;
    await _doseTrackingService.checkAndRecordMissedDoses(medicines);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _markTaken(Medicine medicine) async {
    await _doseTrackingService.markDoseTaken(medicine);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${medicine.name} marked as taken')),
    );
    setState(() {});
  }

  Widget _statusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'taken':
        color = Colors.green;
        label = 'Taken';
        break;
      case 'missed':
        color = Colors.red;
        label = 'Missed';
        break;
      default:
        color = Colors.orange;
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  bool _isCourseActiveToday(Medicine medicine, DateTime today) {
    final start = _tryParseDate(medicine.startDate);
    final end = _tryParseDate(medicine.endDate);
    if (start == null || end == null) {
      return false;
    }
    final day = DateTime(today.year, today.month, today.day);
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    return !day.isBefore(startDay) && !day.isAfter(endDay);
  }

  Future<_PendingTodayData> _loadPendingTodayData(
    List<Medicine> medicines,
  ) async {
    final now = DateTime.now();
    final todayMedicines = medicines
        .where((medicine) => _isCourseActiveToday(medicine, now))
        .toList();
    if (todayMedicines.isEmpty) {
      return const _PendingTodayData(pendingMedicines: <Medicine>[]);
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return const _PendingTodayData(pendingMedicines: <Medicine>[]);
    }

    final todayKey = _dateKey(now);
    final todayLogs = await FirebaseFirestore.instance
        .collection('dose_logs')
        .where('patientId', isEqualTo: uid)
        .where('dateKey', isEqualTo: todayKey)
        .get();

    final statusByMedicineDose = <String, Map<String, String>>{};
    for (final doc in todayLogs.docs) {
      final data = doc.data();
      final medicineId = (data['medicineId'] ?? '').toString();
      final doseKey = (data['doseKey'] ?? '').toString();
      final status = (data['status'] ?? '').toString();
      if (medicineId.isEmpty || doseKey.isEmpty) {
        continue;
      }
      final map = statusByMedicineDose.putIfAbsent(medicineId, () => {});
      map[doseKey] = status;
    }

    final pendingMedicines = <Medicine>[];
    for (final medicine in todayMedicines) {
      final medicineId = medicine.id;
      final doses = medicine.doses.isNotEmpty
          ? medicine.doses
          : (medicine.time.trim().isEmpty
              ? const <DoseSchedule>[]
              : <DoseSchedule>[
                  DoseSchedule(time: medicine.time, mealRelation: 'anytime'),
                ]);
      if (medicineId == null || medicineId.isEmpty || doses.isEmpty) {
        pendingMedicines.add(medicine);
        continue;
      }

      final byDose = statusByMedicineDose[medicineId] ?? const {};
      final hasPendingDose = doses.any((dose) {
        final status = byDose[dose.doseKey] ?? 'pending';
        return status != 'taken' && status != 'missed';
      });
      if (hasPendingDose) {
        pendingMedicines.add(medicine);
      }
    }
    return _PendingTodayData(pendingMedicines: pendingMedicines);
  }

  String _dateKey(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  Widget _buildSloganCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE7EEFA), Color(0xFFF3F7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD5E2F5)),
      ),
      child: const Column(
        children: [
          Text(
            'Health is Wealth',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Stay consistent with every dose, every day.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF475569),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x110F172A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF64A7EE), size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Color(0xFF111827)),
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: ' $label',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle() {
    return const Row(
      children: [
        Text(
          "Today's Schedule",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Divider(
            color: Color(0xFFD5DCE8),
            thickness: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyScheduleCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x110F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        children: [
          Icon(
            Icons.medication_liquid_outlined,
            size: 92,
            color: Color(0xFFBCD8F6),
          ),
          SizedBox(height: 12),
          Text(
            'No medicines added yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          Text(
            'Tap the + button below to add your first medicine reminder.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF4B5563),
              height: 1.4,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Stay healthy. Stay consistent.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPendingTodayCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x110F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        children: [
          Icon(
            Icons.task_alt_outlined,
            size: 92,
            color: Color(0xFFBCD8F6),
          ),
          SizedBox(height: 12),
          Text(
            'No pending medicines for today',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          Text(
            'Taken and missed medicines are available in Adherence History.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF4B5563),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddMedicineButton() {
    return SizedBox(
      width: double.infinity,
      height: 76,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2E84F3), Color(0xFF65B8FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x332E84F3),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => _openAddMedicine(context),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline, color: Colors.white, size: 30),
                SizedBox(width: 10),
                Text(
                  'Add Medicine',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMedicineCard(Medicine medicine) {
    final now = DateTime.now();
    final name = medicine.name;
    final dosage = medicine.dosage;
    final doses = medicine.doses;
    final medicineId = medicine.id;
    final nextReminder = _nextReminderAt(medicine, now);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name.isEmpty ? 'Unnamed Medicine' : name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (medicineId != null && medicineId.isNotEmpty)
                  FutureBuilder<String>(
                    future: _doseTrackingService
                        .getTodayDoseStatusForMedicine(medicine),
                    builder: (context, statusSnapshot) {
                      final status = statusSnapshot.data ?? 'pending';
                      return _statusChip(status);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Dosage: ${dosage.isEmpty ? '-' : dosage}'),
            const SizedBox(height: 4),
            if (doses.isEmpty)
              Text('Time: ${medicine.time.isEmpty ? '-' : medicine.time}')
            else
              ...doses.map((dose) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('Dose: ${dose.time} (${dose.mealLabel})'),
                );
              }),
            const SizedBox(height: 4),
            Text('Course: ${medicine.startDate} to ${medicine.endDate}'),
            const SizedBox(height: 4),
            Text(
              'Next reminder: ${nextReminder == null ? 'No upcoming reminder' : _formatReminderDateTime(nextReminder)}',
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Edit',
                  onPressed: () => _openEditMedicine(medicine),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: () => _deleteMedicine(medicine),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            if (medicineId != null && medicineId.isNotEmpty)
              FutureBuilder<String>(
                future: _doseTrackingService
                    .getTodayDoseStatusForMedicine(medicine),
                builder: (context, statusSnapshot) {
                  final status = statusSnapshot.data ?? 'pending';
                  if (status == 'taken') {
                    return const SizedBox.shrink();
                  }
                  return Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _markTaken(medicine),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Mark Taken'),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          child: Text('Medicare'),
        ),
      ),
      drawer: const AppNavigationDrawer(
        currentRoute: MyApp.routeHome,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _medicinesStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Unable to load medicines'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          final medicines = docs
              .map((doc) => Medicine.fromMap(doc.data(), id: doc.id))
              .toList();
          if (medicines.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _runMissedCheckIfNeeded(medicines);
              _cleanupExpiredMedicines(medicines);
            });
          }

          return FutureBuilder<_PendingTodayData>(
            future: _loadPendingTodayData(medicines),
            builder: (context, pendingSnapshot) {
              if (pendingSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final pendingMedicines =
                  pendingSnapshot.data?.pendingMedicines ?? const <Medicine>[];
              final dueToday = pendingMedicines.length;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                children: [
                  _buildSloganCard(),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.calendar_month_outlined,
                          title: 'Today',
                          value: '$dueToday',
                          label: 'Pending',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _buildSectionTitle(),
                  const SizedBox(height: 12),
                  if (pendingMedicines.isEmpty) ...[
                    if (medicines.isEmpty)
                      _buildEmptyScheduleCard()
                    else
                      _buildNoPendingTodayCard(),
                    const SizedBox(height: 14),
                    _buildAddMedicineButton(),
                    const SizedBox(height: 10),
                  ] else
                    ...pendingMedicines.map((medicine) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildMedicineCard(medicine),
                      );
                    }),
                  if (pendingMedicines.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    _buildAddMedicineButton(),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _PendingTodayData {
  const _PendingTodayData({
    required this.pendingMedicines,
  });

  final List<Medicine> pendingMedicines;
}
