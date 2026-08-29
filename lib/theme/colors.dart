import 'package:flutter/material.dart';

/// Thaigotchi Color Palette
/// 
/// 🌸 River Lotus (Adopt + Searching screens)
/// ☕ Old Cafe (Daily + Chat + Map + Settings)
class AppColors {
  
  // ============ RIVER LOTUS PALETTE ============
  // Used for: Adopt screen, Searching screen
  static const Color riverCream = Color(0xFFF5F3E8);
  static const Color waterMint = Color(0xFFD8E8DD);
  static const Color lotusPink = Color(0xFFF4886B);
  static const Color lotusLight = Color(0xFFF8B5A0);
  static const Color lotusYellow = Color(0xFFF4D766);
  static const Color leafGreen = Color(0xFF5B9B7E);
  static const Color leafLight = Color(0xFF7AB395);
  static const Color leafDark = Color(0xFF4A8068);
  static const Color deepBlue = Color(0xFF1B3A4F);
  
  // ============ OLD CAFE PALETTE ============
  // Used for: Daily, Chat, Map, Settings screens
  static const Color cafeCream = Color(0xFFF5EBD8);
  static const Color cafeWallBrown = Color(0xFFA87F5C);
  static const Color cafeTeakWood = Color(0xFFB85C2D);
  static const Color cafeBrickRed = Color(0xFF8B3A3A);
  static const Color cafeDeepBrown = Color(0xFF5C3A24);
  static const Color cafeTeaTan = Color(0xFFC9A57C);
  static const Color cafeAccent = Color(0xFFE6C896);
  
  // ============ NEUTRAL / UTILITY ============
  static const Color white = Colors.white;
  static const Color cardWhite = Color(0xFFFFFCF7);
  static const Color textPrimary = Color(0xFF5C3A24);
  static const Color textSecondary = Color(0xFFA87F5C);
  static const Color textHint = Color(0xFFCCBDA8);
  static const Color shadow = Color(0x1A000000);
  
  // ============ STATUS COLORS ============
  static const Color success = Color(0xFF5B9B7E);
  static const Color warning = Color(0xFFE6A02F);
  static const Color error = Color(0xFF8B3A3A);
  static const Color info = Color(0xFF1B3A4F);
  
  // ============ BLE STATUS ============
  static const Color bleConnected = Color(0xFF5B9B7E);
  static const Color bleSearching = Color(0xFFE6A02F);
  static const Color bleDisconnected = Color(0xFFCCBDA8);
  static const Color bleError = Color(0xFF8B3A3A);
  
  // ============ GRADIENTS ============
  static const LinearGradient riverLotusBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [riverCream, waterMint, riverCream],
  );
  
  static const LinearGradient cafeBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [cafeCream, cafeAccent],
  );
}