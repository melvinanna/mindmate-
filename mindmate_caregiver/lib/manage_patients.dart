import 'package:flutter/material.dart';
import 'package:mindmate_caregiver/patient.dart';
import 'package:mindmate_caregiver/patient_map.dart';
import 'package:mindmate_caregiver/main.dart'; // Import supabase client
import 'package:mindmate_caregiver/manage_reminders.dart' as manage_reminders;

class ManagePatientsScreen extends StatefulWidget {
  const ManagePatientsScreen({super.key});

  @override
  State<ManagePatientsScreen> createState() => _ManagePatientsScreenState();
}

class _ManagePatientsScreenState extends State<ManagePatientsScreen> {
  // Store the future in a variable to avoid redundant calls in build()
  late Future<List<Map<String, dynamic>>> _patientsFuture;

  @override
  void initState() {
    super.initState();
    _refreshPatients();
  }

  // Helper to trigger data fetching
  void _refreshPatients() {
    setState(() {
      _patientsFuture = _fetchPatients();
    });
  }

  // --- FETCH PATIENTS FUNCTION ---
  Future<List<Map<String, dynamic>>> _fetchPatients() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final response = await supabase
        .from('tbl_patient')
        .select()
        .eq('caregiver_id', user.id)
        .order('patient_name', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("My Patients", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _patientsFuture, // Use the stored future variable
        builder: (context, snapshot) {
          // 1. LOADING STATE
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            );
          }

          // 2. ERROR STATE
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          // 3. EMPTY STATE (No Patients)
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "No Patients Added Yet",
                    style: TextStyle(color: Colors.grey, fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _navigateToAddPatient(context),
                    icon: const Icon(Icons.add),
                    label: const Text("Add New Patient"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // 4. DATA LIST STATE
          final patients = snapshot.data!;

          return RefreshIndicator(
            onRefresh: () async {
              _refreshPatients();
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: patients.length,
              itemBuilder: (context, index) {
                final patient = patients[index];
                final String? photoUrl = patient['patient_photo'];

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.teal.shade50,
                      backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                          ? NetworkImage(photoUrl)
                          : null,
                      child: (photoUrl == null || photoUrl.isEmpty)
                          ? const Icon(Icons.person, color: Colors.teal)
                          : null,
                    ),
                    title: Text(
                      patient['patient_name'] ?? "Unknown",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          "Age: ${patient['patient_age']} | ${patient['patient_gender']}",
                        ),
                        Text(
                          "Condition: ${patient['patient_medical_condition']}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey,
                    ),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(
                                Icons.map,
                                color: Colors.blue,
                              ),
                              title: const Text("Track Live Movement"),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PatientMapScreen(
                                      patientId: patient['id'],
                                      patientName:
                                          patient['patient_name'] ?? "Unknown",
                                    ),
                                  ),
                                );
                              },
                            ),
                            ListTile(
                              leading: const Icon(
                                Icons.alarm,
                                color: Colors.purple,
                              ),
                              title: const Text("Manage Reminders"),
                              onTap: () {
                                Navigator.pop(context);
                                // For now routing to general Reminder screen
                                // In a future iteration we could pass patient_id directly to pre-select it
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const manage_reminders.ManageRemindersScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddPatient(context),
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _navigateToAddPatient(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddPatientScreen()),
    );
    // Properly refresh the data when returning
    if (mounted) {
      _refreshPatients();
    }
  }
}
