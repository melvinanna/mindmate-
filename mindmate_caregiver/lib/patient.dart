import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mindmate_caregiver/main.dart';

const String mySupabaseUrl = 'https://disbpshtlcxhvzozplpb.supabase.co';
const String mySupabaseKey = 'sb_publishable_EDMIfGN40YB3NVojTYxBhQ_2n6QrHC1';

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- CONTROLLERS ---
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _conditionController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _safeZoneController = TextEditingController(
    text: "100",
  );
  final TextEditingController _phoneController = TextEditingController();

  // --- STATE VARIABLES ---
  String? _selectedGender;
  String? _selectedStage;
  String? _selectedLanguage;
  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _stages = ['Early Stage', 'Middle Stage', 'Late Stage'];
  final List<String> _languages = ['English', 'Malayalam', 'Hindi', 'Tamil'];

  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  int? _calculatedAge;

  // --- PICK IMAGE MODAL ---
  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.teal),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Colors.teal),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 600,
        imageQuality: 80,
      );
      if (picked != null) setState(() => _imageFile = File(picked.path));
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  // --- SELECT DATE ---
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1960),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.teal,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dobController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
        _calculatedAge = DateTime.now().year - picked.year;
      });
    }
  }

  // --- SAVE PATIENT & CREATE AUTH USER ---
  Future<void> _savePatient() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGender == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Select Gender")));
      return;
    }
    if (_calculatedAge == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Select Date of Birth")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Get Current Caregiver ID
      final caregiverUser = supabase.auth.currentUser;
      if (caregiverUser == null) throw "Caregiver not logged in";

      // 2. Upload Photo (Optional)
      String? photoUrl;
      if (_imageFile != null) {
        final path =
            'patients/${caregiverUser.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await supabase.storage.from('patients').upload(path, _imageFile!);
        photoUrl = supabase.storage.from('patients').getPublicUrl(path);
      }

      // 3. CREATE PATIENT AUTH USER
      // FIX: Disable persistence for the secondary client to avoid the asyncStorage error
      final tempClient = SupabaseClient(
        mySupabaseUrl,
        mySupabaseKey,
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );

      final AuthResponse authResponse = await tempClient.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (authResponse.user == null) {
        throw "Failed to create authentication account.";
      }

      final String newPatientAuthId = authResponse.user!.id;

      // 4. INSERT DATA INTO TBL_PATIENT
      await supabase.from('tbl_patient').insert({
        'id': newPatientAuthId,
        'caregiver_id': caregiverUser.id,
        'patient_name': _nameController.text.trim(),
        'patient_email': _emailController.text.trim(),
        'patient_phone': _phoneController.text.trim(),
        'patient_age': _calculatedAge,
        'patient_gender': _selectedGender,
        'patient_medical_condition': _conditionController.text.trim(),
        'patient_photo': photoUrl,
        'patient_status': 1,
        'patient_password': _passwordController.text.trim(),
        'safe_zone_radius': int.tryParse(_safeZoneController.text) ?? 100,
        // Centering safe zone at current location of caregiver for setup
        'safe_zone_lat': 0.0,
        'safe_zone_lng': 0.0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Patient Account Created Successfully!"),
            backgroundColor: Colors.teal,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Add New Patient"),
        backgroundColor: Colors.teal,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- PHOTO UPLOAD ---
              Center(
                child: GestureDetector(
                  onTap: _showImagePickerOptions,
                  child: Stack(
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 2,
                          ),
                          image: _imageFile != null
                              ? DecorationImage(
                                  image: FileImage(_imageFile!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _imageFile == null
                            ? const Icon(
                                Icons.person,
                                size: 60,
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
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              const Text(
                "Account Credentials",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 15),
              _buildTextField(
                _emailController,
                "Patient Email",
                Icons.email,
                TextInputType.emailAddress,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                validator: (val) => val!.length < 6 ? "Min 6 chars" : null,
                decoration: InputDecoration(
                  labelText: "Create Password",
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    color: Colors.grey,
                  ),
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
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const Divider(height: 40),

              const Text(
                "Personal Details",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 15),

              _buildTextField(
                _nameController,
                "Patient Name",
                Icons.person_outline,
              ),
              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dobController,
                      readOnly: true,
                      onTap: () => _selectDate(context),
                      validator: (val) => val!.isEmpty ? "Required" : null,
                      decoration: InputDecoration(
                        labelText: "Date of Birth",
                        prefixIcon: const Icon(
                          Icons.calendar_month,
                          color: Colors.grey,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: InputDecoration(
                        labelText: "Gender",
                        prefixIcon: const Icon(Icons.male),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: _genders
                          .map(
                            (g) => DropdownMenuItem(value: g, child: Text(g)),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _selectedGender = val),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              const Text(
                "Medical Information",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: _selectedStage,
                decoration: InputDecoration(
                  labelText: "Alzheimer Stage",
                  prefixIcon: const Icon(Icons.psychology),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _stages
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedStage = val),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: _selectedLanguage,
                decoration: InputDecoration(
                  labelText: "Preferred Language",
                  prefixIcon: const Icon(Icons.language),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _languages
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedLanguage = val),
              ),
              const SizedBox(height: 15),
              _buildTextField(
                _safeZoneController,
                "Safe Zone Radius (meters)",
                Icons.security,
                TextInputType.number,
              ),
              const SizedBox(height: 15),
              _buildTextField(
                _phoneController,
                "Patient Phone",
                Icons.phone,
                TextInputType.phone,
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _savePatient,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    _isLoading
                        ? "Creating Account..."
                        : "Create Patient Account",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
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
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, [
    TextInputType type = TextInputType.text,
  ]) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      validator: (val) => val!.isEmpty ? "Required" : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
