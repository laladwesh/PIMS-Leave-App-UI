import 'package:flutter/material.dart';
import '../../services/warden_service.dart';
import 'dart:developer' as dev;

class StudentHistoryTab extends StatefulWidget {
  final WardenService wardenService;
  
  const StudentHistoryTab({super.key, required this.wardenService});

  @override
  State<StudentHistoryTab> createState() => _StudentHistoryTabState();
}

class _StudentHistoryTabState extends State<StudentHistoryTab> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allStudents = [];
  List<String> _batches = [];
  List<Map<String, dynamic>> _studentsInBatch = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  
  String? _selectedBatch;
  Map<String, dynamic>? _selectedStudent;
  
  List<Map<String, dynamic>> _history = [];
  bool _isLoadingStudents = false;
  bool _isLoadingHistory = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAllStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllStudents() async {
    setState(() {
      _isLoadingStudents = true;
      _error = null;
    });

    try {
      final students = await widget.wardenService.getAllStudents();
      final batches = students
          .map((s) => s['batch']?.toString() ?? '')
          .where((b) => b.isNotEmpty)
          .toSet()
          .toList();
      batches.sort();
      
      setState(() {
        _allStudents = students;
        _batches = batches;
      });
    } catch (e) {
      dev.log('[StudentHistoryTab] Error loading students: $e');
      setState(() {
        _error = 'Failed to load students.';
      });
    } finally {
      if (mounted) setState(() => _isLoadingStudents = false);
    }
  }
  
  void _onBatchSelected(String? batch) {
    if (batch == null || batch == _selectedBatch) return;
    
    setState(() {
      _selectedBatch = batch;
      _studentsInBatch = _allStudents.where((s) =>
        (s['batch']?.toString().trim().toLowerCase() ?? '') ==
        (batch.trim().toLowerCase())
      ).toList();
      _filteredStudents = _studentsInBatch;
      _selectedStudent = null;
      _history = [];
      _searchController.clear();
    });
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filteredStudents = _studentsInBatch.where((s) {
        final name = (s['name'] ?? '').toString().toLowerCase();
        return q.isEmpty || name.contains(q);
      }).toList();
      // If user starts typing, clear selected student to show list again
      _selectedStudent = null;
    });
  }

  Future<void> _loadStudentHistory(Map<String, dynamic> student) async {
    // Hide keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _selectedStudent = student;
      _isLoadingHistory = true;
      _history = [];
      _error = null;
    });

    try {
      final history = await widget.wardenService.getStudentHistory(student['_id']);
      setState(() {
        _history = history;
      });
    } catch (e) {
      dev.log('[StudentHistoryTab] Error loading history: $e');
      setState(() {
        _error = 'Failed to load history for ${student['name']}.';
      });
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  String _formatDate(String isoString) {
    try {
      final d = DateTime.parse(isoString);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Search & Selection Header ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lookup Student History',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              if (_isLoadingStudents)
                const Center(child: LinearProgressIndicator())
              else if (_batches.isEmpty)
                const Text('No batches found.')
              else
                Row(
                  children: [
                    // Batch Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.deepOrange.shade200),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          hint: const Text('Batch', style: TextStyle(color: Colors.deepOrange)),
                          value: _selectedBatch,
                          icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.deepOrange.shade700),
                          style: TextStyle(
                            color: Colors.deepOrange.shade800,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          items: _batches
                              .map((b) => DropdownMenuItem(value: b, child: Text('Batch $b')))
                              .toList(),
                          onChanged: _onBatchSelected,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Search Text Field
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Search Student...',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                            icon: Icon(Icons.search_rounded, color: Colors.grey.shade500),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),

        // ── Content Area ──────────────────────────────────────────────────────
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
    }

    if (_selectedBatch == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Select a batch to view students',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
          ],
        ),
      );
    }

    // List of students view
    if (_selectedStudent == null) {
      if (_filteredStudents.isEmpty) {
        return Center(
          child: Text('No students found.', style: TextStyle(color: Colors.grey.shade500)),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredStudents.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final student = _filteredStudents[index];
          return ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: Colors.deepOrange.shade100,
              child: Text(
                (student['name'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange.shade800),
              ),
            ),
            title: Text(student['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            onTap: () => _loadStudentHistory(student),
          );
        },
      );
    }

    // Timeline View
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _selectedStudent = null),
                tooltip: 'Back to student list',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_selectedStudent!['name']}\'s History',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _history.isEmpty
              ? Center(
                  child: Text('This student has no leave history.',
                      style: TextStyle(color: Colors.grey.shade600)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    final bool isLast = index == _history.length - 1;
                    
                    final wardenStatusMap = item['wardenStatus'] as Map<String, dynamic>? ?? {};
                    final status = wardenStatusMap['status'] ?? 'unknown';
                    final reason = item['reason'] ?? 'No reason provided';
                    final startDate = item['startDate'] != null ? _formatDate(item['startDate']) : 'N/A';
                    final endDate = item['endDate'] != null ? _formatDate(item['endDate']) : 'N/A';

                    Color statusColor = Colors.grey;
                    IconData statusIcon = Icons.help_outline;
                    
                    if (status == 'approved') {
                      statusColor = Colors.green;
                      statusIcon = Icons.check_circle_rounded;
                    } else if (status == 'rejected') {
                      statusColor = Colors.red;
                      statusIcon = Icons.cancel_rounded;
                    } else if (status == 'pending') {
                      statusColor = Colors.orange;
                      statusIcon = Icons.pending_rounded;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade100,
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  reason,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                      color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 6),
                              Text(
                                '$startDate  —  $endDate',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          if (status == 'rejected' && wardenStatusMap['reason'] != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade100),
                              ),
                              child: Text(
                                'Warden Note: ${wardenStatusMap['reason']}',
                                style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                              ),
                            ),
                          ]
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
