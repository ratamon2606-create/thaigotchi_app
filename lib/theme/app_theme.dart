import 'package:flutter/material.dart';
import 'colors.dart';

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      
      // Color scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.leafGreen,
        primary: AppColors.leafGreen,
        secondary: AppColors.cafeWallBrown,
        surface: AppColors.cafeCream,
        error: AppColors.error,
      ),
      
      // Font - Chulabhorn Likit (Thai royal font)
      fontFamily: 'ChulabhornLikit',
      
      // Typography
      textTheme: const TextTheme(
        // Display
        displayLarge: TextStyle(
          fontFamily: 'ChulabhornLikit',
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        displayMedium: TextStyle(
          fontFamily: 'ChulabhornLikit',
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        
        // Heading
        headlineLarge: TextStyle(
          fontFamily: 'ChulabhornLikit',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'ChulabhornLikit',
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'ChulabhornLikit',
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        
        // Title (cards, sections)
        titleLarge: TextStyle(
          fontFamily: 'ChulabhornLikit',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontFamily: 'ChulabhornLikit',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        
        // Body
        bodyLarge: TextStyle(
          fontFamily: 'ChulabhornLikit',
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'ChulabhornLikit',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        bodySmall: TextStyle(
          fontFamily: 'ChulabhornLikit',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        
        // Label (buttons, captions)
        labelLarge: TextStyle(
          fontFamily: 'ChulabhornLikit',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.white,
          letterSpacing: 0.5,
        ),
        labelMedium: TextStyle(
          fontFamily: 'ChulabhornLikit',
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        labelSmall: TextStyle(
          fontFamily: 'ChulabhornLikit',
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: AppColors.textHint,
        ),
      ),
      
      // Elevated button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.leafGreen,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(
            fontFamily: 'ChulabhornLikit',
            fontSize: 18,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
          elevation: 4,
        ),
      ),
      
      // Card theme
      cardTheme: CardThemeData(
        color: AppColors.cardWhite,
        elevation: 2,
        shadowColor: AppColors.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      
      // Input field
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.leafGreen,
            width: 2,
          ),
        ),
        hintStyle: const TextStyle(
          color: AppColors.textHint,
          fontWeight: FontWeight.w300,
        ),
      ),
      
      // Scaffold
      scaffoldBackgroundColor: AppColors.cafeCream,
      
      // App bar (mostly hidden, but defined)
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: TextStyle(
          fontFamily: 'ChulabhornLikit',
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}