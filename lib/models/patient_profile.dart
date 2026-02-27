class PatientProfile {
  const PatientProfile({
    required this.name,
    required this.bloodGroup,
    required this.gender,
    required this.dateOfBirth,
    required this.age,
    required this.weightKg,
    required this.heightCm,
    required this.profileImageBase64,
    required this.allergies,
  });

  final String name;
  final String bloodGroup;
  final String gender;
  final String dateOfBirth;
  final int? age;
  final String weightKg;
  final String heightCm;
  final String profileImageBase64;
  final String allergies;

  factory PatientProfile.fromMap(Map<String, dynamic> map) {
    final ageRaw = map['age'];
    int? parsedAge;
    if (ageRaw is int) {
      parsedAge = ageRaw;
    } else if (ageRaw is num) {
      parsedAge = ageRaw.toInt();
    } else {
      parsedAge = int.tryParse((ageRaw ?? '').toString());
    }

    return PatientProfile(
      name: (map['name'] ?? '').toString(),
      bloodGroup: (map['bloodGroup'] ?? '').toString(),
      gender: (map['gender'] ?? '').toString(),
      dateOfBirth: (map['dateOfBirth'] ?? '').toString(),
      age: parsedAge,
      weightKg: (map['weightKg'] ?? '').toString(),
      heightCm: (map['heightCm'] ?? '').toString(),
      profileImageBase64: (map['profileImageBase64'] ?? '').toString(),
      allergies: (map['allergies'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'bloodGroup': bloodGroup.trim(),
      'gender': gender.trim(),
      'dateOfBirth': dateOfBirth.trim(),
      'age': age,
      'weightKg': weightKg.trim(),
      'heightCm': heightCm.trim(),
      'profileImageBase64': profileImageBase64,
      'allergies': allergies.trim(),
    };
  }
}
