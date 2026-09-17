import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'patient_service',
    'Patient Monitor',
    description: 'Keep the patient safe with background tracking.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'patient_service',
      initialNotificationTitle: 'MindMate Monitor',
      initialNotificationContent: 'Tracking location & safety...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  await Supabase.initialize(
    url: 'https://disbpshtlcxhvzozplpb.supabase.co',
    anonKey: 'sb_publishable_EDMIfGN40YB3NVojTYxBhQ_2n6QrHC1',
  );

  final client = Supabase.instance.client;
  final FlutterTts flutterTts = FlutterTts();
  await flutterTts.setSharedInstance(true);

  // Service-local init for TTS
  await flutterTts.setLanguage("en-US");
  await flutterTts.setSpeechRate(0.5);

  final FlutterLocalNotificationsPlugin localNotif =
      FlutterLocalNotificationsPlugin();
  
  const initializationSettingsAndroid = AndroidInitializationSettings(
    '@mipmap/ic_launcher',
  );
  const initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await localNotif.initialize(
    settings: initializationSettings,
    onDidReceiveNotificationResponse: (details) {},
  );

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  Set<String> alertedMedIDs = {};
  int currentMinute = -1;
  bool wasOutsideSafeZone = false; // Tracks if we already alerted for being outside

  // Start Location Tracking & Monitoring in Background
  Timer.periodic(const Duration(seconds: 45), (timer) async {
    final user = client.auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    if (now.minute != currentMinute) {
      currentMinute = now.minute;
      alertedMedIDs.clear(); // Clear registry for the new minute
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 1. Update DB
      await client
          .from('tbl_patient')
          .update({
            'last_known_location_lat': position.latitude,
            'last_known_location_lng': position.longitude,
          })
          .eq('id', user.id);

      // 2. Insert History
      await client.from('tbl_location_history').insert({
        'patient_id': user.id,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'recorded_at': DateTime.now().toIso8601String(),
      });

      // 3. Safe Zone Check
      final profile = await client
          .from('tbl_patient')
          .select('safe_zone_lat, safe_zone_lng, safe_zone_radius')
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null && profile['safe_zone_lat'] != null) {
        double distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          (profile['safe_zone_lat'] as num).toDouble(),
          (profile['safe_zone_lng'] as num).toDouble(),
        );
        int radius = (profile['safe_zone_radius'] as num?)?.toInt() ?? 100;

        if (distance > radius) {
          if (!wasOutsideSafeZone) {
            wasOutsideSafeZone = true;
            await flutterTts.speak("Warning. You are outside your safe area.");
            await localNotif.show(
              id: 1,
              title: "⚠️ Safe Zone Breach",
              body: "You are outside your designated area. Please return home.",
              notificationDetails: const NotificationDetails(
                android: AndroidNotificationDetails(
                  'patient_alerts',
                  'Patient Alerts',
                  importance: Importance.max,
                  priority: Priority.high,
                ),
              ),
            );
          }
        } else {
          if (wasOutsideSafeZone) {
            wasOutsideSafeZone = false;
            await flutterTts.speak("You are back in your safe area.");
          }
        }
      }

      // 4. Medication Check
      final timeStr =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

      final meds = await client
          .from('tbl_medicine')
          .select()
          .eq('patient_id', user.id);

      for (var med in meds) {
        String? medTime = med['notification_time']?.toString();
        String medIdStr = "med_${med['id']}";

        if (medTime != null &&
            medTime.startsWith(timeStr) &&
            !alertedMedIDs.contains(medIdStr)) {
          alertedMedIDs.add(medIdStr);

          await flutterTts.speak(
            "Reminder. It's time to take ${med['medicine_name']}. Dosage is ${med['dosage']}.",
          );

          await localNotif.show(
            id: med['id'] & 0x7FFFFFFF,
            title: "💊 Medicine Reminder",
            body: "Time for ${med['medicine_name']} (${med['dosage']})",
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'patient_service',
                'Patient Monitor',
                importance: Importance.max,
                priority: Priority.high,
                playSound: true,
              ),
            ),
          );
        }
      }

      // 5. Daily Schedule (Reminder) Check
      final reminders = await client
          .from('tbl_reminder')
          .select()
          .eq('patient_id', user.id);

      for (var r in reminders) {
        String? rTime = r['reminder_time']?.toString();
        String rIdStr = "rem_${r['id']}";

        if (rTime != null &&
            rTime.startsWith(timeStr) &&
            !alertedMedIDs.contains(rIdStr)) {
          alertedMedIDs.add(rIdStr);

          await flutterTts.speak(
            "Schedule Reminder. ${r['title']}. ${r['description'] ?? ''}",
          );

          await localNotif.show(
            id: (r['id'] + 500) & 0x7FFFFFFF,
            title: "📅 Schedule: ${r['title']}",
            body: r['description'] ?? "Time for your scheduled task.",
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'patient_service',
                'Patient Monitor',
                importance: Importance.max,
                priority: Priority.high,
                playSound: true,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Background tracking error: $e");
    }
  });
}
