String friendlyApiError(dynamic resp,
    [String fallback = 'Ocurrió un error. Por favor intenta de nuevo.']) {
  if (resp == null) return fallback;
  try {
    if (resp is Map) {
      if (resp['error'] != null) return resp['error'].toString();
      if (resp['message'] != null) return resp['message'].toString();
      if (resp['reason'] != null) return resp['reason'].toString();
    }
    // If it's a plain string or exception, return it
    return resp.toString();
  } catch (_) {
    return fallback;
  }
}
