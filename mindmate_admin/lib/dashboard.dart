import 'package:flutter/material.dart';
import 'package:mindmate_admin/main.dart';

class DashboardOverview extends StatefulWidget {
  const DashboardOverview({super.key});

  @override
  State<DashboardOverview> createState() => _DashboardOverviewState();
}

class _DashboardOverviewState extends State<DashboardOverview> {
  int _caregiverCount = 0;
  int _patientCount = 0;
  int _pendingComplaints = 0;
  List<Map<String, dynamic>> _recentActivities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      // 1. Fetch Counts
      final cgResponse = await supabase.from('tbl_caregiver').select('id');
      final ptResponse = await supabase.from('tbl_patient').select('id');
      final compResponse = await supabase
          .from('tbl_complaint')
          .select('id')
          .eq('complaint_status', 0);

      // 2. Fetch Recent Activities from the new log table
      final activitiesResponse = await supabase
          .from('tbl_activity_log')
          .select()
          .order('created_at', ascending: false)
          .limit(5);

      setState(() {
        _caregiverCount = cgResponse.length;
        _patientCount = ptResponse.length;
        _pendingComplaints = compResponse.length;
        _recentActivities = List<Map<String, dynamic>>.from(activitiesResponse);
        _loading = false;
      });
    } catch (e) {
      debugPrint("Error fetching dashboard stats: $e");
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _fetchStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Executive Dashboard",
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              "Live system monitoring and management overview.",
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),

            // Stats Cards
            Row(
              children: [
                _buildStatCard(
                  "Caregivers",
                  _caregiverCount.toString(),
                  Icons.people,
                  Colors.blue,
                ),
                _buildStatCard(
                  "Total Patients",
                  _patientCount.toString(),
                  Icons.elderly,
                  Colors.orange,
                ),
                _buildStatCard(
                  "Pending Complaints",
                  _pendingComplaints.toString(),
                  Icons.report_problem,
                  Colors.red,
                ),
                _buildStatCard(
                  "System Health",
                  "Optimal",
                  Icons.speed,
                  Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Lower Section
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildRecentActivitySection()),
                const SizedBox(width: 24),
                Expanded(flex: 1, child: _buildQuickActions()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 20),
            Text(
              value,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Recent System Activities",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          if (_recentActivities.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                "No activity recorded yet.",
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentActivities.length,
              separatorBuilder: (context, index) =>
                  Divider(color: Colors.grey[100]),
              itemBuilder: (context, index) {
                final activity = _recentActivities[index];
                final time = DateTime.parse(activity['created_at']).toLocal();

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal[50],
                    child: Icon(
                      Icons.history,
                      color: Colors.teal[600],
                      size: 18,
                    ),
                  ),
                  title: Text(
                    activity['action'],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(activity['details'] ?? "No details"),
                  trailing: Text(
                    "${time.hour}:${time.minute.toString().padLeft(2, '0')}",
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F26), // Dark premium color
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.teal.withOpacity(0.1), blurRadius: 20),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Quick Actions",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          _actionButton("Verify New Users", Icons.verified_user, Colors.teal),
          _actionButton("Emergency Comms", Icons.campaign, Colors.orange),
          _actionButton("Server Logs", Icons.terminal, Colors.blue),
          _actionButton("System Settings", Icons.settings, Colors.grey),
        ],
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 15),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
