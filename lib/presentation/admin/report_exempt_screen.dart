import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/user_model.dart';
import '../../data/services/cloud_functions_service.dart';
import '../../data/services/notification_service.dart';
import '../../core/constants/app_spacing.dart';

/// Screen for Super Admins to manage which users' tasks are hidden
/// from Team Admin reports.
///
/// Design decisions:
///  - Loads all users via a single Firestore stream (there are < 100).
///  - Exempt list fetched once on init from the Cloud Function.
///  - Client-side search with 300ms debounce prevents API flooding.
///  - Each toggle immediately saves to the backend (auto-save per toggle).
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

  // State
  Set<String> _exemptIds = {};
  final Set<String> _savingUserIds = {}; // Users currently being toggled
  bool _isLoading = true;
  String _searchQuery = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadExemptList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadExemptList() async {
    try {
      final ids = await _cloudFunctions.getReportExemptList();
      if (!mounted) return;
      setState(() {
        _exemptIds = ids.toSet();
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load exempt list: $e';
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _searchQuery = value.toLowerCase().trim());
    });
  }

  /// Toggle a user's exempt status and immediately save to backend.
  Future<void> _toggleUser(String userId) async {
    if (_savingUserIds.contains(userId)) return; // Prevent double-tap

    // Optimistic UI toggle
    final wasExempt = _exemptIds.contains(userId);
    setState(() {
      _savingUserIds.add(userId);
      if (wasExempt) {
        _exemptIds.remove(userId);
      } else {
        _exemptIds.add(userId);
      }
    });

    try {
      await _cloudFunctions.updateReportExemptList(_exemptIds.toList());
      if (!mounted) return;
      setState(() => _savingUserIds.remove(userId));
    } catch (e) {
      if (!mounted) return;
      // Revert on failure
      setState(() {
        if (wasExempt) {
          _exemptIds.add(userId);
        } else {
          _exemptIds.remove(userId);
        }
        _savingUserIds.remove(userId);
      });

      NotificationService.showInAppNotification(
        context,
        title: 'Error',
        message: 'Failed to update: $e',
        icon: Icons.error_outline,
        backgroundColor: Colors.red.shade700,
      );
    }
  }

  List<UserModel> _filterUsers(List<UserModel> users) {
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
      final aExempt = _exemptIds.contains(a.id);
      final bExempt = _exemptIds.contains(b.id);
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: theme.colorScheme.error),
                        const SizedBox(height: AppSpacing.md),
                        Text(_errorMessage!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium),
                        const SizedBox(height: AppSpacing.md),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isLoading = true;
                              _errorMessage = null;
                            });
                            _loadExemptList();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Info banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.3),
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

                    // Exempt count
                    if (_exemptIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Chip(
                            avatar: const Icon(Icons.visibility_off, size: 16),
                            label: Text(
                                '${_exemptIds.length} user${_exemptIds.length == 1 ? '' : 's'} exempt'),
                            backgroundColor:
                                theme.colorScheme.errorContainer
                                    .withValues(alpha: 0.5),
                          ),
                        ),
                      ),

                    // User list
                    Expanded(
                      child: StreamBuilder<List<UserModel>>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .snapshots()
                            .map((snapshot) => snapshot.docs
                                .map((doc) =>
                                    UserModel.fromJson(doc.data(), doc.id))
                                .toList()),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Text('Error loading users: ${snapshot.error}'),
                            );
                          }

                          final allUsers = snapshot.data ?? [];
                          final filtered = _filterUsers(allUsers);

                          if (filtered.isEmpty) {
                            return Center(
                              child: Text(
                                _searchQuery.isNotEmpty
                                    ? 'No users match "$_searchQuery"'
                                    : 'No active users found',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final user = filtered[index];
                              final isExempt = _exemptIds.contains(user.id);
                              final isSaving = _savingUserIds.contains(user.id);

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
                                            : theme.colorScheme.surfaceContainerHighest,
                                        child: Icon(
                                          isExempt
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          size: 20,
                                          color: isExempt
                                              ? theme.colorScheme.error
                                              : theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
