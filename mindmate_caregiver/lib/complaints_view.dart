import 'package:flutter/material.dart';
import 'package:mindmate_caregiver/main.dart';

class CaregiverComplaintsScreen extends StatefulWidget {
  const CaregiverComplaintsScreen({super.key});

  @override
  State<CaregiverComplaintsScreen> createState() => _CaregiverComplaintsScreenState();
}

class _CaregiverComplaintsScreenState extends State<CaregiverComplaintsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _isSubmitting = false;

  late Future<List<Map<String, dynamic>>> _complaintsFuture;

  @override
  void initState() {
    super.initState();
    _complaintsFuture = _fetchComplaints();
  }

  Future<List<Map<String, dynamic>>> _fetchComplaints() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final response = await supabase
        .from('tbl_complaint')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase.from('tbl_complaint').insert({
        'user_id': user.id,
        'complaint_title': _titleController.text,
        'complaint_description': _descController.text,
        'complaint_status': 0, // Pending
      });

      _titleController.clear();
      _descController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Complaint submitted successfully.")),
        );
        setState(() {
          _complaintsFuture = _fetchComplaints();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error submitting complaint: $e")),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Complaints & Feedback", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Report an Issue",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: "Subject",
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _descController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: "Description",
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitComplaint,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Submit Complaint", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 35),
            const Text(
              "Previous Complaints",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _complaintsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text("No complaints found.", style: TextStyle(color: Colors.grey));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final c = snapshot.data![index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: ExpansionTile(
                        title: Text(c['complaint_title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          c['complaint_status'] == 0 ? "Pending" : "Resolved",
                          style: TextStyle(color: c['complaint_status'] == 0 ? Colors.orange : Colors.green),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(15.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Description:", style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(c['complaint_description']),
                                if (c['admin_reply'] != null) ...[
                                  const SizedBox(height: 10),
                                  const Text("Admin Reply:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                                  Text(c['admin_reply']),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
