import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'caregiver_service',
    'Caregiver Alert Monitor',
    description: 'Keep the patient safe by monitoring alerts.',
    importance: Importance.max,
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
      notificationChannelId: 'caregiver_service',
      initialNotificationTitle: 'Caregiver Tracking Active',
      initialNotificationContent: 'Monitoring Patient Emergency SOS...',
      foregroundServiceNotificationId: 999,
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
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Service-local init for TTS
  await flutterTts.setLanguage("en-US");
  await flutterTts.setSpeechRate(0.5);

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

  // Start Alert Monitoring in Background
  Timer.periodic(const Duration(minutes: 5), (timer) async {
    final user = client.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Fetch Patients of this Caregiver
      final patients = await client
          .from('tbl_patient')
          .select(
            'id, patient_name, patient_status, last_known_location_lat, last_known_location_lng',
          )
          .eq('caregiver_id', user.id);

      for (var p in patients) {
        if (p['patient_status'] == 2) {
          // 2 = SOS
          await flutterTts.speak(
            "Alert. Patient ${p['patient_name']} has triggered an SOS.",
          );

          const AndroidNotificationDetails androidDetails =
              AndroidNotificationDetails(
                'caregiver_alert',
                'Emergency Alert',
                importance: Importance.max,
                priority: Priority.high,
                fullScreenIntent: true,
              );

          await notificationsPlugin.show(
            101,
            "🆘 SOS EMERGENCY",
            "Patient ${p['patient_name']} Needs Help!",
            const NotificationDetails(android: androidDetails),
          );

          // 3. Reset Status to 1 (Active) so we don't spam alerts
          // Only do this if it was SOS (status 2)
          await client
              .from('tbl_patient')
              .update({'patient_status': 1})
              .eq('id', p['id']); 
        }
      }
    } catch (e) {
      debugPrint("Background alert monitor failed: $e");
    }
  });
}
