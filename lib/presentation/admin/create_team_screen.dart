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

      setState(() => _isLoading = true);

      try {
        final currentUser = context.read<AuthProvider>().currentUser;
        if (currentUser == null) throw Exception('User not logged in');

        // Create team model
        final team = TeamModel(
          id: '', // Will be set by Firestore
          name: _nameController.text.trim(),
          adminId: currentUser.id,
          memberIds: _selectedMembers.toList(),
          createdBy: currentUser.id,
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

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              final user = users[index];
                              final isSelected = _selectedMembers.contains(
                                user.id,
                              );

                              return CheckboxListTile(
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedMembers.add(user.id);
                                    } else {
                                      _selectedMembers.remove(user.id);
                                    }
                                  });
                                },
                                title: Text(user.name),
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
