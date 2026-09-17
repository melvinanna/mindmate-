import 'package:flutter/material.dart';
import 'package:mindmate_admin/main.dart'; // Import supabase instance

class ManageCaregivers extends StatefulWidget {
  const ManageCaregivers({super.key});

  @override
  State<ManageCaregivers> createState() => _ManageCaregiversState();
}

class _ManageCaregiversState extends State<ManageCaregivers> {
  bool _isAddingNew = false;
  List<Map<String, dynamic>> _caregivers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCaregivers();
  }

  Future<void> _fetchCaregivers() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase.from('tbl_caregiver').select();
      setState(() {
        _caregivers = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching caregivers: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String id, int status) async {
    try {
      await supabase.from('tbl_caregiver').update({'caregiver_status': status}).eq('id', id);
      _fetchCaregivers();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Status Updated"), backgroundColor: Colors.teal),
      );
    } catch (e) {
      debugPrint("Error updating status: $e");
    }
  }

  // --- UI Elements ---

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopBar(),
        const SizedBox(height: 24),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator()) 
                : _isAddingNew ? _buildAddForm() : _buildCaregiverList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isAddingNew ? "Register Caregiver" : "Caregiver Directory",
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87)),
            Text(_isAddingNew ? "Add a new trusted caregiver to the system." : "Verify and manage caregiver accounts.",
                style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => setState(() => _isAddingNew = !_isAddingNew),
          icon: Icon(_isAddingNew ? Icons.arrow_back : Icons.add_moderator),
          label: Text(_isAddingNew ? "Back to List" : "Add New"),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isAddingNew ? Colors.grey[800] : Colors.teal[700],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildCaregiverList() {
    if (_caregivers.isEmpty) {
      return const Center(child: Text("No caregivers found."));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: DataTable(
        columnSpacing: 20,
        headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
        columns: const [
          DataColumn(label: Text('NAME')),
          DataColumn(label: Text('EMAIL')),
          DataColumn(label: Text('CONTACT')),
          DataColumn(label: Text('STATUS')),
          DataColumn(label: Text('PATIENTS')),
          DataColumn(label: Text('ACTIONS')),
        ],
        rows: _caregivers.map((cg) {
          int status = cg['caregiver_status'] ?? 0;
          return DataRow(cells: [
            DataCell(Text(cg['caregiver_name'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w500))),
            DataCell(Text(cg['caregiver_email'] ?? 'N/A')),
            DataCell(Text(cg['caregiver_phone'] ?? 'N/A')),
            DataCell(_buildStatusChip(status)),
            DataCell(TextButton(
              onPressed: () => _viewPatients(cg['id'], cg['caregiver_name']),
              child: const Text("View All", style: TextStyle(color: Colors.blue)),
            )),
            DataCell(Row(
              children: [
                if (status == 0)
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                    tooltip: 'Approve',
                    onPressed: () => _updateStatus(cg['id'], 1),
                  ),
                if (status != 2)
                  IconButton(
                    icon: const Icon(Icons.block, color: Colors.redAccent),
                    tooltip: 'Block',
                    onPressed: () => _updateStatus(cg['id'], 2),
                  ),
                if (status == 2)
                  IconButton(
                    icon: const Icon(Icons.restore, color: Colors.blue),
                    tooltip: 'Unblock',
                    onPressed: () => _updateStatus(cg['id'], 1),
                  ),
              ],
            )),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildStatusChip(int status) {
    Color color;
    String label;
    switch (status) {
      case 1:
        color = Colors.green;
        label = "Verified";
        break;
      case 2:
        color = Colors.red;
        label = "Blocked";
        break;
      default:
        color = Colors.orange;
        label = "Pending";
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  void _viewPatients(String caregiverId, String caregiverName) {
    showDialog(
      context: context,
      builder: (context) => _PatientsUnderCaregiverDialog(caregiverId: caregiverId, caregiverName: caregiverName),
    );
  }

  Widget _buildAddForm() {
    return const Center(child: Text("Caregiver Registration Form (Integration Pending)"));
  }
}

class _PatientsUnderCaregiverDialog extends StatefulWidget {
  final String caregiverId;
  final String caregiverName;
  const _PatientsUnderCaregiverDialog({required this.caregiverId, required this.caregiverName});

  @override
  State<_PatientsUnderCaregiverDialog> createState() => _PatientsUnderCaregiverDialogState();
}

class _PatientsUnderCaregiverDialogState extends State<_PatientsUnderCaregiverDialog> {
  List<Map<String, dynamic>> _patients = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchPatients();
  }

  Future<void> _fetchPatients() async {
    try {
      final response = await supabase.from('tbl_patient').select().eq('caregiver_id', widget.caregiverId);
      setState(() {
        _patients = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      debugPrint("Error fetching patients: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Patients under ${widget.caregiverName}"),
      content: SizedBox(
        width: 500,
        height: 400,
        child: _loading 
            ? const Center(child: CircularProgressIndicator())
            : _patients.isEmpty 
                ? const Center(child: Text("No patients assigned yet."))
                : ListView.builder(
                    itemCount: _patients.length,
                    itemBuilder: (context, index) {
                      final p = _patients[index];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(p['patient_name']),
                        subtitle: Text(p['patient_email']),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      );
                    },
                  ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
    );
  }
}