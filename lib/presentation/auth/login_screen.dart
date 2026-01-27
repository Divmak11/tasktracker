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
import '../common/inputs/app_text_field.dart';

/// Tracks which sign-in method is currently loading
enum _SignInMethod { google, apple }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// Which sign-in method is currently loading (null = none)
  _SignInMethod? _loadingMethod;

  bool get _isLoading => _loadingMethod != null;
  bool get _isGoogleLoading => _loadingMethod == _SignInMethod.google;
  bool get _isAppleLoading => _loadingMethod == _SignInMethod.apple;

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
                      theme.colorScheme.primary.withOpacity(0.2),
                    ]
                    : [
                      theme.colorScheme.primary.withOpacity(0.05),
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
                          color: theme.colorScheme.primary.withOpacity(
                            0.3,
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

                  // Loading Indicator (if loading)
                  if (_isLoading) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Signing in...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],

                  // Sign-In Buttons (Hide when loading)
                  if (!_isLoading) ...[
                    AppButton(
                      text: 'Continue with Google',
                      onPressed: _isLoading ? () {} : _handleGoogleSignIn,
                      type: AppButtonType.primary,
                      leadingWidget: Container(
                        width: 20,
                        height: 20,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Image.network(
                          'https://lh3.googleusercontent.com/COxitqgJr1sJnIDe8-jiKhxDx1FrYbtRHKJ9z_hELisAlapwE9LUPh6fcXIfb5vwpbMl4xl9H9TRFPc5NOO8Sb3VSgIBrfRYvW6cUA',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.g_mobiledata_rounded,
                              size: 16,
                              color: Color(0xFF4285F4),
                            );
                          },
                        ),
                      ),
                      isLoading: _isGoogleLoading,
                      isFullWidth: true,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  const SizedBox(height: AppSpacing.md),

                  // Apple Sign-In Button (iOS/macOS only)
                  if (Platform.isIOS || Platform.isMacOS)
                    AppButton(
                      text: 'Continue with Apple',
                      onPressed: _isLoading ? () {} : _handleAppleSignIn,
                      type: AppButtonType.secondary,
                      icon: Icons.apple_rounded,
                      isLoading: _isAppleLoading,
                      isFullWidth: true,
                    ),

                  // Large spacing to push terms toward bottom
                  const SizedBox(height: AppSpacing.xxl),

                  // Email Login Button (Subtle)
                  TextButton(
                    onPressed: _isLoading ? null : () => context.push('/login/email'),
                    child: Text(
                      'Sign in with Email/Password',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

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

  Widget _buildGoogleIcon() {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            foreground: Paint()
              ..shader = const LinearGradient(
                colors: [
                  Color(0xFF4285F4), // Google Blue
                  Color(0xFFEA4335), // Google Red
                  Color(0xFFFBBC05), // Google Yellow
                  Color(0xFF34A853), // Google Green
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(const Rect.fromLTWH(0, 0, 20, 20)),
          ),
        ),
      ),
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
                        AppStrings.termsOfServiceUrl,
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
                        AppStrings.privacyPolicyUrl,
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
    setState(() => _loadingMethod = _SignInMethod.google);

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
        setState(() => _loadingMethod = null);
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _loadingMethod = _SignInMethod.apple);

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
        setState(() => _loadingMethod = null);
      }
    }
  }

  Future<void> _showReviewerLoginDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isDialogLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: !isDialogLoading,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Email Login'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      AppTextField(
                        label: 'Email',
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !isDialogLoading,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Password',
                        controller: passwordController,
                        obscureText: true,
                        enabled: !isDialogLoading,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDialogLoading ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                AppButton(
                  text: 'Login',
                  isLoading: isDialogLoading,
                  onPressed: isDialogLoading
                      ? null
                      : () async {
                          if (formKey.currentState?.validate() ?? false) {
                            final email = emailController.text.trim();
                            final password = passwordController.text.trim();

                            // Show loading spinner IN THE DIALOG
                            setDialogState(() => isDialogLoading = true);

                            try {
                              await context.read<AuthProvider>().signInWithEmail(
                                    email,
                                    password,
                                  );
                              // SUCCESS: Do NOT pop the dialog!
                              // GoRouter will destroy LoginScreen (and this dialog) 
                              // as a single, clean operation when auth state changes.
                            } catch (e) {
                              // FAILURE: Dialog is still open, show error here.
                              if (context.mounted) {
                                setDialogState(() => isDialogLoading = false);
                                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      e.toString().replaceAll('Exception: ', ''),
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();
    passwordController.dispose();
  }
}
