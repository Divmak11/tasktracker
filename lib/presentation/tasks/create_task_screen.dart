import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_model.dart';
import '../../data/models/team_model.dart';
import '../../data/repositories/team_repository.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/cloud_functions_service.dart';
import '../../data/providers/auth_provider.dart';
import '../common/buttons/app_button.dart';
import '../common/inputs/app_text_field.dart';
import 'widgets/assignee_selection_screen.dart';

// Extended enum for assignment type including Self
enum AssignmentType { member, team, self }

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _cloudFunctions = CloudFunctionsService();
  final _teamRepository = TeamRepository();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  AssignmentType _assignmentType = AssignmentType.member;
  // For multiple member selection
  final List<UserModel> _selectedAssignees = [];
  final List<String> _supervisorIds = [];
  // For team selection (single)
  String? _selectedTeamId;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
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
      // If user selected today, validate time is not in the past
      if (_selectedDate != null) {
        final now = DateTime.now();
        final isToday =
            _selectedDate!.year == now.year &&
            _selectedDate!.month == now.month &&
            _selectedDate!.day == now.day;

        if (isToday) {
          final selectedDateTime = DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            picked.hour,
            picked.minute,
          );

          if (selectedDateTime.isBefore(now)) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Selected time is in the past. Please choose a future time.',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return; // Don't set the time
          }
        }
      }
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

      // Combine date and time
      final deadline = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // Validate deadline is in the future
      if (deadline.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deadline must be in the future'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Get current user for 'self' assignment
      final currentUser = context.read<AuthProvider>().currentUser;

      // Determine assignee based on assignment type
      dynamic assigneeId; // Can be String or List<String>
      String assignedTypeStr;

      if (_assignmentType == AssignmentType.self) {
        if (currentUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to assign to self. Please login again.'),
            ),
          );
          return;
        }
        assigneeId = currentUser.id;
        assignedTypeStr = 'member';
      } else if (_assignmentType == AssignmentType.team) {
        if (_selectedTeamId == null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Please select a team')));
          return;
        }
        assigneeId = _selectedTeamId!;
        assignedTypeStr = 'team';
      } else {
        // Member type - can be single or multiple
        if (_selectedAssignees.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select at least one assignee'),
            ),
          );
          return;
        }
        // Send array if multiple, single string if one
        assigneeId =
            _selectedAssignees.length == 1
                ? _selectedAssignees.first.id
                : _selectedAssignees.map((u) => u.id).toList();
        assignedTypeStr = 'member';
      }

      // Get task title for notification
      final taskTitle = _titleController.text.trim();
      final taskSubtitle = _subtitleController.text.trim();

      // Show loading state
      setState(() => _isLoading = true);

      try {
        // Wait for server response (no optimistic update)
        await _cloudFunctions.assignTask(
          title: taskTitle,
          subtitle: taskSubtitle,
          assignedType: assignedTypeStr,
          assignedTo: assigneeId,
          deadline: deadline,
          supervisorIds: _supervisorIds.isNotEmpty ? _supervisorIds : null,
        );

        if (mounted) {
          NotificationService.showInAppNotification(
            context,
            title: 'Task Created',
            message:
                _selectedAssignees.length > 1
                    ? 'Task assigned to ${_selectedAssignees.length} members'
                    : 'Task "$taskTitle" created successfully',
            icon: Icons.check_circle,
            backgroundColor: Colors.green.shade700,
          );
          context.pop();
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create task: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
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
                      SegmentedButton<AssignmentType>(
                        segments: const [
                          ButtonSegment(
                            value: AssignmentType.member,
                            label: Text('Member'),
                            icon: Icon(Icons.person_outline),
                          ),
                          ButtonSegment(
                            value: AssignmentType.team,
                            label: Text('Team'),
                            icon: Icon(Icons.groups_outlined),
                          ),
                          ButtonSegment(
                            value: AssignmentType.self,
                            label: Text('Self'),
                            icon: Icon(Icons.person),
                          ),
                        ],
                        selected: {_assignmentType},
                        onSelectionChanged: (Set<AssignmentType> newSelection) {
                          setState(() {
                            _assignmentType = newSelection.first;
                            _selectedAssignees.clear();
                            _supervisorIds.clear();
                            _selectedTeamId = null;
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Assignee Selection (hide for 'Self')
                      if (_assignmentType != AssignmentType.self) ...[
                        Text(
                          _assignmentType == AssignmentType.member
                              ? 'Assign To'
                              : 'Assign to Team',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        _assignmentType == AssignmentType.member
                            ? _buildMemberSelector(theme, isDark)
                            : _buildTeamDropdown(),

                        const SizedBox(height: AppSpacing.lg),
                      ],

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

  /// Build the member selector UI with tap-to-open screen
  Widget _buildMemberSelector(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tap area to open selection screen
        InkWell(
          onTap: _openAssigneeSelector,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? AppColors.neutral700 : AppColors.neutral300,
              ),
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person_add_outlined,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    _selectedAssignees.isEmpty
                        ? 'Tap to select assignees'
                        : '${_selectedAssignees.length} assignee${_selectedAssignees.length > 1 ? 's' : ''} selected',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          _selectedAssignees.isEmpty
                              ? (isDark
                                  ? AppColors.neutral500
                                  : AppColors.neutral400)
                              : theme.colorScheme.onSurface,
                      fontWeight:
                          _selectedAssignees.isNotEmpty
                              ? FontWeight.w500
                              : FontWeight.normal,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isDark ? AppColors.neutral500 : AppColors.neutral400,
                ),
              ],
            ),
          ),
        ),

        // Selected assignees display
        if (_selectedAssignees.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children:
                _selectedAssignees.map((user) {
                  return Chip(
                    avatar: CircleAvatar(
                      radius: 12,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      backgroundImage:
                          user.avatarUrl != null
                              ? NetworkImage(user.avatarUrl!)
                              : null,
                      child:
                          user.avatarUrl == null
                              ? Text(
                                user.name.isNotEmpty
                                    ? user.name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              )
                              : null,
                    ),
                    label: Text(user.name, style: theme.textTheme.bodySmall),
                    deleteIcon: Icon(
                      Icons.close,
                      size: 16,
                      color:
                          isDark ? AppColors.neutral400 : AppColors.neutral600,
                    ),
                    onDeleted: () {
                      setState(() {
                        _selectedAssignees.removeWhere((u) => u.id == user.id);
                      });
                    },
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
          ),
        ],
      ],
    );
  }

  /// Open the full-screen assignee selection
  Future<void> _openAssigneeSelector() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder:
            (context) => AssigneeSelectionScreen(
              initiallySelected: _selectedAssignees,
              initialSupervisorIds: _supervisorIds,
            ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedAssignees.clear();
        _selectedAssignees.addAll((result['users'] as List<UserModel>?) ?? []);
        _supervisorIds.clear();
        _supervisorIds.addAll((result['supervisorIds'] as List<String>?) ?? []);
      });
      // Unfocus any text field to prevent keyboard from auto-opening
      FocusManager.instance.primaryFocus?.unfocus();
    }
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
          value: _selectedTeamId,
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
            setState(() => _selectedTeamId = value);
          },
        );
      },
    );
  }
}
