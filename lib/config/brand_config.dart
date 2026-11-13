import 'package:flutter/material.dart';

class BrandConfig {
  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'MRD Track',
  );
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://mrdtrack.mrdsolution.my.id',
  );
  static const String primaryHex = String.fromEnvironment(
    'PRIMARY_HEX',
    defaultValue: '2563EB',
  );

  static Color get primaryColor {
    final clean = primaryHex.replaceAll('#', '');
    final val = int.tryParse('FF$clean', radix: 16) ?? 0xFF2563EB;
    return Color(val);
  }

  static String get wsUrl {
    if (baseUrl.startsWith('https://')) {
      return '${baseUrl.replaceFirst('https://', 'wss://')}/api/socket';
    }
    return '${baseUrl.replaceFirst('http://', 'ws://')}/api/socket';
  }
}
