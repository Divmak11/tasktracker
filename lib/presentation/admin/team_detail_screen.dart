import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/team_model.dart';
import '../../data/models/user_model.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/repositories/team_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../common/cards/app_card.dart';

class TeamDetailScreen extends StatelessWidget {
  final String teamId;

  const TeamDetailScreen({super.key, required this.teamId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final teamRepository = TeamRepository();
    final userRepository = UserRepository();
    final currentUser = context.watch<AuthProvider>().currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Details'),
      ),
      body: StreamBuilder<TeamModel?>(
        stream: teamRepository.getTeamStream(teamId),
        builder: (context, teamSnapshot) {
          if (teamSnapshot.hasError) {
            return Center(child: Text('Error: ${teamSnapshot.error}'));
          }

          if (!teamSnapshot.hasData || teamSnapshot.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final team = teamSnapshot.data!;

          // Access control: Only superAdmin or team members can view
          final isSuperAdmin = currentUser.role == UserRole.superAdmin;
          final isTeamMember = team.memberIds.contains(currentUser.id);
          final hasAccess = isSuperAdmin || isTeamMember;

          if (!hasAccess) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 64,
                      color: isDark ? AppColors.neutral600 : AppColors.neutral400,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Access Denied',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'You are not a member of this team.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? AppColors.neutral400 : AppColors.neutral600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    ElevatedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Edit permission: Only superAdmin or team admin can edit
          final canEdit = isSuperAdmin || team.adminId == currentUser.id;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPaddingMobile),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Team Info Card with optional edit button
                AppCard(
                  type: AppCardType.elevated,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(
                              AppRadius.medium,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              team.name.isNotEmpty ? team.name[0] : '?',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
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
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                '${team.memberIds.length} Members',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color:
                                      isDark
                                          ? AppColors.neutral400
                                          : AppColors.neutral600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Edit button - only visible if canEdit
                        if (canEdit)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Edit Team',
                            onPressed: () => context.push('/admin/teams/$teamId/edit'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Members Section
                Text(
                  'Team Members',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Fetch and display team members from Firestore
                StreamBuilder<List<UserModel>>(
                  stream: userRepository.getAllUsersStream(),
                  builder: (context, usersSnapshot) {
                    if (usersSnapshot.hasError) {
                      return Text(
                        'Error loading members: ${usersSnapshot.error}',
                      );
                    }

                    if (!usersSnapshot.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    // Filter users who are members of this team and admin
                    final allUsers = usersSnapshot.data!;
                    final teamMembers =
                        allUsers
                            .where((user) => team.memberIds.contains(user.id))
                            .toList();

                    // Admin is identified by team.adminId, displayed in the list with ADMIN badge

                    if (teamMembers.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Text('No members in this team'),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: teamMembers.length,
                      separatorBuilder:
                          (context, index) =>
                              const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final member = teamMembers[index];
                        final isAdmin = member.id == team.adminId;

                        return AppCard(
                          type: AppCardType.standard,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              child: Text(
                                member.name.isNotEmpty ? member.name[0] : '?',
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(child: Text(member.name)),
                                if (isAdmin)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.small,
                                      ),
                                    ),
                                    child: Text(
                                      'ADMIN',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color:
                                                theme
                                                    .colorScheme
                                                    .onPrimaryContainer,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(_getRoleDisplayName(member.role)),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.teamAdmin:
        return 'Team Admin';
      case UserRole.member:
        return 'Member';
    }
  }
}
