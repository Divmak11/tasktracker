import 'package:flutter/material.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/user_repository.dart';

/// Full-screen modal for selecting task assignees
class AssigneeSelectionScreen extends StatefulWidget {
  final List<UserModel> initiallySelected;

  const AssigneeSelectionScreen({super.key, this.initiallySelected = const []});

  @override
  State<AssigneeSelectionScreen> createState() =>
      _AssigneeSelectionScreenState();
}

class _AssigneeSelectionScreenState extends State<AssigneeSelectionScreen> {
  final UserRepository _userRepository = UserRepository();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedIds = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Pre-populate with initially selected users
    _selectedIds.addAll(widget.initiallySelected.map((u) => u.id));
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
        title: const Text('Select Assignees'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: _selectedIds.isEmpty ? null : _handleConfirm,
            icon: const Icon(Icons.check),
            label: Text('Done (${_selectedIds.length})'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                        : null,
                filled: true,
                fillColor: isDark ? AppColors.neutral800 : AppColors.neutral100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.large),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Selected count info
          if (_selectedIds.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              child: Row(
                children: [
                  Icon(
                    Icons.people,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${_selectedIds.length} selected',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _selectedIds.clear()),
                    child: const Text('Clear all'),
                  ),
                ],
              ),
            ),

          // User list
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

                final allUsers =
                    snapshot.data!
                        .where((u) => u.status == UserStatus.active)
                        .toList();

                // Apply search filter
                final filteredUsers =
                    _searchQuery.isEmpty
                        ? allUsers
                        : allUsers.where((u) {
                          final query = _searchQuery.toLowerCase();
                          return u.name.toLowerCase().contains(query) ||
                              u.email.toLowerCase().contains(query);
                        }).toList();

                // Sort: selected first, then alphabetically
                filteredUsers.sort((a, b) {
                  final aSelected = _selectedIds.contains(a.id);
                  final bSelected = _selectedIds.contains(b.id);
                  if (aSelected && !bSelected) return -1;
                  if (!aSelected && bSelected) return 1;
                  return a.name.compareTo(b.name);
                });

                if (filteredUsers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color:
                              isDark
                                  ? AppColors.neutral600
                                  : AppColors.neutral400,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'No users found',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color:
                                isDark
                                    ? AppColors.neutral400
                                    : AppColors.neutral600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    final isSelected = _selectedIds.contains(user.id);

                    return _buildUserTile(user, isSelected, theme, isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(
    UserModel user,
    bool isSelected,
    ThemeData theme,
    bool isDark,
  ) {
    return ListTile(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedIds.remove(user.id);
          } else {
            _selectedIds.add(user.id);
          }
        });
      },
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor:
                isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primaryContainer,
            backgroundImage:
                user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
            child:
                user.avatarUrl == null
                    ? Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color:
                            isSelected
                                ? Colors.white
                                : theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                    : null,
          ),
          if (isSelected)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? AppColors.neutral900 : Colors.white,
                    width: 2,
                  ),
                ),
                child: const Icon(Icons.check, size: 12, color: Colors.white),
              ),
            ),
        ],
      ),
      title: Text(
        user.name,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        user.email,
        style: theme.textTheme.bodySmall?.copyWith(
          color: isDark ? AppColors.neutral400 : AppColors.neutral600,
        ),
      ),
      trailing: Checkbox(
        value: isSelected,
        onChanged: (value) {
          setState(() {
            if (value == true) {
              _selectedIds.add(user.id);
            } else {
              _selectedIds.remove(user.id);
            }
          });
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }

  void _handleConfirm() async {
    // Fetch full user models for selected IDs
    final allUsers = await _userRepository.getAllUsersStream().first;
    final selectedUsers =
        allUsers.where((u) => _selectedIds.contains(u.id)).toList();

    if (mounted) {
      Navigator.pop(context, selectedUsers);
    }
  }
}
