import 'package:flutter/material.dart';
import 'package:mindmate_patient/editprofile.dart';
import 'package:mindmate_patient/changepassword.dart';
import 'package:mindmate_patient/login.dart';
import 'package:mindmate_patient/main.dart'; // Ensure Supabase client is imported

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  Map<String, dynamic>? _patientData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final userId = supabase.auth.currentUser!.id;
    final data = await supabase
        .from('tbl_patient')
        .select()
        .eq('id', userId)
        .single();

    setState(() {
      _patientData = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Light Grey Background
      appBar: AppBar(
        title: const Text(
          "My Profile",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // --- 1. PROFILE HEADER ---
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.white,
                    backgroundImage: _patientData!['patient_photo'] != null && 
                                     _patientData!['patient_photo'].isNotEmpty
                        ? NetworkImage(_patientData!['patient_photo'])
                        : null,
                    child: _patientData!['patient_photo'] == null || 
                           _patientData!['patient_photo'].isEmpty
                        ? const Icon(Icons.person, size: 70, color: Colors.teal)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _patientData!['patient_name'] ?? "Unknown",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    _patientData!['patient_email'] ?? "",
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 30),

                  // --- 2. PERSONAL INFO CARD ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Personal Information",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        const Divider(height: 20),
                        _buildInfoRow(
                          "Age",
                          "${_patientData!['patient_age'] ?? 'N/A'} years",
                        ),
                        const SizedBox(height: 10),
                        _buildInfoRow(
                          "Gender",
                          _patientData!['patient_gender'] ?? 'N/A',
                        ),
                        const SizedBox(height: 10),
                        _buildInfoRow(
                          "Condition",
                          _patientData!['patient_medical_condition'] ?? 'N/A',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- 3. ACTIONS LIST ---
                  _buildActionCard(
                    "Edit Profile",
                    Icons.edit,
                    Colors.blue,
                    () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PatientEditProfileScreen(data: _patientData!),
                        ),
                      );
                      _fetchProfile(); // Refresh data when coming back
                    },
                  ),
                  _buildActionCard(
                    "Change Password",
                    Icons.lock,
                    Colors.orange,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PatientChangePassword(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 30),

                  // --- 4. LOGOUT BUTTON ---
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await supabase.auth.signOut();
                        if (mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PatientLoginScreen(),
                            ),
                            (route) => false,
                          );
                        }
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text("Logout"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Helper for Info Rows
  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ],
    );
  }

  // Helper for Action Cards
  Widget _buildActionCard(
    String title,
    IconData icon,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }
}
