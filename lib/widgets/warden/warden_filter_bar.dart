import 'package:flutter/material.dart';

/// A stateless filter bar for the Warden Dashboard.
///
/// Owns NO state of its own — all values flow in from the parent and all
/// mutations are surfaced via callbacks, keeping a clean unidirectional flow.
class WardenFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final String batchFilter;
  final String statusFilter;
  final List<String> batches;
  final DateTimeRange? selectedDateRange;

  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onBatchChanged;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onSelectDateRange;
  final VoidCallback onClearFilters;

  const WardenFilterBar({
    super.key,
    required this.searchController,
    required this.searchQuery,
    required this.batchFilter,
    required this.statusFilter,
    required this.batches,
    required this.selectedDateRange,
    required this.onSearchChanged,
    required this.onBatchChanged,
    required this.onStatusChanged,
    required this.onSelectDateRange,
    required this.onClearFilters,
  });

  bool get _hasActiveFilters =>
      searchQuery.isNotEmpty ||
      batchFilter != 'All' ||
      statusFilter != 'All' ||
      selectedDateRange != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar & Clear Filters Button
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search student...',
                      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.deepOrange.shade500),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close_rounded, color: Colors.grey.shade600),
                              onPressed: () => onSearchChanged(''),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              if (_hasActiveFilters) ...[
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: onClearFilters,
                    icon: const Icon(Icons.refresh_rounded),
                    color: Colors.deepOrange.shade700,
                    tooltip: 'Clear Filters',
                  ),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Filters Scrollable Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDropdown(
                  value: statusFilter,
                  icon: Icons.filter_list_rounded,
                  items: ['All', 'Pending', 'Approved', 'Rejected'],
                  onChanged: onStatusChanged,
                  prefix: 'Status: ',
                ),
                const SizedBox(width: 8),
                _buildDropdown(
                  value: batchFilter,
                  icon: Icons.school_rounded,
                  items: ['All', ...batches],
                  onChanged: onBatchChanged,
                  prefix: 'Batch: ',
                ),
                const SizedBox(width: 8),
                _buildDateButton(),
                
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String prefix,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: value == 'All' ? Colors.grey.shade50 : Colors.deepOrange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value == 'All' ? Colors.grey.shade200 : Colors.deepOrange.shade200,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: value == 'All' ? Colors.grey.shade600 : Colors.deepOrange.shade700),
          style: TextStyle(
            fontSize: 13,
            color: value == 'All' ? Colors.grey.shade800 : Colors.deepOrange.shade800,
            fontWeight: FontWeight.w600,
          ),
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Row(
                children: [
                  if (item == value) ...[
                    Icon(icon, size: 14, color: value == 'All' ? Colors.grey.shade600 : Colors.deepOrange.shade700),
                    const SizedBox(width: 6),
                  ],
                  Text(item == 'All' ? '$prefix$item' : item),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDateButton() {
    final isActive = selectedDateRange != null;
    return InkWell(
      onTap: onSelectDateRange,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.deepOrange.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? Colors.deepOrange.shade200 : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_rounded,
                size: 16,
                color: isActive ? Colors.deepOrange.shade700 : Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              isActive
                  ? '${selectedDateRange!.start.day}/${selectedDateRange!.start.month} - ${selectedDateRange!.end.day}/${selectedDateRange!.end.month}'
                  : 'Dates',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.deepOrange.shade800 : Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
