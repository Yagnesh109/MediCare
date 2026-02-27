import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:medicare_app/app.dart';
import 'package:medicare_app/models/medicine.dart';
import 'package:medicare_app/services/gemini_prescription_service.dart';
import 'package:medicare_app/services/notification_service.dart';
import 'package:medicare_app/widgets/app_bar_pulse_indicator.dart';
import 'package:medicare_app/widgets/app_navigation_drawer.dart';
import 'package:medicare_app/widgets/chatbot_fab.dart';

class AddMedicineScreen extends StatefulWidget {
  const AddMedicineScreen({super.key});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  static const List<String> _mealRelationOptions = <String>[
    'anytime',
    'before_meal',
    'with_meal',
    'after_meal',
  ];
  static const List<String> _mealTypeOptions = <String>[
    '',
    'breakfast',
    'lunch',
    'dinner',
    'snack',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();

  final List<_DoseFormRow> _doses = <_DoseFormRow>[
    const _DoseFormRow(),
  ];

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSaving = false;
  bool _isImportingPrescription = false;
  bool _didLoadArgs = false;
  String? _editingMedicineId;
  _AddMedicineEntryMode _entryMode = _AddMedicineEntryMode.select;

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadArgs) {
      return;
    }
    _didLoadArgs = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map<String, dynamic>) {
      return;
    }

    final medicineId = (args['medicineId'] ?? '').toString().trim();
    if (medicineId.isEmpty) {
      return;
    }
    _editingMedicineId = medicineId;
    _entryMode = _AddMedicineEntryMode.manual;

    _nameController.text = (args['name'] ?? '').toString();
    _dosageController.text = (args['dosage'] ?? '').toString();
    _startDateController.text = (args['startDate'] ?? '').toString();
    _endDateController.text = (args['endDate'] ?? '').toString();

    _startDate = _tryParseDate(_startDateController.text);
    _endDate = _tryParseDate(_endDateController.text);

    final loadedDoses = _extractDosesFromArgs(args);
    if (loadedDoses.isNotEmpty) {
      _doses
        ..clear()
        ..addAll(loadedDoses);
    }
  }

  List<_DoseFormRow> _extractDosesFromArgs(Map<String, dynamic> args) {
    final result = <_DoseFormRow>[];
    final raw = args['doses'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          final dose = DoseSchedule.fromMap(item);
          final parsed = _parseTimeOfDay(dose.time);
          if (parsed != null) {
            result.add(
              _DoseFormRow(
                time: parsed,
                mealRelation: _mealRelationOptions.contains(dose.mealRelation)
                    ? dose.mealRelation
                    : 'anytime',
                mealType: _mealTypeOptions.contains(dose.mealType)
                    ? dose.mealType
                    : '',
              ),
            );
          }
        } else if (item is Map) {
          final mapped = item.map((k, v) => MapEntry(k.toString(), v));
          final dose = DoseSchedule.fromMap(mapped);
          final parsed = _parseTimeOfDay(dose.time);
          if (parsed != null) {
            result.add(
              _DoseFormRow(
                time: parsed,
                mealRelation: _mealRelationOptions.contains(dose.mealRelation)
                    ? dose.mealRelation
                    : 'anytime',
                mealType: _mealTypeOptions.contains(dose.mealType)
                    ? dose.mealType
                    : '',
              ),
            );
          }
        }
      }
    }

    if (result.isEmpty) {
      final legacyTime = (args['time'] ?? '').toString();
      final parsed = _parseTimeOfDay(legacyTime);
      if (parsed != null) {
        result.add(_DoseFormRow(time: parsed));
      }
    }

    return result;
  }

  Future<void> _pickDoseTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _doses[index].time ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() {
      _doses[index] = _doses[index].copyWith(time: picked);
    });
  }

  void _addDoseRow() {
    setState(() {
      _doses.add(const _DoseFormRow());
    });
  }

  void _removeDoseRow(int index) {
    if (_doses.length == 1) {
      return;
    }
    setState(() {
      _doses.removeAt(index);
    });
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      _startDateController.text = _formatDate(picked);
      if (_endDate != null && _endDate!.isBefore(picked)) {
        _endDate = null;
        _endDateController.clear();
      }
    });
  }

  Future<void> _pickEndDate() async {
    final base = _startDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? base,
      firstDate: base,
      lastDate: DateTime(base.year + 10),
    );
    if (picked == null) return;
    setState(() {
      _endDate = picked;
      _endDateController.text = _formatDate(picked);
    });
  }

  String _formatDate(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  DateTime? _tryParseDate(String raw) {
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  static TimeOfDay? _parseTimeOfDay(String raw) {
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

  String _formatTime(TimeOfDay time) {
    final hour12 = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour12:$minute $suffix';
  }

  String _mealRelationLabel(String value) {
    switch (value) {
      case 'before_meal':
        return 'Before meal';
      case 'with_meal':
        return 'With meal';
      case 'after_meal':
        return 'After meal';
      default:
        return 'Anytime';
    }
  }

  String _mealTypeLabel(String value) {
    if (value.isEmpty) return 'Any';
    return value[0].toUpperCase() + value.substring(1);
  }

  List<DoseSchedule> _collectDoses() {
    final seen = <String>{};
    final doses = <DoseSchedule>[];
    for (final row in _doses) {
      final selected = row.time;
      if (selected == null) continue;
      final dose = DoseSchedule(
        time: _formatTime(selected),
        mealRelation: row.mealRelation,
        mealType: row.mealType,
      );
      if (seen.add(dose.doseKey)) {
        doses.add(dose);
      }
    }
    return doses;
  }

  List<DoseSchedule> _dosesFromTimingText(String timingText) {
    final rows = _buildDoseRowsFromTimingText(timingText);
    final doses = <DoseSchedule>[];
    final seen = <String>{};
    for (final row in rows) {
      if (row.time == null) continue;
      final dose = DoseSchedule(
        time: _formatTime(row.time!),
        mealRelation: row.mealRelation,
        mealType: row.mealType,
      );
      if (seen.add(dose.doseKey)) {
        doses.add(dose);
      }
    }
    return doses;
  }

  Future<void> _importFromPrescription() async {
    if (_isImportingPrescription) return;
    final source = await _askImageSource();
    if (source == null) return;

    setState(() => _isImportingPrescription = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 92,
      );
      if (picked == null) {
        return;
      }

      final extracted = await GeminiPrescriptionService.instance
          .extractFromImagePath(picked.path);
      final parsedFallback = _extractFromPrescription(extracted.rawText);
      final firstMedicine =
          extracted.medicines.isNotEmpty ? extracted.medicines.first : null;
      final draft = _PrescriptionDraft(
        name: (firstMedicine?.name ?? '').isNotEmpty
            ? firstMedicine!.name
            : parsedFallback.name,
        dosage: (firstMedicine?.dosage ?? '').isNotEmpty
            ? firstMedicine!.dosage
            : parsedFallback.dosage,
        timingText: firstMedicine != null && firstMedicine.timing.isNotEmpty
            ? firstMedicine.timing.join(', ')
            : parsedFallback.timingText,
        startDateText: _normalizeDate(extracted.startDateText) ??
            parsedFallback.startDateText,
        endDateText:
            _normalizeDate(extracted.endDateText) ?? parsedFallback.endDateText,
      );

      final verified = await _verifyExtractedPrescription(
        draft,
        extracted.medicines,
      );
      if (verified == null || !mounted) {
        return;
      }

      await _saveImportedMedicines(verified.drafts);
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Prescription extraction failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isImportingPrescription = false);
      }
    }
  }

  Future<ImageSource?> _askImageSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose From Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  List<_DoseFormRow> _buildDoseRowsFromTimingText(String timingText) {
    final input = timingText.trim();
    if (input.isEmpty) return const <_DoseFormRow>[];

    final tokens = input
        .split(RegExp(r'[\n,;|]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final seen = <String>{};
    final rows = <_DoseFormRow>[];
    for (final token in tokens) {
      final parsed = _parseTimeOfDay(token);
      if (parsed == null) {
        continue;
      }
      final key = '${parsed.hour}:${parsed.minute}';
      if (!seen.add(key)) {
        continue;
      }
      rows.add(_DoseFormRow(time: parsed));
    }
    return rows;
  }

  List<TimeOfDay> _parseTimingTextToTimes(String timingText) {
    final rows = _buildDoseRowsFromTimingText(timingText);
    final times = <TimeOfDay>[];
    for (final row in rows) {
      if (row.time != null) {
        times.add(row.time!);
      }
    }
    return times;
  }

  String _timingTextFromTimes(List<TimeOfDay> times) {
    if (times.isEmpty) return '';
    final normalized = [...times];
    normalized.sort((a, b) {
      if (a.hour != b.hour) return a.hour.compareTo(b.hour);
      return a.minute.compareTo(b.minute);
    });
    return normalized.map(_formatTime).join(', ');
  }

  _PrescriptionDraft _extractFromPrescription(String text) {
    final normalized = text.replaceAll('\r', '');
    final lines = normalized
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final dosageRegex = RegExp(
      r'\b\d+(?:\.\d+)?\s*(?:mg|mcg|g|ml|iu|units?|tablet|tab|capsule|cap|drops?)\b',
      caseSensitive: false,
    );
    String dosage = '';
    String name = '';
    final timingMatches = RegExp(
      r'\b\d{1,2}:\d{2}\s*(?:AM|PM)\b',
      caseSensitive: false,
    ).allMatches(normalized);
    final timing = <String>[];
    for (final match in timingMatches) {
      final value = match.group(0)?.trim() ?? '';
      if (value.isNotEmpty && !timing.contains(value.toUpperCase())) {
        timing.add(value.toUpperCase());
      }
    }

    for (final line in lines) {
      final match = dosageRegex.firstMatch(line);
      if (match != null) {
        dosage = match.group(0)!.trim();
        final cleaned = line
            .replaceFirst(match.group(0)!, '')
            .replaceAll(RegExp(r'[^A-Za-z0-9\s\-]'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (cleaned.isNotEmpty) {
          name = cleaned;
          break;
        }
      }
    }

    if (name.isEmpty) {
      for (final line in lines) {
        final lower = line.toLowerCase();
        if (lower.startsWith('rx') ||
            lower.contains('patient') ||
            lower.contains('doctor') ||
            lower.contains('hospital') ||
            lower.contains('date')) {
          continue;
        }
        final cleaned = line
            .replaceAll(RegExp(r'[^A-Za-z0-9\s\-]'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (cleaned.length >= 3) {
          name = cleaned;
          break;
        }
      }
    }

    if (dosage.isEmpty) {
      final fallbackDose = RegExp(
        r'\b(?:1|2|3|4|5)\s*(?:tablet|tab|capsule|cap|ml|drop|drops)\b',
        caseSensitive: false,
      );
      final match = fallbackDose.firstMatch(normalized);
      if (match != null) {
        dosage = match.group(0)!.trim();
      }
    }

    final start = _extractDateWithHint(normalized, 'start');
    final end = _extractDateWithHint(normalized, 'end');
    return _PrescriptionDraft(
      name: name,
      dosage: dosage,
      timingText: timing.join(', '),
      startDateText: start ?? '',
      endDateText: end ?? '',
    );
  }

  String? _extractDateWithHint(String text, String hint) {
    final lineRegex = RegExp(
      '$hint[^\\n\\r]*?(\\d{4}[-/]\\d{1,2}[-/]\\d{1,2}|\\d{1,2}[-/]\\d{1,2}[-/]\\d{2,4})',
      caseSensitive: false,
    );
    final lineMatch = lineRegex.firstMatch(text);
    final rawDate = lineMatch?.group(1);
    if (rawDate == null) {
      return null;
    }
    return _normalizeDate(rawDate);
  }

  String? _normalizeDate(String raw) {
    final value = raw.trim().replaceAll('/', '-');
    final ymd = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(value);
    if (ymd != null) {
      final y = int.tryParse(ymd.group(1)!);
      final m = int.tryParse(ymd.group(2)!);
      final d = int.tryParse(ymd.group(3)!);
      if (y == null || m == null || d == null) return null;
      return _formatDate(DateTime(y, m, d));
    }

    final dmy = RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{2,4})$').firstMatch(value);
    if (dmy != null) {
      final d = int.tryParse(dmy.group(1)!);
      final m = int.tryParse(dmy.group(2)!);
      var y = int.tryParse(dmy.group(3)!);
      if (d == null || m == null || y == null) return null;
      if (y < 100) y += 2000;
      return _formatDate(DateTime(y, m, d));
    }
    return null;
  }

  Future<_PrescriptionImportResult?> _verifyExtractedPrescription(
    _PrescriptionDraft draft,
    List<PrescriptionMedicine> extractedMedicines,
  ) async {
    final nameController = TextEditingController(text: draft.name);
    final dosageController = TextEditingController(text: draft.dosage);
    final selectedTimes = _parseTimingTextToTimes(draft.timingText);
    final startController =
        TextEditingController(text: draft.startDateText.trim());
    final endController = TextEditingController(text: draft.endDateText.trim());
    final formKey = GlobalKey<FormState>();
    var selectedIndex = extractedMedicines.isNotEmpty ? 0 : -1;
    final medicineDrafts = <_PrescriptionDraft>[
      if (extractedMedicines.isNotEmpty)
        ...extractedMedicines.map(
          (m) => _PrescriptionDraft(
            name: m.name,
            dosage: m.dosage,
            timingText: m.timing.join(', '),
            startDateText: draft.startDateText,
            endDateText: draft.endDateText,
          ),
        )
      else
        draft,
    ];

    void loadDraftToFields(_PrescriptionDraft d) {
      nameController.text = d.name;
      dosageController.text = d.dosage;
      selectedTimes
        ..clear()
        ..addAll(_parseTimingTextToTimes(d.timingText));
      startController.text = d.startDateText;
      endController.text = d.endDateText;
    }

    _PrescriptionDraft buildCurrentDraft() {
      return _PrescriptionDraft(
        name: nameController.text.trim(),
        dosage: dosageController.text.trim(),
        timingText: _timingTextFromTimes(selectedTimes),
        startDateText: startController.text.trim(),
        endDateText: endController.text.trim(),
      );
    }

    if (selectedIndex >= 0 && selectedIndex < medicineDrafts.length) {
      loadDraftToFields(medicineDrafts[selectedIndex]);
    }

    final result = await showDialog<_PrescriptionImportResult>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> pickDialogDate({
              required bool isStart,
            }) async {
              final now = DateTime.now();
              final existing = _tryParseDate(
                (isStart ? startController.text : endController.text).trim(),
              );
              final startLimit = DateTime(now.year - 1);
              final endLimit = DateTime(now.year + 10);
              final picked = await showDatePicker(
                context: context,
                initialDate: existing ?? now,
                firstDate: startLimit,
                lastDate: endLimit,
              );
              if (picked == null) return;
              if (!context.mounted) return;
              setStateDialog(() {
                if (isStart) {
                  startController.text = _formatDate(picked);
                  final end = _tryParseDate(endController.text.trim());
                  if (end != null && end.isBefore(picked)) {
                    endController.clear();
                  }
                } else {
                  endController.text = _formatDate(picked);
                }
              });
            }

            Future<void> pickDialogTime() async {
              final picked = await showTimePicker(
                context: context,
                initialTime: selectedTimes.isEmpty
                    ? TimeOfDay.now()
                    : selectedTimes.last,
              );
              if (picked == null) return;
              if (!context.mounted) return;
              setStateDialog(() {
                final alreadyExists = selectedTimes.any(
                  (t) => t.hour == picked.hour && t.minute == picked.minute,
                );
                if (!alreadyExists) {
                  selectedTimes.add(picked);
                }
              });
            }

            return AlertDialog(
              title: const Text('Verify Prescription Extraction'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (extractedMedicines.length > 1)
                          const Text(
                            'Detected medicines',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        if (extractedMedicines.length > 1)
                          const SizedBox(height: 10),
                        if (extractedMedicines.length > 1)
                          ...List.generate(extractedMedicines.length, (idx) {
                            final m = extractedMedicines[idx];
                            final label = m.name.isNotEmpty
                                ? m.name
                                : 'Medicine ${idx + 1}';
                            final details =
                                m.dosage.isNotEmpty ? m.dosage : '-';
                            final isSelected = selectedIndex == idx;
                            return InkWell(
                              onTap: () {
                                setStateDialog(() {
                                  if (selectedIndex >= 0 &&
                                      selectedIndex < medicineDrafts.length) {
                                    medicineDrafts[selectedIndex] =
                                        buildCurrentDraft();
                                  }
                                  selectedIndex = idx;
                                  loadDraftToFields(medicineDrafts[idx]);
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF1565C0)
                                        : Colors.black12,
                                  ),
                                  color: isSelected
                                      ? const Color(0xFFEAF4FF)
                                      : Colors.white,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            label,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text('Dosage: $details'),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_circle,
                                        color: Color(0xFF1565C0),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        if (extractedMedicines.length > 1)
                          const Divider(height: 20),
                        TextFormField(
                          controller: nameController,
                          decoration:
                              const InputDecoration(labelText: 'Medicine Name'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please confirm medicine name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: dosageController,
                          decoration:
                              const InputDecoration(labelText: 'Dosage'),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Reminder times',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        if (selectedTimes.isEmpty)
                          const Text(
                            'No times selected yet.',
                            style: TextStyle(color: Colors.black54),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                List.generate(selectedTimes.length, (idx) {
                              final t = selectedTimes[idx];
                              return InputChip(
                                label: Text(_formatTime(t)),
                                onDeleted: () {
                                  setStateDialog(() {
                                    selectedTimes.removeAt(idx);
                                  });
                                },
                              );
                            }),
                          ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: pickDialogTime,
                            icon: const Icon(Icons.access_time),
                            label: const Text('Add Time'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Course dates',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => pickDialogDate(isStart: true),
                                icon: const Icon(Icons.calendar_today_outlined),
                                label: Text(
                                  startController.text.trim().isEmpty
                                      ? 'Start Date'
                                      : startController.text.trim(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => pickDialogDate(isStart: false),
                                icon: const Icon(Icons.event_outlined),
                                label: Text(
                                  endController.text.trim().isEmpty
                                      ? 'End Date'
                                      : endController.text.trim(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: startController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Start Date (tap calendar)',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: endController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'End Date (tap calendar)',
                          ),
                        ),
                        const Text(
                          'User verification required: please confirm medicine, dosage, schedule, and dates.',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    if (selectedIndex >= 0 &&
                        selectedIndex < medicineDrafts.length) {
                      medicineDrafts[selectedIndex] = buildCurrentDraft();
                    }
                    final filtered = medicineDrafts
                        .where((d) => d.name.trim().isNotEmpty)
                        .toList();
                    if (filtered.isEmpty) {
                      return;
                    }
                    Navigator.pop(
                      context,
                      _PrescriptionImportResult(
                        drafts: filtered,
                      ),
                    );
                  },
                  child: Text(
                    medicineDrafts.length > 1 ? 'Apply All Medicines' : 'Apply',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    // Avoid disposing these immediately after dialog pop; during route teardown
    // Flutter may still access them in transient animation frames.
    return result;
  }

  void _resetManualFormAfterSave() {
    _nameController.clear();
    _dosageController.clear();
    _startDateController.clear();
    _endDateController.clear();
    _startDate = null;
    _endDate = null;
    _doses
      ..clear()
      ..add(const _DoseFormRow());
  }

  Future<void> _saveMedicine({bool addAnother = false}) async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login again and retry.')),
      );
      return;
    }

    final doses = _collectDoses();
    if (doses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one valid dose time.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final medicine = Medicine(
      name: _nameController.text.trim(),
      dosage: _dosageController.text.trim(),
      time: doses.first.time,
      doses: doses,
      startDate: _startDateController.text.trim(),
      endDate: _endDateController.text.trim(),
    );

    final payload = medicine.toMap()
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['userId'] = user.uid;

    try {
      final medicines = FirebaseFirestore.instance.collection('medicines');
      DocumentReference<Map<String, dynamic>> docRef;
      if (_editingMedicineId == null || _editingMedicineId!.isEmpty) {
        docRef = await medicines.add(payload);
      } else {
        docRef = medicines.doc(_editingMedicineId);
        await docRef.set(payload, SetOptions(merge: true));
      }

      final startDate = _startDate ?? _tryParseDate(_startDateController.text);
      final endDate = _endDate ?? _tryParseDate(_endDateController.text);

      // Do not block UI on long notification scheduling work.
      unawaited(
        _scheduleRemindersInBackground(
          medicineId: docRef.id,
          medicine: medicine,
          doses: doses,
          startDate: startDate,
          endDate: endDate,
        ),
      );

      if (!mounted) return;
      final isEditing =
          _editingMedicineId != null && _editingMedicineId!.isNotEmpty;
      if (addAnother && !isEditing) {
        setState(_resetManualFormAfterSave);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medicine saved. Add another medicine.')),
        );
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Save medicine failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save medicine: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveImportedMedicines(List<_PrescriptionDraft> drafts) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login again and retry.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    var savedCount = 0;

    try {
      final medicinesCollection =
          FirebaseFirestore.instance.collection('medicines');

      for (final draft in drafts) {
        final name = draft.name.trim();
        if (name.isEmpty) {
          continue;
        }

        final doses = _dosesFromTimingText(draft.timingText);
        if (doses.isEmpty) {
          continue;
        }

        final medicine = Medicine(
          name: name,
          dosage: draft.dosage.trim(),
          time: doses.first.time,
          doses: doses,
          startDate: draft.startDateText.trim(),
          endDate: draft.endDateText.trim(),
        );

        final payload = medicine.toMap()
          ..['createdAt'] = FieldValue.serverTimestamp()
          ..['userId'] = user.uid;

        final docRef = await medicinesCollection.add(payload);
        final startDate = _tryParseDate(medicine.startDate);
        final endDate = _tryParseDate(medicine.endDate);

        unawaited(
          _scheduleRemindersInBackground(
            medicineId: docRef.id,
            medicine: medicine,
            doses: doses,
            startDate: startDate,
            endDate: endDate,
          ),
        );
        savedCount += 1;
      }

      if (!mounted) return;
      if (savedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No medicines were saved. Please ensure each medicine has at least one valid time.',
            ),
          ),
        );
        return;
      }
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save extracted medicines: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _scheduleRemindersInBackground({
    required String medicineId,
    required Medicine medicine,
    required List<DoseSchedule> doses,
    required DateTime? startDate,
    required DateTime? endDate,
  }) async {
    try {
      await NotificationService.instance.showInstantNotification(
        id: medicineId.hashCode ^ 999,
        title: 'Medicare',
        body:
            'Reminder ${_editingMedicineId == null ? 'saved' : 'updated'} for ${medicine.name}',
      );

      await NotificationService.instance.cancelMedicineReminders(
        id: medicineId.hashCode,
      );
      if (startDate != null && endDate != null) {
        await NotificationService.instance.scheduleDailyMedicineReminder(
          id: medicineId.hashCode,
          medicineId: medicineId,
          medicineName: medicine.name,
          dosage: medicine.dosage,
          doses: doses,
          startDate: startDate,
          endDate: endDate,
        );
      }
    } catch (e) {
      debugPrint('Background reminder scheduling failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing =
        _editingMedicineId != null && _editingMedicineId!.isNotEmpty;
    final showEntrySelection = !isEditing && _entryMode == _AddMedicineEntryMode.select;
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
          child: Text(isEditing ? 'Edit Medicine' : 'Add Medicine'),
        ),
      ),
      drawer: const AppNavigationDrawer(
        currentRoute: MyApp.routeAddMedicine,
      ),
      floatingActionButton: const ChatbotFab(heroTag: 'chatbot_add_medicine'),
      body: SafeArea(
        child: showEntrySelection
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Choose Entry Method',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: _isImportingPrescription
                              ? null
                              : _importFromPrescription,
                          icon: _isImportingPrescription
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.document_scanner_outlined),
                          label: Text(
                            _isImportingPrescription
                                ? 'Reading prescription...'
                                : 'OCR Extraction',
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _entryMode = _AddMedicineEntryMode.manual;
                            });
                          },
                          icon: const Icon(Icons.edit_note_outlined),
                          label: const Text('Manual Entry'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!isEditing) ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _entryMode = _AddMedicineEntryMode.select;
                                  });
                                },
                                icon: const Icon(Icons.swap_horiz),
                                label: const Text('Change Method'),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          const Row(
                            children: [
                              Icon(Icons.medication, color: Color(0xFF1565C0)),
                              SizedBox(width: 8),
                              Text(
                                'Medicine Details',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0D47A1),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Medicine Name',
                        prefixIcon: Icon(Icons.local_hospital_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter medicine name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _dosageController,
                      decoration: const InputDecoration(
                        labelText: 'Dosage',
                        prefixIcon: Icon(Icons.science_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter dosage';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Dose Schedule',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(_doses.length, (index) {
                      final row = _doses[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _pickDoseTime(index),
                                    icon: const Icon(Icons.access_time),
                                    label: Text(
                                      row.time == null
                                          ? 'Select time'
                                          : _formatTime(row.time!),
                                    ),
                                  ),
                                ),
                                if (_doses.length > 1) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () => _removeDoseRow(index),
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: 'Remove',
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: row.mealRelation,
                              decoration: const InputDecoration(
                                labelText: 'Meal relation',
                              ),
                              items: _mealRelationOptions
                                  .map(
                                    (value) => DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(_mealRelationLabel(value)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _doses[index] = _doses[index].copyWith(
                                    mealRelation: value,
                                  );
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: row.mealType,
                              decoration: const InputDecoration(
                                labelText: 'Meal type',
                              ),
                              items: _mealTypeOptions
                                  .map(
                                    (value) => DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(_mealTypeLabel(value)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _doses[index] = _doses[index].copyWith(
                                    mealType: value,
                                  );
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addDoseRow,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Another Time'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _startDateController,
                      readOnly: true,
                      onTap: _pickStartDate,
                      decoration: const InputDecoration(
                        labelText: 'Start Date',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Select start date';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _endDateController,
                      readOnly: true,
                      onTap: _pickEndDate,
                      decoration: const InputDecoration(
                        labelText: 'End Date',
                        prefixIcon: Icon(Icons.event_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Select end date';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : () => _saveMedicine(),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_isSaving ? 'Saving...' : 'Save Medicine'),
                    ),
                    const SizedBox(height: 10),
                    if (!isEditing)
                      OutlinedButton.icon(
                        onPressed: _isSaving
                            ? null
                            : () => _saveMedicine(addAnother: true),
                        icon: const Icon(Icons.playlist_add_outlined),
                        label: const Text('Save & Add Another Medicine'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _AddMedicineEntryMode { select, manual }

class _DoseFormRow {
  const _DoseFormRow({
    this.time,
    this.mealRelation = 'anytime',
    this.mealType = '',
  });

  final TimeOfDay? time;
  final String mealRelation;
  final String mealType;

  _DoseFormRow copyWith({
    TimeOfDay? time,
    String? mealRelation,
    String? mealType,
  }) {
    return _DoseFormRow(
      time: time ?? this.time,
      mealRelation: mealRelation ?? this.mealRelation,
      mealType: mealType ?? this.mealType,
    );
  }
}

class _PrescriptionDraft {
  const _PrescriptionDraft({
    required this.name,
    required this.dosage,
    required this.timingText,
    required this.startDateText,
    required this.endDateText,
  });

  final String name;
  final String dosage;
  final String timingText;
  final String startDateText;
  final String endDateText;
}

class _PrescriptionImportResult {
  const _PrescriptionImportResult({
    required this.drafts,
  });

  final List<_PrescriptionDraft> drafts;
}
