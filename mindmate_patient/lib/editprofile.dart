import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mindmate_patient/main.dart'; // Ensure Supabase client is imported

class PatientEditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> data; // Receives current patient data
  const PatientEditProfileScreen({super.key, required this.data});

  @override
  State<PatientEditProfileScreen> createState() =>
      _PatientEditProfileScreenState();
}

class _PatientEditProfileScreenState extends State<PatientEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for all fields
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _ageController;
  late TextEditingController _conditionController;
  late TextEditingController _contactController;
  late TextEditingController _languageController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing data
    _nameController = TextEditingController(text: widget.data['patient_name']);
    _emailController = TextEditingController(
      text: widget.data['patient_email'],
    );
    _ageController = TextEditingController(
      text: widget.data['patient_age']?.toString() ?? "",
    );
    _conditionController = TextEditingController(
      text: widget.data['patient_medical_condition'],
    );
    _contactController = TextEditingController(
      text: widget.data['patient_phone'],
    );
    _languageController = TextEditingController(text: ""); // Initialize it
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _conditionController.dispose();
    _contactController.dispose();
    _languageController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final newEmail = _emailController.text.trim();
      final oldEmail = widget.data['patient_email'];
      bool emailChanged = newEmail != oldEmail;

      // 1. If Email Changed, Update Supabase Auth (Login Credentials)
      if (emailChanged) {
        await supabase.auth.updateUser(UserAttributes(email: newEmail));
      }

      // 2. Update Database Record
      await supabase
          .from('tbl_patient')
          .update({
            'patient_name': _nameController.text.trim(),
            'patient_email': newEmail,
            'patient_age': int.tryParse(_ageController.text.trim()) ?? 0,
            'patient_medical_condition': _conditionController.text.trim(),
            'patient_phone': _contactController.text.trim(),
          })
          .eq('id', widget.data['id']);

      if (mounted) {
        String message = "Profile Updated Successfully!";
        if (emailChanged) {
          message = "Profile Updated! Please verify your new email address.";
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Go back to refresh profile
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Update failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Edit Profile",
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Personal Details",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 15),
              _buildTextField(_nameController, "Full Name", Icons.person),
              const SizedBox(height: 15),
              _buildTextField(
                _ageController,
                "Age",
                Icons.calendar_today,
                TextInputType.number,
              ),
              const SizedBox(height: 15),
              _buildTextField(
                _languageController,
                "Language Preference",
                Icons.language,
              ),

              const SizedBox(height: 30),
              const Text(
                "Account Info",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 15),
              _buildTextField(
                _emailController,
                "Email Address",
                Icons.email,
                TextInputType.emailAddress,
              ),

              const SizedBox(height: 30),
              const Text(
                "Medical & Emergency",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 15),
              _buildTextField(
                _conditionController,
                "Medical Condition",
                Icons.medical_services,
              ),
              const SizedBox(height: 15),
              _buildTextField(
                _contactController,
                "Emergency Contact",
                Icons.phone,
                TextInputType.phone,
              ),

              const SizedBox(height: 40),

              // --- SAVE BUTTON ---
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "SAVE CHANGES",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper Widget for Clean Text Fields
  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, [
    TextInputType type = TextInputType.text,
  ]) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      validator: (val) {
        if (val == null || val.isEmpty) return "Required";
        if (type == TextInputType.emailAddress && !val.contains('@'))
          return "Invalid Email";
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: const Color(0xFFF5F7FA), // Light grey fill
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 12,
        ),
      ),
    );
  }
}
