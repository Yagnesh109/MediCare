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
}
