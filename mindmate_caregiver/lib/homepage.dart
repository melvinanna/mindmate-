import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mindmate_caregiver/manage_patients.dart';
import 'package:mindmate_caregiver/profile.dart';
import 'package:mindmate_caregiver/manage_reminders.dart' as manage_reminders;
import 'package:mindmate_caregiver/manage_medicines.dart' as manage_medicines;
import 'package:mindmate_caregiver/manage_appointments.dart'
    as manage_appointments;
import 'package:mindmate_caregiver/patient_map.dart';
import 'package:mindmate_caregiver/face_training.dart';
import 'package:mindmate_caregiver/emergency_alerts.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mindmate_caregiver/main.dart'; // contains supabase client
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mindmate_caregiver/chatbot_view.dart';
import 'package:mindmate_caregiver/complaints_view.dart';

class CaregiverHomeScreen extends StatefulWidget {
  const CaregiverHomeScreen({super.key});

  @override
  State<CaregiverHomeScreen> createState() => _CaregiverHomeScreenState();
}

class _CaregiverHomeScreenState extends State<CaregiverHomeScreen> {
  int _currentIndex = 0;
  Timer? _remindersTimer;
  List<Map<String, dynamic>> _patientReminders = [];
  List<Map<String, dynamic>> _patientMedicines = [];
  List<Map<String, dynamic>> _patientAppointments = [];
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _initTts();
    _listenToPatientAlerts();
    _initFirebaseMessaging();
    _remindersTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkDueReminders();
    });
  }

  @override
  void dispose() {
    _remindersTimer?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  void _checkDueReminders() {
    final now = DateTime.now();
    final in5Min = now.add(const Duration(minutes: 5));

    final timeStrNow =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final timeStr5m =
        "${in5Min.hour.toString().padLeft(2, '0')}:${in5Min.minute.toString().padLeft(2, '0')}";

    for (var r in _patientReminders) {
      if (r['is_active'] == true) {
        if (r['reminder_time'] == timeStrNow ||
            r['reminder_time'] == "$timeStrNow:00") {
          _speak("Patient reminder due now: ${r['title']}");
          _showNotification("Patient Reminder", r['title'] ?? "");
        } else if (r['reminder_time'] == timeStr5m ||
            r['reminder_time'] == "$timeStr5m:00") {
          _speak("Patient reminder due in 5 minutes: ${r['title']}");
        }
      }
    }

    for (var m in _patientMedicines) {
      if (m['notification_time'] == timeStrNow ||
          m['notification_time'] == "$timeStrNow:00") {
        _speak("Patient medicine due now: ${m['medicine_name']}");
        _showNotification("Patient Medicine", m['medicine_name'] ?? "");
      } else if (m['notification_time'] == timeStr5m ||
          m['notification_time'] == "$timeStr5m:00") {
        _speak("Patient medicine due in 5 minutes: ${m['medicine_name']}");
      }
    }

    for (var a in _patientAppointments) {
      if (a['appointment_time'] == timeStrNow ||
          a['appointment_time'] == "$timeStrNow:00") {
        _speak("Patient appointment now: ${a['doctor_name']}");
        _showNotification("Patient Appointment", a['doctor_name'] ?? "");
      } else if (a['appointment_time'] == timeStr5m ||
          a['appointment_time'] == "$timeStr5m:00") {
        _speak("Patient appointment in 5 minutes: ${a['doctor_name']}");
      }
    }
  }

  void _initFirebaseMessaging() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    String? token = await messaging.getToken();
    final user = supabase.auth.currentUser;
    if (user != null && token != null) {
      await supabase
          .from('tbl_caregiver')
          .update({'fcm_token': token})
          .eq('id', user.id);
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _speak(message.notification!.body ?? "New alert from patient");
        _showNotification(
          message.notification!.title ?? "Patient Update",
          message.notification!.body ?? "",
        );
      }
    });
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  void _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  void _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'alert_channel',
          'Urgent Alerts',
          importance: Importance.max,
          priority: Priority.high,
          color: Colors.red,
          playSound: true,
          enableVibration: true,
        );
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      platformDetails,
    );
    await _flutterTts.speak("$title. $body");
  }

  void _listenToPatientAlerts() {
    final user = supabase.auth.currentUser;
    if (user != null) {
      // 1. Listen to SOS and Safezone Alerts
      supabase
          .from('tbl_patient')
          .stream(primaryKey: ['id'])
          .eq('caregiver_id', user.id)
          .listen((List<Map<String, dynamic>> data) {
            for (var patient in data) {
              // SOS Check
              if (patient['patient_status'] == 2) {
                String name = patient['patient_name'] ?? "A patient";
                _speak("Emergency! $name has triggered an SOS alert!");
                _showNotification("SOS Emergency", "$name pressed SOS!");
                supabase
                    .from('tbl_patient')
                    .update({'patient_status': 1})
                    .eq('id', patient['id']);
              }
            }
          });

      // Fetch alerts for assigned patient
      supabase
          .from('tbl_patient')
          .select('id')
          .eq('caregiver_id', user.id)
          .maybeSingle()
          .then((patient) {
            if (patient != null) {
              String pId = patient['id'];
              supabase
                  .from('tbl_reminder')
                  .stream(primaryKey: ['id'])
                  .eq('patient_id', pId)
                  .listen((data) {
                    if (mounted) setState(() => _patientReminders = data);
                  });
              supabase
                  .from('tbl_medicine')
                  .stream(primaryKey: ['id'])
                  .eq('patient_id', pId)
                  .listen((data) {
                    if (mounted) setState(() => _patientMedicines = data);
                  });
              supabase
                  .from('tbl_appointment')
                  .stream(primaryKey: ['id'])
                  .eq('patient_id', pId)
                  .listen((data) {
                    if (mounted) setState(() => _patientAppointments = data);
                  });
            }
          });
    }
  }

  // List of screens for the bottom navigation
  final List<Widget> _pages = [
    const HomeDashboard(), // 0: Dashboard (Full UI restored below)
    const ManagePatientsScreen(), // 1: Patients List
    const ChatbotScreen(), // 2: Gemini Chatbot
    const SizedBox(), // 3: Settings (Handled by function)
  ];

  // Function to handle navigation logic
  void _onTabTapped(int index) {
    if (index == 3) {
      // 3. SETTINGS TAB -> PROFILE
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CaregiverProfileScreen()),
      );
    } else {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),

      // --- APP BAR ---
      appBar: AppBar(
        backgroundColor: Colors.teal,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Hello, Caregiver",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
            ),
            Text(
              "MindMate+",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CaregiverProfileScreen(),
                  ),
                );
              },
              child: const CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, color: Colors.white),
              ),
            ),
          ),
        ],
      ),

      // --- BOTTOM NAVIGATION ---
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Home"),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: "Patients",
          ), // Index 1
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: "Chat",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Settings",
          ),
        ],
      ),

      // --- MAIN BODY (SWITCHES BASED ON TAB) ---
      body: _pages[_currentIndex],
    );
  }
}

// ==============================================================================
// 1. HOME DASHBOARD WIDGET (FULL UI RESTORED)
// ==============================================================================
class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. PATIENT STATUS CARDS - SHOW ALL PATIENTS
          FutureBuilder<List<Map<String, dynamic>>>(
            future: supabase
                .from('tbl_patient')
                .select()
                .eq('caregiver_id', supabase.auth.currentUser!.id),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                return Column(
                  children: snapshot.data!
                      .map((patient) => Padding(
                            padding: const EdgeInsets.only(bottom: 15),
                            child: _buildPatientStatusCard(patient),
                          ))
                      .toList(),
                );
              }
              return const Center(
                child: Text("Register a patient to start monitoring."),
              );
            },
          ),
          const SizedBox(height: 25),

          // 2. QUICK ACTIONS GRID
          const Text(
            "Quick Actions",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          _buildQuickActionsGrid(context),
          const SizedBox(height: 25),

          // 3. RECENT ALERTS LIST
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Recent Alerts",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  "View All",
                  style: TextStyle(color: Colors.teal),
                ),
              ),
            ],
          ),
          _buildRecentAlerts(),
        ],
      ),
    );
  }

  // --- WIDGET: PATIENT STATUS CARD ---
  static Widget _buildPatientStatusCard(Map<String, dynamic> patient) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade700, Colors.teal.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  shape: BoxShape.circle,
                ),
                child: const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, color: Colors.white, size: 30),
                ),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Monitoring:",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    patient['patient_name'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "ACTIVE",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- WIDGET: QUICK ACTIONS GRID ---
  Widget _buildQuickActionsGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      children: [
        _buildActionBtn("Track Map", Icons.map_outlined, Colors.blue, () async {
          final user = supabase.auth.currentUser;
          if (user != null) {
            final patients = await supabase
                .from('tbl_patient')
                .select('id, patient_name')
                .eq('caregiver_id', user.id);
            if (patients.isNotEmpty) {
              if (patients.length == 1) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PatientMapScreen(
                      patientId: patients[0]['id'],
                      patientName: patients[0]['patient_name'],
                    ),
                  ),
                );
              } else {
                // Show patient selector for multiple patients
                _showPatientSelector(context, patients);
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("No patients found to track.")),
              );
            }
          }
        }),
        _buildActionBtn(
          "Face Portal",
          Icons.face_retouching_natural,
          Colors.indigo,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FaceTrainingScreen(),
              ),
            );
          },
        ),
        _buildActionBtn("Meds", Icons.medication_outlined, Colors.pink, () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  const manage_medicines.ManageMedicinesScreen(),
            ),
          );
        }),
        _buildActionBtn("Reminders", Icons.alarm, Colors.purple, () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  const manage_reminders.ManageRemindersScreen(),
            ),
          );
        }),
        _buildActionBtn(
          "Appointments",
          Icons.calendar_today,
          Colors.indigo,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const manage_appointments.ManageAppointmentsScreen(),
              ),
            );
          },
        ),
        _buildActionBtn("Emergency", Icons.sos, Colors.red, () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EmergencyAlertsScreen(),
            ),
          );
        }),
        _buildActionBtn("Complaints", Icons.feedback_outlined, Colors.teal, () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CaregiverComplaintsScreen(),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActionBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET: RECENT ALERTS LIST ---
  Widget _buildRecentAlerts() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: index == 0
                  ? Colors.red.shade50
                  : Colors.blue.shade50,
              child: Icon(
                index == 0 ? Icons.warning_amber_rounded : Icons.info_outline,
                color: index == 0 ? Colors.red : Colors.blue,
              ),
            ),
            title: Text(
              index == 0 ? "Left Safe Zone" : "Medicine Reminder",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              index == 0
                  ? "Patient moved out of 'Home' zone"
                  : "Donepezil 5mg due",
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            trailing: Text(
              "${index + 1}h ago",
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ),
        );
      },
    );
  }

  // --- PATIENT SELECTOR DIALOG ---
  static void _showPatientSelector(
      BuildContext context, List<Map<String, dynamic>> patients) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Patient to Track"),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: patients.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(patients[index]['patient_name']),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PatientMapScreen(
                      patientId: patients[index]['id'],
                      patientName: patients[index]['patient_name'],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
