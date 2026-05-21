import 'package:flutter/material.dart';

class PremiumDatePicker {
  /// Shows a beautiful bottom sheet for selecting a date range.
  static Future<DateTimeRange?> show(BuildContext context, {DateTimeRange? initialRange}) async {
    return showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PremiumDateSheet(initialRange: initialRange),
    );
  }
}

class _PremiumDateSheet extends StatefulWidget {
  final DateTimeRange? initialRange;
  const _PremiumDateSheet({this.initialRange});

  @override
  State<_PremiumDateSheet> createState() => _PremiumDateSheetState();
}

class _PremiumDateSheetState extends State<_PremiumDateSheet> {
  DateTime? _start;
  DateTime? _end;
  String _activeQuickFilter = '';

  @override
  void initState() {
    super.initState();
    _start = widget.initialRange?.start;
    _end = widget.initialRange?.end;
  }

  void _applyQuickFilter(String label, int daysAgoStart, int daysAgoEnd) {
    final now = DateTime.now();
    setState(() {
      _activeQuickFilter = label;
      _start = now.subtract(Duration(days: daysAgoStart));
      _end = now.subtract(Duration(days: daysAgoEnd));
    });
  }

  void _applyThisMonth() {
    final now = DateTime.now();
    setState(() {
      _activeQuickFilter = 'This Month';
      _start = DateTime(now.year, now.month, 1);
      _end = DateTime(now.year, now.month + 1, 0); // Last day of month
    });
  }

  Future<void> _pickDate(bool isStart) async {
    final initialDate = isStart
        ? (_start ?? DateTime.now())
        : (_end ?? _start ?? DateTime.now());
        
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: Colors.deepOrange.shade600,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.black87,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _activeQuickFilter = ''; // clear quick filter styling
        if (isStart) {
          _start = picked;
          // Reset end if it's before new start
          if (_end != null && _end!.isBefore(_start!)) {
            _end = null;
          }
        } else {
          _end = picked;
          // Reset start if it's after new end
          if (_start != null && _start!.isAfter(_end!)) {
            _start = null;
          }
        }
      });
    }
  }

  String _fmt(DateTime? d) => d == null ? 'Select Date' : '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          const Text(
            'Select Date Range',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Quick Filters
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickFilterChip(
                label: 'Today',
                isActive: _activeQuickFilter == 'Today',
                onTap: () => _applyQuickFilter('Today', 0, 0),
              ),
              _QuickFilterChip(
                label: 'Yesterday',
                isActive: _activeQuickFilter == 'Yesterday',
                onTap: () => _applyQuickFilter('Yesterday', 1, 1),
              ),
              _QuickFilterChip(
                label: 'Last 7 Days',
                isActive: _activeQuickFilter == 'Last 7 Days',
                onTap: () => _applyQuickFilter('Last 7 Days', 6, 0),
              ),
              _QuickFilterChip(
                label: 'Last 30 Days',
                isActive: _activeQuickFilter == 'Last 30 Days',
                onTap: () => _applyQuickFilter('Last 30 Days', 29, 0),
              ),
              _QuickFilterChip(
                label: 'This Month',
                isActive: _activeQuickFilter == 'This Month',
                onTap: _applyThisMonth,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          const Text(
            'Custom Range',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54),
          ),
          const SizedBox(height: 12),

          // Custom Date Pickers
          Row(
            children: [
              Expanded(
                child: _DateSelectorBtn(
                  label: 'Start Date',
                  dateText: _fmt(_start),
                  hasValue: _start != null,
                  onTap: () => _pickDate(true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _DateSelectorBtn(
                  label: 'End Date',
                  dateText: _fmt(_end),
                  hasValue: _end != null,
                  onTap: () => _pickDate(false),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Clear', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: (_start != null && _end != null)
                      ? () => Navigator.pop(context, DateTimeRange(start: _start!, end: _end!))
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.deepOrange.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Apply Filter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class _QuickFilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _QuickFilterChip({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.deepOrange.shade600 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? Colors.deepOrange.shade600 : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black87,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _DateSelectorBtn extends StatelessWidget {
  final String label;
  final String dateText;
  final bool hasValue;
  final VoidCallback onTap;

  const _DateSelectorBtn({
    required this.label,
    required this.dateText,
    required this.hasValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasValue ? Colors.deepOrange.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hasValue ? Colors.deepOrange.shade200 : Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, 
                     size: 16, 
                     color: hasValue ? Colors.deepOrange.shade700 : Colors.grey.shade500),
                const SizedBox(width: 8),
                Text(
                  dateText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: hasValue ? FontWeight.bold : FontWeight.normal,
                    color: hasValue ? Colors.deepOrange.shade800 : Colors.black87,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
