import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../common/buttons/app_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _steps = [
    {
      'title': 'Welcome to TODO Planner',
      'description': 'Organize your tasks, collaborate with your team, and boost your productivity.',
      'icon': Icons.check_circle_outline_rounded,
      'buttonText': 'Get Started',
    },
    {
      'title': 'Stay Notified',
      'description': 'Enable push notifications to never miss a deadline or important update.',
      'icon': Icons.notifications_active_outlined,
      'buttonText': 'Enable Notifications',
      'skipText': 'Skip for now',
    },
    {
      'title': 'Sync Calendar',
      'description': 'Connect your Google Calendar to automatically sync tasks and deadlines.',
      'icon': Icons.calendar_today_rounded,
      'buttonText': 'Connect Calendar',
      'skipText': 'Skip for now',
    },
  ];

  void _nextPage() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.screenPaddingMobile),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            step['icon'] as IconData,
                            size: 80,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        Text(
                          step['title'] as String,
                          style: theme.textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          step['description'] as String,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: isDark ? AppColors.neutral400 : AppColors.neutral600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Page Indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _steps.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? theme.colorScheme.primary
                        : (isDark ? AppColors.neutral700 : AppColors.neutral300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Actions
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPaddingMobile),
              child: Column(
                children: [
                  AppButton(
                    text: _steps[_currentPage]['buttonText'] as String,
                    onPressed: _nextPage,
                  ),
                  if (_steps[_currentPage].containsKey('skipText')) ...[
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: _nextPage,
                      child: Text(
                        _steps[_currentPage]['skipText'] as String,
                        style: TextStyle(
                          color: isDark ? AppColors.neutral400 : AppColors.neutral600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
