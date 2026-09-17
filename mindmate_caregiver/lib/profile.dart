import 'package:flutter/material.dart';
import 'package:mindmate_caregiver/changepassword.dart';
import 'package:mindmate_caregiver/editprofile.dart';
import 'package:mindmate_caregiver/login.dart';
import 'package:mindmate_caregiver/main.dart'; 

class CaregiverProfileScreen extends StatefulWidget {
  const CaregiverProfileScreen({super.key});

  @override
  State<CaregiverProfileScreen> createState() => _CaregiverProfileScreenState();
}

class _CaregiverProfileScreenState extends State<CaregiverProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  // --- FETCH DATA ---
  Future<void> _fetchProfile() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final data = await supabase
          .from('tbl_caregiver')
          .select()
          .eq('id', userId)
          .single();


      setState(() {
        _profileData = data;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading profile: $e")));
      setState(() => _isLoading = false);
    }
  }

  // --- LOGOUT ---
  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const CaregiverLoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("My Profile", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // --- PROFILE HEADER ---
                  const SizedBox(height: 20),
                  Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.teal.shade100, width: 4),
                          image: _profileData?['caregiver_photo'] != null
                              ? DecorationImage(
                                  image: NetworkImage(_profileData!['caregiver_photo']),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _profileData?['caregiver_photo'] == null
                            ? const Icon(Icons.person, size: 60, color: Colors.grey)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _profileData?['caregiver_name'] ?? "Caregiver Name",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _profileData?['caregiver_email'] ?? "email@example.com",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 30),

                  // --- MENU OPTIONS ---
                  _buildProfileOption(
                    icon: Icons.edit_outlined,
                    title: "Edit Profile",
                    onTap: () async {
                      // Wait for result to refresh data if updated
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProfileScreen(userData: _profileData!),
                        ),
                      );
                      if (result == true) _fetchProfile();
                    },
                  ),
                  _buildProfileOption(
                    icon: Icons.lock_outline,
                    title: "Change Password",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
                      );
                    },
                  ),
                  _buildProfileOption(
                    icon: Icons.info_outline,
                    title: "Privacy Policy",
                    onTap: () {},
                  ),
                  const SizedBox(height: 20),

                  // --- LOGOUT BUTTON ---
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _logout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.logout),
                      label: const Text("Logout"),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileOption({required IconData icon, required String title, required VoidCallback onTap}) {
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
          decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.teal),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}