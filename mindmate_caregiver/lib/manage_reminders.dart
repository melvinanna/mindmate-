import 'package:flutter/material.dart';
import 'package:mindmate_caregiver/main.dart'; // contains supabase client

class ManageRemindersScreen extends StatefulWidget {
  const ManageRemindersScreen({super.key});

  @override
  State<ManageRemindersScreen> createState() => _ManageRemindersScreenState();
}

class _ManageRemindersScreenState extends State<ManageRemindersScreen> {
  List<Map<String, dynamic>> _patients = [];
  String? _selectedPatientId;
  late Future<List<Map<String, dynamic>>> _remindersFuture;

  @override
  void initState() {
    super.initState();
    _fetchPatients();
    _remindersFuture = _fetchReminders();
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
          _remindersFuture = _fetchReminders();
        }
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchReminders() async {
    if (_selectedPatientId == null) return [];
    final response = await supabase
        .from('tbl_reminder')
        .select()
        .eq('patient_id', _selectedPatientId!)
        .order('reminder_time', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  void _addReminderForm() {
    if (_selectedPatientId == null) return;
    String title = "";
    String desc = "";
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text("New Medication Reminder"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: "Medicine/Title"),
                onChanged: (val) => title = val,
              ),
              TextField(
                decoration: const InputDecoration(
                  labelText: "Dosage/Description",
                ),
                onChanged: (val) => desc = val,
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
            ],
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
                await supabase.from('tbl_reminder').insert({
                  'patient_id': _selectedPatientId,
                  'title': title,
                  'description': desc,
                  'reminder_time': timestr,
                  'is_active': true,
                });
                if (mounted) {
                  Navigator.pop(context);
                  setState(() {
                    _remindersFuture = _fetchReminders();
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
        title: const Text("Medication Reminders"),
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
                    _remindersFuture = _fetchReminders();
                  });
                },
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _remindersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.isEmpty)
                  return const Center(child: Text("No Reminders Yet"));
                final reminders = snapshot.data!;
                return ListView.builder(
                  itemCount: reminders.length,
                  itemBuilder: (context, index) {
                    final r = reminders[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.medication),
                      ),
                      title: Text(r['title']),
                      subtitle: Text(
                        "${r['description']} \nScheduled: ${r['reminder_time']}",
                      ),
                      trailing: Switch(
                        value: r['is_active'] ?? true,
                        onChanged: (val) async {
                          await supabase
                              .from('tbl_reminder')
                              .update({'is_active': val})
                              .eq('id', r['id']);
                          setState(() {
                            _remindersFuture = _fetchReminders();
                          });
                        },
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
        onPressed: _addReminderForm,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
