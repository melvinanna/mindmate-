import 'package:flutter/material.dart';
// Ensure these imports match your actual file structure
import 'package:mindmate_admin/dashboard.dart';
import 'package:mindmate_admin/login.dart';
import 'package:mindmate_admin/main.dart';
import 'package:mindmate_admin/manage_caregivers.dart';
import 'package:mindmate_admin/manage_patients.dart';
import 'package:mindmate_admin/complaints.dart';
import 'package:mindmate_admin/activity_log.dart';


class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;


  Future<void> _handleLogout() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  // List of Pages to display in the main content area
  // Make sure these widgets are defined in your separate files
  final List<Widget> _pages = [
    const DashboardOverview(),
    const ManageCaregivers(),
    const ManagePatients(),
    const ManageComplaints(),
    const SystemActivityLog(),
  ];


  // List of Titles that update the Header based on selection
  final List<String> _pageTitles = [
    "Dashboard Overview",
    "Caregiver Management",
    "Patient Records",
    "User Complaints",
    "Activity Logs"
  ];


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5), // Soft grey background
      body: Row(
        children: [
          // ----------------- 1. CUSTOM SIDEBAR -----------------
          _buildSidebar(),

          // ----------------- 2. MAIN CONTENT AREA -----------------
          Expanded(
            child: Column(
              children: [
                // A. Header (Top Bar with Profile Dropdown)
                _buildHeader(),

                // B. Page Content (Changes based on selection)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: _pages[_selectedIndex],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================================
  // WIDGET: SIDEBAR (Logo + Navigation)
  // ==============================================================================
  Widget _buildSidebar() {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // --- Brand Logo Area ---
          Container(
            height: 100,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade700, Colors.teal.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: const [
                Icon(Icons.memory, color: Colors.white, size: 32),
                SizedBox(width: 12),
                Text(
                  "MINDMATE+",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // --- Navigation Menu Items ---
          _buildMenuItem(0, "Dashboard", Icons.dashboard_rounded),
          _buildMenuItem(1, "Caregivers", Icons.people_alt_rounded),
          _buildMenuItem(2, "Patients", Icons.accessible_forward_rounded),
          _buildMenuItem(3, "Complaints", Icons.comment_rounded),
          _buildMenuItem(4, "Activity Logs", Icons.analytics_rounded),

        ],
      ),
    );
  }

  // Helper Widget for Sidebar Menu Items
  Widget _buildMenuItem(int index, String title, IconData icon) {
    bool isSelected = _selectedIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            border: isSelected
                ? Border(right: BorderSide(color: Colors.teal.shade700, width: 4))
                : null,
            color: isSelected ? Colors.teal.withOpacity(0.05) : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.teal.shade700 : Colors.grey.shade600,
                size: 24,
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.teal.shade800 : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==============================================================================
  // WIDGET: HEADER (Title + Search + Profile Dropdown)
  // ==============================================================================
  Widget _buildHeader() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // --- Dynamic Page Title ---
          Text(
            _pageTitles[_selectedIndex],
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const Spacer(),

          // --- Search Bar ---
          
          const SizedBox(width: 24),

          // --- Notification Icon ---
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, size: 28),
                onPressed: () {},
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            ],
          ),
          const SizedBox(width: 16),

          PopupMenuButton<String>(
            offset: const Offset(0, 50), // Offsets the menu slightly downwards
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
               
              } 
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              
              const PopupMenuItem<String>(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.redAccent),
                  title: Text('Logout', style: TextStyle(color: Colors.redAccent)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            // Child is the trigger widget (The Admin User info)
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.teal,
                  child: Icon(Icons.person, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Admin User", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text("Super Admin", style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                  ],
                ),
                const SizedBox(width: 8),
                const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey)
              ],
            ),
          ),
        ],
      ),
    );
  }
}