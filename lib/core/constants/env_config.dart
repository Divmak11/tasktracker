import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized environment configuration
class EnvConfig {
  /// Get list of super admin emails (comma-separated in .env)
  static List<String> get superAdminEmails {
    final emailsStr =
        dotenv.env['SUPER_ADMIN_EMAILS'] ??
        dotenv.env['SUPER_ADMIN_EMAIL'] ??
        'admin@yourcompany.com';
    return emailsStr
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Check if an email is a super admin email
  static bool isSuperAdminEmail(String? email) {
    if (email == null || email.isEmpty) return false;
    return superAdminEmails.contains(email.toLowerCase().trim());
  }

  /// Legacy getter for backward compatibility (returns first email)
  static String get superAdminEmail => superAdminEmails.first;

  static String get environment => dotenv.env['ENV'] ?? 'development';

  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => environment == 'production';

  /// Validate that all required environment variables are present
  static void validate() {
    final requiredVars = ['SUPER_ADMIN_EMAILS'];

    for (final varName in requiredVars) {
      if (dotenv.env[varName] == null || dotenv.env[varName]!.isEmpty) {
        // Check legacy variable name for backward compatibility
        if (varName == 'SUPER_ADMIN_EMAILS' &&
            dotenv.env['SUPER_ADMIN_EMAIL'] != null &&
            dotenv.env['SUPER_ADMIN_EMAIL']!.isNotEmpty) {
          continue;
        }
        throw Exception('Missing required environment variable: $varName');
      }
    }
  }
}
