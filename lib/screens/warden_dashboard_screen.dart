// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/data_models.dart';
import '../services/warden_service.dart';
import '../config/app_config.dart';
import 'leave_details_screen.dart';

// Extracted widgets — each in its own focused file
import '../widgets/warden/warden_filter_bar.dart';
import '../widgets/warden/warden_leave_card.dart';
import '../widgets/warden/batch_stats_panel.dart'; // Restored
import '../widgets/warden/student_history_sheet.dart';
import '../widgets/warden/leave_timeline_sheet.dart'; // [NEW]
import '../widgets/warden/student_history_tab.dart'; // [NEW]
import '../widgets/common/premium_date_picker.dart';

import 'dart:developer' as dev;

class WardenDashboardScreen extends StatefulWidget {
  const WardenDashboardScreen({super.key});

  @override
  State<WardenDashboardScreen> createState() => _WardenDashboardScreenState();
}

class _WardenDashboardScreenState extends State<WardenDashboardScreen> {
  // ── Service ──────────────────────────────────────────────────────────────
  late final WardenService _wardenService;

  // ── Data ─────────────────────────────────────────────────────────────────
  List<LeaveRequest> _leaveRequests = [];
  bool _isLoading = false;
  String? _error;
  List<String> _batches = [];
  Map<String, dynamic>? _dashboardStats;

  // ── UI state ─────────────────────────────────────────────────────────────
  int _selectedTab = 0;

  // ── Filter state (wired to WardenFilterBar on Tab 1) ──────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _batchFilter = 'All';
  String _statusFilter = 'All'; 
  DateTimeRange? _selectedDateRange;

  // Debounce timer — avoids an API call per keystroke
  Timer? _searchDebounce;

  // ── Warden profile ────────────────────────────────────────────────────────
  String _wardenName = '';
  String _wardenEmail = '';

  // ────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _wardenService = WardenService(baseUrl: AppConfig.kBaseUrl);
    _loadWardenInfo();
    _loadBatches();
    _loadLeaveRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────────────
  // Data loading
  // ────────────────────────────────────────────────────────────────────────

  Future<void> _loadWardenInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _wardenName = prefs.getString('name') ?? 'Warden';
      _wardenEmail = prefs.getString('email') ?? '';
    });
  }

  Future<void> _loadBatches() async {
    try {
      final students = await _wardenService.getAllStudents();
      final batches = students
          .map((s) => s['batch']?.toString() ?? '')
          .where((b) => b.isNotEmpty)
          .toSet()
          .toList();
      batches.sort();
      setState(() {
        _batches = batches;
      });
    } catch (e) {
      dev.log('[WardenDashboard] Load batches error: $e');
    }
  }

  Future<void> _loadLeaveRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final leaves = await _wardenService.getPendingApplications(
        batch: _batchFilter != 'All' ? _batchFilter : null,
        status: _statusFilter != 'All' ? _statusFilter : null,
        startDate: _selectedDateRange?.start,
        endDate: _selectedDateRange?.end,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      
      // Also load stats based on the same date/batch filter
      final stats = await _wardenService.getStats(
        batch: _batchFilter != 'All' ? _batchFilter : null,
        startDate: _selectedDateRange?.start,
        endDate: _selectedDateRange?.end,
      );

      setState(() {
        _leaveRequests = leaves.map((l) => LeaveRequest.fromJson(l)).toList();
        _dashboardStats = stats;
      });
    } catch (e) {
      dev.log('[WardenDashboard] Load error: $e');
      setState(() => _error = 'Failed to load data.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // Filter helpers
  // ────────────────────────────────────────────────────────────────────────

  void _onSearchChanged(String val) {
    setState(() => _searchQuery = val);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 600),
      _loadLeaveRequests,
    );
  }

  void _onBatchChanged(String? val) {
    if (val == null || val == _batchFilter) return;
    setState(() => _batchFilter = val);
    _loadLeaveRequests();
  }
  
  void _onStatusChanged(String? val) {
    if (val == null || val == _statusFilter) return;
    setState(() => _statusFilter = val);
    _loadLeaveRequests();
  }

  Future<void> _onSelectDateRange() async {
    final picked = await PremiumDatePicker.show(
      context, 
      initialRange: _selectedDateRange,
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() => _selectedDateRange = picked);
      _loadLeaveRequests();
    }
  }

  void _clearFilters() {
    _searchController.clear();
    _searchDebounce?.cancel();
    setState(() {
      _searchQuery = '';
      _batchFilter = 'All';
      _statusFilter = 'All';
      _selectedDateRange = null;
    });
    _loadLeaveRequests();
  }

  // ────────────────────────────────────────────────────────────────────────
  // Build
  // ────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildHeader(),
          // Filter bar only on Applications tab
          if (_selectedTab == 1)
            WardenFilterBar(
              searchController: _searchController,
              searchQuery: _searchQuery,
              batchFilter: _batchFilter,
              statusFilter: _statusFilter,
              batches: _batches,
              selectedDateRange: _selectedDateRange,
              onSearchChanged: _onSearchChanged,
              onBatchChanged: _onBatchChanged,
              onStatusChanged: _onStatusChanged,
              onSelectDateRange: _onSelectDateRange,
              onClearFilters: _clearFilters,
            ),
          Expanded(
            child: _isLoading && _selectedTab != 2 // Tab 2 handles its own loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _selectedTab != 2
                    ? _buildErrorState()
                    : _buildTabContent(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // Tab content routing
  // ────────────────────────────────────────────────────────────────────────

  Widget _buildTabContent() {
    return switch (_selectedTab) {
      0 => _buildDashboardTab(),
      1 => _buildApplicationsTab(),
      2 => StudentHistoryTab(wardenService: _wardenService),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildDashboardTab() {
    // Top 5 recent applications to show on Dashboard
    final recentApplications = _leaveRequests.take(5).toList();

    return RefreshIndicator(
      onRefresh: _loadLeaveRequests,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Welcome card
          _WelcomeCard(name: _wardenName, email: _wardenEmail),
          const SizedBox(height: 24),

          // Batch statistics panel (Removed KPI StatCards)
          BatchStatsPanel(
            statsData: _dashboardStats,
            batchFilter: _batchFilter,
            selectedDateRange: _selectedDateRange,
          ),
          
          // Recent Applications
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Applications',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              if (_leaveRequests.length > 5)
                TextButton(
                  onPressed: () => setState(() => _selectedTab = 1),
                  child: Text('View All', style: TextStyle(color: Colors.deepOrange.shade600)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (recentApplications.isEmpty)
            _buildEmptyState('No recent applications.')
          else
            ...recentApplications.map(_buildLeaveCard).toList(),
        ],
      ),
    );
  }

  Widget _buildApplicationsTab() {
    return RefreshIndicator(
      onRefresh: _loadLeaveRequests,
      child: _leaveRequests.isEmpty
          ? _buildEmptyState('No applications found matching filters.')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _leaveRequests.length,
              itemBuilder: (_, i) => _buildLeaveCard(_leaveRequests[i]),
            ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // Card factory
  // ────────────────────────────────────────────────────────────────────────

  Widget _buildLeaveCard(LeaveRequest request) {
    return WardenLeaveCard(
      request: request,
      formatDate: _formatDate,
      onTap: () => _navigateToDetails(request),
      onApprove: () => _showApprovalDialog(request, true),
      onReject: () => _showApprovalDialog(request, false),
      onViewHistory: () => LeaveTimelineSheet.show(context, request),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // Shared UI helpers
  // ────────────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    String title = 'Dashboard Overview';
    if (_selectedTab == 1) title = 'Applications';
    if (_selectedTab == 2) title = 'Student History';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Row(
            children: [
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.admin_panel_settings_rounded, color: Colors.deepOrange.shade600),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.logout_rounded, color: Colors.grey.shade600),
                onPressed: _handleLogout,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, -5))
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (idx) => setState(() => _selectedTab = idx),
        selectedItemColor: Colors.deepOrange.shade600,
        unselectedItemColor: Colors.grey.shade400,
        backgroundColor: Colors.white,
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        items: const [
          BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.space_dashboard_rounded),
              ),
              label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.folder_shared_rounded),
              ),
              label: 'Apps'),
          BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.history_rounded),
              ),
              label: 'History'),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Text(_error!,
              style: const TextStyle(color: Colors.red, fontSize: 14)),
          const SizedBox(height: 16),
          ElevatedButton(
              onPressed: _loadLeaveRequests,
              child: const Text('Retry')),
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
          Icon(Icons.inbox_rounded, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(message,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  // ────────────────────────────────────────────────────────────────────────
  // Actions
  // ────────────────────────────────────────────────────────────────────────

  Future<void> _navigateToDetails(LeaveRequest request) async {
    try {
      setState(() => _isLoading = true);
      final details =
          await _wardenService.getApplicationDetails(request.id);
      if (!mounted) return;
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => LeaveDetailsScreen(rawJson: details)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load application details.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showApprovalDialog(LeaveRequest request, bool isApproval) {
    final commentController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isApproval ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
              color: isApproval ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(isApproval ? 'Approve Leave' : 'Reject Leave'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Are you sure you want to '
              '${isApproval ? 'approve' : 'reject'} the request for '
              '${request.studentName}?',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              decoration: InputDecoration(
                labelText: isApproval
                    ? 'Comment (Optional)'
                    : 'Reason for rejection *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (!isApproval &&
                  commentController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Rejection reason is required.'),
                      backgroundColor: Colors.red),
                );
                return;
              }
              _handleApproval(
                  request, isApproval, commentController.text.trim());
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isApproval ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isApproval ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleApproval(
      LeaveRequest request, bool isApproval, String comment) async {
    try {
      setState(() => _isLoading = true);
      await _wardenService.decideApplication(
        id: request.id,
        decision: isApproval ? 'approved' : 'rejected',
        rejectionReason: isApproval ? null : comment,
      );
      await _loadLeaveRequests();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isApproval
              ? 'Leave request approved!'
              : 'Leave request rejected.'),
          backgroundColor: isApproval ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to update leave request.'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout', style: TextStyle(color: Colors.red))),
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
          context, '/role-selection', (route) => false);
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Private inline widgets
// ────────────────────────────────────────────────────────────────────────────

class _WelcomeCard extends StatelessWidget {
  final String name;
  final String email;
  const _WelcomeCard({required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [Colors.deepOrange.shade600, Colors.orange.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.deepOrange.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('Welcome back,\n$name',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        color: Colors.white)),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_rounded, color: Colors.white, size: 28),
              )
            ],
          ),
          const SizedBox(height: 12),
          Text(email,
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
