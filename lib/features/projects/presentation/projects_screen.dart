import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/persian_format.dart';
import '../../../core/services/file_exchange.dart';
import '../../../core/widgets/common.dart';
import '../../editor/presentation/circuit_editor_screen.dart';
import '../../editor/presentation/circuit_preview.dart';
import '../application/projects_controller.dart';
import '../domain/circuit_project.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key, required this.onOpenProjectsTab});

  final VoidCallback onOpenProjectsTab;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final TextEditingController _searchController = TextEditingController();
  ProjectSort _sort = ProjectSort.recentlyUpdated;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(CircuitProject project) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder:
          (BuildContext context) => AlertDialog(
            title: const Text('حذف مدار'),
            content: Text(
              'مدار «${project.name}» برای همیشه حذف می‌شود. اگر پشتیبان نگرفته‌اید، '
              'امکان بازگردانی وجود ندارد.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('انصراف'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حذف کن'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await context.read<ProjectsController>().deleteProject(project.id);
      if (mounted) {
        _toast('مدار حذف شد.');
      }
    } catch (error) {
      if (mounted) {
        _toast('حذف انجام نشد: $error');
      }
    }
  }

  Future<void> _duplicate(CircuitProject project) async {
    try {
      final CircuitProject copy = await context
          .read<ProjectsController>()
          .duplicateProject(project.id);
      if (mounted) {
        _toast('«${copy.name}» ساخته شد.');
      }
    } catch (error) {
      if (mounted) {
        _toast('تکثیر انجام نشد: $error');
      }
    }
  }

  Future<void> _rename(CircuitProject project) async {
    final ProjectsController projectsController =
        context.read<ProjectsController>();
    final TextEditingController controller = TextEditingController(
      text: project.name,
    );
    final String? name = await showDialog<String>(
      context: context,
      builder:
          (BuildContext context) => AlertDialog(
            title: const Text('تغییر نام مدار'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 80,
              onSubmitted: (String value) => Navigator.pop(context, value),
              decoration: const InputDecoration(labelText: 'نام جدید'),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('انصراف'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: const Text('ذخیره'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) {
      return;
    }
    try {
      await projectsController.renameProject(project.id, name);
    } catch (error) {
      if (mounted) {
        _toast('تغییر نام انجام نشد: $error');
      }
    }
  }

  Future<void> _share(CircuitProject project) async {
    try {
      await FileExchange.shareTextFile(
        fileName: '${ProjectCodec.safeFileName(project.name)}.json',
        content: ProjectCodec.encode(project),
        mimeType: 'application/json',
        subject: 'پروژه Logic Lab — ${project.name}',
      );
    } catch (error) {
      if (mounted) {
        _toast('خروجی گرفتن انجام نشد: $error');
      }
    }
  }

  Future<void> _importProject() async {
    final ProjectsController controller = context.read<ProjectsController>();
    try {
      final PickedTextFile? file = await FileExchange.pickJsonFile();
      if (file == null) {
        return;
      }
      final CircuitProject project = ProjectCodec.decode(
        file.content,
        asCopy: true,
      );
      await controller.importProject(project);
      if (mounted) {
        _toast('مدار «${project.name}» وارد شد.');
      }
    } catch (error) {
      if (mounted) {
        _toast('وارد کردن انجام نشد: $error');
      }
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ProjectsController projects = context.watch<ProjectsController>();
    final ThemeData theme = Theme.of(context);
    final List<CircuitProject> visible = projects.search(_query, sort: _sort);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: projects.refresh,
          child: ResponsiveCenter(
            maxWidth: 1120,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 14),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'مدارهای من',
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              projects.isLoading
                                  ? 'در حال بارگذاری…'
                                  : '${PersianFormat.digits(projects.count)} مدار ذخیره شده',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'وارد کردن از فایل JSON',
                        onPressed: _importProject,
                        icon: const Icon(Icons.file_download_outlined),
                      ),
                      const SizedBox(width: 6),
                      FilledButton.icon(
                        onPressed: () => EditorLauncher.createAndOpen(context),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('مدار جدید'),
                      ),
                    ],
                  ),
                ),
                if (projects.count > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged:
                                (String value) =>
                                    setState(() => _query = value),
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'جست‌وجوی نام مدار…',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon:
                                  _query.isEmpty
                                      ? null
                                      : IconButton(
                                        tooltip: 'پاک کردن جست‌وجو',
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _query = '');
                                        },
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        PopupMenuButton<ProjectSort>(
                          tooltip: 'مرتب‌سازی',
                          initialValue: _sort,
                          onSelected:
                              (ProjectSort value) =>
                                  setState(() => _sort = value),
                          itemBuilder:
                              (
                                BuildContext context,
                              ) => const <PopupMenuEntry<ProjectSort>>[
                                PopupMenuItem<ProjectSort>(
                                  value: ProjectSort.recentlyUpdated,
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(Icons.update_rounded),
                                    title: Text('آخرین ویرایش'),
                                  ),
                                ),
                                PopupMenuItem<ProjectSort>(
                                  value: ProjectSort.recentlyCreated,
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      Icons.add_circle_outline_rounded,
                                    ),
                                    title: Text('تاریخ ساخت'),
                                  ),
                                ),
                                PopupMenuItem<ProjectSort>(
                                  value: ProjectSort.name,
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(Icons.sort_by_alpha_rounded),
                                    title: Text('نام'),
                                  ),
                                ),
                              ],
                          child: Container(
                            height: 50,
                            padding: const EdgeInsets.symmetric(horizontal: 13),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(Icons.sort_rounded, size: 19),
                                const SizedBox(width: 6),
                                Text(
                                  'مرتب‌سازی',
                                  style: theme.textTheme.labelMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child:
                      projects.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : projects.loadError != null
                          ? SingleChildScrollView(
                            child: InfoBanner(
                              tone: InfoBannerTone.danger,
                              message: projects.loadError!,
                            ),
                          )
                          : visible.isEmpty
                          ? SingleChildScrollView(
                            child: EmptyState(
                              icon:
                                  _query.isEmpty
                                      ? Icons.account_tree_outlined
                                      : Icons.search_off_rounded,
                              title:
                                  _query.isEmpty
                                      ? 'هنوز مداری ذخیره نشده'
                                      : 'مداری با این نام پیدا نشد',
                              message:
                                  _query.isEmpty
                                      ? 'یک مدار خالی بسازید یا یک فایل JSON وارد کنید. '
                                          'همه مدارها آفلاین روی دستگاه شما ذخیره می‌شوند.'
                                      : 'عبارت دیگری را امتحان کنید یا فیلتر جست‌وجو را پاک کنید.',
                              action:
                                  _query.isEmpty
                                      ? FilledButton.icon(
                                        onPressed:
                                            () => EditorLauncher.createAndOpen(
                                              context,
                                            ),
                                        icon: const Icon(Icons.add_rounded),
                                        label: const Text('ساخت مدار'),
                                      )
                                      : OutlinedButton(
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _query = '');
                                        },
                                        child: const Text('پاک کردن جست‌وجو'),
                                      ),
                            ),
                          )
                          : LayoutBuilder(
                            builder: (
                              BuildContext context,
                              BoxConstraints constraints,
                            ) {
                              final int columns =
                                  constraints.maxWidth > 900
                                      ? 3
                                      : constraints.maxWidth > 580
                                      ? 2
                                      : 1;
                              final double width =
                                  (constraints.maxWidth - (columns - 1) * 12) /
                                  columns;
                              return GridView.builder(
                                padding: const EdgeInsets.only(bottom: 8),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                      childAspectRatio:
                                          columns == 1 ? 1.35 : 1.05,
                                    ),
                                itemCount: visible.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final CircuitProject project = visible[index];
                                  return SizedBox(
                                    width: width,
                                    child: _ProjectCard(
                                      project: project,
                                      onOpen:
                                          () => EditorLauncher.open(
                                            context,
                                            project,
                                          ),
                                      onRename: () => _rename(project),
                                      onDuplicate: () => _duplicate(project),
                                      onShare: () => _share(project),
                                      onDelete: () => _confirmDelete(project),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.onOpen,
    required this.onRename,
    required this.onDuplicate,
    required this.onShare,
    required this.onDelete,
  });

  final CircuitProject project;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDuplicate;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SurfaceCard(
      onTap: onOpen,
      padding: EdgeInsets.zero,
      semanticLabel: 'مدار ${project.name}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(flex: 5, child: CircuitPreview(graph: project.graph)),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          project.name,
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          PersianFormat.relativeDate(project.updatedAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: <Widget>[
                            _MetaChip(
                              icon: Icons.memory_rounded,
                              label: PersianFormat.digits(
                                project.componentCount,
                              ),
                            ),
                            _MetaChip(
                              icon: Icons.linear_scale_rounded,
                              label: PersianFormat.digits(project.wireCount),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'گزینه‌های مدار',
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                    onSelected: (String value) {
                      switch (value) {
                        case 'rename':
                          onRename();
                        case 'duplicate':
                          onDuplicate();
                        case 'share':
                          onShare();
                        case 'delete':
                          onDelete();
                      }
                    },
                    itemBuilder:
                        (BuildContext context) =>
                            const <PopupMenuEntry<String>>[
                              PopupMenuItem<String>(
                                value: 'rename',
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    Icons.drive_file_rename_outline_rounded,
                                  ),
                                  title: Text('تغییر نام'),
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'duplicate',
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.copy_all_rounded),
                                  title: Text('تکثیر مدار'),
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'share',
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.ios_share_rounded),
                                  title: Text('خروجی JSON'),
                                ),
                              ),
                              PopupMenuDivider(),
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.delete_outline_rounded),
                                  title: Text('حذف'),
                                ),
                              ),
                            ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 3),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}
