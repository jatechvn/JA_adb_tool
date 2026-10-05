import 'package:flutter/material.dart';

import '../services/smart_upload_service.dart';
import '../utils.dart';
import 'app_colors.dart';
import 'glass_dialog.dart';
import 'localization.dart';

/// Preflight dialog shown when uploading files/folders to Android,
/// allowing the user to review the batch and choose how to resolve filename conflicts.
class UploadConflictDialog extends StatefulWidget {
  final UploadBatchPlan plan;
  final AppColors colors;

  const UploadConflictDialog({
    super.key,
    required this.plan,
    required this.colors,
  });

  @override
  State<UploadConflictDialog> createState() => _UploadConflictDialogState();
}

class _UploadConflictDialogState extends State<UploadConflictDialog> {
  FileConflictPolicy _selectedPolicy = FileConflictPolicy.rename;
  bool _showFileList = false;

  @override
  Widget build(BuildContext context) {
    final conflicts = widget.plan.conflicts;
    final hasConflicts = conflicts.isNotEmpty;

    return GlassDialog(
      width: 640,
      title: context.tr('upload_dialog_title'),
      icon: Icons.cloud_upload_rounded,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Target path info capsule
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: widget.colors.subCardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: widget.colors.subCardBorder),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_open_rounded,
                  size: 18,
                  color: widget.colors.accentCyan,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('android_side'),
                        style: TextStyle(
                          color: widget.colors.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.plan.targetDirectory,
                        style: TextStyle(
                          color: widget.colors.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'JetBrains Mono',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: widget.colors.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: widget.colors.accentCyan.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '${context.tr('files_count_unit').replaceAll('{count}', widget.plan.totalFiles.toString())} • ${Utils.formatBytes(widget.plan.totalBytes)}',
                    style: TextStyle(
                      color: widget.colors.accentCyan,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Conflict alert banner if duplicate files exist
          if (hasConflicts) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: widget.colors.accentAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: widget.colors.accentAmber.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 20,
                    color: widget.colors.accentAmber,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context
                          .tr('upload_conflict_desc')
                          .replaceAll('{count}', conflicts.length.toString()),
                      style: TextStyle(
                        color: widget.colors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Policy selection tiles
            Text(
              context.tr('upload_conflict_title'),
              style: TextStyle(
                color: widget.colors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            _buildPolicyOption(
              policy: FileConflictPolicy.rename,
              title: context.tr('conflict_policy_rename'),
              subtitle: context.tr('conflict_policy_rename_desc'),
              icon: Icons.drive_file_rename_outline_rounded,
            ),
            const SizedBox(height: 6),
            _buildPolicyOption(
              policy: FileConflictPolicy.overwrite,
              title: context.tr('conflict_policy_overwrite'),
              subtitle: context.tr('conflict_policy_overwrite_desc'),
              icon: Icons.find_replace_rounded,
            ),
            const SizedBox(height: 6),
            _buildPolicyOption(
              policy: FileConflictPolicy.skip,
              title: context.tr('conflict_policy_skip'),
              subtitle: context.tr('conflict_policy_skip_desc'),
              icon: Icons.skip_next_rounded,
            ),
            const SizedBox(height: 6),
            _buildPolicyOption(
              policy: FileConflictPolicy.ask,
              title: context.tr('conflict_policy_ask'),
              subtitle: context.tr('conflict_policy_ask_desc'),
              icon: Icons.question_mark_rounded,
            ),
            const SizedBox(height: 10),
          ],

          // Collapsible list of files to preview
          InkWell(
            onTap: () => setState(() => _showFileList = !_showFileList),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _showFileList
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_right_rounded,
                    size: 18,
                    color: widget.colors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    context
                        .tr('view_upload_file_list')
                        .replaceAll(
                          '{count}',
                          widget.plan.totalFiles.toString(),
                        ),
                    style: TextStyle(
                      color: widget.colors.accentCyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_showFileList) ...[
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: widget.colors.subCardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: widget.colors.subCardBorder),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(8),
                itemCount: widget.plan.items.length,
                separatorBuilder: (_, _) => Divider(
                  height: 6,
                  color: widget.colors.subCardBorder.withValues(alpha: 0.3),
                ),
                itemBuilder: (context, index) {
                  final item = widget.plan.items[index];
                  return Row(
                    children: [
                      Icon(
                        item.isConflict
                            ? Icons.warning_amber_rounded
                            : Icons.insert_drive_file_outlined,
                        size: 16,
                        color: item.isConflict
                            ? widget.colors.accentAmber
                            : widget.colors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.relativePath,
                          style: TextStyle(
                            color: widget.colors.textPrimary,
                            fontSize: 11.5,
                            fontFamily: 'JetBrains Mono',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        Utils.formatBytes(item.totalBytes),
                        style: TextStyle(
                          color: widget.colors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      if (item.isConflict) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: widget.colors.accentAmber.withValues(
                              alpha: 0.18,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            context.tr('conflict_item_conflict_badge'),
                            style: TextStyle(
                              color: widget.colors.accentAmber,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 18),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: Text(
                  context.tr('cancel'),
                  style: TextStyle(color: widget.colors.textSecondary),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00ADB5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                label: Text(
                  context.tr('start_upload'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () => Navigator.of(context).pop(_selectedPolicy),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyOption({
    required FileConflictPolicy policy,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedPolicy == policy;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedPolicy = policy),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? widget.colors.accentColor.withValues(alpha: 0.14)
                : widget.colors.subCardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? widget.colors.accentCyan.withValues(alpha: 0.70)
                  : widget.colors.subCardBorder,
              width: isSelected ? 1.2 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? widget.colors.accentCyan
                          : widget.colors.textSecondary.withValues(alpha: 0.5),
                      width: isSelected ? 5 : 1.5,
                    ),
                  ),
                ),
              ),
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? widget.colors.accentCyan
                    : widget.colors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isSelected
                            ? widget.colors.accentCyan
                            : widget.colors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: widget.colors.textMuted,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
