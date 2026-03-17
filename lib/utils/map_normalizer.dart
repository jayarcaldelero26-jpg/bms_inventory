/// Normalizes any Map coming from Hive / JSON / dynamic sources
/// into a safe Map<String, dynamic>.
///
/// Use this EVERY TIME you read data from Hive boxes
/// to avoid:
/// type '_Map<dynamic, dynamic>' is not a subtype of Map<String, dynamic>
Map<String, dynamic> normalizeMap(dynamic data) {
  if (data == null) {
    return <String, dynamic>{};
  }

  // If already correct type, return directly
  if (data is Map<String, dynamic>) {
    return data;
  }

  // If Map but with dynamic keys (Hive case)
  if (data is Map) {
    return data.map((key, value) => MapEntry(key.toString(), value));
  }

  // Fallback (should not happen, but keeps app from crashing)
  return <String, dynamic>{};
}
