import "package:flutter/material.dart";

class AppPalette {
  const AppPalette({
    required this.paper,
    required this.paperLine,
    required this.cardBg,
    required this.ink,
    required this.inkSoft,
    required this.red,
    required this.blue,
    required this.gold,
    required this.correct,
    required this.wrong,
  });

  final Color paper;
  final Color paperLine;
  final Color cardBg;
  final Color ink;
  final Color inkSoft;
  final Color red;
  final Color blue;
  final Color gold;
  final Color correct;
  final Color wrong;

  static const light = AppPalette(
    paper: Color(0xFFF6F1E7),
    paperLine: Color(0xFFDCD2BC),
    cardBg: Color(0xFFFFFDF8),
    ink: Color(0xFF2B2A28),
    inkSoft: Color(0xFF6B6459),
    red: Color(0xFFB23A34),
    blue: Color(0xFF2F4C6B),
    gold: Color(0xFF9C7A29),
    correct: Color(0xFF3E6B4F),
    wrong: Color(0xFFB23A34),
  );

  static const dark = AppPalette(
    paper: Color(0xFF1C1B19),
    paperLine: Color(0xFF302E2A),
    cardBg: Color(0xFF242220),
    ink: Color(0xFFEDE7DA),
    inkSoft: Color(0xFF948C7C),
    red: Color(0xFFD9776F),
    blue: Color(0xFF7FA4C9),
    gold: Color(0xFFD9B65C),
    correct: Color(0xFF7FBE96),
    wrong: Color(0xFFD9776F),
  );
}
