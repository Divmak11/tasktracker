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
import '../../data/services/notification_service.dart';
import '../common/buttons/app_button.dart';
import '../common/inputs/app_text_field.dart';

class EditTeamScreen extends StatefulWidget {
  final String teamId;

  const EditTeamScreen({super.key, required this.teamId});

  @override
  State<EditTeamScreen> createState() => _EditTeamScreenState();
}

class _EditTeamScreenState extends State<EditTeamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _teamRepository = TeamRepository();
  final _userRepository = UserRepository();
  final Set<String> _selectedMembers = {};
  String? _selectedAdminId;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _accessDenied = false;
  bool _isSuperAdmin = false;
  TeamModel? _currentTeam;

  @override
  void initState() {
    super.initState();
    _loadTeam();
  }

  Future<void> _loadTeam() async {
    try {
      final team = await _teamRepository.getTeam(widget.teamId);
      if (team != null && mounted) {
        // Check access: only superAdmin or team admin can edit
        final currentUser = context.read<AuthProvider>().currentUser;
        final isSuperAdmin = currentUser?.role == UserRole.superAdmin;
        final isTeamAdmin = team.adminId == currentUser?.id;
        final canEdit = isSuperAdmin || isTeamAdmin;

        if (!canEdit) {
          setState(() {
            _accessDenied = true;
            _isLoading = false;
          });
          return;
        }

        setState(() {
          _isSuperAdmin = isSuperAdmin;
          _currentTeam = team;
          _nameController.text = team.name;
          _selectedMembers.addAll(team.memberIds);
          _selectedAdminId = team.adminId;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading team: $e')));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleAdminChange(
    String? newAdminId,
    String? newAdminName,
  ) async {
    if (newAdminId == null || newAdminId == _currentTeam?.adminId) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Change Team Admin'),
            content: Text(
              'Promoting $newAdminName will demote the current admin. Continue?',
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

    if (confirm == true && mounted) {
      setState(() => _selectedAdminId = newAdminId);
    }
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState?.validate() ?? false) {
      // Build updates map based on caller's permissions
      final updates = <String, dynamic>{
        'name': _nameController.text.trim(),
      };

      // Only Super Admin can modify members and admin
      if (_isSuperAdmin) {
        if (_selectedMembers.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select at least one member')),
          );
          return;
        }

        if (_selectedAdminId == null ||
            !_selectedMembers.contains(_selectedAdminId)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a valid team admin from the members'),
            ),
          );
          return;
        }

        updates['memberIds'] = _selectedMembers.toList();
        updates['adminId'] = _selectedAdminId;
      }

      setState(() => _isSaving = true);

      try {
        await _teamRepository.updateTeam(widget.teamId, updates);

        if (mounted) {
          setState(() => _isSaving = false);

          NotificationService.showInAppNotification(
            context,
            title: 'Team Updated',
            message: 'Changes have been saved successfully',
            icon: Icons.check_circle,
            backgroundColor: Colors.green.shade700,
          );

          context.pop();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating team: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Team')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Access denied - show error
    if (_accessDenied) {
      final isDark = theme.brightness == Brightness.dark;
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Team')),
        body: Center(
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
                  'Only the team admin or super admin can edit this team.',
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
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Team')),
      body: SafeArea(
        child: StreamBuilder<List<UserModel>>(
          stream: _userRepository.getAllUsersStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final users =
                snapshot.data!
                    .where((u) => u.status == UserStatus.active)
                    .toList();

            if (users.isEmpty) {
              return const Center(child: Text('No active users available'));
            }

            // Filter users for admin dropdown (must be selected members)
            final memberUsers =
                users.where((u) => _selectedMembers.contains(u.id)).toList();

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(
                      AppSpacing.screenPaddingMobile,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppTextField(
                            label: 'Team Name',
                            hint: 'Enter team name',
                            controller: _nameController,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter team name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          // Admin Selection — Super Admin only (editable dropdown)
                          // Team Admin sees read-only display
                          if (_selectedMembers.isNotEmpty) ...[
                            Text(
                              'Team Admin',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            if (_isSuperAdmin)
                              DropdownButtonFormField<String>(
                                value: _selectedAdminId,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.medium,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm,
                                  ),
                                ),
                                items:
                                    memberUsers.map((user) {
                                      return DropdownMenuItem(
                                        value: user.id,
                                        child: Text(user.name),
                                      );
                                    }).toList(),
                                onChanged: (value) {
                                  final user = users.firstWhere(
                                    (u) => u.id == value,
                                  );
                                  _handleAdminChange(value, user.name);
                                },
                                validator: (value) {
                                  if (value == null) {
                                    return 'Please select an admin';
                                  }
                                  return null;
                                },
                              )
                            else
                              // Read-only admin display for Team Admins
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.md,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.medium,
                                  ),
                                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.admin_panel_settings_outlined,
                                      color: theme.colorScheme.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      memberUsers
                                          .where((u) => u.id == _selectedAdminId)
                                          .map((u) => u.name)
                                          .firstOrNull ?? 'Unknown',
                                      style: theme.textTheme.bodyLarge,
                                    ),
                                    const Spacer(),
                                    Text(
                                      'Only Super Admin can change',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: AppSpacing.xl),
                          ],

                          // Members section — Super Admin gets checkboxes, Team Admin gets read-only list
                          Text(
                            _isSuperAdmin ? 'Select Members' : 'Team Members',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),

                          if (!_isSuperAdmin)
                            // Read-only hint for Team Admins
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: Text(
                                'Only Super Admin can modify team members.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ),

                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _isSuperAdmin
                                ? users.length
                                : memberUsers.length,
                            itemBuilder: (context, index) {
                              final user = _isSuperAdmin
                                  ? users[index]
                                  : memberUsers[index];
                              final isSelected = _selectedMembers.contains(
                                user.id,
                              );
                              final isAdmin = user.id == _selectedAdminId;

                              if (_isSuperAdmin) {
                                // Super Admin: interactive checkboxes
                                return CheckboxListTile(
                                  value: isSelected,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value == true) {
                                        _selectedMembers.add(user.id);
                                        if (_selectedMembers.length == 1 &&
                                            _selectedAdminId == null) {
                                          _selectedAdminId = user.id;
                                        }
                                      } else {
                                        // Warn if removing the admin
                                        if (user.id == _selectedAdminId) {
                                          _showAdminRemovalWarning(user);
                                          return;
                                        }
                                        _selectedMembers.remove(user.id);
                                      }
                                    });
                                  },
                                  title: Row(
                                    children: [
                                      Expanded(child: Text(user.name)),
                                      if (isAdmin)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primaryContainer,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'ADMIN',
                                            style: theme.textTheme.labelSmall?.copyWith(
                                              color: theme.colorScheme.onPrimaryContainer,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text(_getRoleDisplayName(user.role)),
                                  secondary: CircleAvatar(
                                    backgroundColor: theme.colorScheme.primaryContainer,
                                    child: Text(
                                      user.name.isNotEmpty ? user.name[0] : '?',
                                      style: TextStyle(
                                        color: theme.colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                  activeColor: theme.colorScheme.primary,
                                  checkColor: theme.colorScheme.onPrimary,
                                );
                              } else {
                                // Team Admin: read-only member list
                                return ListTile(
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
                                      if (isAdmin)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primaryContainer,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'ADMIN',
                                            style: theme.textTheme.labelSmall?.copyWith(
                                              color: theme.colorScheme.onPrimaryContainer,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text(_getRoleDisplayName(user.role)),
                                  contentPadding: EdgeInsets.zero,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom Action
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenPaddingMobile),
                  child: AppButton(
                    text: 'Save Changes',
                    onPressed: _handleSave,
                    isLoading: _isSaving,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Confirmation dialog when Super Admin tries to remove the current admin from members
  Future<void> _showAdminRemovalWarning(UserModel adminUser) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Team Admin?'),
        content: Text(
          '${adminUser.name} is the current team admin. '
          'Removing them from the team will require selecting a new admin. '
          'Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() {
        _selectedMembers.remove(adminUser.id);
        _selectedAdminId = null;
        if (_selectedMembers.isNotEmpty) {
          _selectedAdminId = _selectedMembers.first;
        }
      });
    }
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
