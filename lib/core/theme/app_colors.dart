import 'package:flutter/material.dart';

/// App color definitions for dark modern UI
class AppColors {
  AppColors._();

  // Primary colors
  static const Color primaryBlue = Color(0xFF2196F3);
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color lightBlue = Color(0xFF64B5F6);

  // Marker colors
  static const Color startGreen = Color(0xFF4CAF50);
  static const Color stopBlue = Color(0xFF2196F3);
  static const Color endRed = Color(0xFFF44336);
  static const Color waypointOrange = Color(0xFFFF9800);

  // Transport colors
  static const Color carBlue = Color(0xFF2196F3);
  static const Color busGreen = Color(0xFF4CAF50);
  static const Color trainPurple = Color(0xFF9C27B0);
  static const Color flightRed = Color(0xFFE53935);
  static const Color bikeOrange = Color(0xFFFF9800);
  static const Color walkingTeal = Color(0xFF009688);

  // Dark theme surface colors
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF2D2D2D);
  static const Color darkElevated = Color(0xFF383838);
  static const Color darkBackground = Color(0xFF121212);

  // Light theme surface colors
  static const Color lightSurface = Color(0xFFFAFAFA);
  static const Color lightCard = Color(0xFFFFFFFF);

  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textHint = Color(0xFF757575);

  // Accent colors
  static const Color accentYellow = Color(0xFFFFC107);
  static const Color accentAmber = Color(0xFFFFAB00);

  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Gradient for headers
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryBlue, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Get transport color by type
  static Color getTransportColor(String transportType) {
    switch (transportType.toLowerCase()) {
      case 'car':
        return carBlue;
      case 'bus':
        return busGreen;
      case 'train':
        return trainPurple;
      case 'flight':
        return flightRed;
      case 'bike':
        return bikeOrange;
      case 'walking':
        return walkingTeal;
      default:
        return carBlue;
    }
  }

  // Get transport icon by type
  static IconData getTransportIcon(String transportType) {
    switch (transportType.toLowerCase()) {
      case 'car':
        return Icons.directions_car;
      case 'bus':
        return Icons.directions_bus;
      case 'train':
        return Icons.train;
      case 'flight':
        return Icons.flight;
      case 'bike':
        return Icons.pedal_bike;
      case 'walking':
        return Icons.directions_walk;
      default:
        return Icons.directions_car;
    }
  }
}
