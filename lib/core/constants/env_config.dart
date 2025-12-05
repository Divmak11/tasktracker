import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized environment configuration
class EnvConfig {
  static String get superAdminEmail =>
      dotenv.env['SUPER_ADMIN_EMAIL'] ?? 'admin@yourcompany.com';

  static String get environment => dotenv.env['ENV'] ?? 'development';

  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => environment == 'production';

  /// Validate that all required environment variables are present
  static void validate() {
    final requiredVars = ['SUPER_ADMIN_EMAIL'];

    for (final varName in requiredVars) {
      if (dotenv.env[varName] == null || dotenv.env[varName]!.isEmpty) {
        throw Exception('Missing required environment variable: $varName');
      }
    }
  }
}
