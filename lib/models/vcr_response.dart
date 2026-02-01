// TODO: Replace with package:vcr_shared VcrResponse.

/// Parsed response from VCR Agent (type: "response").
///
/// When shared package is ready, replace this with shared's definition.
class VcrResponse {
  final String? id;
  final String status; // "success" | "error" | "warning"
  final String message;
  final List<String> logs;
  final String? errorCode;

  const VcrResponse({
    this.id,
    required this.status,
    required this.message,
    this.logs = const [],
    this.errorCode,
  });

  factory VcrResponse.fromPayload(Map<String, dynamic> payload, {String? id}) {
    return VcrResponse(
      id: id,
      status: payload['status'] as String? ?? 'error',
      message: payload['message'] as String? ?? '',
      logs: (payload['logs'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      errorCode: payload['error_code'] as String?,
    );
  }

  bool get isSuccess => status == 'success';
  bool get isError => status == 'error';
  bool get isWarning => status == 'warning';
}
