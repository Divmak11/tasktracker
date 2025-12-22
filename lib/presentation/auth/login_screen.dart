import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/auth_provider.dart';
import '../common/buttons/app_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors:
                isDark
                    ? [
                      AppColors.neutral900,
                      theme.colorScheme.primary.withValues(alpha: 0.2),
                    ]
                    : [
                      theme.colorScheme.primary.withValues(alpha: 0.05),
                      Colors.white,
                    ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.screenPaddingMobile),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: AppSpacing.xxl),

                  // Logo & Branding Section
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.3,
                          ),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // App Name
                  Text(
                    AppStrings.appName,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Tagline
                  Text(
                    'Organize. Delegate. Complete.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color:
                          isDark ? AppColors.neutral400 : AppColors.neutral600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl * 2),

                  // Feature Highlights
                  _buildFeatureRow(
                    icon: Icons.group_outlined,
                    text: 'Team collaboration',
                    theme: theme,
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildFeatureRow(
                    icon: Icons.calendar_today_outlined,
                    text: 'Google Calendar sync',
                    theme: theme,
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildFeatureRow(
                    icon: Icons.notifications_outlined,
                    text: 'Smart reminders',
                    theme: theme,
                    isDark: isDark,
                  ),

                  const SizedBox(height: AppSpacing.xxl * 2),

                  // Sign-In Buttons
                  AppButton(
                    text: 'Continue with Google',
                    onPressed: _isLoading ? () {} : _handleGoogleSignIn,
                    type: AppButtonType.primary,
                    leadingWidget: Image.network(
                      'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                      height: 20,
                      width: 20,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.g_mobiledata_rounded,
                          size: 20,
                        );
                      },
                    ),
                    isLoading: _isLoading,
                    isFullWidth: true,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Apple Sign-In Button (iOS/macOS only)
                  if (Platform.isIOS || Platform.isMacOS)
                    AppButton(
                      text: 'Continue with Apple',
                      onPressed: _isLoading ? () {} : _handleAppleSignIn,
                      type: AppButtonType.secondary,
                      icon: Icons.apple_rounded,
                      isLoading: _isLoading,
                      isFullWidth: true,
                    ),

                  // Spacer to push terms to bottom
                  const Spacer(),

                  // Terms
                  _buildTermsAndPolicy(theme),

                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String text,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fixed width container for icon to ensure column alignment
        SizedBox(
          width: 24,
          child: Icon(icon, size: 20, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 160, // Fixed width for text to ensure alignment
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? AppColors.neutral300 : AppColors.neutral700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsAndPolicy(ThemeData theme) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
        children: [
          const TextSpan(text: 'By continuing, you agree to our '),
          TextSpan(
            text: 'Terms of Service',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
            recognizer:
                TapGestureRecognizer()
                  ..onTap =
                      () => _launchUrl(
                        'https://todoplannerapp.com/terms',
                      ),
          ),
          const TextSpan(text: '\nand '),
          TextSpan(
            text: 'Privacy Policy',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
            recognizer:
                TapGestureRecognizer()
                  ..onTap =
                      () => _launchUrl(
                        'https://todoplannerapp.com/privacy',
                      ),
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      await context.read<AuthProvider>().signInWithGoogle();
      // Navigation is handled automatically by auth state listener in AppRouter
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);

    try {
      await context.read<AuthProvider>().signInWithApple();
      // Navigation is handled automatically by auth state listener in AppRouter
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
