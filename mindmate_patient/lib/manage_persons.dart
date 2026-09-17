import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mindmate_patient/add_knownperson.dart';
import 'package:mindmate_patient/main.dart';
import 'package:mindmate_patient/api_config.dart';
import 'package:mindmate_patient/face_scanner.dart';

class ManageKnownPeopleScreen extends StatefulWidget {
  const ManageKnownPeopleScreen({super.key});

  @override
  State<ManageKnownPeopleScreen> createState() =>
      _ManageKnownPeopleScreenState();
}

class _ManageKnownPeopleScreenState extends State<ManageKnownPeopleScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer(); // Audio Player Instance

  // --- 1. FETCH DATA ---
  Future<List<Map<String, dynamic>>> _fetchKnownPeople() async {
    final patientId = supabase.auth.currentUser!.id;
    final response = await supabase
        .from('tbl_known_person')
        .select('*, tbl_patient(patient_name)')
        .eq('patient_id', patientId)
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  // --- 2. DELETE PERSON ---
  Future<void> _deletePerson(String id) async {
    // Show confirmation dialog
    bool confirm =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Delete Person?"),
            content: const Text("This action cannot be undone."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  "Delete",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await supabase.from('tbl_known_person').delete().eq('id', id);

      if (mounted) {
        setState(() {}); // Refresh List
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Person deleted.")));
      }
    }
  }

  // --- 3. IDENTIFY PERSON (FACE RECOGNITION MOCK) ---
  Future<void> _identifyPerson() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceScannerScreen(),
      ),
    );
  }

  // --- 4. SHOW RESULT & PLAY AUDIO ---
  void _showMatchResult(Map<String, dynamic> person) {
    // Auto-play audio if available
    if (person['voice_prompt_message'] != null) {
      _playAudio(person['voice_prompt_message']);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: 400,
          child: Column(
            children: [
              const Text(
                "Match Found! ✅",
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 60,
                backgroundImage: person['image_url'] != null
                    ? NetworkImage(person['image_url'])
                    : null,
                child: person['image_url'] == null
                    ? const Icon(Icons.person, size: 60)
                    : null,
              ),
              const SizedBox(height: 20),
              Text(
                "This is ${person['name']}",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "Relation: ${person['relation']}",
                style: const TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 30),

              // Audio Controls
              if (person['voice_prompt_message'] != null)
                ElevatedButton.icon(
                  onPressed: () => _playAudio(person['voice_prompt_message']),
                  icon: const Icon(Icons.volume_up),
                  label: const Text("Replay Voice Message"),

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                )
              else
                const Text(
                  "No voice message recorded.",
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      _audioPlayer.stop(); // Stop audio when closing popup
    });
  }

  Future<void> _playAudio(String url) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
    } catch (e) {
      debugPrint("Audio Error: $e");
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Family & Friends"),
        backgroundColor: Colors.teal,
        actions: [
          // IDENTIFY BUTTON IN APP BAR
          IconButton(
            icon: const Icon(Icons.face_retouching_natural),
            tooltip: "Identify Person",
            onPressed: _identifyPerson,
          ),
        ],
      ),

      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchKnownPeople(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No known people added yet."));
          }

          final people = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: people.length,
            itemBuilder: (context, index) {
              final person = people[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundImage: person['image_url'] != null
                        ? NetworkImage(person['image_url'])
                        : null,
                    child: person['image_url'] == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(
                    person['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(person['relation']),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Voice Indicator
                      if (person['voice_prompt_message'] != null)
                        IconButton(
                          icon: const Icon(Icons.volume_up, color: Colors.blue),
                          onPressed: () =>
                              _playAudio(person['voice_prompt_message']),
                        ),
                      // DELETE BUTTON
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deletePerson(person['id']),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddKnownPersonScreen(),
            ),
          );
          setState(() {}); // Refresh on return
        },
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Person", style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
