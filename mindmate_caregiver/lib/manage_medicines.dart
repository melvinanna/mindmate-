import 'package:flutter/material.dart';
import 'package:mindmate_caregiver/main.dart'; // contains supabase client

class ManageMedicinesScreen extends StatefulWidget {
  const ManageMedicinesScreen({super.key});

  @override
  State<ManageMedicinesScreen> createState() => _ManageMedicinesScreenState();
}

class _ManageMedicinesScreenState extends State<ManageMedicinesScreen> {
  List<Map<String, dynamic>> _patients = [];
  String? _selectedPatientId;
  late Future<List<Map<String, dynamic>>> _medicinesFuture;

  @override
  void initState() {
    super.initState();
    _fetchPatients();
    _medicinesFuture = Future.value([]);
  }

  Future<void> _fetchPatients() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final data = await supabase
        .from('tbl_patient')
        .select('id, patient_name')
        .eq('caregiver_id', user.id);
    if (mounted) {
      setState(() {
        _patients = List<Map<String, dynamic>>.from(data);
        if (_patients.isNotEmpty && _selectedPatientId == null) {
          _selectedPatientId = _patients.first['id'];
          _medicinesFuture = _fetchMedicines();
        }
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMedicines() async {
    if (_selectedPatientId == null) return [];
    final response = await supabase
        .from('tbl_medicine')
        .select()
        .eq('patient_id', _selectedPatientId!);
    return List<Map<String, dynamic>>.from(response);
  }

  void _addMedicineForm() {
    if (_selectedPatientId == null) return;
    String name = "";
    String dosage = "";
    int stock = 0;
    bool isLongTerm = false;
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text("Add Medicine"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: "Medicine Name"),
                  onChanged: (val) => name = val,
                ),
                TextField(
                  decoration: const InputDecoration(
                    labelText: "Dosage (e.g., 1 pill)",
                  ),
                  onChanged: (val) => dosage = val,
                ),
                TextField(
                  decoration: const InputDecoration(
                    labelText: "Initial Stock Quantity",
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (val) => stock = int.tryParse(val) ?? 0,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Time: ${selectedTime.format(context)}"),
                    TextButton(
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (t != null) setStateDialog(() => selectedTime = t);
                      },
                      child: const Text("Pick Time"),
                    ),
                  ],
                ),
                SwitchListTile(
                  title: const Text("Long Term Medication?"),
                  value: isLongTerm,
                  onChanged: (val) {
                    setStateDialog(() => isLongTerm = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final timestr =
                    "${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}:00";
                await supabase.from('tbl_medicine').insert({
                  'patient_id': _selectedPatientId,
                  'medicine_name': name,
                  'dosage': dosage,
                  'stock': stock,
                  'notification_time': timestr,
                  'is_long_term': isLongTerm,
                });
                if (mounted) {
                  Navigator.pop(context);
                  setState(() {
                    _medicinesFuture = _fetchMedicines();
                  });
                }
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Medicines"),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          if (_patients.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: DropdownButtonFormField<String>(
                value: _selectedPatientId,
                decoration: InputDecoration(
                  labelText: "Select Patient",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _patients
                    .map(
                      (p) => DropdownMenuItem<String>(
                        value: p['id'],
                        child: Text(p['patient_name']),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedPatientId = val;
                    _medicinesFuture = _fetchMedicines();
                  });
                },
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _medicinesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No Medicines Yet"));
                }
                final medicines = snapshot.data!;
                return ListView.builder(
                  itemCount: medicines.length,
                  itemBuilder: (context, index) {
                    final m = medicines[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.pink,
                          child: Icon(Icons.medication, color: Colors.white),
                        ),
                        title: Text(m['medicine_name'] ?? 'Unknown'),
                        subtitle: Text(
                          "Dosage: ${m['dosage']} \nStock: ${m['stock']} \nTime: ${m['notification_time']} \n${m['is_long_term'] == true ? 'Long Term' : 'Short Term'}",
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.add_shopping_cart,
                            color: Colors.teal,
                          ),
                          onPressed: () async {
                            // Quick Add Stock
                            showDialog(
                              context: context,
                              builder: (context) {
                                int addedStock = 0;
                                return AlertDialog(
                                  title: const Text("Top-up Stock"),
                                  content: TextField(
                                    keyboardType: TextInputType.number,
                                    onChanged: (val) =>
                                        addedStock = int.tryParse(val) ?? 0,
                                    decoration: const InputDecoration(
                                      labelText: "Add Quantity",
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text("Cancel"),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        if (addedStock > 0) {
                                          int currentStock = m['stock'] ?? 0;
                                          await supabase
                                              .from('tbl_medicine')
                                              .update({
                                                'stock':
                                                    currentStock + addedStock,
                                              })
                                              .eq('id', m['id']);
                                          if (mounted) {
                                            Navigator.pop(context);
                                            setState(() {
                                              _medicinesFuture =
                                                  _fetchMedicines();
                                            });
                                          }
                                        }
                                      },
                                      child: const Text("Update"),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addMedicineForm,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
