enum ProcessingStatus { pending, processing, completed, delivered, error }

class ProcessingRequestModel {
  final String requestId;
  final String ownerUserId;
  final String targetDeviceId;
  final ProcessingStatus status;
  final DateTime createdAt;
  final String imageUrl;
  final List<String>? audioUrls;
  final String? errorMessage;

  const ProcessingRequestModel({
    required this.requestId,
    required this.ownerUserId,
    required this.targetDeviceId,
    required this.status,
    required this.createdAt,
    required this.imageUrl,
    this.audioUrls,
    this.errorMessage,
  });

  factory ProcessingRequestModel.fromJson(Map<String, dynamic> json) {
    return ProcessingRequestModel(
      requestId: json['request_id'] as String,
      ownerUserId: json['owner_user_id'] as String,
      targetDeviceId: json['target_device_id'] as String,
      status: _parseStatus(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      imageUrl: json['image_url'] as String,
      audioUrls: (json['audio_urls'] as List<dynamic>?)?.cast<String>(),
      errorMessage: json['error_message'] as String?,
    );
  }

  static ProcessingStatus _parseStatus(String value) {
    return ProcessingStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ProcessingStatus.error,
    );
  }

  Map<String, dynamic> toJson() => {
        'request_id': requestId,
        'owner_user_id': ownerUserId,
        'target_device_id': targetDeviceId,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
        'image_url': imageUrl,
        if (audioUrls != null) 'audio_urls': audioUrls,
        if (errorMessage != null) 'error_message': errorMessage,
      };
}
