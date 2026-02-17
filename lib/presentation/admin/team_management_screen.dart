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
import '../../data/models/user_model.dart';
import '../common/cards/app_card.dart';

class TeamManagementScreen extends StatelessWidget {
  const TeamManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final teamRepository = TeamRepository();
    final currentUser = context.watch<AuthProvider>().currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Determine which stream to use based on user role
    // Super Admin: see all teams
    // Team Admin: see teams they admin (memberIds contains them OR adminId is them)
    // Regular Member: see only teams they belong to (read-only)
    final Stream<List<TeamModel>> teamsStream;
    final bool canCreateTeam = PermissionUtils.canCreateTeam(currentUser.role);
    
    if (currentUser.role == UserRole.superAdmin) {
      // Super Admin sees all teams
      teamsStream = teamRepository.getAllTeamsStream();
    } else {
      // Other users only see teams they belong to
      teamsStream = teamRepository.getUserTeamsStream(currentUser.id);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teams'),
      ),
      floatingActionButton: canCreateTeam
          ? FloatingActionButton(
              onPressed: () {
                context.push('${AppRoutes.teamManagement}/create');
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: StreamBuilder<List<TeamModel>>(
        stream: teamsStream,
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
                    currentUser.role == UserRole.superAdmin
                        ? 'No Teams Yet'
                        : 'No Teams',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    currentUser.role == UserRole.superAdmin
                        ? 'Create your first team to get started'
                        : 'You are not part of any team',
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
              // Check if user can edit this team
              final bool canEdit = currentUser.role == UserRole.superAdmin ||
                  team.adminId == currentUser.id;
              
              return AppCard(
                type: AppCardType.standard,
                onTap: () {
                  // Navigate to team detail for all users
                  // TeamDetailScreen handles access control (view-only for non-admins)
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
                      // Show different icon based on access level
                      Icon(
                        canEdit ? Icons.chevron_right_rounded : Icons.visibility_outlined,
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

