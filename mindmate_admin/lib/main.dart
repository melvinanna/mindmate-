import 'package:flutter/material.dart';
import 'package:mindmate_admin/login.dart';
import 'package:mindmate_admin/homepage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  await Supabase.initialize(
    url: 'https://disbpshtlcxhvzozplpb.supabase.co',
    anonKey: 'sb_publishable_EDMIfGN40YB3NVojTYxBhQ_2n6QrHC1',
  );
  runApp(const MindMateAdminApp());
}

final supabase = Supabase.instance.client;

class MindMateAdminApp extends StatelessWidget {
  const MindMateAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MINDMATE+ Admin',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        useMaterial3: true,
      ),
      home: supabase.auth.currentUser != null
          ? const AdminDashboardScreen()
          : const LoginScreen(),
    );
  }
}
