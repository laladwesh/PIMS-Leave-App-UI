/// Converts raw exceptions into simple, user-friendly messages.
/// Never exposes API endpoints, hostnames, or internal error codes.
String friendlyError(Object e) {
  final raw = e.toString();

  // ── Network / connectivity issues ────────────────────────────────────────
  if (raw.contains('SocketException') ||
      raw.contains('Failed host lookup') ||
      raw.contains('No address associated') ||
      raw.contains('errno = 7') ||
      raw.contains('Network is unreachable') ||
      raw.contains('Connection refused') ||
      raw.contains('Connection timed out') ||
      raw.contains('ClientException')) {
    return 'No internet connection. Please check your network and try again.';
  }

  // ── Timeout ──────────────────────────────────────────────────────────────
  if (raw.contains('TimeoutException') ||
      raw.contains('timed out') ||
      raw.contains('timeout')) {
    return 'The request took too long. Please try again.';
  }

  // ── Authentication ───────────────────────────────────────────────────────
  if (raw.contains('401') || raw.contains('Unauthorized')) {
    return 'Your session has expired. Please log in again.';
  }
  if (raw.contains('403') || raw.contains('Forbidden')) {
    return 'You do not have permission to do that.';
  }

  // ── Already marked (409) ────────────────────────────────────────────────
  if (raw.contains('409') || raw.contains('Already marked')) {
    return 'Already marked.';
  }

  // ── Server errors ────────────────────────────────────────────────────────
  if (raw.contains('500') ||
      raw.contains('502') ||
      raw.contains('503') ||
      raw.contains('Internal Server Error')) {
    return 'Something went wrong on the server. Please try again later.';
  }

  // ── Firebase / Google sign-in ────────────────────────────────────────────
  if (raw.contains('firebase') ||
      raw.contains('FirebaseAuth') ||
      raw.contains('google')) {
    return 'Sign-in failed. Please try again.';
  }

  // ── Generic fallback – strip exception prefix only ───────────────────────
  // Still avoid showing raw URLs or stack traces.
  final cleaned = raw
      .replaceAll(RegExp(r'Exception:\s*'), '')
      .replaceAll(RegExp(r'https?://[^\s,]+'), '') // remove any URLs
      .replaceAll(RegExp(r'uri=\S+'), '')           // remove uri= params
      .trim();

  // If cleaned text is reasonably short and not empty, show it.
  if (cleaned.isNotEmpty && cleaned.length < 120) return cleaned;

  return 'Something went wrong. Please try again.';
}
