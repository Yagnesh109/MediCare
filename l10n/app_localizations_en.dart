// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Medicare';

  @override
  String get loginTitle => 'Medicare Login';

  @override
  String get loginSubtitle => 'Manage your medication reminders';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get login => 'Login';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get noAccountRegister => 'Don\'t have an account? Register';

  @override
  String get or => 'OR';

  @override
  String get phoneWithCode => 'Phone (+country code)';

  @override
  String get enterOtp => 'Enter OTP';

  @override
  String get sendOtp => 'Send OTP';

  @override
  String get resendOtp => 'Resend OTP';

  @override
  String get verifyOtpLogin => 'Verify OTP & Login';

  @override
  String get createAccountTitle => 'Create Medicare Account';

  @override
  String get createAccountSubtitle => 'Sign up to start medication reminders';

  @override
  String get fullName => 'Full Name';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get createAccount => 'Create Account';

  @override
  String get alreadyHaveAccount => 'Already have an account? Login';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get adherenceHistory => 'Adherence History';

  @override
  String get caregivers => 'Caregivers';

  @override
  String get addMedicine => 'Add Medicine';

  @override
  String get sideEffectChecker => 'Side Effect Checker';

  @override
  String get profile => 'Profile';

  @override
  String get language => 'Language';

  @override
  String get logout => 'Logout';

  @override
  String get today => 'Today';

  @override
  String get pending => 'Pending';

  @override
  String get todaysSchedule => 'Today\'s Schedule';

  @override
  String get noMedicinesYet => 'No medicines added yet';

  @override
  String get tapToAddFirstMedicine =>
      'Tap the button below to add your first medicine reminder.';

  @override
  String get noPendingMedicinesToday => 'No pending medicines for today';

  @override
  String get adherenceContainsTakenMissed =>
      'Taken and missed medicines are available in Adherence History.';

  @override
  String get addCaregiver => 'Add Caregiver';

  @override
  String get noCaregiversYet => 'No caregivers added yet';

  @override
  String get taken => 'Taken';

  @override
  String get missed => 'Missed';

  @override
  String get all => 'All';

  @override
  String get type => 'Type';

  @override
  String get allDates => 'All Dates';

  @override
  String get doseHistory => 'Dose History';

  @override
  String get clearAllHistory => 'Clear All History';

  @override
  String get clearHistory => 'Clear History';

  @override
  String get deleteAll => 'Delete All';

  @override
  String get clearHistoryConfirm =>
      'This will permanently delete all adherence history from app UI and Firebase database. Continue?';

  @override
  String get adherenceCleared => 'Adherence history cleared';

  @override
  String get caregiverAdded => 'Caregiver added';

  @override
  String get caregiverUpdated => 'Caregiver updated';

  @override
  String get caregiverRemoved => 'Caregiver removed';

  @override
  String get call => 'Call';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get name => 'Name';

  @override
  String get phone => 'Phone';

  @override
  String get pleaseLoginAgain => 'Please login again.';

  @override
  String get pleaseLoginAgainRetry => 'Please login again and retry.';

  @override
  String get profileSaved => 'Profile saved';

  @override
  String get patientName => 'Patient Name';

  @override
  String get gender => 'Gender';

  @override
  String get bloodGroup => 'Blood Group';

  @override
  String get dateOfBirth => 'Date of Birth';

  @override
  String get ageCalculated => 'Age (calculated from DOB)';

  @override
  String get weightKg => 'Weight (kg)';

  @override
  String get heightCm => 'Height (cm)';

  @override
  String get allergies => 'Allergies';

  @override
  String get notSet => 'Not set';

  @override
  String allergiesDisplay(Object value) {
    return 'Allergies: $value';
  }

  @override
  String get bmi => 'BMI';

  @override
  String get analyzeSideEffects => 'Analyze Side Effects';

  @override
  String get analyzing => 'Analyzing...';

  @override
  String get medicineName => 'Medicine Name';

  @override
  String get doseOptional => 'Dose (optional)';

  @override
  String get symptomsComma => 'Symptoms (comma separated)';

  @override
  String get knownConditionsComma => 'Known conditions (comma separated)';

  @override
  String get extraNotesOptional => 'Extra notes (optional)';

  @override
  String get analysisResult => 'Analysis Result';

  @override
  String get urgency => 'Urgency';

  @override
  String get doctorConsultNeeded => 'Doctor consultation needed';

  @override
  String get confidence => 'Confidence';

  @override
  String get source => 'Source';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get possibleReasons => 'Possible Reasons';

  @override
  String get immediateActions => 'Immediate Actions';

  @override
  String get warningSigns => 'Warning Signs';

  @override
  String get guidanceOnly => 'This is guidance only, not a medical diagnosis.';

  @override
  String get medicineSaved => 'Medicine saved successfully';

  @override
  String get medicineUpdated => 'Medicine updated successfully';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get english => 'English';

  @override
  String get hindi => 'Hindi';

  @override
  String get marathi => 'Marathi';
}
