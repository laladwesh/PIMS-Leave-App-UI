import 'package:flutter/material.dart';
import '../models/data_models.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/leave_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'leave_details_screen.dart';
import 'package:flutter/services.dart';
import 'notifications_screen.dart';
import 'dart:developer' as dev;

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  List<LeaveRequest> _leaveRequests = [];
  String? _userEmail;
  String _studentName = ' ';
  String? _token;
  int _selectedTab = 0;
  String _filterStatus = 'All';
  DateTime? _lastBackPressed;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userEmail = prefs.getString('email');
      _studentName = prefs.getString('name') ?? ' ';
      _token = prefs.getString('token');
    });
    await _loadLeaveRequests();
  }

  Future<void> _loadLeaveRequests() async {
    setState(() => _loading = true);
    if (_token == null || _userEmail == null) {
      setState(() {
        _leaveRequests = [];
        _loading = false;
      });
      return;
    }
    try {
      final leaveService = LeaveService();
      final allLeaves = await leaveService.fetchAllLeaves(token: _token!);
      setState(() {
        _leaveRequests = allLeaves;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _leaveRequests = [];
        _loading = false;
      });
      dev.log('[StudentDashboardScreen] Error fetching leaves: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An error occurred. Please try again.')),
        );
      }
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
                  : _selectedTab == 0
                      ? _buildDashboardTab()
                      : _buildApplicationsTab(),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedTab,
          onTap: (idx) {
            setState(() {
              _selectedTab = idx;
            });
          },
          selectedItemColor: Colors.indigo.shade700,
          unselectedItemColor: Colors.grey.shade600,
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
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.indigo.shade600],
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
              Expanded(
                child: Text(
                  _selectedTab == 0 ? 'Student Dashboard' : 'My Applications',
                  style: const TextStyle(
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

  Widget _buildDashboardTab() {
    final recentRequests = _leaveRequests.take(3).toList();

    return RefreshIndicator(
      onRefresh: _loadLeaveRequests,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Welcome Header
          Container(
            padding: const EdgeInsets.all(22.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  Colors.indigo.shade800.withOpacity(0.9),
                  Colors.blue.shade700.withOpacity(0.9),
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
                  color: Colors.indigo.shade900.withOpacity(0.2),
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
                            _studentName.isNotEmpty ? _studentName : 'Student',
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
                        Icons.school_rounded,
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

          // Action Button
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade600, Colors.blue.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.indigo.shade400.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () async {
                  final result =
                      await Navigator.pushNamed(context, '/request-leave');
                  if (result == true) {
                    _loadLeaveRequests();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Request New Leave',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Recent Applications section
          _buildSectionHeader(
              'Recent Applications', () => setState(() => _selectedTab = 1)),
          if (_leaveRequests.isEmpty)
            _buildEmptyState('No leave requests yet.')
          else
            ...recentRequests
                .map((req) => _buildLeaveRequestCard(req))
                .toList(),
        ],
      ),
    );
  }

  Widget _buildApplicationsTab() {
    List<LeaveRequest> filtered = _leaveRequests;
    if (_filterStatus != 'All') {
      filtered = _leaveRequests.where((leave) {
        if (_filterStatus == 'Pending') {
          return (leave.wardenStatus.status == 'pending' ||
                  leave.parentStatus.status == 'pending') &&
              leave.adminStatus.status != 'rejected' &&
              leave.wardenStatus.status != 'rejected' &&
              leave.parentStatus.status != 'rejected';
        }
        if (_filterStatus == 'Approved') {
          return leave.wardenStatus.status == 'approved';
        }
        if (_filterStatus == 'Rejected') {
          return leave.parentStatus.status == 'rejected' ||
              leave.wardenStatus.status == 'rejected' ||
              leave.adminStatus.status == 'rejected' ||
              leave.adminStatus.status == 'stopped';
        }
        return true;
      }).toList();
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
                  value: _filterStatus,
                  icon: const Icon(Icons.filter_list),
                  underline: Container(),
                  onChanged: (val) {
                    setState(() {
                      _filterStatus = val!;
                    });
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
              onRefresh: _loadLeaveRequests,
              child: filtered.isEmpty
                  ? _buildEmptyState('No $_filterStatus applications found.')
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) =>
                          _buildLeaveRequestCard(filtered[index]),
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

    final warden = request.wardenStatus.status;
    final parent = request.parentStatus.status;
    final admin = request.adminStatus.status;

    if (admin == 'stopped' || admin == 'rejected') {
      statusColor = Colors.red;
      statusText = 'Stopped by Admin';
    } else if (warden == 'rejected' || parent == 'rejected') {
      statusColor = Colors.red;
      statusText =
          warden == 'rejected' ? 'Rejected by Warden' : 'Rejected by Parent';
    } else if (warden == 'approved') {
      statusColor = Colors.green;
      statusText = 'Approved';
    } else if (parent == 'approved') {
      statusColor = Colors.blue;
      statusText = 'Pending Warden Approval';
    } else {
      statusColor = Colors.orange;
      statusText = 'Pending Parent Approval';
    }

    final isQRClickable = warden == 'approved' &&
        admin != 'stopped' &&
        request.returnDateTime == null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          if (_token == null || (request.id).isEmpty) return;
          try {
            if (!mounted) return;
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
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Error'),
                  content: const Text('An error occurred. Please try again.'),
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: statusColor, width: 5),
              ),
            ),
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
                            fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
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
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatDate(request.startDate)} - ${_formatDate(request.endDate)}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _buildStatusTimeline(request),
                if (isQRClickable)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Center(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: request.guardStatus.status == 'approved'
                                ? [Colors.indigo.shade600, Colors.indigo.shade400]
                                : [Colors.teal.shade600, Colors.teal.shade400],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () => _showQRCode(request),
                          icon: const Icon(Icons.qr_code_2, color: Colors.white),
                          label: Text(
                            request.guardStatus.status == 'approved'
                                ? 'Show Return QR'
                                : 'Show Departure QR',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper Widgets
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
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline(LeaveRequest leave) {
    // Define the stages of the leave process
    final stages = [
      {'label': 'Parent', 'status': leave.parentStatus.status},
      {'label': 'Warden', 'status': leave.wardenStatus.status},
      {'label': 'Guard', 'status': leave.guardStatus.status},
      {
        'label': 'Return',
        'status': leave.returnDateTime != null ? 'approved' : 'pending'
      },
    ];

    // Determine the current active stage
    int activeStage = 0;
    if (leave.parentStatus.status == 'approved') activeStage = 1;
    if (leave.wardenStatus.status == 'approved') activeStage = 2;
    if (leave.guardStatus.status == 'approved') activeStage = 3;
    if (leave.returnDateTime != null) activeStage = 4;

    // Check for rejection at any stage
    bool isRejected = false;
    if (leave.parentStatus.status == 'rejected' ||
        leave.wardenStatus.status == 'rejected' ||
        leave.adminStatus.status == 'rejected' ||
        leave.adminStatus.status == 'stopped') {
      isRejected = true;
      activeStage = stages.indexWhere(
          (s) => s['status'] == 'rejected' || s['status'] == 'stopped');
      if (activeStage == -1) {
        // If admin rejected
        activeStage = 1;
      }
    }

    List<Widget> timelineWidgets = [];
    for (int i = 0; i < stages.length; i++) {
      final stage = stages[i];
      final status = stage['status'] as String;
      
      Color bubbleBgColor;
      Color iconBorderColor;
      Color textColor;
      IconData iconData;

      final isCurrentStageRejected = (status == 'rejected' || status == 'stopped') || (isRejected && i == activeStage);

      if (isCurrentStageRejected) {
        bubbleBgColor = Colors.red.shade50;
        iconBorderColor = Colors.red.shade600;
        textColor = Colors.red.shade700;
        iconData = Icons.close_rounded;
      } else if (i < activeStage) {
        bubbleBgColor = Colors.green.shade50;
        iconBorderColor = Colors.green.shade600;
        textColor = Colors.green.shade700;
        iconData = Icons.check_rounded;
      } else if (i == activeStage && !isRejected) {
        bubbleBgColor = Colors.indigo.shade50;
        iconBorderColor = Colors.indigo.shade600;
        textColor = Colors.indigo.shade700;
        iconData = Icons.pending_actions_rounded;
      } else {
        bubbleBgColor = Colors.grey.shade50;
        iconBorderColor = Colors.grey.shade300;
        textColor = Colors.grey.shade500;
        iconData = Icons.circle_outlined;
      }

      timelineWidgets.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: bubbleBgColor,
                shape: BoxShape.circle,
                border: Border.all(color: iconBorderColor, width: 1.5),
                boxShadow: i == activeStage && !isRejected
                    ? [
                        BoxShadow(
                          color: Colors.indigo.withOpacity(0.15),
                          blurRadius: 4,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: Icon(
                  iconData,
                  color: iconBorderColor,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              stage['label'] as String,
              style: TextStyle(
                fontSize: 11,
                fontWeight: i <= activeStage ? FontWeight.w600 : FontWeight.normal,
                color: textColor,
              ),
            ),
          ],
        ),
      );

      // Add connector line
      if (i < stages.length - 1) {
        final bool isLineCompleted = i < activeStage && !isRejected;
        timelineWidgets.add(
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18.0), // Align with center of the bubble
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: isLineCompleted ? Colors.green.shade400 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: timelineWidgets,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showQRCode(LeaveRequest approvedLeave) {
    final isReturn = approvedLeave.guardStatus.status == 'approved';
    final qrData = isReturn
        ? '${_studentName}|${approvedLeave.id}'
        : '${_studentName}|${approvedLeave.reason}|${approvedLeave.id}|${approvedLeave.studentBatch}';

    final title = isReturn ? 'Your Return QR Code' : 'Your Departure QR Code';
    final instructions = isReturn
        ? 'Present this code to the guard for scanning upon your return to campus.'
        : 'Present this code to the guard for scanning upon your departure.';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              instructions,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
