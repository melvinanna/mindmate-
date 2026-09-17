import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mindmate_patient/manage_persons.dart';
import 'package:mindmate_patient/profile.dart';
import 'package:mindmate_patient/main.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mindmate_patient/meds_view.dart';
import 'package:mindmate_patient/reminders_view.dart';
import 'package:mindmate_patient/map_view.dart';
import 'package:mindmate_patient/face_scanner.dart';
import 'package:mindmate_patient/chatbot_view.dart';
import 'package:mindmate_patient/memory_notes.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:perfect_volume_control/perfect_volume_control.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  static const MethodChannel _smsChannel = MethodChannel('sms_channel');
  int _currentIndex = 0;
  StreamSubscription<Position>? _positionStream;
  final FlutterTts _flutterTts = FlutterTts();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  String _currentStatus = "I am Safe";
  Position? _currentPosition;
  Map<String, dynamic>? _patientProfile;
  bool _isOutOfSafeZone = false;
  List<Map<String, dynamic>> _todayReminders = [];
  List<Map<String, dynamic>> _todayMedicines = [];
  List<Map<String, dynamic>> _todayAppointments = [];

  // Hardware SOS Logic
  int _volumeClickCount = 0;
  DateTime? _lastVolumeClickTime;
  DateTime? _lastSosTriggerTime;
  StreamSubscription<double>? _volumeSubscription;
  Timer? _reminderTimer;

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _initTts();
    _fetchProfile();
    _startLocationTracking();
    _listenToReminders();
    _initFirebaseMessaging();
    _setupHardwareSos();

    // Check reminders every minute
    _reminderTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkDueReminders();
    });
  }

  void _initFirebaseMessaging() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    String? token = await messaging.getToken();
    final user = supabase.auth.currentUser;
    if (user != null && token != null) {
      await supabase
          .from('tbl_patient')
          .update({'fcm_token': token})
          .eq('id', user.id);
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _speak(message.notification!.body ?? "Alert");
        _showNotification(
          message.notification!.title ?? "Notice",
          message.notification!.body ?? "",
        );
      }
    });
  }

  void _setupHardwareSos() {
    _volumeSubscription = PerfectVolumeControl.stream.listen((double volume) {
      final now = DateTime.now();

      // Cooldown: If SOS was triggered in the last 60 seconds, ignore volume changes for SOS
      if (_lastSosTriggerTime != null &&
          now.difference(_lastSosTriggerTime!) < const Duration(seconds: 60)) {
        return;
      }

      // Reset count if the clicks are more than 2 seconds apart
      if (_lastVolumeClickTime == null ||
          now.difference(_lastVolumeClickTime!) > const Duration(seconds: 2)) {
        _volumeClickCount = 1;
      } else {
        _volumeClickCount++;
      }
      _lastVolumeClickTime = now;

      // Increased threshold to 5 rapid clicks to avoid accidental triggering
      if (_volumeClickCount >= 5) {
        _volumeClickCount = 0; // reset
        _lastSosTriggerTime = now;
        _triggerSos(); // Trigger the SOS logic
      }
    });
  }

  void _triggerSos() async {
    setState(() => _currentStatus = "SOS Sent!");
    await _speak("Emergency SOS triggered by your buttons.");

    // 1. Send SMS and SOS to DB
    final user = supabase.auth.currentUser;
    if (user != null) {
      // reuse the existing sos logic function
      _sendSosAlerts(user.id);
    }
  }

  // Refactored SOS alerting logic
  Future<void> _sendSosAlerts(String userId) async {
    setState(() => _currentStatus = "Sending SOS...");

    // Fetch fresh position for SOS with multiple fallback strategies
    Position? position;
    
    // Strategy 1: Try to get current position with longer timeout
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );
      debugPrint("SOS Location Strategy 1 (getCurrentPosition): Success - $position");
    } catch (e) {
      debugPrint("SOS Location Strategy 1 failed: $e");
    }

    // Strategy 2: Use cached current position from location stream
    if (position == null && _currentPosition != null) {
      position = _currentPosition;
      debugPrint("SOS Location Strategy 2 (cached _currentPosition): Success - $position");
    }

    // Strategy 3: Get last known position from device
    if (position == null) {
      try {
        position = await Geolocator.getLastKnownPosition(
          forceAndroidLocationManager: true,
        );
        debugPrint("SOS Location Strategy 3 (getLastKnownPosition): Success - $position");
      } catch (e) {
        debugPrint("SOS Location Strategy 3 failed: $e");
      }
    }

    // Strategy 4: Rough fallback - use safe zone as reference if available
    if (position == null && _patientProfile != null && 
        _patientProfile!['safe_zone_lat'] != null) {
      debugPrint("SOS Location Strategy 4: Using safe zone coordinates");
      position = Position(
        latitude: (_patientProfile!['safe_zone_lat'] as num).toDouble(),
        longitude: (_patientProfile!['safe_zone_lng'] as num).toDouble(),
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }

    String locStr = position != null
        ? "${position.latitude},${position.longitude}"
        : "Unknown Location";
    
    debugPrint("SOS Final Location: $locStr");

    // Update status to SOS in DB and save location history
    try {
      await supabase
          .from('tbl_patient')
          .update({
            'patient_status': 2,
            'last_known_location_lat': position?.latitude,
            'last_known_location_lng': position?.longitude,
          })
          .eq('id', userId);
      
      // Save to location history for tracking
      if (position != null) {
        await supabase.from('tbl_location_history').insert({
          'patient_id': userId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'recorded_at': DateTime.now().toIso8601String(),
        });
      }
          
      logActivity("SOS Triggered", "Emergency SOS activated at location: $locStr");
    } catch (e) {
      debugPrint("Failed to update status: $e");
    }

    try {
      final patientData = await supabase
          .from('tbl_patient')
          .select('caregiver_id, patient_name')
          .eq('id', userId)
          .maybeSingle();

      if (patientData != null && patientData['caregiver_id'] != null) {
        String patientName = patientData['patient_name'] ?? "Your patient";
        final caregiverData = await supabase
            .from('tbl_caregiver')
            .select('caregiver_phone')
            .eq('id', patientData['caregiver_id'])
            .maybeSingle();

        if (caregiverData != null && caregiverData['caregiver_phone'] != null) {
          String phone = (caregiverData['caregiver_phone'] as String).trim();
          
          if (phone.isEmpty) {
            _showError("Caregiver phone number is empty.");
            return;
          }

          var status = await Permission.sms.request();
          debugPrint("SMS Permission Status: $status");
          
          // Also verify location permission
          var locPermission = await Geolocator.checkPermission();
          if (locPermission == LocationPermission.denied) {
            locPermission = await Geolocator.requestPermission();
          }
          debugPrint("Location Permission Status: $locPermission");

          if (status.isGranted) {
            try {
              debugPrint("Invoking sendSms via MethodChannel. Phone: $phone");
              final result = await _smsChannel.invokeMethod('sendSms', {
                'phone': phone,
                'msg':
                    "EMERGENCY SOS: $patientName requires immediate assistance. View Location: https://maps.google.com/?q=$locStr",
              });
              
              debugPrint("MethodChannel Response: $result");
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("SMS Successfully Sent to $phone"),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
              setState(() => _currentStatus = "SOS Sent!");
              logActivity("SOS SMS Sent", "Destination: $phone");
            } catch (e) {
              debugPrint("MethodChannel SMS Error: $e");
              _showError("Failed to send SMS: $e");
            }
          } else {
            _showError("SMS Permission ($status) - Please enable in app settings.");
          }
        } else {
          _showError("Caregiver contact (phone) is missing in database.");
        }
      } else {
        _showError("Patient or Caregiver record not found.");
      }
    } catch (e) {
      debugPrint("SOS Flow Error: $e");
      _showError("Emergency Process Failed: $e");
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
    setState(() => _currentStatus = "SOS Failed");
  }

  void _initNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );
    await _notificationsPlugin.initialize(settings: settings);
  }

  Future<void> _fetchProfile() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      final data = await supabase
          .from('tbl_patient')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (mounted) setState(() => _patientProfile = data);
    }
  }

  void _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'patient_alerts',
          'Patient Heartbeat',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );
    await _notificationsPlugin.show(
      id: DateTime.now().millisecond & 0x7FFFFFFF,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    // Simple greeting for patient
    await _speak("Welcome back. I am monitoring your location.");
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  Future<void> _startLocationTracking() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return; // Location services are disabled
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return; // Permissions are denied
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return; // Permissions are permanently denied
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((Position? position) async {
          if (position != null) {
            setState(() => _currentPosition = position);

            final user = supabase.auth.currentUser;
            if (user != null) {
              // 1. Update Location in DB
              await supabase
                  .from('tbl_patient')
                  .update({
                    'last_known_location_lat': position.latitude,
                    'last_known_location_lng': position.longitude,
                  })
                  .eq('id', user.id);

              // 2. Safe Zone Check
              if (_patientProfile != null &&
                  _patientProfile!['safe_zone_lat'] != null) {
                double distance = Geolocator.distanceBetween(
                  position.latitude,
                  position.longitude,
                  (_patientProfile!['safe_zone_lat'] as num).toDouble(),
                  (_patientProfile!['safe_zone_lng'] as num).toDouble(),
                );

                int radius =
                    (_patientProfile!['safe_zone_radius'] as num?)?.toInt() ??
                    100;

                if (distance > radius && !_isOutOfSafeZone) {
                  setState(() {
                    _isOutOfSafeZone = true;
                    _currentStatus = "Outside Safe Zone";
                  });
                  _speak(
                    "Warning. You have left your safe area. Please return home or contact your caregiver.",
                  );
                  _showNotification(
                    "⚠️ Safe Zone Breach",
                    "You are outside your designated area.",
                  );
                } else if (distance <= radius && _isOutOfSafeZone) {
                  setState(() {
                    _isOutOfSafeZone = false;
                    _currentStatus = "I am Safe";
                  });
                  _speak("You are back in a safe area.");
                }
              }

              // 3. Insert History
              await supabase.from('tbl_location_history').insert({
                'patient_id': user.id,
                'latitude': position.latitude,
                'longitude': position.longitude,
                'recorded_at': DateTime.now().toIso8601String(),
              });
            }
          }
        });
  }

  void _listenToReminders() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    supabase
        .from('tbl_reminder')
        .stream(primaryKey: ['id'])
        .eq('patient_id', user.id)
        .listen((data) {
          if (mounted) setState(() => _todayReminders = data);
        });

    supabase
        .from('tbl_medicine')
        .stream(primaryKey: ['id'])
        .eq('patient_id', user.id)
        .listen((data) {
          if (mounted) setState(() => _todayMedicines = data);
        });

    supabase
        .from('tbl_appointment')
        .stream(primaryKey: ['id'])
        .eq('patient_id', user.id)
        .listen((data) {
          if (mounted) setState(() => _todayAppointments = data);
        });
  }

  void _checkDueReminders() {
    final now = DateTime.now();
    final in5Min = now.add(const Duration(minutes: 5));

    final timeStrNow =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final timeStr5m =
        "${in5Min.hour.toString().padLeft(2, '0')}:${in5Min.minute.toString().padLeft(2, '0')}";

    for (var r in _todayReminders) {
      if (r['is_active'] == true) {
        if (r['reminder_time'] == timeStrNow ||
            r['reminder_time'] == "$timeStrNow:00") {
          _speak("It is time for ${r['title']}. ${r['description'] ?? ''}");
          _showNotification(r['title'] ?? 'Reminder', r['description'] ?? '');
        } else if (r['reminder_time'] == timeStr5m ||
            r['reminder_time'] == "$timeStr5m:00") {
          _speak("Upcoming reminder in 5 minutes: ${r['title']}.");
        }
      }
    }

    for (var m in _todayMedicines) {
      if (m['notification_time'] == timeStrNow ||
          m['notification_time'] == "$timeStrNow:00") {
        _speak(
          "It is time to take your medicine: ${m['medicine_name']}, dosage ${m['dosage']}.",
        );
        _showNotification(
          "Medicine Time",
          "${m['medicine_name']} - ${m['dosage']}",
        );
      } else if (m['notification_time'] == timeStr5m ||
          m['notification_time'] == "$timeStr5m:00") {
        _speak("Medicine due in 5 minutes: ${m['medicine_name']}.");
      }
    }

    for (var a in _todayAppointments) {
      if (a['appointment_time'] == timeStrNow ||
          a['appointment_time'] == "$timeStrNow:00") {
        _speak("You have an appointment now with ${a['doctor_name']}.");
        _showNotification(
          "Appointment",
          "Dr. ${a['doctor_name']} at ${a['hospital_name']}",
        );
      } else if (a['appointment_time'] == timeStr5m ||
          a['appointment_time'] == "$timeStr5m:00") {
        _speak("Appointment coming up in 5 minutes with ${a['doctor_name']}.");
      }
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _volumeSubscription?.cancel();
    _reminderTimer?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (_currentIndex) {
      case 1:
        body = const PatientMedsScreen();
        break;
      case 2:
        body = const ChatbotScreen();
        break;
      case 3:
        body = const PatientProfileScreen();
        break;
      default:
        body = _buildHomeContent();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "MindMate+",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        backgroundColor: Colors.teal,
        elevation: 4,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                setState(() => _currentIndex = 3);
              },
              child: const CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.teal.shade700,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medication_rounded),
            label: "Meds",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_rounded),
            label: "Support",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: "Profile",
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. MY STATUS CARD
          _buildMyStatusCard(),
          const SizedBox(height: 25),

          // 2. SOS BUTTON
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: () async {
                final user = supabase.auth.currentUser;
                if (user != null) {
                  await _speak("Emergency SOS sent to your caregiver.");
                  await _sendSosAlerts(user.id);
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Sending Emergency SOS..."),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 6,
              ),
              icon: const Icon(Icons.sos, color: Colors.white, size: 30),
              label: const Text(
                "EMERGENCY HELP",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 25),

          // 3. QUICK ACTIONS GRID
          const Text(
            "My Activities",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          _buildQuickActionsGrid(),
          const SizedBox(height: 25),

          // 4. RECENT REMINDERS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "My Reminders",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => _fetchReminders(),
                child: const Text(
                  "Refresh",
                  style: TextStyle(color: Colors.teal),
                ),
              ),
            ],
          ),
          _buildRecentReminders(),
        ],
      ),
    );
  }

  // Define _fetchReminders helper if not already present
  void _fetchReminders() {
    _listenToReminders();
  }

  // --- WIDGET: MY STATUS CARD ---
  Widget _buildMyStatusCard() {
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
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white24,
                  backgroundImage: _patientProfile?['image_url'] != null
                      ? NetworkImage(_patientProfile!['image_url'])
                      : null,
                  child: _patientProfile?['image_url'] == null
                      ? const Icon(Icons.person, color: Colors.white, size: 30)
                      : null,
                ),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Current Status:",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    _currentStatus,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _currentPosition != null
                            ? "${_currentPosition!.latitude.toStringAsFixed(2)}, ${_currentPosition!.longitude.toStringAsFixed(2)}"
                            : "Locating...",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 15),
                      const Icon(
                        Icons.battery_std,
                        color: Colors.white,
                        size: 14,
                      ),
                      const Text(
                        " 85%",
                        style: TextStyle(color: Colors.white, fontSize: 12),
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
  Widget _buildQuickActionsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      children: [
        _buildActionBtn("Track Map", Icons.map_outlined, Colors.blue, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PatientMapScreen()),
          );
        }),
        _buildActionBtn(
          "Face ID",
          Icons.face_unlock_outlined,
          Colors.orange,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FaceScannerScreen(),
              ),
            );
          },
        ),

        // --- NEW BUTTON: KNOWN PERSONS ---
        _buildActionBtn(
          "Family Info",
          Icons.people_alt_rounded,
          Colors.purple,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ManageKnownPeopleScreen(),
              ),
            );
          },
        ),

        // ---------------------------------
        _buildActionBtn("Meds", Icons.medication_outlined, Colors.pink, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PatientMedsScreen()),
          );
        }),
        _buildActionBtn("Schedule", Icons.alarm, Colors.teal, () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PatientRemindersScreen(),
            ),
          );
        }),
        _buildActionBtn("Memory Box", Icons.auto_stories, Colors.indigo, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MemoryNotesScreen()),
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

  // --- WIDGET: RECENT REMINDERS LIST ---
  Widget _buildRecentReminders() {
    if (_todayReminders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            "No reminders for today.",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _todayReminders.length,
      itemBuilder: (context, index) {
        final reminder = _todayReminders[index];
        final bool active = reminder['is_active'] ?? true;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: active ? Colors.teal.shade100 : Colors.grey.shade200,
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: active
                  ? Colors.blue.shade50
                  : Colors.grey.shade100,
              child: Icon(
                Icons.alarm,
                color: active ? Colors.blue : Colors.grey,
              ),
            ),
            title: Text(
              reminder['title'] ?? "Reminder",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: active ? Colors.black : Colors.grey,
              ),
            ),
            subtitle: Text(
              reminder['description'] ?? "",
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            trailing: Text(
              reminder['reminder_time'] ?? "",
              style: TextStyle(
                color: active ? Colors.teal : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () async {
              if (active) {
                await _speak(
                  "This is a reminder for ${reminder['title']}. ${reminder['description']}",
                );
              }
            },
          ),
        );
      },
    );
  }
}
