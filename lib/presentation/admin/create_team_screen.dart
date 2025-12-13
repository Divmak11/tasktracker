import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_spacing.dart';
import '../../data/models/team_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/team_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/services/notification_service.dart';
import '../common/buttons/app_button.dart';
import '../common/inputs/app_text_field.dart';

class CreateTeamScreen extends StatefulWidget {
  const CreateTeamScreen({super.key});

  @override
  State<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends State<CreateTeamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _teamRepository = TeamRepository();
  final _userRepository = UserRepository();
  final Set<String> _selectedMembers = {};
  String? _selectedAdminId; // Team Admin (must be one of the selected members)
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedMembers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one member')),
        );
        return;
      }

      if (_selectedAdminId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a Team Admin')),
        );
        return;
      }

      // Validate Team Admin is in members list
      if (!_selectedMembers.contains(_selectedAdminId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Team Admin must be a team member')),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        final currentUser = context.read<AuthProvider>().currentUser;
        if (currentUser == null) throw Exception('User not logged in');

        // Create team model - Super Admin is NOT auto-added
        // adminId is the selected Team Admin, not the Super Admin
        final team = TeamModel(
          id: '', // Will be set by Firestore
          name: _nameController.text.trim(),
          adminId: _selectedAdminId!, // Selected Team Admin
          memberIds: _selectedMembers.toList(),
          createdBy: currentUser.id, // Super Admin who created it
          createdAt: DateTime.now(),
        );

        // Save to Firestore
        await _teamRepository.createTeam(team);

        if (mounted) {
          setState(() => _isLoading = false);

          // Show success notification
          NotificationService.showInAppNotification(
            context,
            title: 'Team Created',
            message: '${team.name} has been created successfully',
            icon: Icons.check_circle,
            backgroundColor: Colors.green.shade700,
          );

          // Go back to Team List
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating team: $e'),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Create Team')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenPaddingMobile),
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
                      const SizedBox(height: AppSpacing.xl),

                      Text(
                        'Select Members',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Real-time user list from Firestore
                      StreamBuilder<List<UserModel>>(
                        stream: _userRepository.getAllUsersStream(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Text('Error: ${snapshot.error}');
                          }

                          if (!snapshot.hasData) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(AppSpacing.lg),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          final users =
                              snapshot.data!
                                  .where((u) => u.status == UserStatus.active)
                                  .toList();

                          if (users.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(AppSpacing.lg),
                              child: Text('No active users available'),
                            );
                          }

                          // Get selected members as UserModel list for Team Admin dropdown
                          final selectedMemberUsers =
                              users
                                  .where((u) => _selectedMembers.contains(u.id))
                                  .toList();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Member selection list
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: users.length,
                                itemBuilder: (context, index) {
                                  final user = users[index];
                                  final isSelected = _selectedMembers.contains(
                                    user.id,
                                  );
                                  final isTeamAdmin =
                                      _selectedAdminId == user.id;

                                  return CheckboxListTile(
                                    value: isSelected,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedMembers.add(user.id);
                                        } else {
                                          _selectedMembers.remove(user.id);
                                          // Clear admin if removed from members
                                          if (_selectedAdminId == user.id) {
                                            _selectedAdminId = null;
                                          }
                                        }
                                      });
                                    },
                                    title: Row(
                                      children: [
                                        Text(user.name),
                                        if (isTeamAdmin) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  theme
                                                      .colorScheme
                                                      .primaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Admin',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color:
                                                    theme
                                                        .colorScheme
                                                        .onPrimaryContainer,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    subtitle: Text(user.email),
                                    secondary: CircleAvatar(
                                      backgroundColor:
                                          theme.colorScheme.primaryContainer,
                                      child: Text(
                                        user.name.isNotEmpty
                                            ? user.name[0]
                                            : '?',
                                        style: TextStyle(
                                          color:
                                              theme
                                                  .colorScheme
                                                  .onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                    activeColor: theme.colorScheme.primary,
                                    checkColor: theme.colorScheme.onPrimary,
                                  );
                                },
                              ),

                              // Team Admin Selector (only show when members are selected)
                              if (_selectedMembers.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.xl),
                                Text(
                                  'Select Team Admin',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Choose who will manage this team',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                DropdownButtonFormField<String>(
                                  value: _selectedAdminId,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                  ),
                                  hint: const Text('Select Team Admin'),
                                  items:
                                      selectedMemberUsers.map((user) {
                                        return DropdownMenuItem(
                                          value: user.id,
                                          child: Text(user.name),
                                        );
                                      }).toList(),
                                  onChanged: (value) {
                                    setState(() => _selectedAdminId = value);
                                  },
                                  validator: (value) {
                                    if (value == null) {
                                      return 'Please select a Team Admin';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ],
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
                text: 'Create Team',
                onPressed: _handleCreate,
                isLoading: _isLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
