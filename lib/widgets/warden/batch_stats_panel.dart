import 'package:flutter/material.dart';
import '../../screens/warden_analytics_screen.dart';

/// Displays a segmented statistics panel for the currently-loaded leave set.
///
/// Computes approved / pending / rejected counts from the provided server [statsData]
/// and renders a proportional horizontal bar plus labelled metric items.
class BatchStatsPanel extends StatelessWidget {
  final Map<String, dynamic>? statsData;
  final String batchFilter;
  final DateTimeRange? selectedDateRange;

  const BatchStatsPanel({
    super.key,
    required this.statsData,
    required this.batchFilter,
    required this.selectedDateRange,
  });

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    // Safely extract stats from the server response
    final stats = statsData?['statistics'] as Map<String, dynamic>?;
    
    final int total = stats?['totalApplications'] ?? 0;
    final int approved = stats?['approvedCount'] ?? 0;
    final int rejected = stats?['rejectedCount'] ?? 0;
    final int pending = stats?['pendingCount'] ?? 0;

    final double approvedRate = (stats?['approvalRate'] ?? 0.0).toDouble();
    final double rejectedRate = (stats?['rejectionRate'] ?? 0.0).toDouble();
    final double pendingRate = (stats?['pendingRate'] ?? 0.0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200.withOpacity(0.5),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.analytics_rounded, size: 18, color: Colors.deepOrange.shade600),
                      const SizedBox(width: 8),
                      Text(
                        batchFilter == 'All'
                            ? 'All Batches Report'
                            : 'Batch $batchFilter Report',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedDateRange == null
                        ? 'All-time statistics'
                        : 'Interval: ${_fmtDate(selectedDateRange!.start)}'
                            ' – ${_fmtDate(selectedDateRange!.end)}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '$total',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange.shade700),
                    ),
                    Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.deepOrange.shade400,
                        fontWeight: FontWeight.w600,
                      )
                    )
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // ── Proportional bar ─────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (approved > 0)
                    Expanded(
                        flex: approved,
                        child: Container(color: Colors.green.shade400)),
                  if (pending > 0)
                    Expanded(
                        flex: pending,
                        child: Container(color: Colors.orange.shade300)),
                  if (rejected > 0)
                    Expanded(
                        flex: rejected,
                        child: Container(color: Colors.red.shade400)),
                  if (total == 0)
                    Expanded(child: Container(color: Colors.grey.shade200)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // ── Metric labels ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MetricItem('Approved', approved,
                    '${approvedRate.toStringAsFixed(1)}%',
                    Colors.green.shade500),
                _MetricItem('Pending', pending,
                    '${pendingRate.toStringAsFixed(1)}%',
                    Colors.orange.shade400),
                _MetricItem('Rejected', rejected,
                    '${rejectedRate.toStringAsFixed(1)}%',
                    Colors.red.shade400),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── Detailed Analytics Button ────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WardenAnalyticsScreen()),
                );
              },
              icon: const Icon(Icons.bar_chart_rounded, size: 18),
              label: const Text('View Detailed Analytics'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepOrange.shade600,
                side: BorderSide(color: Colors.deepOrange.shade200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final int count;
  final String percentage;
  final Color color;

  const _MetricItem(this.label, this.count, this.percentage, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$count',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(width: 4),
            Text(percentage,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }
}
