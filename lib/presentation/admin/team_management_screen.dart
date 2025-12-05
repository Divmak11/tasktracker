import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/permission_utils.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/repositories/team_repository.dart';
import '../../data/models/team_model.dart';
import '../common/cards/app_card.dart';

class TeamManagementScreen extends StatelessWidget {
  const TeamManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final teamRepository = TeamRepository();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Management'),
      ),
      floatingActionButton: PermissionUtils.canCreateTeam(
        context.watch<AuthProvider>().userRole,
      )
          ? FloatingActionButton(
              onPressed: () {
                context.push('${AppRoutes.teamManagement}/create');
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: StreamBuilder<List<TeamModel>>(
        stream: teamRepository.getAllTeamsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final teams = snapshot.data!;

          if (teams.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.groups_outlined,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'No Teams Yet',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Create your first team to get started',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? AppColors.neutral400 : AppColors.neutral600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenPaddingMobile),
            itemCount: teams.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final team = teams[index];
              return AppCard(
                type: AppCardType.standard,
                onTap: () {
                  context.push('${AppRoutes.teamManagement}/${team.id}');
                },
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                        ),
                        child: Center(
                          child: Text(
                            team.name.isNotEmpty ? team.name[0] : '?',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              team.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '${team.memberIds.length} Members',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? AppColors.neutral400 : AppColors.neutral600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: isDark ? AppColors.neutral600 : AppColors.neutral400,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
