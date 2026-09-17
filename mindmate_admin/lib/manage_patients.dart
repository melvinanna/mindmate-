import 'package:flutter/material.dart';
import 'package:mindmate_admin/main.dart';

class ManagePatients extends StatefulWidget {
  const ManagePatients({super.key});

  @override
  State<ManagePatients> createState() => _ManagePatientsState();
}

class _ManagePatientsState extends State<ManagePatients> {
  List<Map<String, dynamic>> _patients = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchPatients();
  }

  Future<void> _fetchPatients() async {
    try {
      final response = await supabase.from('tbl_patient').select('*, tbl_caregiver(caregiver_name)');
      setState(() {
        _patients = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      debugPrint("Error fetching patients: $e");
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Patient Master Records", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Expanded(
          child: _loading 
              ? const Center(child: CircularProgressIndicator())
              : _patients.isEmpty
                  ? const Center(child: Text("No patients registered yet."))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.5,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                      ),
                      itemCount: _patients.length,
                      itemBuilder: (context, index) {
                        final p = _patients[index];
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade200)),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(radius: 25, backgroundColor: Colors.teal, child: Icon(Icons.person, color: Colors.white)),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(p['patient_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                          Text(p['patient_email'], style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Divider(color: Colors.grey[100]),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text("Caregiver", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                        Text(p['tbl_caregiver']?['caregiver_name'] ?? "Unassigned", style: const TextStyle(fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.location_on, color: Colors.redAccent),
                                      onPressed: () {
                                        // Open Tracking
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}