import 'package:flutter/material.dart';
import '../services/parent_service.dart';
import '../models/data_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/auth_service.dart';
import 'package:flutter/services.dart';
import 'leave_details_screen.dart';
import 'notifications_screen.dart';
import '../services/leave_service.dart';
import 'dart:developer' as dev;
import '../helpers/error_handler.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  List<LeaveRequest> _leaveRequests = [];
  String _filterOption = 'All';
  int _selectedTab = 0;
  bool _loading = true;
  String? _token;
  String? _userEmail;
  String? _Name;
  DateTime? _lastBackPressed;
  List<Map<String, dynamic>> _wardConcerns = [];
  final ScrollController _dashboardScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadTokenAndFetchApplications();
  }

  Future<void> _loadTokenAndFetchApplications() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _token = prefs.getString('token');
      _userEmail = prefs.getString('email');
      _Name = prefs.getString('name') ?? 'Parent';
    });
    await _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      if (_token == null || _token!.isEmpty) {
        throw Exception('No authentication token found.');
      }
      
      List<LeaveRequest> fetchedLeaves = [];
      List<Map<String, dynamic>> fetchedConcerns = [];

      try {
        fetchedLeaves = await ParentService.fetchApplications(token: _token!);
      } catch (e) {
        dev.log('Error fetching applications: $e');
      }

      try {
        fetchedConcerns = await ParentService.fetchWardConcerns(token: _token!);
      } catch (e) {
        dev.log('Error fetching concerns: $e');
      }

      setState(() {
        _leaveRequests = fetchedLeaves;
        _wardConcerns = fetchedConcerns;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressed == null ||
            now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          _lastBackPressed = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Press back again to exit')),
          );
          return;
        }
        await SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildTabContent(),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedTab,
          onTap: (idx) => setState(() => _selectedTab = idx),
          selectedItemColor: Colors.green.shade700,
          unselectedItemColor: Colors.grey.shade600,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_outlined),
              activeIcon: Icon(Icons.list_alt),
              label: 'Applications',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.report_problem_outlined),
              activeIcon: Icon(Icons.report_problem),
              label: 'Concerns',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade400, Colors.green.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Row(
            children: [
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Parent Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const NotificationsScreen()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.account_circle_outlined,
                    color: Colors.white),
                onPressed: () {
                  Navigator.pushNamed(context, '/parent-profile');
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () async {
                  final shouldLogout = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirm Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );
                  if (shouldLogout == true) {
                    final prefs = await SharedPreferences.getInstance();
                    final fcmToken = prefs.getString('fcm_token');
                    if (fcmToken != null && fcmToken.isNotEmpty) {
                      try {
                        await AuthService().deleteFcmToken(fcmToken: fcmToken);
                      } catch (_) {}
                    }
                    await prefs.clear();
                    try {
                      await GoogleSignIn().signOut();
                    } catch (_) {}
                    if (!mounted) return;
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/role-selection',
                      (route) => false,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _buildAllApplicationsTab();
      case 2:
        return _buildAllConcernsTab();
      default:
        return Container();
    }
  }

  Widget _buildDashboardTab() {
    final recentRequests = _leaveRequests.take(2).toList();
    final recentConcerns = _wardConcerns.take(2).toList();
    final pendingCount =
        _leaveRequests.where((r) => r.parentStatus.status == 'pending').length;
    final approvedCount =
        _leaveRequests.where((r) => r.parentStatus.status == 'approved').length;

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        controller: _dashboardScrollController,
        children: [
          // Welcome Header
          Container(
            padding: const EdgeInsets.all(22.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  Colors.teal.shade800.withOpacity(0.95),
                  Colors.green.shade700.withOpacity(0.95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.shade900.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _Name ?? "Parent",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.family_restroom_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.white.withOpacity(0.15), height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.email_outlined,
                      color: Colors.white.withOpacity(0.7),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _userEmail ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Stat Cards
          Row(
            children: [
              Expanded(
                  child: _buildStatCard(
                      'Pending Actions',
                      pendingCount.toString(),
                      Icons.pending_actions,
                      Colors.orange)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildStatCard(
                      'Approved Leaves',
                      approvedCount.toString(),
                      Icons.check_circle,
                      Colors.blue)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildStatCard(
                      'Total Concerns',
                      _wardConcerns.length.toString(),
                      Icons.report,
                      Colors.red)),
            ],
          ),
          const SizedBox(height: 24),

          // Recent Applications section
          _buildSectionHeader(
              'Recent Applications', () => setState(() => _selectedTab = 1)),
          if (recentRequests.isEmpty)
            _buildEmptyState('No recent leave applications.')
          else
            ...recentRequests.map(_buildLeaveRequestCard).toList(),

          const SizedBox(height: 24),

          // Ward Concerns section
          _buildSectionHeader(
              'Recent Ward Concerns', () => setState(() => _selectedTab = 2)),
          if (recentConcerns.isEmpty)
            _buildEmptyState('No recent concerns reported.')
          else
            ...recentConcerns.map(_buildConcernCard).toList(),
        ],
      ),
    );
  }

  Widget _buildAllApplicationsTab() {
    List<LeaveRequest> filteredRequests = _leaveRequests;
    if (_filterOption != 'All') {
      filteredRequests = _leaveRequests
          .where((r) => r.parentStatus.status == _filterOption.toLowerCase())
          .toList();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'All Applications',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                DropdownButton<String>(
                  value: _filterOption,
                  icon: const Icon(Icons.filter_list),
                  underline: Container(),
                  onChanged: (String? newValue) {
                    setState(() => _filterOption = newValue!);
                  },
                  items: <String>['All', 'Pending', 'Approved', 'Rejected']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchData,
              child: filteredRequests.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [_buildEmptyState('No $_filterOption applications found.')],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filteredRequests.length,
                      itemBuilder: (context, index) =>
                          _buildLeaveRequestCard(filteredRequests[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllConcernsTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Text(
              'All Concerns',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchData,
              child: _wardConcerns.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [_buildEmptyState('No concerns reported yet.')],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _wardConcerns.length,
                      itemBuilder: (context, index) =>
                          _buildConcernCard(_wardConcerns[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveRequestCard(LeaveRequest request) {
    Color statusColor;
    String statusText;
    bool showActionButtons = request.parentStatus.status == 'pending';

    switch (request.parentStatus.status) {
      case 'pending':
        statusColor = Colors.orange.shade600;
        statusText = 'Pending Your Approval';
        break;
      case 'approved':
        statusColor = Colors.teal.shade600;
        statusText = 'Approved by You';
        break;
      case 'rejected':
        statusColor = Colors.red.shade600;
        statusText = 'Rejected by You';
        break;
      default:
        statusColor = Colors.grey.shade600;
        statusText = 'Status: ${request.parentStatus.status}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: statusColor, width: 6),
            ),
          ),
          child: InkWell(
            onTap: () async {
              if (_token == null || (request.id).isEmpty) return;
              try {
                if (!mounted) return;
                dev.log(
                    '[ParentDashboard] Fetching leave details for id: ${request.id}');
                dev.log('[ParentDashboard] Using token: $_token');
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) =>
                      const Center(child: CircularProgressIndicator()),
                );
                final leaveService = LeaveService();
                final rawJson = await leaveService.fetchLeaveById(
                  token: _token!,
                  leaveId: request.id,
                );
                dev.log(
                    '[ParentDashboard] API response for leave details: $rawJson');
                if (!mounted) return;
                Navigator.pop(context); // Remove loading dialog
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LeaveDetailsScreen(
                      rawJson: (rawJson.containsKey('leave'))
                          ? rawJson['leave'] as Map<String, dynamic>
                          : null,
                    ),
                  ),
                );
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context); // Remove loading dialog if present
                  dev.log('[ParentDashboard] Error fetching leave details: $e');
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Could Not Load Details'),
                      content: Text(friendlyError(e)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          request.reason,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withOpacity(0.2), width: 1),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Batch: ${request.studentBatch}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildInfoRow(
                          Icons.person_outline_rounded,
                          'Student: ${request.studentName}',
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoRow(
                          Icons.calendar_today_rounded,
                          '${_formatDate(request.startDate)} - ${_formatDate(request.endDate)}',
                        ),
                      ),
                      Expanded(
                        child: _buildInfoRow(
                          Icons.timer_outlined,
                          '${request.endDate.difference(request.startDate).inDays + 1} day(s)',
                        ),
                      ),
                    ],
                  ),
                  if (showActionButtons)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.teal.shade600, Colors.teal.shade500],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () => _showApprovalDialog(request, true),
                                icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                                label: const Text(
                                  'Approve',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () => _showApprovalDialog(request, false),
                                icon: Icon(Icons.close_rounded, size: 16, color: Colors.red.shade700),
                                label: Text(
                                  'Reject',
                                  style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConcernCard(Map<String, dynamic> concern) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.warning_amber_rounded, color: Colors.red.shade600, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    concern['description'] ?? 'No description provided',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Batch: ${concern['batch']}',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoRow(
                    Icons.person_outline_rounded,
                    'Student: ${concern['studentName']}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.calendar_today_rounded,
              'Created At: ${_formatDate(DateTime.parse(concern['createdAt']))}',
            ),
          ],
        ),
      ),
    );
  }

  // Helper Widgets for UI
  Widget _buildStatCard(
      String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            count,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onViewAll) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          TextButton(
            onPressed: onViewAll,
            child: const Text('View All'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 50, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text, style: TextStyle(color: Colors.grey.shade700))),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showApprovalDialog(LeaveRequest request, bool isApproval) {
    final TextEditingController commentController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isApproval ? Icons.check_circle_outline : Icons.cancel_outlined,
              color: isApproval ? Colors.teal : Colors.red,
            ),
            const SizedBox(width: 10),
            Text(
              isApproval ? 'Approve Leave' : 'Reject Leave',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to ${isApproval ? 'approve' : 'reject'} the request for ${request.studentName}?',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              decoration: InputDecoration(
                labelText: isApproval ? 'Comment (Optional)' : 'Reason for rejection (Required)',
                labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isApproval ? Colors.teal : Colors.red, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              maxLines: 2,
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: () {
              if (!isApproval && commentController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason for rejection.')),
                );
                return;
              }
              _handleApproval(request, isApproval, commentController.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isApproval ? Colors.teal : Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isApproval ? 'Approve' : 'Reject', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleApproval(
      LeaveRequest request, bool isApproval, String comment) async {
    if (_token == null) return;
    try {
      await ParentService.sendParentDecision(
        parentToken: request.parentToken ?? '',
        decision: isApproval ? 'approved' : 'rejected',
        token: _token!,
      );
      await _fetchData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isApproval
              ? 'Leave request approved successfully!'
              : 'Leave request rejected.'),
          backgroundColor: isApproval ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Failed to ${isApproval ? 'approve' : 'reject'} leave request.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
