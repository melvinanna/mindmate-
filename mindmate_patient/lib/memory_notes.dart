import 'package:flutter/material.dart';
import 'package:mindmate_patient/main.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class MemoryNotesScreen extends StatefulWidget {
  const MemoryNotesScreen({super.key});

  @override
  State<MemoryNotesScreen> createState() => _MemoryNotesScreenState();
}

class _MemoryNotesScreenState extends State<MemoryNotesScreen> {
  late Future<List<Map<String, dynamic>>> _notesFuture;

  @override
  void initState() {
    super.initState();
    _notesFuture = _fetchNotes();
  }

  Future<List<Map<String, dynamic>>> _fetchNotes() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final response = await supabase
        .from('tbl_memory_note')
        .select()
        .eq('patient_id', user.id)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  void _showAddNoteDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    File? attachedImage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "New Memory",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: "Title (e.g., My Grandchild's Birthday)",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: contentController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: "Tell the story...",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
                const SizedBox(height: 15),
                if (attachedImage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.file(attachedImage!, height: 150, width: double.infinity, fit: BoxFit.cover),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picker = ImagePicker();
                          final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                          if (pickedFile != null) {
                            setModalState(() => attachedImage = File(pickedFile.path));
                          }
                        },
                        icon: const Icon(Icons.image),
                        label: const Text("Add Photo"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picker = ImagePicker();
                          final pickedFile = await picker.pickImage(source: ImageSource.camera);
                          if (pickedFile != null) {
                            setModalState(() => attachedImage = File(pickedFile.path));
                          }
                        },
                        icon: const Icon(Icons.camera_alt),
                        label: const Text("Take Photo"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (titleController.text.isEmpty || contentController.text.isEmpty) return;
                      
                      final user = supabase.auth.currentUser;
                      if (user == null) return;

                      String? imageUrl;
                      if (attachedImage != null) {
                         final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
                        await supabase.storage.from('photos').upload(fileName, attachedImage!);
                        imageUrl = supabase.storage.from('photos').getPublicUrl(fileName);
                      }

                      await supabase.from('tbl_memory_note').insert({
                        'patient_id': user.id,
                        'note_title': titleController.text,
                        'note_content': contentController.text,
                        'image_url': imageUrl,
                      });

                      if (mounted) {
                        Navigator.pop(ctx);
                        setState(() {
                          _notesFuture = _fetchNotes();
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text("Preserve Memory", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Memory Box", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _notesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_stories, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 20),
                  const Text(
                    "No memories saved yet.",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final notes = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final n = notes[index];
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                margin: const EdgeInsets.only(bottom: 20),
                elevation: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (n['image_url'] != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        child: Image.network(
                          n['image_url'],
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                n['note_title'],
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () async {
                                  await supabase.from('tbl_memory_note').delete().eq('id', n['id']);
                                  setState(() {
                                    _notesFuture = _fetchNotes();
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            n['note_content'],
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Saved on: ${n['created_at'].toString().split('T')[0]}",
                            style: const TextStyle(color: Colors.teal, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddNoteDialog,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
