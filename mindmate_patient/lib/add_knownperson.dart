import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mindmate_patient/main.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart'; // REQUIRED for permissions

import 'package:mindmate_patient/face_scanner.dart';

class AddKnownPersonScreen extends StatefulWidget {
  const AddKnownPersonScreen({super.key});

  @override
  State<AddKnownPersonScreen> createState() => _AddKnownPersonScreenState();
}

class _AddKnownPersonScreenState extends State<AddKnownPersonScreen> {
  final _formKey = GlobalKey<FormState>();

  // Input Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _relationController = TextEditingController();

  // Media Variables
  File? _imageFile;
  String? _audioPath;

  // State Variables
  bool _isLoading = false;
  bool _isRecording = false;
  final AudioRecorder _audioRecorder = AudioRecorder();

  @override
  void dispose() {
    _nameController.dispose();
    _relationController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Library'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    try {
      final XFile? picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 600,
        imageQuality: 80,
      );

      if (picked != null) {
        setState(() => _imageFile = File(picked.path));
      }
    } catch (e) {
      debugPrint("Picker Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Could not pick image: $e")));
      }
    }
  }

  // --- 2. RECORD AUDIO (Permissions Fixed) ---
  Future<void> _startRecording() async {
    try {
      // STEP 1: EXPLICITLY REQUEST PERMISSION
      var status = await Permission.microphone.request();

      if (status != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Microphone permission is required to record voice.",
              ),
            ),
          );
        }
        return;
      }

      // STEP 2: PREPARE PATH
      final directory = await getApplicationDocumentsDirectory();
      // Create a unique filename using timestamp
      final String path =
          '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // STEP 3: START RECORDING
      // Check if recorder is already running to avoid errors
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }

      await _audioRecorder.start(const RecordConfig(), path: path);

      setState(() => _isRecording = true);
    } catch (e) {
      debugPrint("Record Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Mic Error: $e")));
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _audioPath = path;
      });
      debugPrint("Recorded audio saved at: $_audioPath");
    } catch (e) {
      debugPrint("Stop Error: $e");
    }
  }

  // --- 3. SAVE TO DATABASE ---
  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;

    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please add a photo for facial recognition."),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw "User not logged in";

      String? photoUrl;
      String? audioUrl;
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      // A. Upload Photo
      if (_imageFile != null) {
        final path = 'known_persons/${user.id}/photo_$timestamp.jpg';
        await supabase.storage
            .from('photos')
            .upload(
              path,
              _imageFile!,
              fileOptions: const FileOptions(upsert: true),
            );
        photoUrl = supabase.storage.from('photos').getPublicUrl(path);
      }

      // B. Upload Audio
      if (_audioPath != null) {
        final File audioFile = File(_audioPath!);
        final path = 'known_persons/${user.id}/voice_$timestamp.m4a';
        await supabase.storage
            .from('audio_messages')
            .upload(
              path,
              audioFile,
              fileOptions: const FileOptions(upsert: true),
            );
        audioUrl = supabase.storage.from('audio_messages').getPublicUrl(path);
      }

      // C. Insert into DB
      await supabase.from('tbl_known_person').insert({
        'name': _nameController.text.trim(),
        'relation': _relationController.text.trim(),
        'image_url': photoUrl,
        'voice_prompt_message': audioUrl,
        'patient_id': user.id,
      });

      if (mounted) {
        logActivity("Added Known Person", "Registered ${_nameController.text} as ${_relationController.text}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Person Added Successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Upload Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Known Person"),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.face_retouching_natural),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FaceScannerScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- 1. PHOTO PICKER UI ---
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.teal, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: _imageFile != null
                              ? FileImage(_imageFile!)
                              : null,
                          child: _imageFile == null
                              ? const Icon(
                                  Icons.add_a_photo,
                                  size: 40,
                                  color: Colors.grey,
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Tap to add face photo",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // --- 2. TEXT FIELDS ---
              TextFormField(
                controller: _nameController,
                validator: (val) => val!.isEmpty ? "Required" : null,
                decoration: InputDecoration(
                  labelText: "Person's Name",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _relationController,
                validator: (val) => val!.isEmpty ? "Required" : null,
                decoration: InputDecoration(
                  labelText: "Relationship (e.g., Son, Doctor)",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.favorite),
                ),
              ),
              const SizedBox(height: 30),

              // --- 3. VOICE RECORDER UI ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Voice Identification",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "Record a greeting (e.g., 'Hi, it's your son John')",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 15),

                    GestureDetector(
                      onLongPress: _startRecording, // Hold to record
                      onLongPressUp: _stopRecording, // Release to stop
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _isRecording
                              ? Colors.red.withOpacity(0.1)
                              : Colors.teal.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isRecording ? Colors.red : Colors.teal,
                            width: 3,
                          ),
                          boxShadow: _isRecording
                              ? [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.4),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : [],
                        ),
                        child: Icon(
                          _isRecording ? Icons.mic : Icons.mic_none,
                          color: _isRecording ? Colors.red : Colors.teal,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      _isRecording
                          ? "Recording... Release to Stop"
                          : (_audioPath != null
                                ? "Voice Recorded ✅"
                                : "Hold Button to Record"),
                      style: TextStyle(
                        color: _isRecording
                            ? Colors.red
                            : (_audioPath != null
                                  ? Colors.green
                                  : Colors.black),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // --- 4. SUBMIT BUTTON ---
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
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
                          "SAVE PERSON",
                          style: TextStyle(
                            color: Colors.white,
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
}
