class DoseSchedule {
  const DoseSchedule({
    required this.time,
    required this.mealRelation,
    this.mealType = '',
  });

  final String time;
  final String mealRelation;
  final String mealType;

  Map<String, dynamic> toMap() {
    return {
      'time': time,
      'mealRelation': mealRelation,
      'mealType': mealType,
    };
  }

  factory DoseSchedule.fromMap(Map<String, dynamic> map) {
    return DoseSchedule(
      time: (map['time'] ?? '').toString(),
      mealRelation: (map['mealRelation'] ?? 'anytime').toString(),
      mealType: (map['mealType'] ?? '').toString(),
    );
  }

  String get doseKey =>
      '${time.trim().toUpperCase()}|${mealRelation.trim()}|${mealType.trim().toLowerCase()}';

  String get mealLabel {
    switch (mealRelation) {
      case 'before_meal':
        return mealType.isEmpty ? 'Before meal' : 'Before $mealType';
      case 'with_meal':
        return mealType.isEmpty ? 'With meal' : 'With $mealType';
      case 'after_meal':
        return mealType.isEmpty ? 'After meal' : 'After $mealType';
      default:
        return 'Anytime';
    }
  }
}

class Medicine {
  const Medicine({
    this.id,
    required this.name,
    required this.dosage,
    required this.time,
    required this.doses,
    required this.startDate,
    required this.endDate,
  });

  final String? id;
  final String name;
  final String dosage;
  final String time;
  final List<DoseSchedule> doses;
  final String startDate;
  final String endDate;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dosage': dosage,
      'time': time,
      'doses': doses.map((e) => e.toMap()).toList(),
      'startDate': startDate,
      'endDate': endDate,
    };
  }

  factory Medicine.fromMap(Map<String, dynamic> map, {String? id}) {
    final rawDoses = map['doses'];
    final parsedDoses = <DoseSchedule>[];
    if (rawDoses is List) {
      for (final item in rawDoses) {
        if (item is Map<String, dynamic>) {
          parsedDoses.add(DoseSchedule.fromMap(item));
        } else if (item is Map) {
          parsedDoses.add(
            DoseSchedule.fromMap(item.map((k, v) => MapEntry(k.toString(), v))),
          );
        }
      }
    }

    final legacyTime = (map['time'] ?? '').toString();
    final doses = parsedDoses.isNotEmpty
        ? parsedDoses
        : (legacyTime.trim().isEmpty
            ? const <DoseSchedule>[]
            : <DoseSchedule>[
                DoseSchedule(
                  time: legacyTime,
                  mealRelation: 'anytime',
                ),
              ]);

    return Medicine(
      id: id,
      name: (map['name'] ?? '').toString(),
      dosage: (map['dosage'] ?? '').toString(),
      time: doses.isNotEmpty ? doses.first.time : legacyTime,
      doses: doses,
      startDate: (map['startDate'] ?? '').toString(),
      endDate: (map['endDate'] ?? '').toString(),
    );
  }
}
