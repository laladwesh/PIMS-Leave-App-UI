import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as dev;

class WardenService {
  final String baseUrl;

  WardenService({required this.baseUrl});

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Converts a [DateTime] to an ISO 8601 date string (YYYY-MM-DD).
  String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ---------------------------------------------------------------------------
  // 1. GET /warden/applications — with optional server-side query parameters
  //
  //    batch      : e.g. "2012" — omit or set null for all batches
  //    status     : "pending" | "approved" | "rejected" — omit for all
  //    startDate  : ISO date string, e.g. "2026-05-01"
  //    endDate    : ISO date string, e.g. "2026-05-31"
  //    search     : free-text student name / reason search on the server
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getPendingApplications({
    String? batch,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    String? search,
  }) async {
    final headers = await _getHeaders();

    // Build query parameters map — only include non-null / non-trivial values
    final qp = <String, String>{};
    if (batch != null && batch.isNotEmpty) qp['batch'] = batch;
    if (status != null && status.toLowerCase() != 'all') qp['status'] = status.toLowerCase();
    if (startDate != null) qp['startDate'] = _isoDate(startDate);
    if (endDate != null) qp['endDate'] = _isoDate(endDate);
    if (search != null && search.isNotEmpty) qp['search'] = search;

    final url = Uri.parse('$baseUrl/warden/applications')
        .replace(queryParameters: qp.isNotEmpty ? qp : null);

    dev.log('[WardenService] GET $url');
    final res = await http.get(url, headers: headers);

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return List<Map<String, dynamic>>.from(data['leaves']);
    } else {
      throw Exception('getPendingApplications failed: ${res.statusCode} ${res.body}');
    }
  }

  // ---------------------------------------------------------------------------
  // 2. GET /warden/applications/:id — full details of a single application
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> getApplicationDetails(String id) async {
    final headers = await _getHeaders();
    final url = Uri.parse('$baseUrl/warden/applications/$id');

    dev.log('[WardenService] GET $url');
    final res = await http.get(url, headers: headers);

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      dev.log('[WardenService] Application details: ${data['leave']}');
      return Map<String, dynamic>.from(data['leave']);
    } else {
      throw Exception('getApplicationDetails failed: ${res.statusCode}');
    }
  }

  // ---------------------------------------------------------------------------
  // 3. PATCH /warden/applications/:id — approve or reject a leave request
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> decideApplication({
    required String id,
    required String decision, // "approved" | "rejected"
    String? rejectionReason,
  }) async {
    final headers = await _getHeaders();
    final url = Uri.parse('$baseUrl/warden/applications/$id');
    final body = {
      'decision': decision,
      if (decision == 'rejected' && rejectionReason != null)
        'rejectionReason': rejectionReason,
    };

    dev.log('[WardenService] PATCH $url | body: ${json.encode(body)}');
    final res = await http.patch(url, headers: headers, body: json.encode(body));

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body)['leave']);
    } else {
      throw Exception('decideApplication failed: ${res.statusCode}');
    }
  }

  // ---------------------------------------------------------------------------
  // 4. GET /warden/stats — aggregated statistics for a batch / date range
  //
  //    Returns: { statistics: { totalApplications, approvedCount, ... }, ... }
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> getStats({
    String? batch,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final headers = await _getHeaders();

    final qp = <String, String>{};
    if (batch != null && batch.isNotEmpty) qp['batch'] = batch;
    if (startDate != null) qp['startDate'] = _isoDate(startDate);
    if (endDate != null) qp['endDate'] = _isoDate(endDate);

    final url = Uri.parse('$baseUrl/warden/stats')
        .replace(queryParameters: qp.isNotEmpty ? qp : null);

    dev.log('[WardenService] GET $url');
    final res = await http.get(url, headers: headers);

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body));
    } else {
      throw Exception('getStats failed: ${res.statusCode}');
    }
  }

  // ---------------------------------------------------------------------------
  // 5. GET /warden/students/:studentId/history — full leave history for one student
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getStudentHistory(String studentId) async {
    final headers = await _getHeaders();
    final url = Uri.parse('$baseUrl/warden/students/$studentId/history');

    dev.log('[WardenService] GET $url');
    final res = await http.get(url, headers: headers);

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return List<Map<String, dynamic>>.from(data['history']);
    } else {
      throw Exception('getStudentHistory failed: ${res.statusCode}');
    }
  }

  // ---------------------------------------------------------------------------
  // 6. GET /warden/students?batch=2024 — get list of students (optional batch)
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getAllStudents({String? batch}) async {
    final headers = await _getHeaders();
    final qp = batch != null && batch.isNotEmpty ? <String, String>{'batch': batch} : <String, String>{};
    final url = Uri.parse('$baseUrl/warden/students').replace(queryParameters: qp.isNotEmpty ? qp : null);

    dev.log('[WardenService] GET $url');
    final res = await http.get(url, headers: headers);

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return List<Map<String, dynamic>>.from(data['students'] ?? []);
    } else {
      throw Exception('getAllStudents failed: ${res.statusCode}');
    }
  }
}
