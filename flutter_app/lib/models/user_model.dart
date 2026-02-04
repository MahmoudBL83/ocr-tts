class UserModel {
  final String userId;
  final String email;
  final String? displayName;
  final String? pairedDeviceId;

  const UserModel({
    required this.userId,
    required this.email,
    this.displayName,
    this.pairedDeviceId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        userId: json['user_id'] as String,
        email: json['email'] as String,
        displayName: json['display_name'] as String?,
        pairedDeviceId: json['paired_device_id'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'email': email,
        'display_name': displayName,
        'paired_device_id': pairedDeviceId,
      };
}
