import 'dart:async' show unawaited;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/api_service.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show window;
import '../providers/saved_files_provider.dart';

/// Reusable subject-grouped file browser.
/// Used by both NotesViewWidget and QuestionPapersViewWidget.
class SubjectFilesView extends ConsumerStatefulWidget {
  final SavedFileType fileType;
  final String title;
  final String subtitle;
  final IconData headerIcon;
  final Color accentColor;
  final String emptyTitle;
  final String emptyHint;
  final IconData emptyIcon;

  const SubjectFilesView({
    super.key,
    required this.fileType,
    required this.title,
    required this.subtitle,
    required this.headerIcon,
    required this.accentColor,
    required this.emptyTitle,
    required this.emptyHint,
    required this.emptyIcon,
  });

  @override
  ConsumerState<SubjectFilesView> createState() => _SubjectFilesViewState();
}

class _SubjectFilesViewState extends ConsumerState<SubjectFilesView>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grouped = ref
        .watch(savedFilesProvider.notifier)
        .groupedBySubject(widget.fileType);
    // Re-build when provider state changes
    ref.watch(savedFilesProvider);

    final isMobile = MediaQuery.of(context).size.width < 600;

    return FadeTransition(
      opacity: _fade,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Page Header ──────────────────────────────────────────────────
          _PageHeader(
            title: widget.title,
            subtitle: widget.subtitle,
            icon: widget.headerIcon,
            accentColor: widget.accentColor,
            fileCount: ref
                .watch(savedFilesProvider)
                .where((f) => f.type == widget.fileType)
                .length,
            isMobile: isMobile,
          ),

          // ── Content ──────────────────────────────────────────────────────
          Expanded(
            child: grouped.isEmpty
                ? _EmptyState(
                    icon: widget.emptyIcon,
                    title: widget.emptyTitle,
                    hint: widget.emptyHint,
                    accentColor: widget.accentColor,
                  )
                : ListView(
                    padding: EdgeInsets.fromLTRB(
                        isMobile ? 16 : 24, 16, isMobile ? 16 : 24, 32),
                    children: grouped.entries.map((entry) {
                      return _SubjectGroup(
                        subjectName: entry.key,
                        files: entry.value,
                        accentColor: widget.accentColor,
                        onRemove: (id) =>
                            ref.read(savedFilesProvider.notifier).remove(id),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final int fileCount;
  final bool isMobile;

  const _PageHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.fileCount,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 24, isMobile ? 16 : 24, isMobile ? 16 : 24, 16),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: AppColors.getBorderColor(context))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: isMobile ? 20 : 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getHeadingColor(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (fileCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$fileCount file${fileCount == 1 ? '' : 's'}',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: isMobile ? 12 : 13,
                    color: AppColors.getBodyColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SubjectGroup extends StatefulWidget {
  final String subjectName;
  final List<SavedFile> files;
  final Color accentColor;
  final void Function(String id) onRemove;

  const _SubjectGroup({
    required this.subjectName,
    required this.files,
    required this.accentColor,
    required this.onRemove,
  });

  @override
  State<_SubjectGroup> createState() => _SubjectGroupState();
}

class _SubjectGroupState extends State<_SubjectGroup> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject header row
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: widget.accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.subjectName,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getHeadingColor(context),
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${widget.files.length}',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: widget.accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.getBodyColor(context),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // File list
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                Divider(height: 1, color: AppColors.getBorderColor(context)),
                ...widget.files.map((file) => _FileCard(
                      file: file,
                      accentColor: widget.accentColor,
                      onRemove: () => widget.onRemove(file.id),
                    )),
              ],
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _FileCard extends StatefulWidget {
  final SavedFile file;
  final Color accentColor;
  final VoidCallback onRemove;

  const _FileCard({
    required this.file,
    required this.accentColor,
    required this.onRemove,
  });

  @override
  State<_FileCard> createState() => _FileCardState();
}

class _FileCardState extends State<_FileCard> {
  bool _hovered = false;

  void _openFile() {
    final url = widget.file.fileUrl;
    final ext = url.split('.').last.split('?').first.toLowerCase();
    final isPdf = ext == 'pdf';

    if (kIsWeb) {
      // PDFs: use Google Docs Viewer to avoid Chrome's built-in viewer failing
      // on Cloudinary image-type delivery URLs.
      final openUrl = isPdf
          ? 'https://docs.google.com/viewer?url=${Uri.encodeComponent(url)}&embedded=true'
          : url;
      html.window.open(openUrl, '_blank');
    } else {
      unawaited(
          launchUrl(Uri.parse(url), webOnlyWindowName: '_blank'));
    }
  }

  void _downloadFile() async {
    final url = widget.file.fileUrl;
    final cleanUrl = url.split('?').first;

    // Get a signed URL from backend to bypass Cloudinary 401 on raw delivery.
    final signed = await ApiService().getSignedDownloadUrl(cleanUrl);
    if (signed != null && signed.isNotEmpty) {
      if (kIsWeb) {
        html.window.open(signed, '_blank');
      } else {
        unawaited(launchUrl(Uri.parse(signed), webOnlyWindowName: '_blank'));
      }
      return;
    }

    // Fallback: only add fl_attachment for raw-type URLs.
    String downloadUrl = cleanUrl;
    if (downloadUrl.contains('cloudinary.com') &&
        downloadUrl.contains('/raw/upload/')) {
      downloadUrl = downloadUrl.replaceFirst(
          '/raw/upload/', '/raw/upload/fl_attachment/');
    }
    if (kIsWeb) {
      html.window.open(downloadUrl, '_blank');
    } else {
      unawaited(launchUrl(Uri.parse(downloadUrl), webOnlyWindowName: '_blank'));
    }
  }


  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        color: _hovered
            ? widget.accentColor.withValues(alpha: 0.04)
            : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: isMobile
              ? _MobileLayout(
                  file: file,
                  accentColor: widget.accentColor,
                  onOpen: _openFile,
                  onDownload: _downloadFile,
                  onRemove: widget.onRemove,
                )
              : _DesktopLayout(
                  file: file,
                  accentColor: widget.accentColor,
                  hovered: _hovered,
                  onOpen: _openFile,
                  onDownload: _downloadFile,
                  onRemove: widget.onRemove,
                ),
        ),
      ),
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  final SavedFile file;
  final Color accentColor;
  final bool hovered;
  final VoidCallback onOpen;
  final VoidCallback onDownload;
  final VoidCallback onRemove;

  const _DesktopLayout({
    required this.file,
    required this.accentColor,
    required this.hovered,
    required this.onOpen,
    required this.onDownload,
    required this.onRemove,
  });

  static IconData _iconForFile(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
      return FeatherIcons.image;
    }
    if (ext == 'pdf') return FeatherIcons.fileText;
    if (['doc', 'docx'].contains(ext)) return FeatherIcons.file;
    if (['ppt', 'pptx'].contains(ext)) return FeatherIcons.monitor;
    if (['xls', 'xlsx'].contains(ext)) return FeatherIcons.grid;
    return FeatherIcons.paperclip;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // File icon
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child:
              Icon(_iconForFile(file.fileName), color: accentColor, size: 20),
        ),
        const SizedBox(width: 14),

        // File info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                file.fileName,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getHeadingColor(context),
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(FeatherIcons.user,
                      size: 10, color: AppColors.getBodyColor(context)),
                  const SizedBox(width: 4),
                  Text(
                    file.sharedBy,
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: AppColors.getBodyColor(context)),
                  ),
                  const SizedBox(width: 10),
                  Icon(FeatherIcons.clock,
                      size: 10, color: AppColors.getBodyColor(context)),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM d, y').format(file.savedAt),
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: AppColors.getBodyColor(context)),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Action buttons (visible on hover)
        AnimatedOpacity(
          opacity: hovered ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 180),
          child: Row(
            children: [
              _ActionBtn(
                  icon: FeatherIcons.externalLink,
                  tooltip: 'Open',
                  onTap: onOpen,
                  color: accentColor),
              const SizedBox(width: 6),
              _ActionBtn(
                  icon: FeatherIcons.download,
                  tooltip: 'Download',
                  onTap: onDownload,
                  color: accentColor),
              const SizedBox(width: 6),
              _ActionBtn(
                  icon: FeatherIcons.trash2,
                  tooltip: 'Remove',
                  onTap: onRemove,
                  color: Colors.red),
            ],
          ),
        ),
      ],
    );
  }
}

class _MobileLayout extends StatelessWidget {
  final SavedFile file;
  final Color accentColor;
  final VoidCallback onOpen;
  final VoidCallback onDownload;
  final VoidCallback onRemove;

  const _MobileLayout({
    required this.file,
    required this.accentColor,
    required this.onOpen,
    required this.onDownload,
    required this.onRemove,
  });

  static IconData _iconForFile(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
      return FeatherIcons.image;
    }
    if (ext == 'pdf') return FeatherIcons.fileText;
    return FeatherIcons.paperclip;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child:
              Icon(_iconForFile(file.fileName), color: accentColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                file.fileName,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getHeadingColor(context),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text(
                '${file.sharedBy} · ${DateFormat('MMM d').format(file.savedAt)}',
                style: GoogleFonts.outfit(
                    fontSize: 10, color: AppColors.getBodyColor(context)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _ActionBtn(
            icon: FeatherIcons.externalLink,
            tooltip: 'Open',
            onTap: onOpen,
            color: accentColor),
        const SizedBox(width: 4),
        _ActionBtn(
            icon: FeatherIcons.trash2,
            tooltip: 'Remove',
            onTap: onRemove,
            color: Colors.red),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  const _ActionBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;
  final Color accentColor;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.hint,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child:
                Icon(icon, size: 52, color: accentColor.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.getHeadingColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.getBodyColor(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FeatherIcons.messageSquare, size: 14, color: accentColor),
                const SizedBox(width: 8),
                Text(
                  'Go to Messages → tap 💾 on any file',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
