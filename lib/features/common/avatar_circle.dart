import 'package:flutter/material.dart';

const List<String> kAvatarEmojis = [
  '🎧', '🎵', '🔥', '🌙', '⭐', '🌊',
  '💜', '🚀', '🎤', '🪐', '🎸', '🪩',
];

const List<int> kAvatarColors = [
  0xFF6C5CE7,
  0xFF00CEC9,
  0xFFFF7675,
  0xFFFD79A8,
  0xFF74B9FF,
  0xFF55EFC4,
];

class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    super.key,
    required this.emoji,
    required this.colorValue,
    this.radius = 24,
    this.fontSize,
  });

  final String emoji;
  final int colorValue;
  final double radius;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Color(colorValue),
      child: Text(
        emoji,
        style: TextStyle(fontSize: fontSize ?? radius * 0.95),
      ),
    );
  }
}
