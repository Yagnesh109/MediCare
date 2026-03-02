import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';

class DemoEmailService {
  DemoEmailService._();
  static final DemoEmailService instance = DemoEmailService._();

  // DEMO ONLY: Do not ship real credentials in production apps.
  static const String _senderEmail = 'kotwalyagnesh2006@gmail.com';
  static const String _placeholderPassword =
      'REPLACE_WITH_NEW_16_CHAR_APP_PASSWORD';
  static const String _appPassword = 'rawxasbnbozthjhw';

  bool get isConfigured =>
      _senderEmail.isNotEmpty &&
      _appPassword.isNotEmpty &&
      _appPassword != _placeholderPassword;

  Future<void> sendMissedDoseEmail({
    required String toEmail,
    required String caregiverName,
    required String patientIdentifier,
    required String medicineName,
    required String dosage,
    required String scheduledTime,
    required String dateKey,
  }) async {
    if (!isConfigured) {
      throw Exception('Demo email sender is not configured.');
    }

    final smtpServer = gmail(_senderEmail, _appPassword);
    final message = Message()
      ..from = const Address(_senderEmail, 'Medicare Alerts')
      ..recipients.add(toEmail)
      ..subject = 'Medicare Alert: Missed dose for $medicineName'
      ..text = 'Hi $caregiverName,\n\n'
          'Patient $patientIdentifier may have missed a dose.\n\n'
          'Medicine: $medicineName\n'
          'Dosage: $dosage\n'
          'Scheduled Time: $scheduledTime\n'
          'Date: $dateKey\n\n'
          'Please check in with them.\n\n'
          'Medicare';

    await send(message, smtpServer);
  }

  Future<void> sendPatientMedicineAssignedEmail({
    required String toEmail,
    required String patientName,
    required String caregiverName,
    required String medicineName,
    required String dosage,
    required List<String> schedules,
    required String startDate,
    required String endDate,
  }) async {
    if (!isConfigured) {
      throw Exception('Demo email sender is not configured.');
    }

    final smtpServer = gmail(_senderEmail, _appPassword);
    final scheduleText = schedules.isEmpty ? '-' : schedules.join(', ');
    final message = Message()
      ..from = const Address(_senderEmail, 'Medicare Alerts')
      ..recipients.add(toEmail)
      ..subject = 'Medicare: New medicine assigned'
      ..text = 'Hi ${patientName.trim().isEmpty ? 'Patient' : patientName.trim()},\n\n'
          'A new medicine was assigned to you by '
          '${caregiverName.trim().isEmpty ? 'your caregiver' : caregiverName.trim()}.\n\n'
          'Medicine: $medicineName\n'
          'Dosage: $dosage\n'
          'Schedule: $scheduleText\n'
          'Start Date: ${startDate.trim().isEmpty ? '-' : startDate.trim()}\n'
          'End Date: ${endDate.trim().isEmpty ? '-' : endDate.trim()}\n\n'
          'Please follow the schedule carefully.\n\n'
          'Medicare';

    await send(message, smtpServer);
  }

  Future<void> sendPatientMedicineReminderEmail({
    required String toEmail,
    required String patientName,
    required String medicineName,
    required String dosage,
    required String scheduledTime,
    required String dateKey,
  }) async {
    if (!isConfigured) {
      throw Exception('Demo email sender is not configured.');
    }

    final smtpServer = gmail(_senderEmail, _appPassword);
    final message = Message()
      ..from = const Address(_senderEmail, 'Medicare Alerts')
      ..recipients.add(toEmail)
      ..subject = 'Medicare Reminder: $medicineName'
      ..text = 'Hi ${patientName.trim().isEmpty ? 'Patient' : patientName.trim()},\n\n'
          'This is your medicine reminder.\n\n'
          'Medicine: $medicineName\n'
          'Dosage: $dosage\n'
          'Time: $scheduledTime\n'
          'Date: $dateKey\n\n'
          'Please take your medicine on time.\n\n'
          'Medicare';

    await send(message, smtpServer);
  }

}
