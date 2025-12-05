import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_spacing.dart';
import '../../data/models/team_model.dart';
import '../../data/models/user_model.dart';
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
        setState(() {
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
      if (_selectedMembers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one member')),
        );
        return;
      }

      if (_selectedAdminId == null ||
          !_selectedMembers.contains(_selectedAdminId)) {
        // If admin is removed or not selected, default to first member or show error
        // Ideally, force selection. For now, let's default to first member if current admin is removed
        if (_selectedMembers.isNotEmpty) {
          _selectedAdminId = _selectedMembers.first;
        }
      }

      setState(() => _isSaving = true);

      try {
        // Update team in Firestore
        await _teamRepository.updateTeam(widget.teamId, {
          'name': _nameController.text.trim(),
          'memberIds': _selectedMembers.toList(),
          'adminId': _selectedAdminId,
        });

        if (mounted) {
          setState(() => _isSaving = false);

          // Show success notification
          NotificationService.showInAppNotification(
            context,
            title: 'Team Updated',
            message: 'Changes have been saved successfully',
            icon: Icons.check_circle,
            backgroundColor: Colors.green.shade700,
          );

          // Go back
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

                          // Admin Selection
                          if (_selectedMembers.isNotEmpty) ...[
                            Text(
                              'Team Admin',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.sm),
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
                            ),
                            const SizedBox(height: AppSpacing.xl),
                          ],

                          Text(
                            'Select Members',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),

                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              final user = users[index];
                              final isSelected = _selectedMembers.contains(
                                user.id,
                              );
                              final isAdmin = user.id == _selectedAdminId;

                              return CheckboxListTile(
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedMembers.add(user.id);
                                      // If this is the first member, make them admin by default if none selected
                                      if (_selectedMembers.length == 1 &&
                                          _selectedAdminId == null) {
                                        _selectedAdminId = user.id;
                                      }
                                    } else {
                                      _selectedMembers.remove(user.id);
                                      // If removed user was admin, clear admin selection
                                      if (user.id == _selectedAdminId) {
                                        _selectedAdminId = null;
                                        // Auto-select another member if available
                                        if (_selectedMembers.isNotEmpty) {
                                          _selectedAdminId =
                                              _selectedMembers.first;
                                        }
                                      }
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
                                          color:
                                              theme
                                                  .colorScheme
                                                  .primaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            12,
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
                                subtitle: Text(user.email),
                                secondary: CircleAvatar(
                                  backgroundColor:
                                      theme.colorScheme.primaryContainer,
                                  child: Text(
                                    user.name.isNotEmpty ? user.name[0] : '?',
                                    style: TextStyle(
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                                contentPadding: EdgeInsets.zero,
                                activeColor: theme.colorScheme.primary,
                                checkColor: theme.colorScheme.onPrimary,
                              );
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
}
