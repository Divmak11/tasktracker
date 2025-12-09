import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/services/cloud_functions_service.dart';
import '../../data/services/notification_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final UserRepository _userRepository = UserRepository();
  final CloudFunctionsService _cloudFunctions = CloudFunctionsService();
  final TextEditingController _searchController = TextEditingController();
  
  UserRole? _selectedRoleFilter;
  UserStatus? _selectedStatusFilter;
  String _searchQuery = '';

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        automaticallyImplyLeading: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPaddingMobile,
              AppSpacing.sm,
              AppSpacing.screenPaddingMobile,
              AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.neutral900 : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.neutral800 : AppColors.neutral200,
                  width: 1,
                ),
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                prefixIcon: Icon(
                  Icons.search,
                  color: isDark ? AppColors.neutral500 : AppColors.neutral400,
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          size: 18,
                          color: isDark ? AppColors.neutral500 : AppColors.neutral400,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? AppColors.neutral800 : AppColors.neutral50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                isDense: true,
              ),
              style: theme.textTheme.bodyMedium,
            ),
          ),

          // Compact Filters - Single Row
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingMobile,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.neutral900 : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.neutral800 : AppColors.neutral200,
                  width: 1,
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Status Filters
                  _buildCompactChip('All', _selectedStatusFilter == null, () {
                    setState(() => _selectedStatusFilter = null);
                  }),
                  const SizedBox(width: AppSpacing.xs),
                  _buildCompactChip('Active', _selectedStatusFilter == UserStatus.active, () {
                    setState(() => _selectedStatusFilter = UserStatus.active);
                  }),
                  const SizedBox(width: AppSpacing.xs),
                  _buildCompactChip('Revoked', _selectedStatusFilter == UserStatus.revoked, () {
                    setState(() => _selectedStatusFilter = UserStatus.revoked);
                  }),
                  
                  // Vertical divider
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    width: 1,
                    height: 24,
                    color: isDark ? AppColors.neutral700 : AppColors.neutral300,
                  ),
                  
                  // Role Filters
                  _buildCompactChip('All Roles', _selectedRoleFilter == null, () {
                    setState(() => _selectedRoleFilter = null);
                  }),
                  const SizedBox(width: AppSpacing.xs),
                  _buildCompactChip('Admin', _selectedRoleFilter == UserRole.superAdmin, () {
                    setState(() => _selectedRoleFilter = UserRole.superAdmin);
                  }),
                  const SizedBox(width: AppSpacing.xs),
                  _buildCompactChip('Team Admin', _selectedRoleFilter == UserRole.teamAdmin, () {
                    setState(() => _selectedRoleFilter = UserRole.teamAdmin);
                  }),
                  const SizedBox(width: AppSpacing.xs),
                  _buildCompactChip('Member', _selectedRoleFilter == UserRole.member, () {
                    setState(() => _selectedRoleFilter = UserRole.member);
                  }),
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
                
                // Apply role filter
                if (_selectedRoleFilter != null) {
                  users = users.where((u) => u.role == _selectedRoleFilter).toList();
                }
                
                // Apply status filter
                if (_selectedStatusFilter != null) {
                  users = users.where((u) => u.status == _selectedStatusFilter).toList();
                }
                
                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  users = users.where((u) {
                    return u.name.toLowerCase().contains(_searchQuery) ||
                        u.email.toLowerCase().contains(_searchQuery);
                  }).toList();
                }

                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_off_outlined,
                          size: 64,
                          color: isDark ? AppColors.neutral600 : AppColors.neutral400,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'No users found',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: isDark ? AppColors.neutral400 : AppColors.neutral600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.screenPaddingMobile),
                  itemCount: users.length,
                  separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return _buildUserTile(user, theme, isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Compact chip widget for filters
  Widget _buildCompactChip(String label, bool isSelected, VoidCallback onTap) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : (isDark ? AppColors.neutral800 : AppColors.neutral100),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : (isDark ? AppColors.neutral700 : AppColors.neutral300),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.neutral300 : AppColors.neutral700),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // Streamlined user tile
  Widget _buildUserTile(UserModel user, ThemeData theme, bool isDark) {
    final isRevoked = user.status == UserStatus.revoked;

    return InkWell(
      onTap: () => context.push('/admin/users/${user.id}/tasks'),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.neutral800 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? AppColors.neutral800 : AppColors.neutral200,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Compact Avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            
            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name + Role Badge + Revoked Status (inline)
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _buildCompactRoleBadge(user.role, theme),
                      if (isRevoked) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'REVOKED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.orange,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  
                  // Email only
                  Text(
                    user.email,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.neutral400 : AppColors.neutral600,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            // Actions Menu
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                size: 20,
                color: isDark ? AppColors.neutral400 : AppColors.neutral600,
              ),
              iconSize: 20,
              padding: EdgeInsets.zero,
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
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'view_tasks',
                  height: 40,
                  child: Row(
                    children: const [
                      Icon(Icons.assignment_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('View Tasks', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'change_role',
                  height: 40,
                  child: Text('Change Role', style: TextStyle(fontSize: 14)),
                ),
                if (!isRevoked)
                  PopupMenuItem(
                    value: 'revoke',
                    height: 40,
                    child: Text('Revoke Access', style: TextStyle(fontSize: 14)),
                  )
                else
                  PopupMenuItem(
                    value: 'restore',
                    height: 40,
                    child: Text('Restore Access', style: TextStyle(fontSize: 14)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Compact role badge
  Widget _buildCompactRoleBadge(UserRole role, ThemeData theme) {
    final roleConfig = _getRoleConfig(role);
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: roleConfig['color'].withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        roleConfig['short'],
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: roleConfig['color'],
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Map<String, dynamic> _getRoleConfig(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return {'short': 'ADMIN', 'color': Colors.purple};
      case UserRole.teamAdmin:
        return {'short': 'TEAM', 'color': Colors.blue};
      case UserRole.member:
        return {'short': 'MEMBER', 'color': Colors.green};
    }
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
}
