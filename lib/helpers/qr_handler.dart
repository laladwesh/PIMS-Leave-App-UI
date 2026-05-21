import 'package:flutter/material.dart';
import 'dart:developer' as dev;
import '../services/guard_service.dart';
import 'error_handler.dart';

class QrHandler {
  final String jwtToken;
  final BuildContext context;
  final void Function(String message) onMessage;

  const QrHandler({
    required this.jwtToken,
    required this.context,
    required this.onMessage,
  });

  // ── Entry point ──────────────────────────────────────────────────────────

  Future<void> handleQrCode(String qrData, String tab) async {
    if (tab == 'departure') {
      await _handleDeparture(qrData);
    } else if (tab == 'return') {
      await _handleReturn(qrData);
    }
  }

  // ── Departure flow ───────────────────────────────────────────────────────

  Future<void> _handleDeparture(String qrData) async {
    try {
      final data = qrData.split('|');
      final leaveId = _extractObjectId(data);
      if (leaveId == null) { onMessage('Invalid QR: Leave ID not found.'); return; }

      final batch = data.length > 3 ? data[3] : 'N/A';
      dev.log('Departure – Leave ID: $leaveId');

      final decision = await _showLeaveDetailsDialog(
        name: data.isNotEmpty ? data[0] : '—',
        reason: data.length > 1 ? data[1] : '—',
        leaveId: leaveId,
        batch: batch,
      );
      if (decision == null) return;

      String? rejectionReason;
      if (decision == 'rejected') {
        rejectionReason = await _showRejectionReasonDialog();
        if (rejectionReason == null || rejectionReason.trim().isEmpty) return;
      }

      final response = await GuardService.decideOnDeparture(
        jwtToken: jwtToken, id: leaveId, decision: decision, rejectionReason: rejectionReason,
      );
      dev.log('decideOnDeparture: $response');
      onMessage('Leave $decision successfully');
    } catch (e) {
      dev.log('Error in _handleDeparture: $e');
      onMessage(friendlyError(e));
    }
  }

  // ── Return flow ──────────────────────────────────────────────────────────

  Future<void> _handleReturn(String qrData) async {
    try {
      final data = qrData.split('|');
      final snapshot = await GuardService.getDepartedAwaitingReturn(jwtToken);
      final leaves = snapshot['leaves'] as List<dynamic>? ?? [];

      dynamic matchingLeave;
      String? foundLeaveId;
      for (var part in data) {
        matchingLeave = leaves.firstWhere(
          (l) => l['_id'].toString() == part.trim(), orElse: () => null,
        );
        if (matchingLeave != null) { foundLeaveId = part.trim(); break; }
      }

      if (matchingLeave == null || foundLeaveId == null) {
        onMessage('No matching leave found for return.'); return;
      }

      final confirm = await _showReturnConfirmDialog(
        studentName: matchingLeave['student']['name'] ?? '—',
      );
      if (confirm != true) return;

      final response = await GuardService.markStudentReturn(jwtToken: jwtToken, id: foundLeaveId);
      dev.log('markStudentReturn: $response');
      onMessage('Student marked as returned successfully');
    } catch (e) {
      dev.log('Error in _handleReturn: $e');
      onMessage(friendlyError(e));
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String? _extractObjectId(List<String> parts) {
    final re = RegExp(r'^[a-fA-F0-9]{24}$');
    for (final p in parts) {
      if (re.hasMatch(p.trim())) return p.trim();
    }
    return null;
  }

  // ── Shared dialog shell ──────────────────────────────────────────────────

  Future<T?> _qrDialog<T>({
    required IconData icon,
    required String title,
    required List<Color> gradientColors,
    required Widget body,
    required List<Widget> actions,
  }) {
    return showDialog<T>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gradient header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors,
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white24,
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(title, style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ]),
              ),
              // Content
              Padding(padding: const EdgeInsets.fromLTRB(18, 16, 18, 8), child: body),
              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
                child: Row(
                  children: [
                    for (int i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: actions[i]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Dialog implementations ───────────────────────────────────────────────

  Future<String?> _showLeaveDetailsDialog({
    required String name, required String reason,
    required String leaveId, required String batch,
  }) {
    return _qrDialog<String>(
      icon: Icons.badge_outlined,
      title: 'Leave Details',
      gradientColors: const [Color(0xFF6C63FF), Color(0xFF48CAE4)],
      body: Column(children: [
        _row(Icons.person_outline, 'Student', name),
        _row(Icons.notes_outlined, 'Reason', reason),
        _row(Icons.tag_outlined, 'Leave ID', '${leaveId.substring(0, 8)}…'),
        _row(Icons.school_outlined, 'Batch', batch),
      ]),
      actions: [
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context, 'rejected'),
          icon: const Icon(Icons.close, size: 16, color: Color(0xFFFF6B6B)),
          label: const Text('Reject', style: TextStyle(color: Color(0xFFFF6B6B))),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 13),
            side: const BorderSide(color: Color(0xFFFF6B6B)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, 'approved'),
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Approve'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 13),
            backgroundColor: const Color(0xFF6C63FF),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Future<bool?> _showReturnConfirmDialog({required String studentName}) {
    return _qrDialog<bool>(
      icon: Icons.login_rounded,
      title: 'Confirm Return',
      gradientColors: const [Color(0xFF11998E), Color(0xFF38EF7D)],
      body: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: const TextStyle(color: Color(0xFFB0B3C6), fontSize: 14, height: 1.5),
          children: [
            const TextSpan(text: 'Mark hostel return for\n'),
            TextSpan(text: studentName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const TextSpan(text: '?'),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 13),
            side: BorderSide(color: Colors.white.withOpacity(0.2)),
            foregroundColor: const Color(0xFFB0B3C6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.check_circle_outline, size: 16),
          label: const Text('Confirm'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 13),
            backgroundColor: const Color(0xFF11998E),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Future<String?> _showRejectionReasonDialog() {
    final controller = TextEditingController();
    return _qrDialog<String>(
      icon: Icons.report_outlined,
      title: 'Reason for Rejection',
      gradientColors: const [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
      body: TextField(
        controller: controller,
        maxLines: 3,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Enter rejection reason…',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.06),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.12))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.12))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.5)),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context, null),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 13),
            side: BorderSide(color: Colors.white.withOpacity(0.2)),
            foregroundColor: const Color(0xFFB0B3C6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          icon: const Icon(Icons.send_rounded, size: 16),
          label: const Text('Submit'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 13),
            backgroundColor: const Color(0xFFFF6B6B),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  // ── UI micro-helpers ─────────────────────────────────────────────────────

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [
      Icon(icon, size: 16, color: const Color(0xFF6C63FF)),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(color: Color(0xFF8B8FA8), fontSize: 13)),
      const Spacer(),
      Text(value, style: const TextStyle(
          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
    ]),
  );
}
