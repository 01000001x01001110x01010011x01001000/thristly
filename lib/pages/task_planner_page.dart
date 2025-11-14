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
  static const _prefsKey = 'weekly_tasks_v2';
  late SharedPreferences _prefs;

  List<Map<String, String>> _tasks = [];
  Set<String> _completedIds = {};
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

  String _currentWeekId([DateTime? date]) {
    final dt = (date ?? DateTime.now()).toUtc();
    final thursday = dt.add(Duration(days: (4 - (dt.weekday))));
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

    final nowWeek = _currentWeekId();
    if (_completedWeekId != nowWeek) {
      _completedWeekId = nowWeek;
      _completedIds.clear();
      await _saveState();
    }

    if (mounted) setState(() => _loading = false);
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

  Future<void> _showAddEditSheet({int? editIndex}) async {
    final isEdit = editIndex != null;
    final controller = TextEditingController(text: isEdit ? _tasks[editIndex]['text'] : '');
    await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(
                children: [
                  Text(isEdit ? 'Edit task' : 'Add weekly task', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  )
                ],
              ),
              TextField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(hintText: 'Task description'),
                onSubmitted: (_) => Navigator.of(ctx).pop(controller.text.trim()),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                      child: Text(isEdit ? 'Save' : 'Add')),
                ),
              ]),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    ).then((res) async {
      if (res != null && res.isNotEmpty) {
        if (isEdit) {
          setState(() => _tasks[editIndex!]['text'] = res);
        } else {
          final id = DateTime.now().microsecondsSinceEpoch.toString();
          setState(() => _tasks.add({'id': id, 'text': res}));
        }
        await _saveState();
      }
    });
  }

  Future<void> _removeTaskAt(int index) async {
    final removed = _tasks.removeAt(index);
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkWeekRollover();
    }
    super.didChangeAppLifecycleState(state);
  }

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
    final progress = total == 0 ? 0.0 : (done / total);

    return Scaffold(
      appBar: AppBar(
        title: Text('Weekly Tasks (recurring)'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _resetWeek,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset completions for this week',
          ),
          IconButton(
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
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Clear all tasks',
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(value: progress, minHeight: 8),
                ),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_completedWeekId ?? _currentWeekId(), style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${(progress * 100).round()}% • $done/$total', style: Theme.of(context).textTheme.bodySmall),
                ),
              ])
            ]),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.checklist_rtl, size: 56, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 12),
                    const Text('No weekly tasks yet.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(icon: const Icon(Icons.add), label: const Text('Add task'), onPressed: () => _showAddEditSheet()),
                  ]),
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

                    return Dismissible(
                      key: ValueKey(id),
                      background: Container(
                        color: Colors.redAccent,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        final res = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete task'),
                            content: Text('Delete "$text"?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                              FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
                            ],
                          ),
                        );
                        return res == true;
                      },
                      onDismissed: (_) => _removeTaskAt(i),
                      child: Card(
                        child: ListTile(
                          visualDensity: VisualDensity.compact,
                          leading: Checkbox(
                            value: completed,
                            onChanged: (v) => _toggleComplete(id, v ?? false),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          title: Text(
                            text,
                            style: TextStyle(decoration: completed ? TextDecoration.lineThrough : null, color: completed ? Colors.grey : null),
                          ),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              tooltip: 'Edit task',
                              onPressed: () => _showAddEditSheet(editIndex: i),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20),
                              tooltip: 'Delete task',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete task'),
                                    content: Text('Delete "$text"?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                      FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
                                    ],
                                  ),
                                );
                                if (confirm == true) await _removeTaskAt(i);
                              },
                            ),
                          ]),
                          onTap: () => _toggleComplete(id, !completed),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add task'),
        onPressed: () => _showAddEditSheet(),
      ),
    );
  }
}
