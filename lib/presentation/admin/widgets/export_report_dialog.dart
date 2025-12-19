import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/team_model.dart';
import '../../../data/repositories/team_repository.dart';
import '../../../data/services/cloud_functions_service.dart';
import '../../common/buttons/app_button.dart';

class ExportReportDialog extends StatefulWidget {
  const ExportReportDialog({super.key});

  @override
  State<ExportReportDialog> createState() => _ExportReportDialogState();
}

class _ExportReportDialogState extends State<ExportReportDialog> {
  final TeamRepository _teamRepository = TeamRepository();

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _selectedTeam = 'all';
  String _selectedStatus = 'all';
  bool _isGenerating = false;

  List<TeamModel> _teams = [];
  bool _isLoadingTeams = true;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    try {
      final teams = await _teamRepository.getAllTeamsStream().first;
      setState(() {
        _teams = teams;
        _isLoadingTeams = false;
      });
    } catch (e) {
      setState(() => _isLoadingTeams = false);
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(
            context,
          ).copyWith(colorScheme: Theme.of(context).colorScheme),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  // Notification plugin instance
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) async {
        // Open the file when notification is tapped
        if (response.payload != null) {
          await OpenFilex.open(response.payload!);
        }
      },
    );
  }

  Future<void> _showDownloadNotification(
    String filePath,
    String fileName,
  ) async {
    await _initNotifications();

    const androidDetails = AndroidNotificationDetails(
      'downloads',
      'Downloads',
      channelDescription: 'Download notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Report Downloaded',
      'Tap to open $fileName',
      details,
      payload: filePath,
    );
  }

  Future<Directory> _getReportDirectory() async {
    if (Platform.isAndroid) {
      // Request storage permission for Downloads folder access
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        // For Android 11+, try notification permission for download notification
        await Permission.notification.request();
      }

      // Use public Downloads folder for easy user access
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (await downloadsDir.exists()) {
        return downloadsDir;
      }
      // Fallback to path_provider's downloads directory
      final dir = await getDownloadsDirectory();
      if (dir != null) return dir;
      // Last fallback to app documents
      return await getApplicationDocumentsDirectory();
    } else {
      // iOS: Use documents directory
      return await getApplicationDocumentsDirectory();
    }
  }

  Future<void> _generateReport() async {
    setState(() => _isGenerating = true);

    try {
      final cloudFunctions = CloudFunctionsService();

      // Call backend to generate PDF
      final result = await cloudFunctions.exportReport(
        startDate: _startDate,
        endDate: _endDate,
        teamId: _selectedTeam,
        status: _selectedStatus,
      );

      if (!mounted) return;

      // Get PDF data (base64 string from backend)
      final pdfBase64 = result['pdfBase64'] as String;
      final taskCount = result['taskCount'] as int;

      // Convert base64 to bytes
      final pdfBytes = base64.decode(pdfBase64);

      // Generate filename
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final fileName = 'Task_Report_$dateStr.pdf';

      // Get save directory (Todo: Manager folder)
      final directory = await _getReportDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      // Save file
      await file.writeAsBytes(pdfBytes);

      if (!mounted) return;

      // Show download notification
      await _showDownloadNotification(filePath, fileName);

      // Close dialog and show success snackbar
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report saved ($taskCount tasks)'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: () => OpenFilex.open(filePath),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _shareReport() async {
    setState(() => _isGenerating = true);

    try {
      final cloudFunctions = CloudFunctionsService();

      final result = await cloudFunctions.exportReport(
        startDate: _startDate,
        endDate: _endDate,
        teamId: _selectedTeam,
        status: _selectedStatus,
      );

      if (!mounted) return;

      final pdfBase64 = result['pdfBase64'] as String;
      final taskCount = result['taskCount'] as int;
      final pdfBytes = base64.decode(pdfBase64);

      // Save to temp directory for sharing
      final tempDir = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final fileName = 'Task_Report_$dateStr.pdf';
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(pdfBytes);

      if (!mounted) return;

      // Use native share sheet
      await Share.shareXFiles(
        [XFile(tempFile.path)],
        subject: 'Task Report - $dateStr',
        text: 'Task Report with $taskCount tasks',
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.picture_as_pdf, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Export Report',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Date Range
            Text(
              'Date Range',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: _selectDateRange,
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
                      Icons.date_range,
                      color:
                          isDark ? AppColors.neutral400 : AppColors.neutral600,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '${DateFormat('MMM d, yyyy').format(_startDate)} - ${DateFormat('MMM d, yyyy').format(_endDate)}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color:
                          isDark ? AppColors.neutral600 : AppColors.neutral400,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Team Filter
            Text(
              'Team',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              value: _selectedTeam,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('All Teams')),
                if (_isLoadingTeams)
                  const DropdownMenuItem(
                    value: 'loading',
                    enabled: false,
                    child: Text('Loading teams...'),
                  )
                else
                  ..._teams.map(
                    (team) => DropdownMenuItem(
                      value: team.id,
                      child: Text(team.name),
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null && value != 'loading') {
                  setState(() => _selectedTeam = value);
                }
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            // Status Filter
            Text(
              'Status',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Status')),
                DropdownMenuItem(value: 'ongoing', child: Text('Ongoing')),
                DropdownMenuItem(value: 'completed', child: Text('Completed')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedStatus = value);
                }
              },
            ),
            const SizedBox(height: AppSpacing.xl),

            // Info
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Report includes task details, assignees, and status history.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Actions
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed:
                        _isGenerating
                            ? null
                            : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton(
                    text: 'Generate PDF',
                    onPressed: _isGenerating ? null : _generateReport,
                    isLoading: _isGenerating,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Show the export report dialog
Future<void> showExportReportDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) => const ExportReportDialog(),
  );
}
