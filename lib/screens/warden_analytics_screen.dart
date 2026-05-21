import 'package:flutter/material.dart';
import '../services/warden_service.dart';
import '../config/app_config.dart';
import '../widgets/common/premium_date_picker.dart';
import 'dart:developer' as dev;

class WardenAnalyticsScreen extends StatefulWidget {
  const WardenAnalyticsScreen({super.key});

  @override
  State<WardenAnalyticsScreen> createState() => _WardenAnalyticsScreenState();
}

class _WardenAnalyticsScreenState extends State<WardenAnalyticsScreen> {
  late final WardenService _wardenService;
  
  bool _isLoading = false;
  String? _error;
  
  List<String> _batches = [];
  String _selectedBatch = 'All';
  DateTimeRange? _selectedDateRange;
  
  Map<String, dynamic>? _statsData;

  @override
  void initState() {
    super.initState();
    _wardenService = WardenService(baseUrl: AppConfig.kBaseUrl);
    _loadBatches();
    _loadStats();
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
      if (mounted) setState(() => _batches = batches);
    } catch (e) {
      dev.log('[WardenAnalytics] Error loading batches: $e');
    }
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final stats = await _wardenService.getStats(
        batch: _selectedBatch != 'All' ? _selectedBatch : null,
        startDate: _selectedDateRange?.start,
        endDate: _selectedDateRange?.end,
      );
      if (mounted) {
        setState(() {
          _statsData = stats;
        });
      }
    } catch (e) {
      dev.log('[WardenAnalytics] Error loading stats: $e');
      if (mounted) setState(() => _error = 'Failed to load analytics data.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onSelectDateRange() async {
    final picked = await PremiumDatePicker.show(
      context, 
      initialRange: _selectedDateRange,
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() => _selectedDateRange = picked);
      _loadStats();
    }
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Detailed Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildFilterHeader(),
            Expanded(
              child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                      : _buildAnalyticsContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filter Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: [
              // Batch Dropdown
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedBatch,
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade600),
                      style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600),
                      items: ['All', ..._batches]
                          .map((b) => DropdownMenuItem(value: b, child: Text(b == 'All' ? 'All Batches' : 'Batch $b')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null && val != _selectedBatch) {
                          setState(() => _selectedBatch = val);
                          _loadStats();
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Date Range Picker Button
              Expanded(
                child: InkWell(
                  onTap: _onSelectDateRange,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      color: _selectedDateRange != null ? Colors.deepOrange.shade50 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedDateRange != null ? Colors.deepOrange.shade200 : Colors.grey.shade200
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.date_range_rounded, 
                            size: 18, 
                            color: _selectedDateRange != null ? Colors.deepOrange.shade700 : Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedDateRange == null 
                                ? 'All Dates' 
                                : '${_fmtDate(_selectedDateRange!.start)} - ${_fmtDate(_selectedDateRange!.end)}',
                            style: TextStyle(
                              color: _selectedDateRange != null ? Colors.deepOrange.shade900 : Colors.black87,
                              fontWeight: _selectedDateRange != null ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_selectedDateRange != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  setState(() => _selectedDateRange = null);
                  _loadStats();
                },
                icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.grey),
                label: const Text('Clear Date', style: TextStyle(color: Colors.grey)),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent() {
    if (_statsData == null) return const SizedBox.shrink();

    final stats = _statsData!['statistics'] as Map<String, dynamic>? ?? {};
    final batchBreakdown = _statsData!['batchBreakdown'] as List<dynamic>? ?? [];

    final int total = stats['totalApplications'] ?? 0;
    final double approvalRate = (stats['approvalRate'] ?? 0.0).toDouble();
    final double rejectionRate = (stats['rejectionRate'] ?? 0.0).toDouble();

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Global KPIs
          Row(
            children: [
              Expanded(
                child: _buildKPICard(
                  'Total', 
                  total.toString(), 
                  Icons.receipt_long_rounded, 
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKPICard(
                  'Approval Rate', 
                  '${approvalRate.toStringAsFixed(1)}%', 
                  Icons.check_circle_outline_rounded, 
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKPICard(
                  'Rejection Rate', 
                  '${rejectionRate.toStringAsFixed(1)}%', 
                  Icons.cancel_outlined, 
                  Colors.red,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          const Text(
            'Batch Breakdown',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 12),

          if (batchBreakdown.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Text('No applications data found.', style: TextStyle(color: Colors.grey.shade600)),
            )
          else
            ...batchBreakdown.map((b) => _buildBatchCard(b as Map<String, dynamic>)),
        ],
      ),
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(color: color.shade50, blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color.shade600, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color.shade800),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBatchCard(Map<String, dynamic> batchData) {
    final batch = batchData['batch']?.toString() ?? 'Unknown';
    final total = batchData['total'] ?? 0;
    final approved = batchData['approved'] ?? 0;
    final rejected = batchData['rejected'] ?? 0;
    final pending = batchData['pending'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Batch $batch', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Total: $total', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Proportional bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  if (approved > 0) Expanded(flex: approved, child: Container(color: Colors.green.shade400)),
                  if (pending > 0) Expanded(flex: pending, child: Container(color: Colors.orange.shade300)),
                  if (rejected > 0) Expanded(flex: rejected, child: Container(color: Colors.red.shade400)),
                  if (total == 0) Expanded(child: Container(color: Colors.grey.shade200)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Sub-metrics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniMetric('Approved', approved, Colors.green),
              _buildMiniMetric('Pending', pending, Colors.orange),
              _buildMiniMetric('Rejected', rejected, Colors.red),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, int value, MaterialColor color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color.shade400, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        Text('$value', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }
}
