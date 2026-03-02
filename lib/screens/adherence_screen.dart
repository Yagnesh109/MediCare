import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:medicare_app/app.dart';
import 'package:medicare_app/l10n/app_localizations.dart';
import 'package:medicare_app/services/phi_e2ee_service.dart';
import 'package:medicare_app/services/user_role_service.dart';
import 'package:medicare_app/widgets/app_bar_pulse_indicator.dart';
import 'package:medicare_app/widgets/app_navigation_drawer.dart';
import 'package:medicare_app/widgets/chatbot_fab.dart';

class AdherenceScreen extends StatefulWidget {
  const AdherenceScreen({super.key});

  @override
  State<AdherenceScreen> createState() => _AdherenceScreenState();
}

class _AdherenceScreenState extends State<AdherenceScreen> {
  DateTime? _selectedDate;
  String _statusFilter = 'all';
  bool _isClearing = false;
  bool _isRoleLoading = true;
  bool _isCaregiver = false;
  List<Map<String, String>> _caregiverPatients = <Map<String, String>>[];
  String _selectedPatientRecordId = '';

  @override
  void initState() {
    super.initState();
    _bootstrapRoleAndPatients();
  }

  Future<void> _bootstrapRoleAndPatients() async {
    final role = await UserRoleService.instance.getCurrentRole();
    final caregiver = role == AppUserRole.caregiver;
    if (!caregiver) {
      if (!mounted) return;
      setState(() {
        _isCaregiver = false;
        _isRoleLoading = false;
      });
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final snapshot = await FirebaseFirestore.instance
        .collection('caregiver_patients')
        .where('caregiverId', isEqualTo: uid)
        .get();
    final patients = snapshot.docs.map((doc) {
      final data = doc.data();
      return <String, String>{
        'id': doc.id,
        'name': (data['name'] ?? '').toString().trim(),
      };
    }).toList();
    if (!mounted) return;
    setState(() {
      _isCaregiver = true;
      _caregiverPatients = patients;
      _selectedPatientRecordId = patients.isEmpty ? '' : patients.first['id']!;
      _isRoleLoading = false;
    });
  }

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
    final l10n = AppLocalizations.of(context)!;
    switch (status) {
      case 'taken':
        return l10n.taken;
      case 'missed':
        return l10n.missed;
      default:
        return 'Unknown';
    }
  }

  List<Map<String, dynamic>> _applyFilters(
    List<Map<String, dynamic>> docs,
  ) {
    return docs.where((data) {
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

  Future<void> _clearHistoryByDocIds(List<String> docIds) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.clearHistory),
          content: Text(l10n.clearHistoryConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.deleteAll),
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
      const chunk = 300;
      for (var i = 0; i < docIds.length; i += chunk) {
        final batch = FirebaseFirestore.instance.batch();
        final end = (i + chunk > docIds.length) ? docIds.length : i + chunk;
        for (final docId in docIds.sublist(i, end)) {
          batch.delete(FirebaseFirestore.instance.collection('dose_logs').doc(docId));
        }
        await batch.commit();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adherenceCleared)),
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

  Widget _caregiverPatientSelector() {
    if (!_isCaregiver) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPatientRecordId.isEmpty ? null : _selectedPatientRecordId,
          hint: const Text('Select Patient'),
          isExpanded: true,
          items: _caregiverPatients.map((patient) {
            final id = patient['id'] ?? '';
            final name = patient['name']?.isEmpty ?? true
                ? 'Unnamed patient'
                : patient['name']!;
            return DropdownMenuItem<String>(
              value: id,
              child: Text(name),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _selectedPatientRecordId = value);
          },
        ),
      ),
    );
  }

  Widget _filterBar() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFD4DDED)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                            ? l10n.allDates
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
            itemBuilder: (context) => [
              PopupMenuItem(value: 'all', child: Text(l10n.all)),
              PopupMenuItem(value: 'taken', child: Text(l10n.taken)),
              PopupMenuItem(value: 'missed', child: Text(l10n.missed)),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${l10n.type}:',
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _statusFilter == 'all'
                        ? l10n.all
                        : _statusFilter[0].toUpperCase() + _statusFilter.substring(1),
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

  Widget _doseHistoryCard(List<Map<String, dynamic>> docs) {
    if (docs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('No history found for selected filters'),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (var i = 0; i < docs.length && i < 40; i++) ...[
            _doseRow(docs[i]),
            if (i < docs.length - 1 && i < 39)
              const Divider(height: 1, color: Color(0xFFE7ECF5)),
          ],
        ],
      ),
    );
  }

  Widget _doseRow(Map<String, dynamic> data) {
    final name = (data['medicineName'] ?? '').toString();
    final dosage = (data['dosage'] ?? '').toString();
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
                Text(
                  'Dosage: ${dosage.isEmpty ? '-' : dosage}',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 16, color: Color(0xFF6B7280)),
                    const SizedBox(width: 5),
                    Text(
                      time.isEmpty ? '--:--' : time,
                      style: const TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _formatDateKey(dateKey),
                      style: const TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
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

  Future<List<Map<String, dynamic>>> _decryptDoseLogs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final result = <Map<String, dynamic>>[];
    for (final doc in docs) {
      try {
        final plain = await PhiE2eeService.instance.decryptPhiMap(
          stored: doc.data(),
          domain: 'dose_log',
        );
        plain['_docId'] = doc.id;
        plain['updatedAt'] =
            (doc.data()['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        result.add(plain);
      } catch (_) {}
    }
    return result;
  }

  Future<Set<String>> _loadCaregiverPatientMedicineIds(String caregiverUid) async {
    if (_selectedPatientRecordId.isEmpty) {
      return const <String>{};
    }
    final snapshot = await FirebaseFirestore.instance
        .collection('medicines')
        .where('userId', isEqualTo: caregiverUid)
        .where('targetPatientRecordId', isEqualTo: _selectedPatientRecordId)
        .get();
    return snapshot.docs.map((doc) => doc.id).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final l10n = AppLocalizations.of(context)!;
    if (uid == null || uid.isEmpty) {
      return Scaffold(
        body: Center(child: Text(l10n.pleaseLoginAgain)),
      );
    }
    if (_isRoleLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isCaregiver && _caregiverPatients.isEmpty) {
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
        body: const Center(
          child: Text('No patients linked to this caregiver yet'),
        ),
      );
    }

    final logsStream = _isCaregiver
        ? FirebaseFirestore.instance.collection('dose_logs').snapshots()
        : FirebaseFirestore.instance
            .collection('dose_logs')
            .where('patientId', isEqualTo: uid)
            .snapshots();

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
          child: Text(l10n.adherenceHistory),
        ),
      ),
      drawer: const AppNavigationDrawer(
        currentRoute: MyApp.routeAdherence,
      ),
      floatingActionButton: const ChatbotFab(heroTag: 'chatbot_adherence'),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: logsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(l10n.adherenceHistory));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _decryptDoseLogs(docs),
            builder: (context, decryptedSnapshot) {
              if (decryptedSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final allLogs = decryptedSnapshot.data ?? const <Map<String, dynamic>>[];
              if (!_isCaregiver) {
                final filtered = _buildFilteredHistory(allLogs, null);
                return _buildHistoryLayout(filtered, uid, l10n);
              }
              return FutureBuilder<Set<String>>(
                future: _loadCaregiverPatientMedicineIds(uid),
                builder: (context, medicineIdSnapshot) {
                  if (medicineIdSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final medicineIds = medicineIdSnapshot.data ?? const <String>{};
                  final filtered = _buildFilteredHistory(allLogs, medicineIds);
                  return _buildHistoryLayout(filtered, uid, l10n);
                },
              );
            },
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _buildFilteredHistory(
    List<Map<String, dynamic>> allLogs,
    Set<String>? allowedMedicineIds,
  ) {
    final statusLogs = allLogs.where((doc) {
      final status = (doc['status'] ?? '').toString();
      return status == 'taken' || status == 'missed';
    }).toList();

    final scoped = (!_isCaregiver || allowedMedicineIds == null)
        ? statusLogs
        : statusLogs.where((doc) {
            final medicineId = (doc['medicineId'] ?? '').toString();
            return medicineId.isNotEmpty && allowedMedicineIds.contains(medicineId);
          }).toList();
    scoped.sort((a, b) {
      final ad = (a['dateKey'] ?? '').toString();
      final bd = (b['dateKey'] ?? '').toString();
      if (ad != bd) return bd.compareTo(ad);
      final at = (a['updatedAt'] ?? 0) as int;
      final bt = (b['updatedAt'] ?? 0) as int;
      return bt.compareTo(at);
    });
    return _applyFilters(scoped);
  }

  Widget _buildHistoryLayout(
    List<Map<String, dynamic>> filteredDocs,
    String uid,
    AppLocalizations l10n,
  ) {
    final takenCount = filteredDocs
        .where((d) => (d['status'] ?? '').toString() == 'taken')
        .length;
    final missedCount = filteredDocs
        .where((d) => (d['status'] ?? '').toString() == 'missed')
        .length;
    final clearDocIds = filteredDocs
        .map((doc) => (doc['_docId'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_isCaregiver) ...[
          _caregiverPatientSelector(),
          const SizedBox(height: 10),
        ],
        _filterBar(),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                icon: Icons.check_circle,
                iconColor: const Color(0xFF10B981),
                label: l10n.taken,
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
                label: l10n.missed,
                value: '$missedCount',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _sectionTitle(
          l10n.doseHistory,
          trailing: TextButton.icon(
            onPressed: _isClearing || clearDocIds.isEmpty
                ? null
                : () => _clearHistoryByDocIds(clearDocIds),
            icon: _isClearing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_sweep_outlined),
            label: Text(l10n.clearAllHistory),
          ),
        ),
        const SizedBox(height: 10),
        _doseHistoryCard(filteredDocs),
        const SizedBox(height: 20),
      ],
    );
  }
}
