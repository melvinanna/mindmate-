import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mindmate_caregiver/splash_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mindmate_caregiver/background_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final FlutterTts tts = FlutterTts();
  await tts.setSharedInstance(true);
  String text = message.notification?.body ?? "Caregiver Alert";
  await tts.speak(text);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await Supabase.initialize(
    url: 'https://disbpshtlcxhvzozplpb.supabase.co',
    anonKey: 'sb_publishable_EDMIfGN40YB3NVojTYxBhQ_2n6QrHC1',
  );

  // Requesting necessary permissions on app start
  await [
    Permission.notification,
    Permission.location,
    Permission.locationAlways,
  ].request();

  await initializeService();
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

Future<void> logActivity(String action, String? details) async {
  try {
    final user = supabase.auth.currentUser;
    if (user != null) {
      await supabase.from('tbl_activity_log').insert({
        'user_id': user.id,
        'user_type': 'Caregiver',
        'action': action,
        'details': details,
      });
    }
  } catch (e) {
    debugPrint("Failed to log activity: $e");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}
