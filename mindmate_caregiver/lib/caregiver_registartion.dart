import 'dart:io'; // Required for File handling
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Import Image Picker
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mindmate_caregiver/main.dart';

class CaregiverRegistrationScreen extends StatefulWidget {
  const CaregiverRegistrationScreen({super.key});

  @override
  State<CaregiverRegistrationScreen> createState() =>
      _CaregiverRegistrationScreenState();
}

class _CaregiverRegistrationScreenState
    extends State<CaregiverRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  // Image Picker Variables
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  // --- FUNCTION: SHOW OPTIONS (Gallery or Camera) ---
  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.teal),
                title: const Text('Photo Library'),
                onTap: () {
                  _pickImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera, color: Colors.teal),
                title: const Text('Camera'),
                onTap: () {
                  _pickImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 20), // Bottom spacing
            ],
          ),
        );
      },
    );
  }

  // --- FUNCTION: PICK IMAGE ---
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source, // Use the source passed from the sheet
        maxWidth: 600, // Optimize image size
        imageQuality: 80, // Compress slightly
      );
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      _showError("Failed to pick image: $e");
    }
  }

  // --- FUNCTION: REGISTER ---
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passController.text.trim();
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();

      // 1. Create Auth User
      final AuthResponse res = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (res.user == null) throw "Registration failed.";

      // 2. Upload Photo (If selected)
      if (_imageFile != null) {
        final String userId = res.user!.id;
        final String path =
            'caregivers/$userId/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';

        // Upload to Supabase Storage bucket named 'profiles'
        await supabase.storage
            .from('profiles')
            .upload(
              path,
              _imageFile!,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
              ),
            );
      }

      // 3. Insert into Database
      await supabase.from('tbl_caregiver').insert({
        'id': res.user!.id,
        'caregiver_name': name,
        'caregiver_email': email,
        'caregiver_phone': phone,
        'caregiver_status': 0, // Pending
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Registration Successful! Please login."),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError("An error occurred: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Create Account",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // --- PROFILE PHOTO UPLOAD (UPDATED) ---
                GestureDetector(
                  onTap: _showPickerOptions, // <--- CHANGED TO SHOW MENU
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.teal.shade100,
                            width: 2,
                          ),
                          image: _imageFile != null
                              ? DecorationImage(
                                  image: FileImage(
                                    _imageFile!,
                                  ), // Show selected image
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _imageFile == null
                            ? const Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.teal,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Tap to upload photo",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 30),

                // --- FORM FIELDS ---
                _buildTextField(
                  _nameController,
                  "Full Name",
                  Icons.person_outline,
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  _emailController,
                  "Email Address",
                  Icons.email_outlined,
                  TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  _phoneController,
                  "Phone Number",
                  Icons.phone_outlined,
                  TextInputType.phone,
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  _addressController,
                  "Home Address",
                  Icons.location_on_outlined,
                  TextInputType.streetAddress,
                ),
                const SizedBox(height: 16),

                // --- PASSWORD ---
                TextFormField(
                  controller: _passController,
                  obscureText: !_isPasswordVisible,
                  validator: (val) =>
                      val!.length < 6 ? "Min 6 characters required" : null,
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // --- CONFIRM PASSWORD ---
                TextFormField(
                  controller: _confirmPassController,
                  obscureText: !_isPasswordVisible,
                  validator: (val) {
                    if (val!.isEmpty) return "Confirm your password";
                    if (val != _passController.text)
                      return "Passwords do not match";
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: "Confirm Password",
                    prefixIcon: const Icon(Icons.lock_reset),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // --- REGISTER BUTTON ---
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
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
                            "REGISTER",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),
                const Text(
                  "By registering, you agree to our Terms & Privacy Policy.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper Widget
  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, [
    TextInputType type = TextInputType.text,
  ]) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      validator: (val) => val!.isEmpty ? "This field is required" : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
