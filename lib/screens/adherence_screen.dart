import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:medicare_app/app.dart';
import 'package:medicare_app/widgets/app_bar_pulse_indicator.dart';
import 'package:medicare_app/widgets/app_navigation_drawer.dart';

class AdherenceScreen extends StatefulWidget {
  const AdherenceScreen({super.key});

  @override
  State<AdherenceScreen> createState() => _AdherenceScreenState();
}

class _AdherenceScreenState extends State<AdherenceScreen> {
  DateTime? _selectedDate;
  String _statusFilter = 'all';

  Color _statusColor(String status) {
    switch (status) {
      case 'taken':
        return const Color(0xFF10B981);
      case 'missed':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFD18A1B);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'taken':
        return Icons.check_circle;
      case 'missed':
        return Icons.cancel;
      default:
        return Icons.hourglass_bottom;
    }
  }

  int _streakDays(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final Map<String, String> dayStatus = {};
    for (final doc in docs) {
      final data = doc.data();
      final day = (data['dateKey'] ?? '').toString();
      final status = (data['status'] ?? '').toString();
      if (day.isEmpty) continue;
      final current = dayStatus[day];
      if (current == 'missed') continue;
      if (status == 'missed') {
        dayStatus[day] = 'missed';
      } else if (status == 'taken') {
        dayStatus[day] = 'taken';
      } else {
        dayStatus.putIfAbsent(day, () => status);
      }
    }

    final keys = dayStatus.keys.toList()..sort((a, b) => b.compareTo(a));
    int streak = 0;
    DateTime? expected;
    for (final key in keys) {
      final day = DateTime.tryParse(key);
      if (day == null) continue;
      final normalized = DateTime(day.year, day.month, day.day);
      if (expected == null) {
        final today = DateTime.now();
        final todayNorm = DateTime(today.year, today.month, today.day);
        final yesterday = todayNorm.subtract(const Duration(days: 1));
        if (normalized != todayNorm && normalized != yesterday) break;
        expected = normalized;
      }
      if (normalized != expected) break;
      if (dayStatus[key] != 'taken') break;
      streak += 1;
      expected = expected.subtract(const Duration(days: 1));
    }
    return streak;
  }

  String _dateKey(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  String _formatDate(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$dd/$mm/${date.year}';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'taken':
        return 'Taken';
      case 'missed':
        return 'Missed';
      default:
        return 'Pending';
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final data = doc.data();
      final status = (data['status'] ?? 'pending').toString();
      final day = (data['dateKey'] ?? '').toString();
      if (_statusFilter != 'all' && status != _statusFilter) {
        return false;
      }
      if (_selectedDate != null && day != _dateKey(_selectedDate!)) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (selected == null) return;
    setState(() =>
        _selectedDate = DateTime(selected.year, selected.month, selected.day));
  }

  Widget _filterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFD4DDED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x110F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      color: Color(0xFF2A6DBA),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedDate == null
                            ? 'All Dates'
                            : _formatDate(_selectedDate!),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF2A6DBA),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(width: 1, height: 26, color: const Color(0xFFD6DEEA)),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            initialValue: _statusFilter,
            onSelected: (value) => setState(() => _statusFilter = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'all', child: Text('All')),
              PopupMenuItem(value: 'taken', child: Text('Taken')),
              PopupMenuItem(value: 'missed', child: Text('Missed')),
              PopupMenuItem(value: 'pending', child: Text('Pending')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Type:',
                    style: TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _statusFilter == 'all'
                        ? 'All'
                        : _statusFilter[0].toUpperCase() +
                            _statusFilter.substring(1),
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_drop_down, color: Color(0xFF4B5563)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x110F172A),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 30),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _adherenceSummaryCard({
    required int takenCount,
    required int totalCount,
  }) {
    final percent =
        totalCount == 0 ? 0 : ((takenCount / totalCount) * 100).round();
    final progress = totalCount == 0 ? 0.0 : takenCount / totalCount;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x110F172A),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 106,
            height: 106,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 12,
                  backgroundColor: const Color(0xFFD8E8F9),
                  color: const Color(0xFF64A7EE),
                ),
                Text(
                  '$percent%',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$percent% Adherence',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Start your streak today',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Divider(
            color: Color(0xFFD5DCE8),
            thickness: 2,
          ),
        ),
      ],
    );
  }

  Widget _doseHistoryCard(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('No dose logs for selected filters'),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x110F172A),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < docs.length && i < 20; i++) ...[
            _doseRow(docs[i]),
            if (i < docs.length - 1 && i < 19)
              const Divider(height: 1, color: Color(0xFFE7ECF5)),
          ],
        ],
      ),
    );
  }

  Widget _doseRow(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final name = (data['medicineName'] ?? '').toString();
    final time = (data['scheduledTime'] ?? '').toString();
    final status = (data['status'] ?? 'pending').toString();
    final color = _statusColor(status);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FD),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.medication_outlined,
              color: Color(0xFF64A7EE),
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Medicine Name' : name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.schedule,
                        size: 16, color: Color(0xFF6B7280)),
                    const SizedBox(width: 5),
                    Text(
                      time.isEmpty ? '--:--' : time,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              Icon(_statusIcon(status), color: color, size: 30),
              const SizedBox(width: 6),
              Text(
                _statusLabel(status),
                style: TextStyle(
                  color: color,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Please login again.')),
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
          child: Text('Adherence History'),
        ),
      ),
      drawer: const AppNavigationDrawer(
        currentRoute: MyApp.routeAdherence,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('dose_logs')
            .where('patientId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load adherence logs'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          docs.sort((a, b) {
            final ad = (a.data()['dateKey'] ?? '').toString();
            final bd = (b.data()['dateKey'] ?? '').toString();
            if (ad != bd) return bd.compareTo(ad);
            final at =
                (a.data()['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                    0;
            final bt =
                (b.data()['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                    0;
            return bt.compareTo(at);
          });

          final filteredDocs = _applyFilters(docs);
          final takenCount = filteredDocs
              .where((d) => (d.data()['status'] ?? '').toString() == 'taken')
              .length;
          final missedCount = filteredDocs
              .where((d) => (d.data()['status'] ?? '').toString() == 'missed')
              .length;
          final pendingCount = filteredDocs
              .where((d) =>
                  (d.data()['status'] ?? 'pending').toString() == 'pending')
              .length;
          final streak = _streakDays(filteredDocs);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _filterBar(),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _metricCard(
                      icon: Icons.local_fire_department,
                      iconColor: const Color(0xFFF59E0B),
                      label: 'Streak',
                      value: '$streak days',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _metricCard(
                      icon: Icons.check_circle,
                      iconColor: const Color(0xFF10B981),
                      label: 'Taken',
                      value: '$takenCount',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _metricCard(
                      icon: Icons.cancel,
                      iconColor: const Color(0xFFEF4444),
                      label: 'Missed',
                      value: '$missedCount',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _metricCard(
                      icon: Icons.hourglass_bottom,
                      iconColor: const Color(0xFFD18A1B),
                      label: 'Pending',
                      value: '$pendingCount',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _adherenceSummaryCard(
                takenCount: takenCount,
                totalCount: takenCount + missedCount + pendingCount,
              ),
              const SizedBox(height: 16),
              _sectionTitle('Dose History'),
              const SizedBox(height: 10),
              _doseHistoryCard(filteredDocs),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}
