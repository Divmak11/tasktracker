import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPaddingMobile),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo & Title
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  AppStrings.appName,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Welcome! Please sign in to continue.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.neutral400 : AppColors.neutral600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Google Sign-In Button
                AppButton(
                  text: 'Continue with Google',
                  onPressed: _isLoading ? () {} : _handleGoogleSignIn,
                  type: AppButtonType.secondary,
                  icon: Icons.g_mobiledata_rounded,
                  isLoading: _isLoading,
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
                  ),
                const SizedBox(height: AppSpacing.xxl),

                // Terms
                Text(
                  'By continuing, you agree to our Terms of Service and Privacy Policy.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      await context.read<AuthProvider>().signInWithGoogle();
      
      // Navigation is handled automatically by auth state listener in AppRouter
      // No manual navigation needed here
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
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
        setState(() => _isLoading = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
