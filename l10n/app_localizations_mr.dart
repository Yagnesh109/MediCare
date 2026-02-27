// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Marathi (`mr`).
class AppLocalizationsMr extends AppLocalizations {
  AppLocalizationsMr([String locale = 'mr']) : super(locale);

  @override
  String get appTitle => 'मेडिकेअर';

  @override
  String get loginTitle => 'मेडिकेअर लॉगिन';

  @override
  String get loginSubtitle => 'तुमचे औषध रिमाइंडर व्यवस्थापित करा';

  @override
  String get email => 'ईमेल';

  @override
  String get password => 'पासवर्ड';

  @override
  String get login => 'लॉगिन';

  @override
  String get continueWithGoogle => 'Google द्वारे पुढे जा';

  @override
  String get noAccountRegister => 'खाते नाही? नोंदणी करा';

  @override
  String get or => 'किंवा';

  @override
  String get phoneWithCode => 'फोन (+देश कोड)';

  @override
  String get enterOtp => 'OTP टाका';

  @override
  String get sendOtp => 'OTP पाठवा';

  @override
  String get resendOtp => 'OTP पुन्हा पाठवा';

  @override
  String get verifyOtpLogin => 'OTP पडताळा आणि लॉगिन करा';

  @override
  String get createAccountTitle => 'मेडिकेअर खाते तयार करा';

  @override
  String get createAccountSubtitle =>
      'औषध रिमाइंडर सुरू करण्यासाठी साइन अप करा';

  @override
  String get fullName => 'पूर्ण नाव';

  @override
  String get confirmPassword => 'पासवर्ड पुष्टी करा';

  @override
  String get createAccount => 'खाते तयार करा';

  @override
  String get alreadyHaveAccount => 'आधीच खाते आहे? लॉगिन करा';

  @override
  String get dashboard => 'डॅशबोर्ड';

  @override
  String get adherenceHistory => 'अनुपालन इतिहास';

  @override
  String get caregivers => 'केअरगिव्हर्स';

  @override
  String get addMedicine => 'औषध जोडा';

  @override
  String get sideEffectChecker => 'साइड इफेक्ट तपासक';

  @override
  String get profile => 'प्रोफाइल';

  @override
  String get language => 'भाषा';

  @override
  String get logout => 'लॉगआउट';

  @override
  String get today => 'आज';

  @override
  String get pending => 'प्रलंबित';

  @override
  String get todaysSchedule => 'आजचे वेळापत्रक';

  @override
  String get noMedicinesYet => 'अजून कोणतीही औषधे जोडलेली नाहीत';

  @override
  String get tapToAddFirstMedicine =>
      'पहिले औषध रिमाइंडर जोडण्यासाठी खालील बटण दाबा.';

  @override
  String get noPendingMedicinesToday => 'आज कोणतीही प्रलंबित औषधे नाहीत';

  @override
  String get adherenceContainsTakenMissed =>
      'घेतलेली आणि चुकलेली औषधे अनुपालन इतिहासात उपलब्ध आहेत.';

  @override
  String get addCaregiver => 'केअरगिव्हर जोडा';

  @override
  String get noCaregiversYet => 'अजून कोणताही केअरगिव्हर जोडलेला नाही';

  @override
  String get taken => 'घेतले';

  @override
  String get missed => 'चुकले';

  @override
  String get all => 'सर्व';

  @override
  String get type => 'प्रकार';

  @override
  String get allDates => 'सर्व तारखा';

  @override
  String get doseHistory => 'डोस इतिहास';

  @override
  String get clearAllHistory => 'संपूर्ण इतिहास साफ करा';

  @override
  String get clearHistory => 'इतिहास साफ करा';

  @override
  String get deleteAll => 'सर्व हटवा';

  @override
  String get clearHistoryConfirm =>
      'यामुळे अॅप UI आणि Firebase डेटाबेसमधील सर्व अनुपालन इतिहास कायमचा हटवला जाईल. पुढे जावे?';

  @override
  String get adherenceCleared => 'अनुपालन इतिहास साफ केला';

  @override
  String get caregiverAdded => 'केअरगिव्हर जोडला';

  @override
  String get caregiverUpdated => 'केअरगिव्हर अपडेट केला';

  @override
  String get caregiverRemoved => 'केअरगिव्हर हटवला';

  @override
  String get call => 'कॉल';

  @override
  String get edit => 'संपादित करा';

  @override
  String get delete => 'हटवा';

  @override
  String get save => 'सेव्ह';

  @override
  String get cancel => 'रद्द करा';

  @override
  String get name => 'नाव';

  @override
  String get phone => 'फोन';

  @override
  String get pleaseLoginAgain => 'कृपया पुन्हा लॉगिन करा.';

  @override
  String get pleaseLoginAgainRetry =>
      'कृपया पुन्हा लॉगिन करून पुन्हा प्रयत्न करा.';

  @override
  String get profileSaved => 'प्रोफाइल सेव्ह झाले';

  @override
  String get patientName => 'रुग्णाचे नाव';

  @override
  String get gender => 'लिंग';

  @override
  String get bloodGroup => 'रक्तगट';

  @override
  String get dateOfBirth => 'जन्मतारीख';

  @override
  String get ageCalculated => 'वय (DOB वरून गणना)';

  @override
  String get weightKg => 'वजन (किलो)';

  @override
  String get heightCm => 'उंची (सेमी)';

  @override
  String get allergies => 'अॅलर्जी';

  @override
  String get notSet => 'सेट नाही';

  @override
  String allergiesDisplay(Object value) {
    return 'अॅलर्जी: $value';
  }

  @override
  String get bmi => 'BMI';

  @override
  String get analyzeSideEffects => 'साइड इफेक्ट विश्लेषण करा';

  @override
  String get analyzing => 'विश्लेषण सुरू आहे...';

  @override
  String get medicineName => 'औषधाचे नाव';

  @override
  String get doseOptional => 'डोस (ऐच्छिक)';

  @override
  String get symptomsComma => 'लक्षणे (स्वल्पविरामाने वेगळे)';

  @override
  String get knownConditionsComma => 'ज्ञात स्थिती (स्वल्पविरामाने वेगळे)';

  @override
  String get extraNotesOptional => 'अतिरिक्त नोंदी (ऐच्छिक)';

  @override
  String get analysisResult => 'विश्लेषण परिणाम';

  @override
  String get urgency => 'तातडी';

  @override
  String get doctorConsultNeeded => 'डॉक्टरांचा सल्ला आवश्यक';

  @override
  String get confidence => 'विश्वास पातळी';

  @override
  String get source => 'स्रोत';

  @override
  String get yes => 'होय';

  @override
  String get no => 'नाही';

  @override
  String get possibleReasons => 'संभाव्य कारणे';

  @override
  String get immediateActions => 'तात्काळ कृती';

  @override
  String get warningSigns => 'धोक्याची चिन्हे';

  @override
  String get guidanceOnly => 'हे फक्त मार्गदर्शन आहे, वैद्यकीय निदान नाही.';

  @override
  String get medicineSaved => 'औषध यशस्वीरीत्या सेव्ह झाले';

  @override
  String get medicineUpdated => 'औषध यशस्वीरीत्या अपडेट झाले';

  @override
  String get selectLanguage => 'भाषा निवडा';

  @override
  String get english => 'इंग्रजी';

  @override
  String get hindi => 'हिंदी';

  @override
  String get marathi => 'मराठी';
}
