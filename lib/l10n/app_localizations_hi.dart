// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'मेडिकेयर';

  @override
  String get loginTitle => 'मेडिकेयर लॉगिन';

  @override
  String get loginSubtitle => 'अपनी दवा रिमाइंडर प्रबंधित करें';

  @override
  String get email => 'ईमेल';

  @override
  String get password => 'पासवर्ड';

  @override
  String get login => 'लॉगिन';

  @override
  String get continueWithGoogle => 'Google से जारी रखें';

  @override
  String get noAccountRegister => 'खाता नहीं है? रजिस्टर करें';

  @override
  String get or => 'या';

  @override
  String get phoneWithCode => 'फोन (+देश कोड)';

  @override
  String get enterOtp => 'OTP दर्ज करें';

  @override
  String get sendOtp => 'OTP भेजें';

  @override
  String get resendOtp => 'OTP दोबारा भेजें';

  @override
  String get verifyOtpLogin => 'OTP सत्यापित करें और लॉगिन करें';

  @override
  String get createAccountTitle => 'मेडिकेयर खाता बनाएं';

  @override
  String get createAccountSubtitle =>
      'दवा रिमाइंडर शुरू करने के लिए साइन अप करें';

  @override
  String get fullName => 'पूरा नाम';

  @override
  String get confirmPassword => 'पासवर्ड की पुष्टि करें';

  @override
  String get createAccount => 'खाता बनाएं';

  @override
  String get alreadyHaveAccount => 'पहले से खाता है? लॉगिन करें';

  @override
  String get dashboard => 'डैशबोर्ड';

  @override
  String get adherenceHistory => 'अनुपालन इतिहास';

  @override
  String get caregivers => 'केयरगिवर्स';

  @override
  String get addMedicine => 'दवा जोड़ें';

  @override
  String get sideEffectChecker => 'साइड इफेक्ट चेकर';

  @override
  String get profile => 'प्रोफाइल';

  @override
  String get language => 'भाषा';

  @override
  String get logout => 'लॉगआउट';

  @override
  String get today => 'आज';

  @override
  String get pending => 'लंबित';

  @override
  String get todaysSchedule => 'आज का शेड्यूल';

  @override
  String get noMedicinesYet => 'अभी तक कोई दवा नहीं जोड़ी गई';

  @override
  String get tapToAddFirstMedicine =>
      'अपना पहला दवा रिमाइंडर जोड़ने के लिए नीचे बटन दबाएं।';

  @override
  String get noPendingMedicinesToday => 'आज कोई लंबित दवा नहीं है';

  @override
  String get adherenceContainsTakenMissed =>
      'ली गई और छूटी दवाएं अनुपालन इतिहास में उपलब्ध हैं।';

  @override
  String get addCaregiver => 'केयरगिवर जोड़ें';

  @override
  String get noCaregiversYet => 'अभी तक कोई केयरगिवर नहीं जोड़ा गया';

  @override
  String get taken => 'ली गई';

  @override
  String get missed => 'छूटी';

  @override
  String get all => 'सभी';

  @override
  String get type => 'प्रकार';

  @override
  String get allDates => 'सभी तिथियाँ';

  @override
  String get doseHistory => 'डोज इतिहास';

  @override
  String get clearAllHistory => 'सारा इतिहास साफ करें';

  @override
  String get clearHistory => 'इतिहास साफ करें';

  @override
  String get deleteAll => 'सभी हटाएं';

  @override
  String get clearHistoryConfirm =>
      'यह ऐप UI और Firebase डेटाबेस से पूरा अनुपालन इतिहास स्थायी रूप से हटा देगा। जारी रखें?';

  @override
  String get adherenceCleared => 'अनुपालन इतिहास साफ कर दिया गया';

  @override
  String get caregiverAdded => 'केयरगिवर जोड़ा गया';

  @override
  String get caregiverUpdated => 'केयरगिवर अपडेट किया गया';

  @override
  String get caregiverRemoved => 'केयरगिवर हटाया गया';

  @override
  String get call => 'कॉल';

  @override
  String get edit => 'संपादित करें';

  @override
  String get delete => 'हटाएं';

  @override
  String get save => 'सेव करें';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get name => 'नाम';

  @override
  String get phone => 'फोन';

  @override
  String get pleaseLoginAgain => 'कृपया फिर से लॉगिन करें।';

  @override
  String get pleaseLoginAgainRetry =>
      'कृपया फिर से लॉगिन करें और दोबारा प्रयास करें।';

  @override
  String get profileSaved => 'प्रोफाइल सेव हो गया';

  @override
  String get patientName => 'रोगी का नाम';

  @override
  String get gender => 'लिंग';

  @override
  String get bloodGroup => 'ब्लड ग्रुप';

  @override
  String get dateOfBirth => 'जन्म तिथि';

  @override
  String get ageCalculated => 'आयु (DOB से गणना)';

  @override
  String get weightKg => 'वजन (किग्रा)';

  @override
  String get heightCm => 'ऊंचाई (सेमी)';

  @override
  String get allergies => 'एलर्जी';

  @override
  String get notSet => 'सेट नहीं';

  @override
  String allergiesDisplay(Object value) {
    return 'एलर्जी: $value';
  }

  @override
  String get bmi => 'BMI';

  @override
  String get analyzeSideEffects => 'साइड इफेक्ट विश्लेषण करें';

  @override
  String get analyzing => 'विश्लेषण हो रहा है...';

  @override
  String get medicineName => 'दवा का नाम';

  @override
  String get doseOptional => 'डोज (वैकल्पिक)';

  @override
  String get symptomsComma => 'लक्षण (कॉमा से अलग)';

  @override
  String get knownConditionsComma => 'ज्ञात स्थितियाँ (कॉमा से अलग)';

  @override
  String get extraNotesOptional => 'अतिरिक्त नोट्स (वैकल्पिक)';

  @override
  String get analysisResult => 'विश्लेषण परिणाम';

  @override
  String get urgency => 'तात्कालिकता';

  @override
  String get doctorConsultNeeded => 'डॉक्टर से परामर्श आवश्यक';

  @override
  String get confidence => 'विश्वसनीयता';

  @override
  String get source => 'स्रोत';

  @override
  String get yes => 'हाँ';

  @override
  String get no => 'नहीं';

  @override
  String get possibleReasons => 'संभावित कारण';

  @override
  String get immediateActions => 'तुरंत किए जाने वाले कार्य';

  @override
  String get warningSigns => 'चेतावनी संकेत';

  @override
  String get guidanceOnly => 'यह केवल मार्गदर्शन है, चिकित्सीय निदान नहीं।';

  @override
  String get medicineSaved => 'दवा सफलतापूर्वक सेव हुई';

  @override
  String get medicineUpdated => 'दवा सफलतापूर्वक अपडेट हुई';

  @override
  String get selectLanguage => 'भाषा चुनें';

  @override
  String get english => 'अंग्रेज़ी';

  @override
  String get hindi => 'हिंदी';

  @override
  String get marathi => 'मराठी';
}
