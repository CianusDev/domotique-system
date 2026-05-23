/// Generic wrapper matching backend `ControllerResponse` shape:
/// `{ success: bool, message: string, data?: T }`
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;

  const ApiResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T? Function(Map<String, dynamic>)? fromData,
  ) {
    final rawData = json['data'];
    return ApiResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      data: rawData != null && fromData != null
          ? fromData(rawData as Map<String, dynamic>)
          : null,
    );
  }
}
