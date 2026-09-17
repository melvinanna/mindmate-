import 'package:flutter/material.dart';
import 'package:mindmate_admin/main.dart';

class SystemActivityLog extends StatefulWidget {
  const SystemActivityLog({super.key});

  @override
  State<SystemActivityLog> createState() => _SystemActivityLogState();
}

class _SystemActivityLogState extends State<SystemActivityLog> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('tbl_activity_log')
          .select()
          .order('created_at', ascending: false)
          .limit(50);
      
      setState(() {
        _logs = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching logs: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("System Activity Logs", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            IconButton(
              onPressed: _fetchLogs,
              icon: const Icon(Icons.refresh),
              tooltip: "Refresh Logs",
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _logs.isEmpty
                  ? const Center(child: Text("No activity logs found."))
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        final time = DateTime.parse(log['created_at']).toLocal();
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _getLogColor(log['user_type']).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getLogIcon(log['user_type']),
                                  color: _getLogColor(log['user_type']),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      log['action'],
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    Text(
                                      log['details'] ?? "No details provided.",
                                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "By ${log['user_type']} • ${time.day}/${time.month} ${time.hour}:${time.minute.toString().padLeft(2, '0')}",
                                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Color _getLogColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'patient': return Colors.teal;
      case 'caregiver': return Colors.orange;
      case 'admin': return Colors.blue;
      default: return Colors.grey;
    }
  }

  IconData _getLogIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'patient': return Icons.elderly;
      case 'caregiver': return Icons.people;
      case 'admin': return Icons.admin_panel_settings;
      default: return Icons.history;
    }
  }
}
