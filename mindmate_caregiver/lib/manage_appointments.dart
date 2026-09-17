import 'package:flutter/material.dart';
import 'package:mindmate_caregiver/main.dart'; // contains supabase client
import 'package:intl/intl.dart';

class ManageAppointmentsScreen extends StatefulWidget {
  const ManageAppointmentsScreen({super.key});

  @override
  State<ManageAppointmentsScreen> createState() =>
      _ManageAppointmentsScreenState();
}

class _ManageAppointmentsScreenState extends State<ManageAppointmentsScreen> {
  List<Map<String, dynamic>> _patients = [];
  String? _selectedPatientId;
  late Future<List<Map<String, dynamic>>> _appointmentsFuture;

  @override
  void initState() {
    super.initState();
    _fetchPatients();
    _appointmentsFuture = Future.value([]);
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
          _appointmentsFuture = _fetchAppointments();
        }
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAppointments() async {
    if (_selectedPatientId == null) return [];
    final response = await supabase
        .from('tbl_appointment')
        .select()
        .eq('patient_id', _selectedPatientId!)
        .order('appointment_date', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  void _addAppointmentForm() {
    if (_selectedPatientId == null) return;
    String doctor = "";
    String hospital = "";
    String notes = "";
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text("New Appointment"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: "Doctor Name"),
                  onChanged: (val) => doctor = val,
                ),
                TextField(
                  decoration: const InputDecoration(
                    labelText: "Hospital / Clinic",
                  ),
                  onChanged: (val) => hospital = val,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: "Notes"),
                  onChanged: (val) => notes = val,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}",
                    ),
                    TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setStateDialog(() => selectedDate = d);
                      },
                      child: const Text("Pick Date"),
                    ),
                  ],
                ),
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
                final datestr = DateFormat('yyyy-MM-dd').format(selectedDate);
                await supabase.from('tbl_appointment').insert({
                  'patient_id': _selectedPatientId,
                  'doctor_name': doctor,
                  'hospital_name': hospital,
                  'notes': notes,
                  'appointment_date': datestr,
                  'appointment_time': timestr,
                  'status': 0,
                });
                if (mounted) {
                  Navigator.pop(context);
                  setState(() {
                    _appointmentsFuture = _fetchAppointments();
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
        title: const Text("Manage Appointments"),
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
                    _appointmentsFuture = _fetchAppointments();
                  });
                },
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _appointmentsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No Appointments Yet"));
                }
                final appointments = snapshot.data!;
                return ListView.builder(
                  itemCount: appointments.length,
                  itemBuilder: (context, index) {
                    final a = appointments[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          child: Icon(
                            Icons.calendar_today,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          "${a['doctor_name']} @ ${a['hospital_name']}",
                        ),
                        subtitle: Text(
                          "Date: ${a['appointment_date']} \nTime: ${a['appointment_time']} \nNotes: ${a['notes']}",
                        ),
                        isThreeLine: true,
                        trailing: DropdownButton<int>(
                          value: a['status'] ?? 0,
                          items: const [
                            DropdownMenuItem(value: 0, child: Text("Pending")),
                            DropdownMenuItem(
                              value: 1,
                              child: Text("Completed"),
                            ),
                            DropdownMenuItem(
                              value: 2,
                              child: Text("Cancelled"),
                            ),
                          ],
                          onChanged: (val) async {
                            if (val != null) {
                              await supabase
                                  .from('tbl_appointment')
                                  .update({'status': val})
                                  .eq('id', a['id']);
                              setState(() {
                                _appointmentsFuture = _fetchAppointments();
                              });
                            }
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
        onPressed: _addAppointmentForm,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
