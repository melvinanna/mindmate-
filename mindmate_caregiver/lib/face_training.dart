import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mindmate_caregiver/main.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class FaceTrainingScreen extends StatefulWidget {
  final String? patientId;
  const FaceTrainingScreen({super.key, this.patientId});

  @override
  State<FaceTrainingScreen> createState() => _FaceTrainingScreenState();
}

class _FaceTrainingScreenState extends State<FaceTrainingScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _relationController = TextEditingController();
  
  File? _imageFile;
  String? _audioPath;
  bool _isLoading = false;
  bool _isRecording = false;
  final AudioRecorder _audioRecorder = AudioRecorder();
  
  String? _selectedPatientId;
  List<Map<String, dynamic>> _patients = [];

  @override
  void initState() {
    super.initState();
    _selectedPatientId = widget.patientId;
    _fetchPatients();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _fetchPatients() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final data = await supabase
        .from('tbl_patient')
        .select('id, patient_name')
        .eq('caregiver_id', user.id);
    setState(() => _patients = List<Map<String, dynamic>>.from(data));
    if (_selectedPatientId == null && _patients.isNotEmpty) {
      _selectedPatientId = _patients.first['id'].toString();
    }
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
                title: const Text('From Library'),
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

    final XFile? picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 70,
    );
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _startRecording() async {
    try {
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Mic permission denied.")),
          );
        }
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final String path = '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }

      await _audioRecorder.start(const RecordConfig(), path: path);
      setState(() => _isRecording = true);
    } catch (e) {
      debugPrint("Record Error: $e");
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _audioPath = path;
      });
    } catch (e) {
      debugPrint("Stop Error: $e");
    }
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate() || _imageFile == null || _selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add photo and complete fields.")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Upload Photo
      final String photoPath = 'known_persons/$_selectedPatientId/photo_$timestamp.jpg';
      await supabase.storage.from('photos').upload(photoPath, _imageFile!);
      final String photoUrl = supabase.storage.from('photos').getPublicUrl(photoPath);

      // Upload Audio
      String? audioUrl;
      if (_audioPath != null) {
        final String audioPathInBucket = 'known_persons/$_selectedPatientId/voice_$timestamp.m4a';
        await supabase.storage.from('audio_messages').upload(audioPathInBucket, File(_audioPath!));
        audioUrl = supabase.storage.from('audio_messages').getPublicUrl(audioPathInBucket);
      }

      await supabase.from('tbl_known_person').insert({
        'name': _nameController.text.trim(),
        'relation': _relationController.text.trim(),
        'image_url': photoUrl,
        'voice_prompt_message': audioUrl,
        'patient_id': _selectedPatientId,
      });

      if (mounted) {
        logActivity("Face Data Registered", "Uploaded face training for ${_nameController.text} (Relation: ${_relationController.text}) to Patient ID: $_selectedPatientId");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Successfully added Person!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Face Training Portal"),
        backgroundColor: Colors.teal,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedPatientId,
                      decoration: const InputDecoration(
                        labelText: "Target Patient",
                        border: OutlineInputBorder(),
                      ),
                      items: _patients
                          .map((p) => DropdownMenuItem(
                                value: p['id'].toString(),
                                child: Text(p['patient_name']),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedPatientId = val),
                    ),
                    const SizedBox(height: 30),
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 70,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                          child: _imageFile == null ? const Icon(Icons.camera_alt, size: 40) : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Center(child: Text("Register Face Photo", style: TextStyle(color: Colors.grey))),
                    const SizedBox(height: 30),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: "Person's Name", border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _relationController,
                      decoration: const InputDecoration(labelText: "Relationship", border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 30),
                    
                    // Voice Recorder UI
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          const Text("Recorded Prompt", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 15),
                          GestureDetector(
                            onLongPress: _startRecording,
                            onLongPressUp: _stopRecording,
                            child: CircleAvatar(
                              radius: 35,
                              backgroundColor: _isRecording ? Colors.red : Colors.teal,
                              child: Icon(_isRecording ? Icons.mic : Icons.mic_none, color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text(_isRecording ? "Recording..." : (_audioPath != null ? "Voice Captured ✅" : "Hold to Record Voice")),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _upload,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.all(16)),
                      child: const Text("LINK TO SYSTEM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
