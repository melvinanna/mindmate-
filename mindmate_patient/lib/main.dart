import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mindmate_patient/splash_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mindmate_patient/background_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

// Background message handler for FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  // Speak the notification in background
  final FlutterTts tts = FlutterTts();
  await tts.setSharedInstance(true);
  String text = message.notification?.body ?? "New Notification";
  await tts.speak(text);
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'mindmate_alerts', // id
  'MindMate Alerts', // title
  description: 'Notifications for reminders and schedules.',
  importance: Importance.max,
  playSound: true,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize Local Notifications
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  const initializationSettingsAndroid = AndroidInitializationSettings(
    '@mipmap/ic_launcher',
  );
  const initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
    onDidReceiveNotificationResponse: (details) {},
  );

  // Foreground message handler
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null) {
      flutterLocalNotificationsPlugin.show(
        id: notification.hashCode & 0x7FFFFFFF,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
        ),
      );

      // Also speak it
      final FlutterTts tts = FlutterTts();
      tts.speak(notification.body ?? "");
    }
  });

  // Initialize Supabase
  await Supabase.initialize(
       url: 'https://disbpshtlcxhvzozplpb.supabase.co',
        anonKey: 'sb_publishable_EDMIfGN40YB3NVojTYxBhQ_2n6QrHC1',
  );

  // Request All Permissions
  await [
    Permission.location,
    Permission.locationAlways,
    Permission.notification,
    Permission.sms,
    Permission.microphone,
    Permission.camera,
  ].request();

  await initializeService();
  runApp(const MainApp());
}

final supabase = Supabase.instance.client;

Future<void> logActivity(String action, String? details) async {
  try {
    final user = supabase.auth.currentUser;
    if (user != null) {
      await supabase.from('tbl_activity_log').insert({
        'user_id': user.id,
        'user_type': 'Patient',
        'action': action,
        'details': details,
      });
    }
  } catch (e) {
    debugPrint("Failed to log activity: $e");
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}
