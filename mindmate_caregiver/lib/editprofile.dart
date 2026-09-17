import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mindmate_caregiver/main.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData; // Pass current data

  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _emailController; // Added Email Controller
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize with existing data
    _nameController = TextEditingController(text: widget.userData['caregiver_name']);
    _emailController = TextEditingController(text: widget.userData['caregiver_email']); // Load Email
    _phoneController = TextEditingController(text: widget.userData['caregiver_contact']);
    _addressController = TextEditingController(text: widget.userData['caregiver_address']);
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser!.id;
      final newEmail = _emailController.text.trim();
      final oldEmail = widget.userData['caregiver_email'];
      bool emailChanged = newEmail != oldEmail;

      // 1. If Email Changed, Update Supabase Auth (Login Credentials)
      if (emailChanged) {
        await supabase.auth.updateUser(
          UserAttributes(email: newEmail),
        );
      }

      // 2. Update Custom Database Table
      await supabase.from('tbl_caregiver').update({
        'caregiver_name': _nameController.text.trim(),
        'caregiver_email': newEmail, // Update email in DB too
        'caregiver_phone': _phoneController.text.trim(),
      }).eq('id', userId);


      if (mounted) {
        String message = "Profile Updated Successfully!";
        
        // Show specific message if email was changed (Supabase sends confirmation)
        if (emailChanged) {
          message = "Profile Updated! Please verify your new email address.";
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message), 
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true); // Return true to trigger refresh
      }
    } on AuthException catch (e) {
      // Handle Email already taken or specific Auth errors
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Update failed: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Edit Profile", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(_nameController, "Full Name", Icons.person),
              const SizedBox(height: 20),

              // --- ADDED EMAIL FIELD ---
              _buildTextField(
                _emailController, 
                "Email Address", 
                Icons.email, 
                TextInputType.emailAddress
              ),
              const SizedBox(height: 20),

              _buildTextField(_phoneController, "Phone Number", Icons.phone, TextInputType.phone),
              const SizedBox(height: 20),
              
              _buildTextField(_addressController, "Address", Icons.location_on, TextInputType.streetAddress),
              const SizedBox(height: 40),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white, // Text Color
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading 
                    ? const SizedBox(
                        height: 20, width: 20, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      ) 
                    : const Text("SAVE CHANGES", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, [TextInputType type = TextInputType.text]) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      validator: (val) {
        if (val == null || val.isEmpty) return "Required";
        // Basic Email Regex if it's the email field
        if (type == TextInputType.emailAddress && !val.contains('@')) return "Invalid Email";
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}