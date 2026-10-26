import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// TaskTrail - Campus Deadline Tracker (polished UI)
// Flutter + Provider + SharedPreferences + Material 3
// ============================================================

const List<String> kCategories = ['Assignment', 'Exam', 'Project', 'Other'];

class CatStyle {
  final IconData icon;
  final Color color;
  const CatStyle(this.icon, this.color);
}

const Map<String, CatStyle> kCatStyles = {
  'All': CatStyle(Icons.apps_rounded, Color(0xFF6C5CE7)),
  'Assignment': CatStyle(Icons.edit_note_rounded, Color(0xFF6C63FF)),
  'Exam': CatStyle(Icons.quiz_rounded, Color(0xFFFF5C7C)),
  'Project': CatStyle(Icons.rocket_launch_rounded, Color(0xFF00B894)),
  'Other': CatStyle(Icons.bookmark_rounded, Color(0xFFF39C12)),
};

CatStyle styleFor(String c) => kCatStyles[c] ?? kCatStyles['Other']!;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

Color cardColor(BuildContext c) =>
    isDark(c) ? const Color(0xFF1A1B30) : Colors.white;

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..load(),
      child: const TaskTrailApp(),
    ),
  );
}

// ------------------------------------------------------------
// MODEL
// ------------------------------------------------------------
class Task {
  final String id;
  final String title;
  final String description;
  final String category;
  final DateTime dueDate;
  final bool done;

  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.dueDate,
    this.done = false,
  });

  Task copyWith({bool? done}) => Task(
        id: id,
        title: title,
        description: description,
        category: category,
        dueDate: dueDate,
        done: done ?? this.done,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'dueDate': dueDate.toIso8601String(),
        'done': done,
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String,
        description: (j['description'] ?? '') as String,
        category: (j['category'] ?? 'Other') as String,
        dueDate: DateTime.parse(j['dueDate'] as String),
        done: (j['done'] ?? false) as bool,
      );
}

// ------------------------------------------------------------
// STATE (Provider)
// ------------------------------------------------------------
class AppState extends ChangeNotifier {
  List<Task> _tasks = [];
  bool loading = true;
  String? error;
  String query = '';
  String category = 'All';
  ThemeMode themeMode = ThemeMode.light;
  SharedPreferences? _prefs;

  List<Task> _demoTasks() {
    final d = dateOnly(DateTime.now());
    return [
      Task(
        id: 'demo1',
        title: 'Submit Flutter mini project',
        description: 'Push the code to GitHub and share the deployed link.',
        category: 'Project',
        dueDate: d,
      ),
      Task(
        id: 'demo2',
        title: 'DBMS assignment 3',
        description: 'Normalization and ER diagram questions.',
        category: 'Assignment',
        dueDate: d.add(const Duration(days: 2)),
      ),
      Task(
        id: 'demo3',
        title: 'Revise Operating Systems',
        description: 'Scheduling, deadlocks and memory management.',
        category: 'Exam',
        dueDate: d.add(const Duration(days: 5)),
      ),
    ];
  }

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs!.getString('tasks');
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        _tasks = list
            .map((e) => Task.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } else if (!(_prefs!.getBool('seeded') ?? false)) {
        _tasks = _demoTasks();
        await _prefs!.setBool('seeded', true);
        await _saveTasks();
      }
      query = _prefs!.getString('query') ?? '';
      category = _prefs!.getString('category') ?? 'All';
      themeMode =
          (_prefs!.getBool('dark') ?? false) ? ThemeMode.dark : ThemeMode.light;
      error = null;
    } catch (e) {
      error = 'Could not load your saved tasks.';
    }
    loading = false;
    notifyListeners();
  }

  Future<void> retry() async {
    loading = true;
    error = null;
    notifyListeners();
    await load();
  }

  Future<void> _saveTasks() async {
    await _prefs?.setString(
        'tasks', jsonEncode(_tasks.map((t) => t.toJson()).toList()));
  }

  List<Task> get visibleTasks {
    final q = query.trim().toLowerCase();
    final list = _tasks.where((t) {
      if (category != 'All' && t.category != category) return false;
      if (q.isEmpty) return true;
      return t.title.toLowerCase().contains(q) ||
          t.description.toLowerCase().contains(q);
    }).toList();
    list.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      return a.dueDate.compareTo(b.dueDate);
    });
    return list;
  }

  int get totalCount => _tasks.length;
  int get pendingCount => _tasks.where((t) => !t.done).length;
  int get doneCount => _tasks.where((t) => t.done).length;
  int get overdueCount {
    final today = dateOnly(DateTime.now());
    return _tasks.where((t) => !t.done && t.dueDate.isBefore(today)).length;
  }

  Future<void> addTask(Task t) async {
    _tasks.add(t);
    notifyListeners();
    await _saveTasks();
  }

  Future<void> toggleDone(String id) async {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i == -1) return;
    _tasks[i] = _tasks[i].copyWith(done: !_tasks[i].done);
    notifyListeners();
    await _saveTasks();
  }

  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
    await _saveTasks();
  }

  Future<void> setQuery(String v) async {
    query = v;
    notifyListeners();
    await _prefs?.setString('query', v);
  }

  Future<void> setCategory(String v) async {
    category = v;
    notifyListeners();
    await _prefs?.setString('category', v);
  }

  Future<void> toggleTheme() async {
    themeMode =
        themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    await _prefs?.setBool('dark', themeMode == ThemeMode.dark);
  }
}

// ------------------------------------------------------------
// APP + THEME
// ------------------------------------------------------------
ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF6C5CE7),
      brightness: b,
    ),
    scaffoldBackgroundColor:
        dark ? const Color(0xFF0F1020) : const Color(0xFFF4F5FB),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

class TaskTrailApp extends StatelessWidget {
  const TaskTrailApp({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.select<AppState, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      title: 'TaskTrail',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const HomeScreen(),
    );
  }
}

// ------------------------------------------------------------
// SHARED HELPERS
// ------------------------------------------------------------
Future<bool> confirmDelete(BuildContext context, Task t) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.red, size: 30),
      ),
      title: const Text('Delete this task?'),
      content: Text('"${t.title}" will be permanently removed.',
          textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return ok == true;
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Pill({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

({String label, Color color, IconData icon}) dueInfo(Task t) {
  if (t.done) {
    return (label: 'Completed', color: Colors.green, icon: Icons.check_circle);
  }
  final diff = dateOnly(t.dueDate).difference(dateOnly(DateTime.now())).inDays;
  if (diff < 0) {
    return (
      label: 'Overdue ${-diff}d',
      color: Colors.red,
      icon: Icons.warning_amber_rounded
    );
  }
  if (diff == 0) {
    return (label: 'Today', color: Colors.deepOrange, icon: Icons.bolt_rounded);
  }
  if (diff == 1) {
    return (label: 'Tomorrow', color: Colors.orange, icon: Icons.schedule);
  }
  if (diff < 7) {
    return (label: 'In $diff days', color: Colors.blue, icon: Icons.schedule);
  }
  return (
    label: DateFormat('d MMM').format(t.dueDate),
    color: Colors.blueGrey,
    icon: Icons.event_rounded
  );
}

// ------------------------------------------------------------
// HOME SCREEN
// ------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _search = TextEditingController();
  bool _synced = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openAdd() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const AddTaskSheet(),
    );
    if (added == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task added successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (!state.loading && !_synced) {
      _search.text = state.query;
      _synced = true;
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New task'),
      ),
      body: _body(context, state),
    );
  }

  Widget _body(BuildContext context, AppState state) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 64),
            const SizedBox(height: 12),
            Text(state.error!),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: () => context.read<AppState>().retry(),
                child: const Text('Try again')),
          ],
        ),
      );
    }

    final tasks = state.visibleTasks;
    final scheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _Header(state: state)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
            child: TextField(
              controller: _search,
              onChanged: (v) => context.read<AppState>().setQuery(v),
              decoration: InputDecoration(
                hintText: 'Search your tasks...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: state.query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _search.clear();
                          context.read<AppState>().setQuery('');
                        },
                      ),
                filled: true,
                fillColor: cardColor(context),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 54,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: ['All', ...kCategories].map((c) {
                final s = styleFor(c);
                final selected = state.category == c;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: ChoiceChip(
                    avatar: Icon(s.icon,
                        size: 18, color: selected ? Colors.white : s.color),
                    label: Text(c),
                    selected: selected,
                    showCheckmark: false,
                    selectedColor: s.color,
                    backgroundColor: cardColor(context),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : scheme.onSurface,
                    ),
                    onSelected: (_) => context.read<AppState>().setCategory(c),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Text(
              'Your tasks (${tasks.length})',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (tasks.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(hasAny: state.totalCount > 0),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _TaskTile(task: tasks[i]),
                childCount: tasks.length,
              ),
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------
// HEADER (gradient + progress ring)
// ------------------------------------------------------------
class _Header extends StatelessWidget {
  final AppState state;
  const _Header({required this.state});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final total = state.totalCount;
    final progress = total == 0 ? 0.0 : state.doneCount / total;
    final allDone = total > 0 && state.pendingCount == 0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 16, 20, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5B4BFF), Color(0xFF9B59F5)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_greeting(),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 15)),
                    const SizedBox(height: 2),
                    const Text('TaskTrail',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(DateFormat('EEEE, d MMMM').format(DateTime.now()),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Toggle theme',
                onPressed: () => context.read<AppState>().toggleTheme(),
                style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2)),
                icon: Icon(
                  state.themeMode == ThemeMode.dark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 78,
                  height: 78,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: v,
                            strokeWidth: 8,
                            strokeCap: StrokeCap.round,
                            backgroundColor: Colors.white24,
                            valueColor:
                                const AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                      ),
                      Text('${(progress * 100).round()}%',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        allDone
                            ? 'All caught up!'
                            : '${state.pendingCount} task${state.pendingCount == 1 ? '' : 's'} to go',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text('${state.doneCount} of $total completed',
                          style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _HeaderPill(
                              icon: Icons.schedule_rounded,
                              text: '${state.pendingCount} pending'),
                          if (state.overdueCount > 0)
                            _HeaderPill(
                                icon: Icons.warning_amber_rounded,
                                text: '${state.overdueCount} overdue'),
                        ],
                      ),
                    ],
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

class _HeaderPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HeaderPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// TASK TILE (swipe to delete, tap for details)
// ------------------------------------------------------------
class _TaskTile extends StatelessWidget {
  final Task task;
  const _TaskTile({required this.task});

  void _showDetails(BuildContext context) {
    final s = styleFor(task.category);
    final due = dueInfo(task);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.title,
                style: Theme.of(ctx)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _Pill(icon: s.icon, text: task.category, color: s.color),
                _Pill(icon: due.icon, text: due.label, color: due.color),
                _Pill(
                    icon: Icons.event_rounded,
                    text: DateFormat.yMMMd().format(task.dueDate),
                    color: Colors.blueGrey),
              ],
            ),
            const SizedBox(height: 16),
            Text(task.description.isEmpty
                ? 'No description added.'
                : task.description),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: () {
                  context.read<AppState>().toggleDone(task.id);
                  Navigator.pop(ctx);
                },
                icon: Icon(task.done
                    ? Icons.undo_rounded
                    : Icons.check_circle_rounded),
                label: Text(task.done ? 'Mark as pending' : 'Mark as done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = styleFor(task.category);
    final due = dueInfo(task);
    final dark = isDark(context);
    final messenger = ScaffoldMessenger.of(context);
    final titleColor = task.done
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45)
        : Theme.of(context).colorScheme.onSurface;

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirmDelete(context, task),
      onDismissed: (_) {
        context.read<AppState>().deleteTask(task.id);
        messenger.showSnackBar(const SnackBar(content: Text('Task deleted')));
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 26),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardColor(context),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.25 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showDetails(context),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 6, color: s.color),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () =>
                                  context.read<AppState>().toggleDone(task.id),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: task.done
                                      ? s.color
                                      : Colors.transparent,
                                  border: Border.all(color: s.color, width: 2),
                                ),
                                child: task.done
                                    ? const Icon(Icons.check_rounded,
                                        size: 18, color: Colors.white)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: titleColor,
                                      decoration: task.done
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      _Pill(
                                          icon: s.icon,
                                          text: task.category,
                                          color: s.color),
                                      _Pill(
                                          icon: due.icon,
                                          text: due.label,
                                          color: due.color),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              icon: Icon(Icons.delete_outline_rounded,
                                  color: Colors.grey.shade500),
                              onPressed: () async {
                                final ok = await confirmDelete(context, task);
                                if (ok && context.mounted) {
                                  context
                                      .read<AppState>()
                                      .deleteTask(task.id);
                                  messenger.showSnackBar(const SnackBar(
                                      content: Text('Task deleted')));
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// EMPTY STATE
// ------------------------------------------------------------
class _EmptyState extends StatelessWidget {
  final bool hasAny;
  const _EmptyState({required this.hasAny});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [
                  const Color(0xFF5B4BFF).withValues(alpha: 0.18),
                  const Color(0xFF9B59F5).withValues(alpha: 0.18),
                ]),
              ),
              child: Icon(
                hasAny ? Icons.search_off_rounded : Icons.task_alt_rounded,
                size: 60,
                color: const Color(0xFF6C5CE7),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              hasAny ? 'No matching tasks' : 'Nothing here yet',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              hasAny
                  ? 'Try a different keyword or category.'
                  : 'Tap "New task" to add your first deadline.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// ADD TASK SHEET (validation + duplicate-submit guard)
// ------------------------------------------------------------
class AddTaskSheet extends StatefulWidget {
  const AddTaskSheet({super.key});

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String _category = kCategories.first;
  DateTime? _due;
  bool _dateError = false;
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      );

  DateTime get _today => dateOnly(DateTime.now());

  bool get _isCustomDate {
    if (_due == null) return false;
    final d = dateOnly(_due!);
    return d != _today &&
        d != _today.add(const Duration(days: 1)) &&
        d != _today.add(const Duration(days: 7));
  }

  void _setDue(DateTime d) => setState(() {
        _due = dateOnly(d);
        _dateError = false;
      });

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) _setDue(picked);
  }

  Future<void> _submit() async {
    if (_submitting) return; // duplicate-submit guard
    final valid = _formKey.currentState!.validate();
    setState(() => _dateError = _due == null);
    if (!valid || _due == null) return;

    setState(() => _submitting = true);
    await context.read<AppState>().addTask(
          Task(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            title: _title.text.trim(),
            description: _desc.text.trim(),
            category: _category,
            dueDate: _due!,
          ),
        );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(t,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      );

  Widget _dateChip(String label, DateTime value) {
    final selected = _due != null && dateOnly(_due!) == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _setDue(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New task',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                decoration: _dec('Title *', Icons.title_rounded),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Title is required';
                  }
                  if (v.trim().length < 3) {
                    return 'Title must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _desc,
                maxLength: 200,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: _dec('Description (optional)', Icons.notes_rounded),
                validator: (v) => (v != null && v.length > 200)
                    ? 'Description cannot exceed 200 characters'
                    : null,
              ),
              _label('Category'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: kCategories.map((c) {
                  final s = styleFor(c);
                  final selected = _category == c;
                  return ChoiceChip(
                    avatar: Icon(s.icon,
                        size: 18, color: selected ? Colors.white : s.color),
                    label: Text(c),
                    selected: selected,
                    showCheckmark: false,
                    selectedColor: s.color,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : null,
                    ),
                    onSelected: (_) => setState(() => _category = c),
                  );
                }).toList(),
              ),
              _label('Due date *'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _dateChip('Today', _today),
                  _dateChip('Tomorrow', _today.add(const Duration(days: 1))),
                  _dateChip('Next week', _today.add(const Duration(days: 7))),
                  ChoiceChip(
                    avatar: const Icon(Icons.calendar_month_rounded, size: 18),
                    label: Text(_isCustomDate
                        ? DateFormat('d MMM yyyy').format(_due!)
                        : 'Pick date'),
                    selected: _isCustomDate,
                    onSelected: (_) => _pickDate(),
                  ),
                ],
              ),
              if (_dateError)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Text('Please choose a due date',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12)),
                ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_rounded),
                  label: const Text('Save task',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}