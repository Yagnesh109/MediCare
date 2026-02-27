import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:medicare_app/firebase_options.dart';
import 'package:medicare_app/models/medicine.dart';
import 'package:medicare_app/services/dose_tracking_service.dart';
import 'package:medicare_app/services/voice_alert_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

const String _actionTaken = 'dose_taken';
const String _actionSkipped = 'dose_skipped';
const String _actionSnooze = 'dose_snooze';
const int _maxSnoozeCount = 2;

@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  try {
    if (!dotenv.isInitialized) {
      await dotenv.load(fileName: '.env');
    }
  } catch (_) {}
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
  try {
    await NotificationService.instance.init();
  } catch (_) {}
  await NotificationService.instance.handleNotificationAction(response);
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'medicare_reminders',
    'Medicare Reminders',
    description: 'Daily reminders for medicines',
    importance: Importance.high,
  );

  bool _isInitialized = false;
  bool _localNotificationsReady = false;
  String _timezoneName = 'unknown';
  final Map<int, Timer> _inAppVoiceTimers = <int, Timer>{};

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    tz_data.initializeTimeZones();
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
      _timezoneName = timezoneName;
      debugPrint('Notification timezone set: $timezoneName');
    } catch (e) {
      debugPrint('Failed to set timezone, falling back to UTC: $e');
      tz.setLocalLocation(tz.getLocation('UTC'));
      _timezoneName = 'UTC';
    }

    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    try {
      await _localNotifications.initialize(
        const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
        onDidReceiveNotificationResponse: handleNotificationAction,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
      _localNotificationsReady = true;
    } catch (e) {
      debugPrint('Local notifications initialize failed: $e');
      _localNotificationsReady = false;
    }
    await VoiceAlertService.instance.init();

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    try {
      if (Platform.isAndroid) {
        final notifyStatus = await Permission.notification.status;
        if (!notifyStatus.isGranted) {
          await Permission.notification.request();
        }
        final batteryStatus =
            await Permission.ignoreBatteryOptimizations.status;
        if (!batteryStatus.isGranted) {
          await Permission.ignoreBatteryOptimizations.request();
        }
      }

      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
      final canExact = await androidPlugin?.canScheduleExactNotifications();
      debugPrint('Exact alarm permission status: $canExact');

      if (_localNotificationsReady) {
        await androidPlugin?.createNotificationChannel(_channel);
      }
    } catch (e) {
      debugPrint('Notification permission/channel setup failed: $e');
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (!_localNotificationsReady) return;
      final notification = message.notification;
      if (notification == null) return;
      try {
        await _localNotifications.show(
          message.hashCode,
          notification.title ?? 'Medicare',
          notification.body ?? 'Medicine reminder',
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
        );
      } catch (e) {
        debugPrint('Foreground local notification failed: $e');
      }
    });
  }

  Future<void> scheduleDailyMedicineReminder({
    required int id,
    required String medicineId,
    required String medicineName,
    required String dosage,
    required List<DoseSchedule> doses,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (!_localNotificationsReady) {
      debugPrint('Skipping schedule: local notifications not ready');
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    final minLead = now.add(const Duration(minutes: 2));
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);

    if (endDay.isBefore(startDay)) {
      debugPrint('Skipping schedule: end date is before start date');
      return;
    }

    final today = DateTime(now.year, now.month, now.day);
    final effectiveStart = startDay.isAfter(today) ? startDay : today;
    if (effectiveStart.isAfter(endDay)) {
      debugPrint('Skipping schedule: current date is outside medicine range');
      return;
    }

    try {
      final baseId = id.abs() % 20000000;
      final canExact = await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.canScheduleExactNotifications();

      if (doses.isEmpty) {
        debugPrint('Skipping schedule: no dose times configured');
        return;
      }

      var scheduledCount = 0;
      for (var day = effectiveStart;
          !day.isAfter(endDay);
          day = day.add(const Duration(days: 1))) {
        final isToday = day.year == now.year &&
            day.month == now.month &&
            day.day == now.day;
        for (final dose in doses) {
          final parsedTime = _parseTimeOfDay(dose.time);
          if (parsedTime == null) {
            continue;
          }

          final scheduledDateBase = tz.TZDateTime(
            tz.local,
            day.year,
            day.month,
            day.day,
            parsedTime.hour,
            parsedTime.minute,
          );
          tz.TZDateTime scheduledDate = scheduledDateBase;

          if (!scheduledDate.isAfter(now)) {
            continue;
          }
          // If today's chosen time is very close, do not skip it; schedule at safe lead time.
          if (isToday && !scheduledDate.isAfter(minLead)) {
            scheduledDate = minLead;
          }

          final notificationId = _safeNotificationId(baseId, scheduledCount);
          scheduledCount++;
          final payload = _buildDosePayload(
            patientId: FirebaseAuth.instance.currentUser?.uid ?? '',
            medicineId: medicineId,
            medicineName: medicineName,
            dosage: dosage,
            scheduledTime: dose.time,
            dateKey: _dateKey(scheduledDate),
            doseKey: dose.doseKey,
            mealRelation: dose.mealRelation,
            mealType: dose.mealType,
            snoozeCount: 0,
          );
          debugPrint(
            'Scheduling reminder[$scheduledCount] now=$now scheduled=$scheduledDate tz=$_timezoneName exact=$canExact id=$notificationId',
          );
          await _localNotifications.zonedSchedule(
            notificationId,
            'Medicine Reminder',
            '$medicineName - $dosage (${dose.mealLabel})',
            scheduledDate,
            _notificationDetailsWithActions(),
            payload: payload,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
          _scheduleInAppVoiceReminder(
            notificationId: notificationId,
            scheduledDate: scheduledDate,
            medicineName: medicineName,
            scheduledTime: dose.time,
          );
        }
      }

      if (scheduledCount == 0) {
        debugPrint(
          'No reminders scheduled: no future reminder time inside selected date range.',
        );
      }
      final pending = await _localNotifications.pendingNotificationRequests();
      debugPrint(
        'Scheduled reminders complete. count=$scheduledCount range=$effectiveStart..$endDay pending=${pending.length}',
      );
    } catch (e) {
      debugPrint('Failed to schedule daily reminder: $e');
    }
  }

  Future<void> handleNotificationAction(NotificationResponse response) async {
    if (!_localNotificationsReady) {
      try {
        await init();
      } catch (_) {}
    }
    final actionId = response.actionId ?? '';
    final payloadRaw = response.payload;
    if (payloadRaw == null || payloadRaw.isEmpty) {
      return;
    }

    try {
      final map = jsonDecode(payloadRaw) as Map<String, dynamic>;
      final medicineId = (map['medicineId'] ?? '').toString();
      final patientId = (map['patientId'] ?? '').toString();
      final medicineName = (map['medicineName'] ?? '').toString();
      final dosage = (map['dosage'] ?? '').toString();
      final scheduledTime = (map['scheduledTime'] ?? '').toString();
      final dateKey = (map['dateKey'] ?? '').toString();
      final doseKey = (map['doseKey'] ?? '').toString();
      final mealRelation = (map['mealRelation'] ?? '').toString();
      final mealType = (map['mealType'] ?? '').toString();
      final snoozeCount = (map['snoozeCount'] as num?)?.toInt() ?? 0;

      if (medicineId.isEmpty || dateKey.isEmpty) {
        return;
      }
      if (actionId.isEmpty) {
        await VoiceAlertService.instance.speakReminder(
          medicineName: medicineName,
          time: scheduledTime,
        );
      }

      if (actionId == _actionTaken) {
        await DoseTrackingService.instance.setDoseStatusFromNotification(
          medicineId: medicineId,
          medicineName: medicineName,
          dosage: dosage,
          scheduledTime: scheduledTime,
          dateKey: dateKey,
          doseKey: doseKey,
          mealRelation: mealRelation,
          mealType: mealType,
          status: 'taken',
          patientId: patientId,
        );
      } else if (actionId == _actionSkipped) {
        await DoseTrackingService.instance.setDoseStatusFromNotification(
          medicineId: medicineId,
          medicineName: medicineName,
          dosage: dosage,
          scheduledTime: scheduledTime,
          dateKey: dateKey,
          doseKey: doseKey,
          mealRelation: mealRelation,
          mealType: mealType,
          status: 'missed',
          patientId: patientId,
        );
      } else if (actionId == _actionSnooze) {
        if (snoozeCount >= _maxSnoozeCount) {
          return;
        }
        await _scheduleSnoozeReminder(
          medicineId: medicineId,
          medicineName: medicineName,
          dosage: dosage,
          patientId: patientId,
          scheduledTime: scheduledTime,
          dateKey: dateKey,
          doseKey: doseKey,
          mealRelation: mealRelation,
          mealType: mealType,
          nextSnoozeCount: snoozeCount + 1,
        );
      }
    } catch (e) {
      debugPrint('Failed to handle notification action: $e');
    }
  }

  NotificationDetails _notificationDetailsWithActions() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(
            _actionTaken,
            'Taken',
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            _actionSkipped,
            'Skipped',
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            _actionSnooze,
            'Snooze 5m',
            cancelNotification: true,
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

  String _buildDosePayload({
    required String patientId,
    required String medicineId,
    required String medicineName,
    required String dosage,
    required String scheduledTime,
    required String dateKey,
    required String doseKey,
    required String mealRelation,
    required String mealType,
    required int snoozeCount,
  }) {
    return jsonEncode({
      'patientId': patientId,
      'medicineId': medicineId,
      'medicineName': medicineName,
      'dosage': dosage,
      'scheduledTime': scheduledTime,
      'dateKey': dateKey,
      'doseKey': doseKey,
      'mealRelation': mealRelation,
      'mealType': mealType,
      'snoozeCount': snoozeCount,
    });
  }

  Future<void> _scheduleSnoozeReminder({
    required String medicineId,
    required String medicineName,
    required String dosage,
    required String patientId,
    required String scheduledTime,
    required String dateKey,
    required String doseKey,
    required String mealRelation,
    required String mealType,
    required int nextSnoozeCount,
  }) async {
    if (!_localNotificationsReady) return;

    final now = tz.TZDateTime.now(tz.local);
    final snoozeAt = now.add(const Duration(minutes: 5));
    final snoozeId = DateTime.now().millisecondsSinceEpoch % 2147483646;
    final payload = _buildDosePayload(
      patientId: patientId,
      medicineId: medicineId,
      medicineName: medicineName,
      dosage: dosage,
      scheduledTime: scheduledTime,
      dateKey: dateKey,
      doseKey: doseKey,
      mealRelation: mealRelation,
      mealType: mealType,
      snoozeCount: nextSnoozeCount,
    );

    await _localNotifications.zonedSchedule(
      snoozeId == 0 ? 1 : snoozeId,
      'Medicine Reminder (Snooze $nextSnoozeCount/$_maxSnoozeCount)',
      '$medicineName - $dosage',
      snoozeAt,
      _notificationDetailsWithActions(),
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    _scheduleInAppVoiceReminder(
      notificationId: snoozeId == 0 ? 1 : snoozeId,
      scheduledDate: snoozeAt,
      medicineName: medicineName,
      scheduledTime: scheduledTime,
    );
    debugPrint(
      'Snoozed reminder medicine=$medicineId count=$nextSnoozeCount at=$snoozeAt',
    );
    final pending = await _localNotifications.pendingNotificationRequests();
    debugPrint('Pending notifications after snooze: ${pending.length}');
  }

  TimeOfDay? _parseTimeOfDay(String raw) {
    final input = raw.trim().toUpperCase();
    final regex = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$');
    final match = regex.firstMatch(input);
    if (match == null) return null;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final meridiem = match.group(3)!;
    if (meridiem == 'PM' && hour != 12) hour += 12;
    if (meridiem == 'AM' && hour == 12) hour = 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _dateKey(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  // Deterministic IDs prevent Android from overwriting previously scheduled alarms.
  int _safeNotificationId(int baseId, int index) {
    final candidate = (baseId * 100) + index;
    return candidate < 1 ? 1 : candidate;
  }

  void _scheduleInAppVoiceReminder({
    required int notificationId,
    required tz.TZDateTime scheduledDate,
    required String medicineName,
    required String scheduledTime,
  }) {
    _inAppVoiceTimers.remove(notificationId)?.cancel();
    final now = tz.TZDateTime.now(tz.local);
    final delay = scheduledDate.difference(now);
    if (delay.isNegative || delay == Duration.zero) {
      return;
    }
    _inAppVoiceTimers[notificationId] = Timer(delay, () async {
      _inAppVoiceTimers.remove(notificationId);
      await VoiceAlertService.instance.speakReminder(
        medicineName: medicineName,
        time: scheduledTime,
      );
    });
  }

  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_localNotificationsReady) return;
    try {
      await _localNotifications.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
      debugPrint('Instant notification shown: id=$id');
    } catch (e) {
      debugPrint('Instant notification failed: $e');
    }
  }

  Future<void> cancelMedicineReminders({
    required int id,
    int days = 5000,
  }) async {
    if (!_localNotificationsReady) return;
    final baseId = id.abs() % 20000000;
    for (int i = 0; i < days; i++) {
      final notificationId = _safeNotificationId(baseId, i);
      _inAppVoiceTimers.remove(notificationId)?.cancel();
      await _localNotifications.cancel(notificationId);
    }
  }
}
