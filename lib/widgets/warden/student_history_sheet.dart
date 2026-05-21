import 'package:flutter/material.dart';
import 'dart:developer' as dev;
import '../../models/data_models.dart';
import '../../services/warden_service.dart';

/// A self-loading bottom sheet that fetches a student's leave history from the
/// API and falls back to the locally-loaded list if the network call fails.
///
/// Usage:
/// ```dart
/// StudentHistorySheet.show(context,
///   studentId: request.studentId,
///   studentName: request.studentName,
///   wardenService: _wardenService,
///   localFallback: _leaveRequests,
/// );
/// ```
class StudentHistorySheet extends StatefulWidget {
  final String studentId;
  final String studentName;
  final WardenService wardenService;
  final List<LeaveRequest> localFallback;

  const StudentHistorySheet({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.wardenService,
    required this.localFallback,
  });

  /// Convenience method to push the sheet from any [BuildContext].
  static void show(
    BuildContext context, {
    required String studentId,
    required String studentName,
    required WardenService wardenService,
    required List<LeaveRequest> localFallback,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StudentHistorySheet(
        studentId: studentId,
        studentName: studentName,
        wardenService: wardenService,
        localFallback: localFallback,
      ),
    );
  }

  @override
  State<StudentHistorySheet> createState() => _StudentHistorySheetState();
}

class _StudentHistorySheetState extends State<StudentHistorySheet> {
  List<LeaveRequest> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final raw =
          await widget.wardenService.getStudentHistory(widget.studentId);
      if (!mounted) return;
      setState(() {
        _history = raw.map((e) => LeaveRequest.fromJson(e)).toList();
        _loading = false;
      });
    } catch (e) {
      dev.log('[StudentHistorySheet] API error: $e — using local fallback');
      if (!mounted) return;
      setState(() {
        _history = widget.localFallback
            .where((r) => r.studentId == widget.studentId)
            .toList();
        _loading = false;
      });
    }
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.70,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // ── Drag handle ──────────────────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),
          // ── Header ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Student Leave History',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.studentName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.deepOrange.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          // ── Content ───────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _history.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined,
                                size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'No past leave applications.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        itemCount: _history.length,
                        itemBuilder: (context, index) => _HistoryItem(
                          request: _history[index],
                          isLast: index == _history.length - 1,
                          formatDate: _fmtDate,
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Private history item ───────────────────────────────────────────────────────

class _HistoryItem extends StatelessWidget {
  final LeaveRequest request;
  final bool isLast;
  final String Function(DateTime) formatDate;

  const _HistoryItem({
    required this.request,
    required this.isLast,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (request.wardenStatus.status) {
      case 'approved':
        color = Colors.green;
        icon = Icons.check_circle_outline;
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.error_outline;
        break;
      default:
        color = Colors.orange;
        icon = Icons.help_outline;
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
                  request.reason,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  request.wardenStatus.status.toUpperCase(),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color),
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
                '${formatDate(request.startDate)} — ${formatDate(request.endDate)}',
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          if (request.wardenStatus.reason != null &&
              request.wardenStatus.reason!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Text(
                'Warden Note: ${request.wardenStatus.reason}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.red.shade800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
