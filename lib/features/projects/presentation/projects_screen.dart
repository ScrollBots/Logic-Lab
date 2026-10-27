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
  bool _selectMode = false;
  final Set<String> _selected = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ignore: unused_element
  void _enterSelectMode() {
    setState(() {
      _selectMode = true;
      _selected.clear();
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selected.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  // ignore: unused_element
  void _selectAll(List<CircuitProject> visible) {
    setState(() {
      if (_selected.length == visible.length && visible.isNotEmpty) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(visible.map((CircuitProject p) => p.id));
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) {
      return;
    }
    final int count = _selected.length;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder:
          (BuildContext context) => AlertDialog(
            title: const Text('حذف مدارها'),
            content: Text(
              '$count مدار برای همیشه حذف می‌شود. اگر پشتیبان نگرفته‌اید، '
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
                child: const Text('حذف همه'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final ProjectsController controller = context.read<ProjectsController>();
    for (final String id in List<String>.from(_selected)) {
      try {
        await controller.deleteProject(id);
      } catch (_) {
        // Continue with the rest; the controller surfaces the error.
      }
    }
    if (mounted) {
      _toast('$count مدار حذف شد.');
      _exitSelectMode();
    }
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

    // App bar title/context based on select mode
    final bool selectMode = _selectMode;
    final int selectedCount = _selected.length;

    // Title: shows "مدارهای من" normally, or selection count in select mode
    final Widget appBarTitle =
        selectMode
            ? Row(
              children: <Widget>[
                const Icon(
                  Icons.check_box_outline_blank_rounded,
                  size: 20,
                  color: Colors.amber,
                ),
                const SizedBox(width: 6),
                Text(
                  'انتخاب $selectedCount مدار',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            )
            : const Text('مدارهای من');

    // Action button: Delete selected, visible only in select mode with selections
    final Widget? deleteActionButton =
        selectMode && selectedCount > 0
            ? FilledButton(
              onPressed: _deleteSelected,
              child: Text('حذف $selectedCount مدار'),
            )
            : null;

    // Back/close button: visible only in select mode
    final Widget? backButton =
        selectMode
            ? IconButton(
              tooltip: 'بازگشت',
              onPressed: _exitSelectMode,
              icon: const Icon(Icons.close_rounded),
            )
            : null;

    return Scaffold(
      appBar: AppBar(
        title: appBarTitle,
        actions: <Widget>[
          if (backButton != null) backButton,
          if (deleteActionButton != null) deleteActionButton,
        ],
        automaticallyImplyLeading: false,
      ),
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
                      // In select mode, show spacer instead of title area
                      if (selectMode)
                        const Spacer()
                      else
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'مدارهای من',
                                key: const Key('projects-page-title'),
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
                      // Select mode action button on the right
                      if (selectMode)
                        IconButton(
                          tooltip: 'انجام',
                          onPressed: _exitSelectMode,
                          icon: const Icon(Icons.done_rounded),
                        )
                      else
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
                                      ? 'هنود مداری ذخیره نشده'
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
                                  return _ProjectCard(
                                    project: project,
                                    isSelectMode: _selectMode,
                                    selected: _selected.contains(project.id),
                                    onToggleSelection:
                                        () => _toggleSelection(project.id),
                                    onOpen:
                                        () => EditorLauncher.open(
                                          context,
                                          project,
                                        ),
                                    onRename: () => _rename(project),
                                    onDuplicate: () => _duplicate(project),
                                    onShare: () => _share(project),
                                    onDelete: () => _confirmDelete(project),
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
    required this.isSelectMode,
    required this.selected,
    required this.onToggleSelection,
    required this.onOpen,
    required this.onRename,
    required this.onDuplicate,
    required this.onShare,
    required this.onDelete,
  });

  final CircuitProject project;
  final bool isSelectMode;
  final bool selected;
  final VoidCallback onToggleSelection;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDuplicate;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // In select mode, the onTap is for toggling selection, not opening
    final bool tapIsSelection = isSelectMode;
    return GestureDetector(
      onTap: tapIsSelection ? onToggleSelection : onOpen,
      onLongPress: !tapIsSelection ? onOpen : null,
      child: SurfaceCard(
        onTap: tapIsSelection ? null : onOpen,
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
                    // Selection checkbox/toggle in select mode
                    if (isSelectMode)
                      Container(
                        margin: const EdgeInsets.only(
                          top: 10,
                          bottom: 10,
                          right: 8,
                        ),
                        child: SelectionCheckbox(
                          isSelected: selected,
                          onChanged: onToggleSelection,
                        ),
                      )
                    else
                      const SizedBox(width: 0, height: 0),
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
                    // In select mode, show checkmark; otherwise show popup menu
                    if (isSelectMode)
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 20,
                        color:
                            selected
                                ? Colors.amber
                                : theme.colorScheme.onSurfaceVariant,
                      )
                    else
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
                            (
                              BuildContext context,
                            ) => const <PopupMenuEntry<String>>[
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
      ),
    );
  }
}

class SelectionCheckbox extends StatelessWidget {
  const SelectionCheckbox({super.key, required this.isSelected, required this.onChanged});

  final bool isSelected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color:
            isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: theme.colorScheme.outline, width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: IconButton(
        icon:
            isSelected
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : const Icon(
                  Icons.check_outlined,
                  size: 16,
                  color: Colors.grey,
                ),
        onPressed: onChanged,
        tooltip: isSelected ? 'انتخاب شده' : 'انتخاب',
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
