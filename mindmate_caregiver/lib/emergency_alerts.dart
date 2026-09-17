import 'package:flutter/material.dart';
import 'package:mindmate_caregiver/main.dart';

class EmergencyAlertsScreen extends StatefulWidget {
  const EmergencyAlertsScreen({super.key});

  @override
  State<EmergencyAlertsScreen> createState() => _EmergencyAlertsScreenState();
}

class _EmergencyAlertsScreenState extends State<EmergencyAlertsScreen> {
  late Future<List<Map<String, dynamic>>> _alertsFuture;

  @override
  void initState() {
    super.initState();
    _alertsFuture = _fetchAlerts();
  }

  Future<List<Map<String, dynamic>>> _fetchAlerts() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    // In this schema, we don't have a separate tbl_alerts,
    // so we identify SOS via patient_status in tbl_patient.
    final response = await supabase
        .from('tbl_patient')
        .select()
        .eq('caregiver_id', user.id);

    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Emergency Dashboard"),
        backgroundColor: Colors.red,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _alertsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No active emergencies"));
          }

          final patients = snapshot.data!;
          return ListView.builder(
            itemCount: patients.length,
            itemBuilder: (context, index) {
              final p = patients[index];
              final bool isEmergency = p['patient_status'] == 2;

              if (!isEmergency) {
                return const SizedBox(); // Only show emergencies
              }

              return Card(
                color: Colors.red.shade50,
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  leading: const Icon(Icons.sos, color: Colors.red, size: 40),
                  title: Text(
                    "${p['patient_name']} needs HELP!",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  subtitle: Text(
                    "Location: ${p['last_known_location_lat']}, ${p['last_known_location_lng']}",
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {
                      // Reset status
                      supabase
                          .from('tbl_patient')
                          .update({'patient_status': 1})
                          .eq('id', p['id'])
                          .then(
                            (_) => setState(() {
                              _alertsFuture = _fetchAlerts();
                            }),
                          );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text("Resolved"),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
