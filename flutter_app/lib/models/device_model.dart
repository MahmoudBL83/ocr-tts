class DeviceModel {
  final String deviceId;
  final String friendlyName;
  final bool isOnline;

  const DeviceModel({
    required this.deviceId,
    required this.friendlyName,
    this.isOnline = false,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) => DeviceModel(
        deviceId: json['device_id'] as String,
        friendlyName: json['friendly_name'] as String? ?? 'ESP32 Device',
        isOnline: json['is_online'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'friendly_name': friendlyName,
        'is_online': isOnline,
      };
}
