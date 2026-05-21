import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/data_models.dart';

class LeaveTimelineSheet extends StatelessWidget {
  final LeaveRequest request;

  const LeaveTimelineSheet({super.key, required this.request});

  static void show(BuildContext context, LeaveRequest request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LeaveTimelineSheet(request: request),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('d MMM yyyy, HH:mm').format(dt);
  }

  Widget _buildTimelineStop(
    BuildContext context, {
    required String title,
    required IconData icon,
    required LeaveStatusDetail statusObj,
    required bool isFirst,
    required bool isLast,
  }) {
    final status = statusObj.status;
    final decided = status != 'pending' && status.isNotEmpty;

    Color color;
    if (!decided) {
      color = Colors.grey.shade400;
    } else if (status == 'approved') {
      color = Colors.green;
    } else if (status == 'rejected' || status == 'stopped') {
      color = Colors.red;
    } else {
      color = Colors.orange;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Spine
          SizedBox(
            width: 40,
            child: Column(
              children: [
                if (!isFirst)
                  Container(width: 2, height: 20, color: Colors.grey.shade300),
                CircleAvatar(
                  backgroundColor: decided ? color : Colors.grey.shade200,
                  radius: 16,
                  child: Icon(icon,
                      color: decided ? Colors.white : Colors.grey.shade500,
                      size: 18),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey.shade300,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  )
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
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
                          title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          (status.isEmpty ? 'pending' : status).toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (decided &&
                      statusObj.reason != null &&
                      statusObj.reason!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Reason: ${statusObj.reason}',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                  if (decided && statusObj.decidedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(statusObj.decidedAt),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Approval Timeline',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildTimelineStop(
              context,
              title: 'Parent Approval',
              icon: Icons.family_restroom,
              statusObj: request.parentStatus,
              isFirst: true,
              isLast: false,
            ),
            _buildTimelineStop(
              context,
              title: 'Warden Approval',
              icon: Icons.admin_panel_settings,
              statusObj: request.wardenStatus,
              isFirst: false,
              isLast: false,
            ),
            _buildTimelineStop(
              context,
              title: 'Guard Check-out',
              icon: Icons.security,
              statusObj: request.guardStatus,
              isFirst: false,
              isLast: false,
            ),
            _buildTimelineStop(
              context,
              title: 'Admin Verification',
              icon: Icons.verified_user,
              statusObj: request.adminStatus,
              isFirst: false,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}
