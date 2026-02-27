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
  bool _isClearing = false;

  Color _statusColor(String status) {
    switch (status) {
      case 'taken':
        return const Color(0xFF10B981);
      case 'missed':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'taken':
        return Icons.check_circle;
      case 'missed':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
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

  String _formatDateKey(String dateKey) {
    final parsed = DateTime.tryParse(dateKey);
    if (parsed == null) {
      return dateKey.isEmpty ? '-' : dateKey;
    }
    return _formatDate(parsed);
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'taken':
        return 'Taken';
      case 'missed':
        return 'Missed';
      default:
        return 'Unknown';
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

  Future<void> _clearHistory(String uid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear History'),
          content: const Text(
            'This will permanently delete all adherence history from app UI and Firebase database. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) {
      return;
    }

    setState(() => _isClearing = true);
    try {
      final collection = FirebaseFirestore.instance.collection('dose_logs');
      while (true) {
        final snapshot = await collection
            .where('patientId', isEqualTo: uid)
            .limit(300)
            .get();
        if (snapshot.docs.isEmpty) {
          break;
        }

        final batch = FirebaseFirestore.instance.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adherence history cleared')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to clear history: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isClearing = false);
      }
    }
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

  Widget _sectionTitle(String title, {Widget? trailing}) {
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
        if (trailing != null) ...[
          const SizedBox(width: 10),
          trailing,
        ],
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
    final dateKey = (data['dateKey'] ?? '').toString();
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
                    const SizedBox(width: 12),
                    const Icon(Icons.calendar_today_outlined,
                        size: 16, color: Color(0xFF6B7280)),
                    const SizedBox(width: 5),
                    Text(
                      _formatDateKey(dateKey),
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

          final historyDocs = docs.where((doc) {
            final status = (doc.data()['status'] ?? '').toString();
            return status == 'taken' || status == 'missed';
          }).toList();
          final filteredDocs = _applyFilters(historyDocs);
          final takenCount = filteredDocs
              .where((d) => (d.data()['status'] ?? '').toString() == 'taken')
              .length;
          final missedCount = filteredDocs
              .where((d) => (d.data()['status'] ?? '').toString() == 'missed')
              .length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _filterBar(),
              const SizedBox(height: 14),
              Row(
                children: [
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
                ],
              ),
              const SizedBox(height: 16),
              _sectionTitle(
                'Dose History',
                trailing: TextButton.icon(
                  onPressed: _isClearing ? null : () => _clearHistory(uid),
                  icon: _isClearing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Clear All History'),
                ),
              ),
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
