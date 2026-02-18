import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/user_model.dart';
import '../../data/providers/data_cache_provider.dart';
import '../../data/services/cloud_functions_service.dart';
import '../../data/services/notification_service.dart';
import '../../core/constants/app_spacing.dart';

/// Screen for Super Admins to manage which users' tasks are hidden
/// from Team Admin reports.
///
/// Design decisions:
///  - User list consumed from [DataCacheProvider.allUsers] — no extra Firestore listener.
///  - Exempt list consumed from [DataCacheProvider.cachedExemptIds] — no Cloud Function read.
///  - Optimistic toggle: updates the provider immediately, then fires the write in background.
///  - Client-side search with 300ms debounce prevents unnecessary rebuilds.
///  - Per-user loading state prevents double-tap issues.
class ReportExemptScreen extends StatefulWidget {
  const ReportExemptScreen({super.key});

  @override
  State<ReportExemptScreen> createState() => _ReportExemptScreenState();
}

class _ReportExemptScreenState extends State<ReportExemptScreen> {
  final CloudFunctionsService _cloudFunctions = CloudFunctionsService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  final Set<String> _savingUserIds = {}; // Users currently being toggled
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _searchQuery = value.toLowerCase().trim());
    });
  }

  /// Toggle a user's exempt status and immediately save to backend.
  ///
  /// IMPORTANT: reads [DataCacheProvider.cachedExemptIds] live at the moment
  /// of the call — never from a closure parameter — to prevent the race
  /// condition where two rapid toggles compute their new sets from the same
  /// stale snapshot and the second write silently overwrites the first.
  Future<void> _toggleUser(String userId) async {
    if (_savingUserIds.contains(userId)) return; // Prevent double-tap

    final cache = context.read<DataCacheProvider>();
    // Read LIVE state at the moment of action, not from a captured closure.
    final currentExemptIds = Set<String>.from(cache.cachedExemptIds);
    final wasExempt = currentExemptIds.contains(userId);

    // Optimistic UI: update the provider immediately
    final newIds = Set<String>.from(currentExemptIds);
    if (wasExempt) {
      newIds.remove(userId);
    } else {
      newIds.add(userId);
    }
    cache.setExemptIds(newIds);
    setState(() => _savingUserIds.add(userId));

    try {
      await _cloudFunctions.updateReportExemptList(newIds.toList());
      // Firestore stream in DataCacheProvider will confirm the write automatically.
    } catch (e) {
      // Revert optimistic update on failure
      cache.setExemptIds(currentExemptIds);
      if (!mounted) return;
      NotificationService.showInAppNotification(
        context,
        title: 'Error',
        message: 'Failed to update: $e',
        icon: Icons.error_outline,
        backgroundColor: Colors.red.shade700,
      );
    } finally {
      if (mounted) setState(() => _savingUserIds.remove(userId));
    }
  }

  List<UserModel> _filterUsers(List<UserModel> users, Set<String> exemptIds) {
    // Only show active users (no point exempting pending/revoked)
    var filtered = users.where((u) => u.status == UserStatus.active).toList();

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((u) {
        final name = u.name.toLowerCase();
        final email = u.email.toLowerCase();
        return name.contains(_searchQuery) || email.contains(_searchQuery);
      }).toList();
    }

    // Sort: exempt first, then alphabetical by name
    filtered.sort((a, b) {
      final aExempt = exemptIds.contains(a.id);
      final bExempt = exemptIds.contains(b.id);
      if (aExempt != bExempt) return aExempt ? -1 : 1;
      return a.name.compareTo(b.name);
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Exempt Users'),
      ),
      body: Consumer<DataCacheProvider>(
        builder: (context, cache, _) {
          final allUsers = cache.allUsers;
          final exemptIds = cache.cachedExemptIds;
          final filtered = _filterUsers(allUsers, exemptIds);

          return Column(
            children: [
              // Info banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 20,
                        color: theme.colorScheme.onPrimaryContainer),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Toggle users whose tasks should be hidden from Team Admin reports. Changes are saved automatically.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              // Exempt count chip
              if (exemptIds.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      avatar: const Icon(Icons.visibility_off, size: 16),
                      label: Text(
                          '${exemptIds.length} user${exemptIds.length == 1 ? '' : 's'} exempt'),
                      backgroundColor: theme.colorScheme.errorContainer
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ),

              // User list — show spinner until BOTH user list AND exempt list
              // have delivered their first snapshot. Checking only allUsers.isEmpty
              // would show a permanent spinner for orgs with zero users, and would
              // briefly show all toggles as OFF if exemptIds arrives after allUsers.
              Expanded(
                child: (!cache.allUsersLoaded || !cache.exemptListLoaded)
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? Center(
                            child: Text(
                              _searchQuery.isNotEmpty
                                  ? 'No users match "$_searchQuery"'
                                  : 'No active users found',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final user = filtered[index];
                              final isExempt = exemptIds.contains(user.id);
                              final isSaving =
                                  _savingUserIds.contains(user.id);

                              return SwitchListTile(
                                value: isExempt,
                                onChanged: isSaving
                                    ? null // Disable while saving
                                    : (_) => _toggleUser(user.id),
                                title: Text(
                                  user.name,
                                  style: theme.textTheme.titleSmall,
                                ),
                                subtitle: Text(
                                  user.email,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                secondary: isSaving
                                    ? const SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          ),
                                        ),
                                      )
                                    : CircleAvatar(
                                        backgroundColor: isExempt
                                            ? theme.colorScheme.errorContainer
                                            : theme.colorScheme
                                                .surfaceContainerHighest,
                                        child: Icon(
                                          isExempt
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          size: 20,
                                          color: isExempt
                                              ? theme.colorScheme.error
                                              : theme.colorScheme
                                                  .onSurfaceVariant,
                                        ),
                                      ),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}
