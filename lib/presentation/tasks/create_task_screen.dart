import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_model.dart';
import '../../data/models/team_model.dart';
import '../../data/repositories/team_repository.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/cloud_functions_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/providers/auth_provider.dart';
import '../common/buttons/app_button.dart';
import '../common/inputs/app_text_field.dart';
import '../common/widgets/voice_input_button.dart';
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
  String _loadingMessage = '';

  // Image attachments
  final List<XFile> _pendingImages = [];

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
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
    FocusScope.of(context).unfocus();
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

          if (selectedDateTime.isBefore(now.add(const Duration(minutes: 1)))) {
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
      setState(() {
        _isLoading = true;
        _loadingMessage = 'Creating task...';
      });

      try {
        final hasImages = _pendingImages.isNotEmpty;
        final imageFiles = _pendingImages.map((xf) => File(xf.path)).toList();
        final imageCount = _pendingImages.length;

        // Step 1: Create the task
        final result = await _cloudFunctions.assignTask(
          title: taskTitle,
          subtitle: taskSubtitle,
          assignedType: assignedTypeStr,
          assignedTo: assigneeId,
          deadline: deadline,
          supervisorIds: _supervisorIds.isNotEmpty ? _supervisorIds : null,
        );

        final taskId = result['taskId'] as String?;

        // Step 2: Upload images synchronously if any
        if (hasImages && taskId != null && mounted) {
          setState(() {
            _loadingMessage = 'Uploading image 1 of $imageCount...';
          });

          try {
            final urls = await StorageService.uploadAll(
              taskId: taskId,
              files: imageFiles,
              onProgress: (completed, total) {
                if (mounted) {
                  setState(() {
                    _loadingMessage = completed == total
                        ? 'Finalizing...'
                        : 'Uploading image ${completed + 1} of $total...';
                  });
                }
              },
            );

            // Update task with attachment URLs
            if (mounted) {
              setState(() => _loadingMessage = 'Saving attachments...');
            }
            await _cloudFunctions.updateTask(
              taskId: taskId,
              attachmentUrls: urls,
            );
          } catch (uploadError) {
            // Task was created but images failed — warn user but don't block
            if (mounted) {
              NotificationService.showInAppNotification(
                context,
                title: 'Images Failed',
                message: 'Task created but image upload failed. You can retry from task details.',
                icon: Icons.warning_amber_rounded,
                backgroundColor: Colors.orange.shade700,
              );
            }
          }
        }

        // Step 3: Show success and pop
        if (mounted) {
          final message = _selectedAssignees.length > 1
              ? 'Task assigned to ${_selectedAssignees.length} members'
              : 'Task "$taskTitle" created successfully';
          NotificationService.showInAppNotification(
            context,
            title: 'Task Created',
            message: hasImages
                ? '$message with $imageCount attachment${imageCount > 1 ? 's' : ''}'
                : message,
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
          setState(() {
            _isLoading = false;
            _loadingMessage = '';
          });
        }
      }
    }
  }

  Future<void> _pickAttachmentImages() async {
    FocusScope.of(context).unfocus();
    final remaining = StorageService.maxAttachments - _pendingImages.length;
    if (remaining <= 0) return;

    final images = await StorageService.pickImages(remaining: remaining);
    if (images.isNotEmpty && mounted) {
      setState(() {
        _pendingImages.addAll(images);
      });
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
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                behavior: HitTestBehavior.translucent,
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
                        suffixIcon: VoiceInputButton(
                          fieldName: 'Title',
                          controller: _titleController,
                          maxLength: 100,
                          onTextConfirmed: (text, mode) {
                            setState(() {
                              if (mode == TextInsertMode.append) {
                                _titleController.text = '${_titleController.text} $text'.trim();
                              } else {
                                _titleController.text = text;
                              }
                            });
                          },
                        ),
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
                        textInputAction: TextInputAction.done,
                        suffixIcon: VoiceInputButton(
                          fieldName: 'Description',
                          controller: _subtitleController,
                          maxLength: 500,
                          onTextConfirmed: (text, mode) {
                            setState(() {
                              if (mode == TextInsertMode.append) {
                                _subtitleController.text = '${_subtitleController.text} $text'.trim();
                              } else {
                                _subtitleController.text = text;
                              }
                            });
                          },
                        ),
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
                          FocusScope.of(context).unfocus();
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

                      // Image Attachments Section
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Attachments',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Add up to ${StorageService.maxAttachments} images',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.neutral500 : AppColors.neutral400,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _buildImageAttachmentArea(theme, isDark),
                    ],
                  ),
                ),
              ),
              ),
            ),

            // Bottom Action
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPaddingMobile),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoading && _loadingMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Text(
                        _loadingMessage,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  AppButton(
                    text: 'Create Task',
                    onPressed: _handleCreate,
                    isLoading: _isLoading,
                  ),
                ],
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
          onTap: () {
            FocusScope.of(context).unfocus();
            _openAssigneeSelector();
          },
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
    FocusScope.of(context).unfocus();
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
            FocusScope.of(context).unfocus();
            setState(() => _selectedTeamId = value);
          },
        );
      },
    );
  }

  /// Build the image attachment area: thumbnails + add button
  Widget _buildImageAttachmentArea(ThemeData theme, bool isDark) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _pendingImages.length +
            (_pendingImages.length < StorageService.maxAttachments ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          // Last item is the "add" button
          if (index == _pendingImages.length) {
            return _buildAddImageTile(theme, isDark);
          }
          return _buildImageThumbnail(index, theme, isDark);
        },
      ),
    );
  }

  Widget _buildAddImageTile(ThemeData theme, bool isDark) {
    return InkWell(
      onTap: _pickAttachmentImages,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          borderRadius: BorderRadius.circular(AppRadius.medium),
          color: theme.colorScheme.primary.withValues(alpha: 0.05),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              color: theme.colorScheme.primary,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              'Add',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageThumbnail(int index, ThemeData theme, bool isDark) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          child: Image.file(
            File(_pendingImages[index].path),
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () {
              setState(() => _pendingImages.removeAt(index));
            },
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
