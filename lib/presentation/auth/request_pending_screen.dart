import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/auth_provider.dart';
import '../common/buttons/app_button.dart';

class RequestPendingScreen extends StatelessWidget {
  const RequestPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPaddingMobile),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Illustration
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.hourglass_top_rounded,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              
              // Title
              Text(
                'Approval Pending',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              
              // Description
              Text(
                'Your account is currently under review by the Super Admin. You will receive a notification once your access is approved.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isDark ? AppColors.neutral400 : AppColors.neutral600,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              
              // Logout Button
              AppButton(
                text: 'Logout',
                onPressed: () async {
                  await context.read<AuthProvider>().logout();
                  if (context.mounted) {
                    context.go(AppRoutes.login);
                  }
                },
                type: AppButtonType.secondary,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
