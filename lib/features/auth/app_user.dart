import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.avatarEmoji,
    required this.avatarColorValue,
  });

  final String id;
  final String email;
  final String displayName;
  final String avatarEmoji;
  final int avatarColorValue;

  AppUser copyWith({
    String? displayName,
    String? avatarEmoji,
    int? avatarColorValue,
  }) {
    return AppUser(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      avatarColorValue: avatarColorValue ?? this.avatarColorValue,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'avatarEmoji': avatarEmoji,
        'avatarColorValue': avatarColorValue,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: (json['email'] as String?) ?? '',
        displayName: (json['displayName'] as String?) ?? 'Listener',
        avatarEmoji: (json['avatarEmoji'] as String?) ?? '🎧',
        avatarColorValue: (json['avatarColorValue'] as int?) ?? 0xFF6C5CE7,
      );

  @override
  List<Object?> get props => [id, email, displayName, avatarEmoji, avatarColorValue];
}
