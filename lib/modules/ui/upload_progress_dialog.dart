import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic.dart';
import '../utils.dart';
import 'app_colors.dart';
import 'glass_dialog.dart';
import 'localization.dart';

/// Live progress dialog displaying both overall and per-file upload progress,
/// transfer speed, estimated time remaining (ETA), and a real-time file queue.
class UploadProgressDialog extends StatefulWidget {
  final UploadBatchPlan plan;
  final AppColors colors;
  final FileConflictPolicy conflictPolicy;

  const UploadProgressDialog({
    super.key,
    required this.plan,
    required this.colors,
    this.conflictPolicy = FileConflictPolicy.rename,
  });

  @override
  State<UploadProgressDialog> createState() => _UploadProgressDialogState();
}

class _UploadProgressDialogState extends State<UploadProgressDialog> {
  bool _isQueueExpanded = true;
  final ScrollController _queueScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final logic = Provider.of<AppLogic>(context, listen: false);
      logic.executeBatchUpload(
        plan: widget.plan,
        conflictPolicy: widget.conflictPolicy,
        onConflictPrompt: _handleConflictPrompt,
      );
    });
  }

  Future<FileConflictPolicy?> _handleConflictPrompt(FileUploadItem item) async {
    if (!mounted) return null;
    return showDialog<FileConflictPolicy>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => GlassDialog(
        width: 440,
        title: context.tr('conflict_item_conflict_badge'),
        icon: Icons.warning_amber_rounded,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${item.originalName}\n${Utils.formatBytes(item.totalBytes)}',
              style: TextStyle(
                color: widget.colors.textPrimary,
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(FileConflictPolicy.rename),
              child: Text(context.tr('conflict_policy_rename')),
            ),
            const SizedBox(height: 6),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(FileConflictPolicy.overwrite),
              child: Text(context.tr('conflict_policy_overwrite')),
            ),
            const SizedBox(height: 6),
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(FileConflictPolicy.skip),
              child: Text(context.tr('conflict_policy_skip')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _queueScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logic = Provider.of<AppLogic>(context);
    final progress =
        logic.batchUploadProgress ??
        BatchUploadProgress(
          totalFiles: widget.plan.totalFiles,
          completedFiles: 0,
          skippedFiles: 0,
          failedFiles: 0,
          totalBytes: widget.plan.totalBytes,
          transferredBytes: 0,
          overallProgress: 0.0,
          currentFileProgress: 0.0,
        );

    final isFinished = progress.isFinished;
    final isCancelled = progress.isCancelled;

    return GlassDialog(
      width: 660,
      title: isFinished
          ? (isCancelled
                ? context.tr('status_cancelled')
                : context.tr('upload_completed_title'))
          : context.tr('upload_dialog_title'),
      icon: isFinished
          ? (isCancelled
                ? Icons.cancel_outlined
                : Icons.check_circle_outline_rounded)
          : Icons.cloud_upload_rounded,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Overall Progress Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.colors.subCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.colors.subCardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          context.tr('overall_progress'),
                          style: TextStyle(
                            color: widget.colors.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${progress.completedFiles + progress.skippedFiles + progress.failedFiles}/${progress.totalFiles})',
                          style: TextStyle(
                            color: widget.colors.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${(progress.overallProgress * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: widget.colors.accentCyan,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'JetBrains Mono',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Overall progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.overallProgress,
                    minHeight: 8,
                    backgroundColor: widget.colors.borderDefault.withValues(
                      alpha: 0.25,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCancelled ? Colors.redAccent : widget.colors.accentCyan,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Stats row: Volume, Speed, ETA
                Row(
                  children: [
                    // Volume
                    Icon(
                      Icons.storage_rounded,
                      size: 14,
                      color: widget.colors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${Utils.formatBytes(progress.transferredBytes)} / ${Utils.formatBytes(progress.totalBytes)}',
                      style: TextStyle(
                        color: widget.colors.textSecondary,
                        fontSize: 11,
                        fontFamily: 'JetBrains Mono',
                      ),
                    ),
                    const Spacer(),

                    // Speed badge
                    if (!isFinished && progress.speedBytesPerSec > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: widget.colors.accentColor.withValues(
                            alpha: 0.14,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.speed_rounded,
                              size: 13,
                              color: widget.colors.accentCyan,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              progress.speedFormatted,
                              style: TextStyle(
                                color: widget.colors.accentCyan,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'JetBrains Mono',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // ETA badge
                    if (!isFinished) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: widget.colors.subCardBorder.withValues(
                            alpha: 0.25,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 13,
                              color: widget.colors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${context.tr('eta_remaining')}: ${progress.etaFormatted}',
                              style: TextStyle(
                                color: widget.colors.textSecondary,
                                fontSize: 10.5,
                                fontFamily: 'JetBrains Mono',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 2. Current File Card (shown when actively transferring)
          if (!isFinished && progress.currentItem != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.colors.subCardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: widget.colors.accentCyan.withValues(alpha: 0.40),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.insert_drive_file_rounded,
                        size: 16,
                        color: widget.colors.accentCyan,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          progress.currentItem!.relativePath,
                          style: TextStyle(
                            color: widget.colors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'JetBrains Mono',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(progress.currentFileProgress * 100).toInt()}%',
                        style: TextStyle(
                          color: widget.colors.accentCyan,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.currentFileProgress,
                      minHeight: 5,
                      backgroundColor: widget.colors.borderDefault.withValues(
                        alpha: 0.20,
                      ),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.colors.accentEmerald,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${Utils.formatBytes(progress.currentItem!.transferredBytes)} / ${Utils.formatBytes(progress.currentItem!.totalBytes)}',
                        style: TextStyle(
                          color: widget.colors.textMuted,
                          fontSize: 10.5,
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                      if (progress.currentItem!.isConflict)
                        Text(
                          context.tr('conflict_action_note'),
                          style: TextStyle(
                            color: widget.colors.accentAmber,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 3. Finished Summary Card
          if (isFinished) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isCancelled
                    ? Colors.redAccent.withValues(alpha: 0.12)
                    : widget.colors.accentEmerald.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCancelled
                      ? Colors.redAccent.withValues(alpha: 0.45)
                      : widget.colors.accentEmerald.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isCancelled
                        ? Icons.info_outline_rounded
                        : Icons.check_circle_rounded,
                    size: 22,
                    color: isCancelled
                        ? Colors.redAccent
                        : widget.colors.accentEmerald,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCancelled
                              ? context.tr('upload_cancelled_summary')
                              : context.tr('upload_completed_summary'),
                          style: TextStyle(
                            color: widget.colors.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context
                              .tr('upload_stats_summary')
                              .replaceAll(
                                '{completed}',
                                progress.completedFiles.toString(),
                              )
                              .replaceAll(
                                '{skipped}',
                                progress.skippedFiles.toString(),
                              )
                              .replaceAll(
                                '{failed}',
                                progress.failedFiles.toString(),
                              ),
                          style: TextStyle(
                            color: widget.colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 4. File Queue List Header
          InkWell(
            onTap: () => setState(() => _isQueueExpanded = !_isQueueExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _isQueueExpanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_right_rounded,
                    size: 18,
                    color: widget.colors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    context
                        .tr('queue_details')
                        .replaceAll(
                          '{count}',
                          widget.plan.items.length.toString(),
                        ),
                    style: TextStyle(
                      color: widget.colors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${progress.completedFiles}/${widget.plan.items.length}',
                    style: TextStyle(
                      color: widget.colors.accentCyan,
                      fontSize: 11.5,
                      fontFamily: 'JetBrains Mono',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4b. File Queue List Items
          if (_isQueueExpanded) ...[
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 170),
              decoration: BoxDecoration(
                color: widget.colors.subCardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: widget.colors.subCardBorder),
              ),
              child: Scrollbar(
                controller: _queueScrollController,
                thumbVisibility: true,
                child: ListView.separated(
                  controller: _queueScrollController,
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: widget.plan.items.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 6,
                    color: widget.colors.subCardBorder.withValues(alpha: 0.3),
                  ),
                  itemBuilder: (context, index) {
                    final item = widget.plan.items[index];
                    return _buildQueueItemRow(item);
                  },
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // 5. Actions Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!isFinished) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.colors.textSecondary,
                    side: BorderSide(color: widget.colors.subCardBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  icon: const Icon(Icons.skip_next_rounded, size: 16),
                  label: Text(
                    context.tr('skip_this_file'),
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  onPressed: () => logic.skipCurrentUploadFile(),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: Text(
                    context.tr('cancel_upload'),
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  onPressed: () => logic.cancelBatchUpload(),
                ),
              ] else ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00ADB5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    context.tr('close'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQueueItemRow(FileUploadItem item) {
    IconData statusIcon;
    Color statusColor;
    String statusLabel;

    switch (item.status) {
      case FileUploadItemStatus.pending:
        statusIcon = Icons.hourglass_empty_rounded;
        statusColor = widget.colors.textMuted;
        statusLabel = context.tr('status_pending');
        break;
      case FileUploadItemStatus.checking:
        statusIcon = Icons.search_rounded;
        statusColor = widget.colors.accentCyan;
        statusLabel = context.tr('status_checking');
        break;
      case FileUploadItemStatus.uploading:
        statusIcon = Icons.arrow_upward_rounded;
        statusColor = widget.colors.accentCyan;
        statusLabel = '${(item.progress * 100).toInt()}%';
        break;
      case FileUploadItemStatus.completed:
        statusIcon = Icons.check_circle_rounded;
        statusColor = widget.colors.accentEmerald;
        statusLabel = context.tr('status_completed');
        break;
      case FileUploadItemStatus.overwritten:
        statusIcon = Icons.check_circle_rounded;
        statusColor = widget.colors.accentAmber;
        statusLabel = context.tr('status_overwritten');
        break;
      case FileUploadItemStatus.skipped:
        statusIcon = Icons.redo_rounded;
        statusColor = widget.colors.textMuted;
        statusLabel = context.tr('status_skipped');
        break;
      case FileUploadItemStatus.failed:
        statusIcon = Icons.error_outline_rounded;
        statusColor = Colors.redAccent;
        statusLabel = context.tr('status_failed');
        break;
      case FileUploadItemStatus.cancelled:
        statusIcon = Icons.cancel_outlined;
        statusColor = widget.colors.textMuted;
        statusLabel = context.tr('status_cancelled');
        break;
    }

    return Row(
      children: [
        Icon(statusIcon, size: 15, color: statusColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.relativePath,
                style: TextStyle(
                  color: widget.colors.textPrimary,
                  fontSize: 11.5,
                  fontFamily: 'JetBrains Mono',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (item.targetName != item.originalName)
                Text(
                  '→ ${item.targetName}',
                  style: TextStyle(
                    color: widget.colors.accentCyan,
                    fontSize: 10,
                    fontFamily: 'JetBrains Mono',
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          Utils.formatBytes(item.totalBytes),
          style: TextStyle(color: widget.colors.textMuted, fontSize: 10.5),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            statusLabel,
            style: TextStyle(
              color: statusColor,
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
