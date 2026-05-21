import 'package:flutter/material.dart';
import '../../models/data_models.dart';

/// A self-contained card widget that renders one warden leave request.
///
/// All interactions are delegated to callbacks, so the card owns zero state.
class WardenLeaveCard extends StatelessWidget {
  final LeaveRequest request;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onViewHistory;
  final String Function(DateTime) formatDate;

  const WardenLeaveCard({
    super.key,
    required this.request,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
    required this.onViewHistory,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final bool showActions = request.parentStatus.status == 'approved' &&
        request.wardenStatus.status == 'pending';

    Color indicatorColor = Colors.orange;
    if (request.wardenStatus.status == 'approved') {
      indicatorColor = Colors.green;
    } else if (request.wardenStatus.status == 'rejected') {
      indicatorColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade100, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            color: Colors.white,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: indicatorColor, width: 6)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
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
                      _StatusBadge(
                          label: request.wardenStatus.status.toUpperCase(),
                          color: indicatorColor),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Student Details row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.deepOrange.shade50,
                            child: Icon(Icons.person_rounded,
                                size: 18, color: Colors.deepOrange.shade600),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                request.studentName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black87),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Batch: ${request.studentBatch}',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600),
                              )
                            ],
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200)
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.history_rounded, size: 20),
                          color: Colors.deepOrange.shade600,
                          tooltip: 'View Leave History',
                          onPressed: onViewHistory,
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1),
                  ),
                  
                  // Dates
                  Row(
                    children: [
                      Icon(Icons.calendar_month_rounded,
                          size: 16, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        '${formatDate(request.startDate)}  —  ${formatDate(request.endDate)}',
                        style: TextStyle(
                            color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  
                  // Parent comment (if any)
                  if (request.parentStatus.reason != null &&
                      request.parentStatus.reason!.isNotEmpty)
                    _ParentComment(comment: request.parentStatus.reason!),
                    
                  // Action buttons
                  if (showActions)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              label: 'Approve',
                              icon: Icons.check_circle_outline_rounded,
                              color: Colors.green,
                              isFilled: true,
                              onPressed: onApprove,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionButton(
                              label: 'Reject',
                              icon: Icons.cancel_outlined,
                              color: Colors.red,
                              isFilled: false,
                              onPressed: onReject,
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
}

// ── Private helper sub-widgets ────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
      ),
    );
  }
}

class _ParentComment extends StatelessWidget {
  final String comment;
  const _ParentComment({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade100)
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote_rounded, size: 16, color: Colors.blueGrey.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              comment,
              style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.blueGrey.shade800,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isFilled;
  final VoidCallback onPressed;
  
  const _ActionButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.isFilled,
      required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return isFilled 
      ? ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        )
      : OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color.withOpacity(0.5), width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
      );
  }
}
