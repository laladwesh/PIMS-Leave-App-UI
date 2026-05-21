import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../config/app_config.dart';

class LeaveDetailsScreen extends StatefulWidget {
  final Map<String, dynamic>? rawJson;

  const LeaveDetailsScreen({super.key, required this.rawJson});

  @override
  State<LeaveDetailsScreen> createState() => _LeaveDetailsScreenState();
}

class _LeaveDetailsScreenState extends State<LeaveDetailsScreen> {
  String? previewUrl;
  bool loadingPreview = false;
  String? previewError;

  @override
  void initState() {
    super.initState();
    _fetchDocumentPreview();
  }

  Future<void> _fetchDocumentPreview() async {
    final rawJson = widget.rawJson;
    if (rawJson == null) return;
    final docUrl = rawJson['documentUrl']?.toString() ?? '';
    if (docUrl.isEmpty) return;
    setState(() {
      loadingPreview = true;
      previewError = null;
    });
    try {
      setState(() {
        previewUrl = '${AppConfig.kBaseUrl}/drive/$docUrl';
        loadingPreview = false;
      });
    } catch (e) {
      setState(() {
        previewError = 'Failed to load document preview.';
        loadingPreview = false;
      });
    }
  }

  String _getField(String key) => widget.rawJson?[key]?.toString() ?? '';

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('d MMM yyyy, HH:mm').format(dt);
    } catch (_) {
      return iso;
    }
  }

  Widget _buildTimelineStop(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Map<String, dynamic> statusObj,
    required bool isFirst,
    required bool isLast,
  }) {
    final status = statusObj['status']?.toString() ?? 'pending';
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
                      statusObj['reason'] != null &&
                      statusObj['reason'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Reason: ${statusObj['reason']}',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                  if (decided &&
                      statusObj['decidedAt'] != null &&
                      statusObj['decidedAt'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(statusObj['decidedAt']),
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
    if (widget.rawJson == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Leave Details')),
        body: const Center(child: Text('No details available.')),
      );
    }

    final reason = _getField('reason');
    final startDate = _formatDate(_getField('startDate'));
    final endDate = _formatDate(_getField('endDate'));
    final createdAt = _formatDate(_getField('createdAt'));
    final hasDocument = _getField('documentUrl').isNotEmpty;

    Map<String, dynamic> parentStatus = widget.rawJson!['parentStatus'] ?? {};
    Map<String, dynamic> wardenStatus = widget.rawJson!['wardenStatus'] ?? {};
    Map<String, dynamic> guardStatus = widget.rawJson!['guardStatus'] ?? {};
    Map<String, dynamic> adminStatus = widget.rawJson!['adminStatus'] ?? {};

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: CustomScrollView(
        slivers: [
          // Premium App Bar
          SliverAppBar(
            expandedHeight: 140.0,
            floating: false,
            pinned: true,
            backgroundColor: Colors.deepOrange.shade600,
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16, right: 16),
              title: const Text(
                'Leave Application Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepOrange.shade500, Colors.deepOrange.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -30,
                      top: -30,
                      child: Icon(Icons.assignment_rounded, size: 140, color: Colors.white.withOpacity(0.15)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Body Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Reason Card ─────────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.grey.shade200.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 8))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.deepOrange.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.format_quote_rounded, color: Colors.deepOrange.shade500, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text('Reason for Leave', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          reason,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(height: 1),
                        ),
                        Row(
                          children: [
                            Icon(Icons.history_rounded, size: 16, color: Colors.grey.shade500),
                            const SizedBox(width: 6),
                            Text('Applied on: $createdAt', style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Dates Card ─────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _DateCard(
                          title: 'Departure',
                          date: startDate,
                          icon: Icons.logout_rounded,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _DateCard(
                          title: 'Return',
                          date: endDate,
                          icon: Icons.login_rounded,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),

                  // ── Document Preview ───────────────────────────────────────
                  if (hasDocument) ...[
                    const Text('Attached Document', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.grey.shade200.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 8))
                        ],
                      ),
                      child: Column(
                        children: [
                          if (loadingPreview)
                            const Padding(
                              padding: EdgeInsets.all(32.0),
                              child: CircularProgressIndicator(),
                            )
                          else if (previewError != null)
                            Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Text(previewError!, style: const TextStyle(color: Colors.red)),
                            )
                          else if (previewUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                previewUrl!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 120,
                                  color: Colors.grey.shade100,
                                  child: Center(
                                    child: Icon(Icons.insert_drive_file_rounded, size: 48, color: Colors.grey.shade400),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.open_in_new_rounded, size: 18),
                              label: const Text('Open Full Document', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepOrange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: () async {
                                if (previewUrl != null) {
                                  await launchUrl(Uri.parse(previewUrl!), mode: LaunchMode.externalApplication);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // ── Approval Timeline ───────────────────────────────────────
                  const Text('Approval Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 16),
                  
                  _buildTimelineStop(
                    context,
                    title: 'Parent Approval',
                    icon: Icons.family_restroom,
                    statusObj: parentStatus,
                    isFirst: true,
                    isLast: false,
                  ),
                  _buildTimelineStop(
                    context,
                    title: 'Warden Approval',
                    icon: Icons.admin_panel_settings,
                    statusObj: wardenStatus,
                    isFirst: false,
                    isLast: false,
                  ),
                  _buildTimelineStop(
                    context,
                    title: 'Guard Check-out',
                    icon: Icons.security,
                    statusObj: guardStatus,
                    isFirst: false,
                    isLast: adminStatus['status']?.toString() != 'stopped',
                  ),
                  if (adminStatus['status']?.toString() == 'stopped')
                    _buildTimelineStop(
                      context,
                      title: 'Admin Verification',
                      icon: Icons.verified_user,
                      statusObj: adminStatus,
                      isFirst: false,
                      isLast: true,
                    ),
                    
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  final String title;
  final String date;
  final IconData icon;
  final Color color;

  const _DateCard({
    required this.title,
    required this.date,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade200.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 8))
        ],
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            date,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
