import 'package:flutter/material.dart';
import '../../core/constants/app_spacing.dart';
import '../../data/models/invite_model.dart';
import '../../data/models/team_model.dart';
import '../../data/services/cloud_functions_service.dart';
import '../../data/repositories/team_repository.dart';
import '../common/buttons/app_button.dart';
import '../common/inputs/app_text_field.dart';

class InviteUsersScreen extends StatefulWidget {
  const InviteUsersScreen({super.key});

  @override
  State<InviteUsersScreen> createState() => _InviteUsersScreenState();
}

class _InviteUsersScreenState extends State<InviteUsersScreen>
    with SingleTickerProviderStateMixin {
  final CloudFunctionsService _cloudFunctions = CloudFunctionsService();
  final TeamRepository _teamRepository = TeamRepository();
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late TabController _tabController;
  List<InviteModel> _invites = [];
  List<TeamModel> _teams = [];
  String? _selectedTeamId;
  bool _isLoading = true;
  bool _isSending = false;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _cloudFunctions.getInvites(),
        _teamRepository.getAllTeamsStream().first,
      ]);

      final invitesData = results[0] as Map<String, dynamic>;
      final teamsData = results[1] as List<TeamModel>;

      setState(() {
        _invites =
            (invitesData['invites'] as List<dynamic>)
                .map((e) => InviteModel.fromMap(Map<String, dynamic>.from(e)))
                .toList();
        _teams = teamsData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load data: $e')));
      }
    }
  }

  Future<void> _sendInvite() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);
    try {
      await _cloudFunctions.sendInvite(
        email: _emailController.text.trim(),
        teamId: _selectedTeamId,
      );

      _emailController.clear();
      setState(() {
        _selectedTeamId = null;
        _isSending = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invite sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadData();
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to send invite: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resendInvite(InviteModel invite) async {
    try {
      await _cloudFunctions.resendInvite(invite.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invite resent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to resend: $e')));
      }
    }
  }

  Future<void> _cancelInvite(InviteModel invite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Cancel Invite'),
            content: Text(
              'Are you sure you want to cancel the invite to ${invite.email}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Yes, Cancel'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      await _cloudFunctions.cancelInvite(invite.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invite cancelled')));
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to cancel: $e')));
      }
    }
  }

  List<InviteModel> get _filteredInvites {
    if (_filterStatus == 'all') return _invites;
    return _invites.where((i) => i.status.value == _filterStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Users'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Send Invite'), Tab(text: 'Invites List')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSendInviteTab(theme), _buildInvitesListTab(theme)],
      ),
    );
  }

  Widget _buildSendInviteTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPaddingMobile),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.large),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                    child: const Icon(
                      Icons.person_add_outlined,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invite New Users',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Send email invitations to new team members',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Email Input
            Text(
              'Email Address',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _emailController,
              hint: 'Enter email address',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: const Icon(Icons.email_outlined),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an email address';
                }
                final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                if (!emailRegex.hasMatch(value)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),

            const SizedBox(height: AppSpacing.lg),

            // Team Selection (Optional - for email mention only)
            Text(
              'Mention Team in Email (Optional)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: DropdownButtonFormField<String>(
                value: _selectedTeamId,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.group_outlined),
                ),
                hint: const Text('Select a team to mention in email'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('No team'),
                  ),
                  ..._teams.map(
                    (team) => DropdownMenuItem<String>(
                      value: team.id,
                      child: Text(team.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _selectedTeamId = value);
                },
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Info Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Invited users will receive an email with a Play Store download link. When they sign up with the same email, they will be auto-approved as members. Team assignment can be done later.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Send Button
            AppButton(
              text: 'Send Invite',
              onPressed: _sendInvite,
              isLoading: _isSending,
              isFullWidth: true,
              icon: Icons.send,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvitesListTab(ThemeData theme) {
    return Column(
      children: [
        // Filter Chips
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPaddingMobile,
            vertical: AppSpacing.sm,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'All', theme),
                const SizedBox(width: AppSpacing.sm),
                _buildFilterChip('pending', 'Pending', theme),
                const SizedBox(width: AppSpacing.sm),
                _buildFilterChip('accepted', 'Accepted', theme),
                const SizedBox(width: AppSpacing.sm),
                _buildFilterChip('expired', 'Expired', theme),
                const SizedBox(width: AppSpacing.sm),
                _buildFilterChip('cancelled', 'Cancelled', theme),
              ],
            ),
          ),
        ),

        const Divider(height: 1),

        // Invites List
        Expanded(
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredInvites.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mail_outline,
                          size: 64,
                          color: theme.disabledColor,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'No invites found',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.disabledColor,
                          ),
                        ),
                      ],
                    ),
                  )
                  : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(
                        AppSpacing.screenPaddingMobile,
                      ),
                      itemCount: _filteredInvites.length,
                      itemBuilder: (context, index) {
                        return _buildInviteCard(_filteredInvites[index], theme);
                      },
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String value, String label, ThemeData theme) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterStatus = value);
      },
      selectedColor: theme.colorScheme.primaryContainer,
      checkmarkColor: theme.colorScheme.primary,
    );
  }

  Widget _buildInviteCard(InviteModel invite, ThemeData theme) {
    final statusColor = _getStatusColor(invite.status);
    final teamName =
        invite.teamId != null
            ? _teams
                .firstWhere(
                  (t) => t.id == invite.teamId,
                  orElse:
                      () => TeamModel(
                        id: '',
                        name: 'Unknown Team',
                        adminId: '',
                        memberIds: [],
                        createdBy: '',
                      ),
                )
                .name
            : null;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: Icon(
                    Icons.email_outlined,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invite.email,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (teamName != null)
                        Text(
                          'Team: $teamName',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: Text(
                    invite.status.displayName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: theme.hintColor),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Sent ${_formatDate(invite.createdAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                if (invite.status == InviteStatus.pending) ...[
                  const SizedBox(width: AppSpacing.md),
                  Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: invite.isExpired ? Colors.red : theme.hintColor,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    invite.isExpired
                        ? 'Expired'
                        : 'Expires ${_formatDate(invite.expiresAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: invite.isExpired ? Colors.red : theme.hintColor,
                    ),
                  ),
                ],
              ],
            ),
            if (invite.canResend || invite.canCancel) ...[
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (invite.canResend)
                    TextButton.icon(
                      onPressed: () => _resendInvite(invite),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Resend'),
                    ),
                  if (invite.canCancel)
                    TextButton.icon(
                      onPressed: () => _cancelInvite(invite),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Cancel'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(InviteStatus status) {
    switch (status) {
      case InviteStatus.pending:
        return Colors.orange;
      case InviteStatus.accepted:
        return Colors.green;
      case InviteStatus.expired:
        return Colors.grey;
      case InviteStatus.cancelled:
        return Colors.red;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
