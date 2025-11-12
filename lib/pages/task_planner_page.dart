// lib/pages/task_planner_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TaskPlannerPage extends StatefulWidget {
  const TaskPlannerPage({super.key});

  @override
  State<TaskPlannerPage> createState() => _TaskPlannerPageState();
}

class _TaskPlannerPageState extends State<TaskPlannerPage> with WidgetsBindingObserver {
  static const _prefsKey = 'weekly_tasks_v2'; // bumped version
  late SharedPreferences _prefs;


  // Task model: id and text.
  // We store List<Map<String, String>> as JSON: [{'id': '123', 'text': 'Drink water'}]
  List<Map<String, String>> _tasks = [];

  // Completed task ids for the current week.
  Set<String> _completedIds = {};

  // The week id for which _completedIds is valid, e.g. "2025-W46"
  String? _completedWeekId;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPrefsAndLoad();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // compute current ISO week id like "2025-W46"
  String _currentWeekId([DateTime? date]) {
    final dt = date ?? DateTime.now().toUtc();
    // ISO week date algorithm
    // Thursday-based week: week 1 is the week with Jan 4th.
    final thursday = dt.add(Duration(days: (4 - dt.weekday)));
    final weekYear = thursday.year;
    final firstJan = DateTime.utc(weekYear, 1, 1);
    final daysBetween = thursday.difference(firstJan).inDays;
    final weekNumber = (daysBetween / 7).floor() + 1;
    return '$weekYear-W${weekNumber.toString().padLeft(2, '0')}';
  }

  Future<void> _initPrefsAndLoad() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(raw);
        final tasksRaw = decoded['tasks'] as List<dynamic>? ?? [];
        _tasks = tasksRaw
            .map((e) => {
                  'id': e['id'] as String? ?? '',
                  'text': e['text'] as String? ?? '',
                })
            .toList();
        _completedWeekId = decoded['completedWeekId'] as String?;
        final completedList = List<String>.from(decoded['completedIds'] ?? <String>[]);
        _completedIds = completedList.toSet();
      } catch (_) {
        _createEmptyState();
      }
    } else {
      _createEmptyState();
    }

    // If saved week differs from current week, clear completions (start fresh week).
    final nowWeek = _currentWeekId();
    if (_completedWeekId != nowWeek) {
      _completedWeekId = nowWeek;
      _completedIds.clear();
      await _saveState();
    }

    setState(() => _loading = false);
  }

  void _createEmptyState() {
    _tasks = [];
    _completedIds = {};
    _completedWeekId = _currentWeekId();
  }

  Future<void> _saveState() async {
    final payload = {
      'tasks': _tasks,
      'completedWeekId': _completedWeekId,
      'completedIds': _completedIds.toList(),
    };
    await _prefs.setString(_prefsKey, jsonEncode(payload));
  }

  Future<void> _addTask() async {
    final controller = TextEditingController();
    final res = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add weekly task'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Task description'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(controller.text.trim()), child: const Text('Add')),
        ],
      ),
    );

    if (res != null && res.isNotEmpty) {
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      setState(() => _tasks.add({'id': id, 'text': res}));
      await _saveState();
    }
  }

  Future<void> _editTask(int index) async {
    final task = _tasks[index];
    final controller = TextEditingController(text: task['text']);
    final res = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit task'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );

    if (res != null && res.isNotEmpty) {
      setState(() => _tasks[index]['text'] = res);
      await _saveState();
    }
  }

  Future<void> _removeTask(int index) async {
    final removed = _tasks.removeAt(index);
    // also remove completion if present
    _completedIds.remove(removed['id']);
    await _saveState();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed "${removed['text']}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            setState(() => _tasks.insert(index, removed));
            await _saveState();
          },
        ),
      ),
    );
  }

  Future<void> _toggleComplete(String id, bool value) async {
    setState(() {
      if (value) {
        _completedIds.add(id);
      } else {
        _completedIds.remove(id);
      }
    });
    await _saveState();
  }

  // Manually reset completions for the current week (keeps tasks)
  Future<void> _resetWeek() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset this week'),
        content: const Text('This will clear all completions for the current week. Tasks will remain.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _completedIds.clear());
      _completedWeekId = _currentWeekId();
      await _saveState();
    }
  }

  // Called when app lifecycle changes; useful to detect week rollovers while app is in background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkWeekRollover();
    }
    super.didChangeAppLifecycleState(state);
  }

  // If week changed while the app wasn't active, reset completions automatically.
  Future<void> _checkWeekRollover() async {
    final nowWeek = _currentWeekId();
    if (_completedWeekId != nowWeek) {
      setState(() {
        _completedWeekId = nowWeek;
        _completedIds.clear();
      });
      await _saveState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New week — task completions reset')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _tasks.length;
    final done = _completedIds.length;
    final progress = total == 0 ? 0.0 : done / total;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Weekly Tasks (recurring)'),
            const SizedBox(height: 2),
            Text(
              _completedWeekId ?? _currentWeekId(),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset completions for this week',
            onPressed: _resetWeek,
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Clear all tasks',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear all tasks?'),
                  content: const Text('This will remove all tasks permanently.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Clear')),
                  ],
                ),
              );
              if (confirmed == true) {
                setState(() {
                  _tasks.clear();
                  _completedIds.clear();
                });
                await _saveState();
              }
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(value: progress),
                ),
                const SizedBox(width: 12),
                Text('${(progress * 100).round()}%'),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No weekly tasks yet.'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add task'),
                        onPressed: _addTask,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: _tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final task = _tasks[i];
                    final id = task['id']!;
                    final text = task['text'] ?? '';
                    final completed = _completedIds.contains(id);

                    return Card(
                      child: ListTile(
                        leading: Checkbox(
                          value: completed,
                          onChanged: (v) => _toggleComplete(id, v ?? false),
                        ),
                        title: Text(
                          text,
                          style: TextStyle(
                            decoration: completed ? TextDecoration.lineThrough : null,
                            color: completed ? Colors.grey : null,
                          ),
                        ),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editTask(i),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _removeTask(i),
                          ),
                        ]),
                        onTap: () => _toggleComplete(id, !completed),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add task'),
        onPressed: _addTask,
      ),
    );
  }
}
