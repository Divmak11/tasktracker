import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/services/cloud_functions_service.dart';
import '../../data/services/notification_service.dart';
import '../common/cards/app_card.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final UserRepository _userRepository = UserRepository();
  final CloudFunctionsService _cloudFunctions = CloudFunctionsService();
  UserRole? _selectedFilter;

  Future<void> _showChangeRoleDialog(UserModel user) async {
    UserRole? newRole = user.role;

    final result = await showDialog<UserRole>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Change Role for ${user.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<UserRole>(
                    title: const Text('Super Admin'),
                    value: UserRole.superAdmin,
                    groupValue: newRole,
                    onChanged: (value) => setState(() => newRole = value),
                  ),
                  RadioListTile<UserRole>(
                    title: const Text('Team Admin'),
                    value: UserRole.teamAdmin,
                    groupValue: newRole,
                    onChanged: (value) => setState(() => newRole = value),
                  ),
                  RadioListTile<UserRole>(
                    title: const Text('Member'),
                    value: UserRole.member,
                    groupValue: newRole,
                    onChanged: (value) => setState(() => newRole = value),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(newRole),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && result != user.role && mounted) {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Confirm Role Change'),
              content: Text(
                'Are you sure you want to change ${user.name}\'s role from ${_getRoleText(user.role)} to ${_getRoleText(result)}?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Confirm'),
                ),
              ],
            ),
      );

      if (confirmed == true && mounted) {
        // OPTIMISTIC UPDATE: Show success immediately
        NotificationService.showInAppNotification(
          context,
          title: 'Role Updated',
          message: '${user.name} is now a ${_getRoleText(result)}',
          icon: Icons.verified_user,
          backgroundColor: Colors.green.shade700,
        );

        // Fire cloud function in background
        _cloudFunctions.updateUserRole(user.id, result.toJson()).catchError((error) {
          debugPrint('Failed to update role: $error');
          return <String, dynamic>{};
        });
      }
    }
  }

  Future<void> _handleRevokeAccess(UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Revoke Access'),
            content: Text('Revoke access for ${user.name}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
                child: const Text('Revoke'),
              ),
            ],
          ),
    );

    if (confirm == true && mounted) {
      // OPTIMISTIC UPDATE: Show success immediately
      NotificationService.showInAppNotification(
        context,
        title: 'Access Revoked',
        message: 'Access for ${user.name} has been revoked',
        icon: Icons.block,
        backgroundColor: Colors.orange.shade700,
      );

      // Fire cloud function in background
      _cloudFunctions.revokeUserAccess(user.id).catchError((error) {
        debugPrint('Failed to revoke access: $error');
        return <String, dynamic>{};
      });
    }
  }

  Future<void> _handleRestoreAccess(UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Restore Access'),
            content: Text('Restore access for ${user.name}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Restore'),
              ),
            ],
          ),
    );

    if (confirm == true && mounted) {
      // OPTIMISTIC UPDATE: Show success immediately
      NotificationService.showInAppNotification(
        context,
        title: 'Access Restored',
        message: 'Access for ${user.name} has been restored',
        icon: Icons.check_circle,
        backgroundColor: Colors.green.shade700,
      );

      // Fire cloud function in background
      _cloudFunctions.restoreUserAccess(user.id).catchError((error) {
        debugPrint('Failed to restore access: $error');
        return <String, dynamic>{};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        automaticallyImplyLeading: true,
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: isDark ? AppColors.neutral900 : AppColors.neutral50,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  _buildFilterChip(context, null, 'All'),
                  const SizedBox(width: AppSpacing.sm),
                  _buildFilterChip(context, UserRole.superAdmin, 'Super Admin'),
                  const SizedBox(width: AppSpacing.sm),
                  _buildFilterChip(context, UserRole.teamAdmin, 'Team Admin'),
                  const SizedBox(width: AppSpacing.sm),
                  _buildFilterChip(context, UserRole.member, 'Members'),
                ],
              ),
            ),
          ),

          // User List
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: _userRepository.getAllUsersStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var users = snapshot.data!;
                if (_selectedFilter != null) {
                  users =
                      users.where((u) => u.role == _selectedFilter).toList();
                }

                if (users.isEmpty) {
                  return const Center(child: Text('No users found'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.screenPaddingMobile),
                  itemCount: users.length,
                  separatorBuilder:
                      (context, index) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isRevoked = user.status == UserStatus.revoked;

                    return AppCard(
                      type: AppCardType.standard,
                      onTap:
                          () => context.push('/admin/users/${user.id}/tasks'),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            user.name.isNotEmpty ? user.name[0] : '?',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(child: Text(user.name)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getRoleColor(user.role, theme),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.small,
                                ),
                              ),
                              child: Text(
                                _getRoleText(user.role),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: AppSpacing.xs),
                            Text(user.email),
                            if (isRevoked)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.xs,
                                ),
                                child: Text(
                                  'Access Revoked',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'view_tasks':
                                context.push('/admin/users/${user.id}/tasks');
                                break;
                              case 'change_role':
                                _showChangeRoleDialog(user);
                                break;
                              case 'revoke':
                                _handleRevokeAccess(user);
                                break;
                              case 'restore':
                                _handleRestoreAccess(user);
                                break;
                            }
                          },
                          itemBuilder:
                              (context) => [
                                const PopupMenuItem(
                                  value: 'view_tasks',
                                  child: Row(
                                    children: [
                                      Icon(Icons.assignment_outlined, size: 18),
                                      SizedBox(width: 8),
                                      Text('View Tasks'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'change_role',
                                  child: Text('Change Role'),
                                ),
                                if (!isRevoked)
                                  const PopupMenuItem(
                                    value: 'revoke',
                                    child: Text('Revoke Access'),
                                  )
                                else
                                  const PopupMenuItem(
                                    value: 'restore',
                                    child: Text('Restore Access'),
                                  ),
                              ],
                        ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, UserRole? role, String label) {
    final theme = Theme.of(context);
    final isSelected = _selectedFilter == role;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? role : null;
        });
      },
      selectedColor: theme.colorScheme.primaryContainer,
      checkmarkColor: theme.colorScheme.onPrimaryContainer,
    );
  }

  String _getRoleText(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.teamAdmin:
        return 'Team Admin';
      case UserRole.member:
        return 'Member';
    }
  }

  Color _getRoleColor(UserRole role, ThemeData theme) {
    switch (role) {
      case UserRole.superAdmin:
        return Colors.purple;
      case UserRole.teamAdmin:
        return Colors.blue;
      case UserRole.member:
        return Colors.green;
    }
  }
}
