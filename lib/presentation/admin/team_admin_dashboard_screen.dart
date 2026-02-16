import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_model.dart';
import '../../data/models/team_model.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/repositories/team_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../common/cards/app_card.dart';
import 'widgets/export_report_dialog.dart';

/// Scoped dashboard for Team Admins.
/// Shows analytics and actions limited to their team(s).
class TeamAdminDashboardScreen extends StatefulWidget {
  const TeamAdminDashboardScreen({super.key});

  @override
  State<TeamAdminDashboardScreen> createState() =>
      _TeamAdminDashboardScreenState();
}

class _TeamAdminDashboardScreenState extends State<TeamAdminDashboardScreen> {
  final TeamRepository _teamRepository = TeamRepository();
  final TaskRepository _taskRepository = TaskRepository();

  List<TeamModel> _myTeams = [];
  bool _isLoading = true;
  int _teamMemberCount = 0;
  int _teamActiveTasksCount = 0;
  int _teamOverdueTasksCount = 0;

  @override
  void initState() {
    super.initState();
    _loadTeamData();
  }

  Future<void> _loadTeamData() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Get teams where this user is admin
      final allTeams = await _teamRepository.getAllTeamsStream().first;
      final myTeams =
          allTeams.where((t) => t.adminId == userId).toList();

      // Aggregate stats across all my teams
      final memberIds = <String>{};
      for (final team in myTeams) {
        memberIds.addAll(team.memberIds);
      }

      // Count active tasks for team members
      int activeTasks = 0;
      int overdueTasks = 0;
      for (final memberId in memberIds) {
        final tasks =
            await _taskRepository.getOngoingAssignedTasksStream(memberId).first;
        activeTasks += tasks.length;
        overdueTasks += tasks.where((t) => t.isOverdue).length;
      }

      if (mounted) {
        setState(() {
          _myTeams = myTeams;
          _teamMemberCount = memberIds.length;
          _teamActiveTasksCount = activeTasks;
          _teamOverdueTasksCount = overdueTasks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Admin Panel'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding:
                  const EdgeInsets.all(AppSpacing.screenPaddingMobile),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Team Analytics',
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.md),

                  // Stats Grid
                  _buildStatsGrid(context, screenWidth),

                  const SizedBox(height: AppSpacing.xxl),

                  Text(
                    'Quick Actions',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  _buildActionCard(
                    context,
                    'Generate Team Report',
                    'Export task data for your team members',
                    Icons.summarize_outlined,
                    () => _showExportDialog(context),
                  ),

                  _buildActionCard(
                    context,
                    'Reschedule Requests',
                    'Review pending reschedule requests',
                    Icons.schedule,
                    () => context.push(AppRoutes.rescheduleApproval),
                  ),

                  if (_myTeams.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      'My Teams',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ..._myTeams.map((team) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _buildTeamCard(context, team),
                        )),
                  ],
                ],
              ),
            ),
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ExportReportDialog(),
    );
  }

  Widget _buildStatsGrid(BuildContext context, double screenWidth) {
    final crossAxisCount = screenWidth > 600 ? 3 : 2;
    final childAspectRatio =
        screenWidth > 600 ? 1.2 : (screenWidth > 400 ? 1.1 : 1.0);

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: childAspectRatio,
      children: [
        _buildStatCard(
          context,
          'My Teams',
          '${_myTeams.length}',
          Icons.groups_outlined,
        ),
        _buildStatCard(
          context,
          'Team Members',
          '$_teamMemberCount',
          Icons.people_outline,
        ),
        _buildStatCard(
          context,
          'Active Tasks',
          '$_teamActiveTasksCount',
          Icons.task_outlined,
        ),
        _buildStatCard(
          context,
          'Overdue',
          '$_teamOverdueTasksCount',
          Icons.warning_amber_outlined,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      type: AppCardType.elevated,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: theme.colorScheme.primary),
            const SizedBox(height: AppSpacing.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.neutral400 : AppColors.neutral600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamCard(BuildContext context, TeamModel team) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      type: AppCardType.standard,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Icon(
                Icons.groups,
                color: theme.colorScheme.onPrimaryContainer,
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
                  const SizedBox(height: 4),
                  Text(
                    '${team.memberIds.length} members',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          isDark ? AppColors.neutral400 : AppColors.neutral600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      type: AppCardType.standard,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          isDark ? AppColors.neutral400 : AppColors.neutral600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? AppColors.neutral600 : AppColors.neutral400,
            ),
          ],
        ),
      ),
    );
  }
}
