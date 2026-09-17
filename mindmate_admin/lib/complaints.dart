import 'package:flutter/material.dart';
import 'package:mindmate_admin/main.dart';

class ManageComplaints extends StatefulWidget {
  const ManageComplaints({super.key});

  @override
  State<ManageComplaints> createState() => _ManageComplaintsState();
}

class _ManageComplaintsState extends State<ManageComplaints> {
  List<Map<String, dynamic>> _complaints = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchComplaints();
  }

  Future<void> _fetchComplaints() async {
    setState(() => _isLoading = true);
    try {
      // Fetch complaints
      final response = await supabase
          .from('tbl_complaint')
          .select()
          .order('created_at', ascending: false);
      
      setState(() {
        _complaints = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching complaints: $e");
      setState(() => _isLoading = false);
    }
  }

  final TextEditingController _replyController = TextEditingController();

  Future<void> _submitReply(Map<String, dynamic> complaint) async {
    try {
      await supabase.from('tbl_complaint').update({
        'admin_reply': _replyController.text,
        'complaint_status': 1, // Mark as Resolved
      }).eq('id', complaint['id']);

      _fetchComplaints();
      if (mounted) Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reply sent and complaint marked as resolved."), backgroundColor: Colors.teal),
      );
    } catch (e) {
      debugPrint("Error replying to complaint: $e");
    }
  }

  void _showReplyDialog(Map<String, dynamic> complaint) {
    _replyController.text = complaint['admin_reply'] ?? '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Reply to: ${complaint['complaint_title']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("User ID: ${complaint['user_id']}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
              child: Text(complaint['complaint_description'], style: const TextStyle(fontStyle: FontStyle.italic)),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _replyController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Enter your official reply...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => _submitReply(complaint),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Send Reply"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("System Complaints", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Expanded(
          child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _complaints.isEmpty
                  ? const Center(child: Text("No complaints found at the moment."))
                  : ListView.builder(
                      itemCount: _complaints.length,
                      itemBuilder: (context, index) {
                        final complaint = _complaints[index];
                        final isResolved = complaint['complaint_status'] == 1;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        complaint['complaint_title'],
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isResolved ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        isResolved ? "RESOLVED" : "PENDING",
                                        style: TextStyle(
                                          color: isResolved ? Colors.green : Colors.orange,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  complaint['complaint_description'],
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                                if (isResolved && complaint['admin_reply'] != null) ...[
                                  const Divider(height: 32),
                                  const Text("Admin Reply:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal)),
                                  const SizedBox(height: 4),
                                  Text(complaint['admin_reply'], style: TextStyle(color: Colors.teal[700])),
                                ],
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: isResolved
                                      ? OutlinedButton(
                                          onPressed: () => _showReplyDialog(complaint),
                                          child: const Text("Update Reply"),
                                        )
                                      : ElevatedButton.icon(
                                          onPressed: () => _showReplyDialog(complaint),
                                          icon: const Icon(Icons.reply, size: 18),
                                          label: const Text("Reply Now"),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.amber[800],
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
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
