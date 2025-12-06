import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/task_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/team_model.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/team_repository.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/cloud_functions_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../common/buttons/app_button.dart';
import '../common/inputs/app_text_field.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _memberSearchController = TextEditingController();
  final _cloudFunctions = CloudFunctionsService();
  final _userRepository = UserRepository();
  final _teamRepository = TeamRepository();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  TaskAssignedType _assignedType = TaskAssignedType.member;
  String? _selectedAssigneeId;
  String? _selectedAssigneeName;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _memberSearchController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _handleCreate() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedDate == null || _selectedTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select deadline date and time')),
        );
        return;
      }
      if (_selectedAssigneeId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an assignee')),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        final authProvider = context.read<AuthProvider>();
        final currentUser = authProvider.currentUser;

        if (currentUser == null) {
          throw Exception('User not logged in');
        }

        // Combine date and time
        final deadline = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );

        // Call Cloud Function to assign task
        await _cloudFunctions.assignTask(
          title: _titleController.text.trim(),
          subtitle: _subtitleController.text.trim(),
          assignedType: _assignedType.name,
          assignedTo: _selectedAssigneeId!,
          deadline: deadline,
        );

        if (mounted) {
          setState(() => _isLoading = false);

          // Show success notification
          NotificationService.showInAppNotification(
            context,
            title: 'Task Created',
            message:
                'Task "${_titleController.text.trim()}" created successfully',
            icon: Icons.check_circle,
            backgroundColor: Colors.green.shade700,
          );

          // Go back
          context.pop();
        }
      } on FirebaseFunctionsException catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.message ?? e.code}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating task: $e'),
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
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Create Task')),
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
                        label: 'Task Title',
                        hint: 'Enter task title',
                        controller: _titleController,
                        maxLength: 100,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter task title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      AppTextField(
                        label: 'Description',
                        hint: 'Enter task description',
                        controller: _subtitleController,
                        maxLines: 4,
                        maxLength: 500,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Assignment Type Toggle
                      Text(
                        'Assignment Type',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SegmentedButton<TaskAssignedType>(
                        segments: const [
                          ButtonSegment(
                            value: TaskAssignedType.member,
                            label: Text('Member'),
                            icon: Icon(Icons.person_outline),
                          ),
                          ButtonSegment(
                            value: TaskAssignedType.team,
                            label: Text('Team'),
                            icon: Icon(Icons.groups_outlined),
                          ),
                        ],
                        selected: {_assignedType},
                        onSelectionChanged: (
                          Set<TaskAssignedType> newSelection,
                        ) {
                          setState(() {
                            _assignedType = newSelection.first;
                            _selectedAssigneeId = null; // Reset selection
                            _selectedAssigneeName = null;
                            _memberSearchController.clear();
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Assignee Dropdown
                      Text(
                        _assignedType == TaskAssignedType.member
                            ? 'Assign To'
                            : 'Assign to Team',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      _assignedType == TaskAssignedType.member
                          ? _buildMemberDropdown()
                          : _buildTeamDropdown(),

                      const SizedBox(height: AppSpacing.lg),

                      // Deadline
                      Text('Deadline', style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.sm),

                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(
                                AppRadius.medium,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color:
                                        isDark
                                            ? AppColors.neutral700
                                            : AppColors.neutral300,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.medium,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 20,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      _selectedDate != null
                                          ? dateFormat.format(_selectedDate!)
                                          : 'Select Date',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color:
                                                _selectedDate != null
                                                    ? theme
                                                        .colorScheme
                                                        .onSurface
                                                    : (isDark
                                                        ? AppColors.neutral500
                                                        : AppColors.neutral400),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: InkWell(
                              onTap: _pickTime,
                              borderRadius: BorderRadius.circular(
                                AppRadius.medium,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color:
                                        isDark
                                            ? AppColors.neutral700
                                            : AppColors.neutral300,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.medium,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 20,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      _selectedTime != null
                                          ? _selectedTime!.format(context)
                                          : 'Select Time',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color:
                                                _selectedTime != null
                                                    ? theme
                                                        .colorScheme
                                                        .onSurface
                                                    : (isDark
                                                        ? AppColors.neutral500
                                                        : AppColors.neutral400),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
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
                text: 'Create Task',
                onPressed: _handleCreate,
                isLoading: _isLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberDropdown() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<List<UserModel>>(
      stream: _userRepository.getAllUsersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final users =
            snapshot.data!.where((u) => u.status == UserStatus.active).toList();

        return Autocomplete<UserModel>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              // Show first 20 users when field is empty but focused
              return users.take(20);
            }
            final query = textEditingValue.text.toLowerCase();
            return users
                .where((user) {
                  return user.name.toLowerCase().contains(query) ||
                      user.email.toLowerCase().contains(query);
                })
                .take(50); // Limit results for performance
          },
          displayStringForOption: (UserModel user) => user.name,
          fieldViewBuilder: (
            BuildContext context,
            TextEditingController fieldController,
            FocusNode focusNode,
            VoidCallback onFieldSubmitted,
          ) {
            // Sync the field controller with selected value
            if (_selectedAssigneeName != null && fieldController.text.isEmpty) {
              fieldController.text = _selectedAssigneeName!;
            }
            return TextField(
              controller: fieldController,
              focusNode:
                  focusNode, // Must use Autocomplete's focusNode for dropdown to work
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _selectedAssigneeId != null
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _selectedAssigneeId = null;
                              _selectedAssigneeName = null;
                              fieldController.clear();
                            });
                          },
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
            );
          },
          optionsViewBuilder: (
            BuildContext context,
            AutocompleteOnSelected<UserModel> onSelected,
            Iterable<UserModel> options,
          ) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(AppRadius.medium),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 250),
                  width:
                      MediaQuery.of(context).size.width -
                      (AppSpacing.screenPaddingMobile * 2),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.neutral800 : Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    border: Border.all(
                      color:
                          isDark ? AppColors.neutral700 : AppColors.neutral200,
                    ),
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final user = options.elementAt(index);
                      final isSelected = _selectedAssigneeId == user.id;
                      return ListTile(
                        dense: true,
                        selected: isSelected,
                        selectedTileColor: theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.3),
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        title: Text(
                          user.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight:
                                isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          user.email,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                isDark
                                    ? AppColors.neutral400
                                    : AppColors.neutral600,
                          ),
                        ),
                        onTap: () => onSelected(user),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          onSelected: (UserModel user) {
            setState(() {
              _selectedAssigneeId = user.id;
              _selectedAssigneeName = user.name;
            });
          },
        );
      },
    );
  }

  Widget _buildTeamDropdown() {
    return StreamBuilder<List<TeamModel>>(
      stream: _teamRepository.getAllTeamsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }

        final teams = snapshot.data!;

        if (teams.isEmpty) {
          return const Text('No teams available');
        }

        return DropdownButtonFormField<String>(
          value: _selectedAssigneeId,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
          ),
          hint: const Text('Select team'),
          items:
              teams.map((team) {
                return DropdownMenuItem(value: team.id, child: Text(team.name));
              }).toList(),
          onChanged: (value) {
            setState(() => _selectedAssigneeId = value);
          },
        );
      },
    );
  }
}
