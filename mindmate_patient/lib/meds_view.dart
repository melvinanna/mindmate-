import 'package:flutter/material.dart';
import 'package:mindmate_patient/main.dart';

class PatientMedsScreen extends StatefulWidget {
  const PatientMedsScreen({super.key});

  @override
  State<PatientMedsScreen> createState() => _PatientMedsScreenState();
}

class _PatientMedsScreenState extends State<PatientMedsScreen> {
  late Future<List<Map<String, dynamic>>> _medsFuture;

  @override
  void initState() {
    super.initState();
    _medsFuture = _fetchMeds();
  }

  Future<List<Map<String, dynamic>>> _fetchMeds() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final response = await supabase
        .from('tbl_medicine')
        .select()
        .eq('patient_id', user.id);
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "My Medicines",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _medsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.medication, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 20),
                  const Text(
                    "No medications scheduled.",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final meds = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: meds.length,
            itemBuilder: (context, index) {
              final m = meds[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.pink.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.medication,
                      color: Colors.pink,
                      size: 30,
                    ),
                  ),
                  title: Text(
                    m['medicine_name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      Text(
                        "Dosage: ${m['dosage']}",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      Text(
                        "Time: ${m['notification_time']}",
                        style: const TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  trailing: Radio(
                    value: true,
                    groupValue: false, // In a real app, track daily completion
                    onChanged: (val) {},
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
