// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // MethodChannel used to call platform-specific implementations
  static const _channel = MethodChannel('thristify/native_exact');

  // Controllers for the editable fields in the UI.
  final _title = TextEditingController(text: 'Thristify Reminder');
  final _body = TextEditingController(text: 'Time to hydrate! 💧');
  final _interval = TextEditingController(text: '15');

  // Daily window start and end times for scheduling reminders.
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 18, minute: 0);

  // Whether the schedule is currently active (as reported by platform).
  bool _scheduled = false;

  // Loading indicator while syncing
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _initPlatformPermissions();
    _syncStatus();
  }

  // Ask the platform to request post-notification permission (iOS/Android 13+)
  // and to request ignoring battery optimizations on Android if needed.
  Future<void> _initPlatformPermissions() async {
    try {
      await _channel.invokeMethod('requestPostNotificationsIfNeeded');
    } catch (_) {}
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizationsIfNeeded');
    } catch (_) {}
  }

  // Query the platform for current scheduling status and saved configuration.
  // Updates controllers and state accordingly.
  Future<void> _syncStatus() async {
    setState(() => _syncing = true);
    try {
      final res = await _channel.invokeMethod('getStatus') as Map?;
      if (res != null) {
        setState(() {
          _scheduled = (res['scheduled'] as bool?) ?? false;
          final t = res['title'] as String?;
          final b = res['body'] as String?;
          final m = res['minutes'];
          final sh = res['startHour'];
          final sm = res['startMinute'];
          final eh = res['endHour'];
          final em = res['endMinute'];
          if (t != null && t.isNotEmpty) _title.text = t;
          if (b != null && b.isNotEmpty) _body.text = b;
          if (m is int && m > 0) _interval.text = m.toString();
          if (sh is int && sm is int) _start = TimeOfDay(hour: sh, minute: sm);
          if (eh is int && em is int) _end = TimeOfDay(hour: eh, minute: em);
        });
      }
    } catch (_) {
      // ignore errors silently; keep existing values
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  // Show a time picker and update the start time if the user picks one.
  Future<void> _pickStart() async {
    final picked = await showTimePicker(context: context, initialTime: _start);
    if (picked != null) setState(() => _start = picked);
  }

  // Show a time picker and update the end time if the user picks one.
  Future<void> _pickEnd() async {
    final picked = await showTimePicker(context: context, initialTime: _end);
    if (picked != null) setState(() => _end = picked);
  }

  // Validate interval input; returns minutes or null if invalid.
  int? _validatedInterval() {
    final minutes = int.tryParse(_interval.text.trim());
    if (minutes == null || minutes <= 0) return null;
    return minutes;
  }

  // Start scheduling reminders using the platform channel. Sends current
  // title/body/interval and daily window to the native side.
  Future<void> _startSchedule() async {
    final minutes = _validatedInterval();
    if (minutes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid interval in minutes (number > 0).')),
      );
      return;
    }

    try {
      final res = await _channel.invokeMethod('scheduleWindow', {
        'minutes': minutes,
        'title': _title.text,
        'body': _body.text,
        'startHour': _start.hour,
        'startMinute': _start.minute,
        'endHour': _end.hour,
        'endMinute': _end.minute,
      });
      setState(() => _scheduled = res == 'scheduled');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Running: ${_start.format(context)}–${_end.format(context)}, every ${minutes}m'),
        ),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to schedule: ${e.message ?? 'unknown error'}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to schedule: $e')));
    }
  }

  // Cancel any scheduled reminders on the native side and update UI state.
  Future<void> _stopSchedule() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop reminders?'),
        content: const Text('This will stop scheduled reminders. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Stop')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _channel.invokeMethod('cancelExact');
    } catch (_) {}
    setState(() => _scheduled = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Reminders stopped')));
  }

  @override
  void dispose() {
    // Dispose controllers to free resources.
    _title.dispose();
    _body.dispose();
    _interval.dispose();
    super.dispose();
  }

  String _statusSummary() {
    final minutes = _validatedInterval() ?? int.tryParse(_interval.text) ?? 0;
    return 'Window ${_start.format(context)}–${_end.format(context)} • every ${minutes}m • ${_scheduled ? 'Running' : 'Stopped'}';
  }

  @override
  Widget build(BuildContext context) {
    final stopStartBtn = FilledButton.tonal(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
      ),
      onPressed: _scheduled ? _stopSchedule : _startSchedule,
      child: Text(_scheduled ? 'Stop reminders' : 'Start reminders'),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thristify'),
        actions: [
          IconButton(
            tooltip: 'Request permissions',
            onPressed: _initPlatformPermissions,
            icon: const Icon(Icons.privacy_tip_outlined),
          ),
          IconButton(
            tooltip: 'Sync status',
            onPressed: _syncStatus,
            icon: _syncing ? const Padding(
              padding: EdgeInsets.all(10.0),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ) : const Icon(Icons.sync),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Card with form fields
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: 'Notification title',
                      hintText: 'e.g. Thristify Reminder',
                      prefixIcon: Icon(Icons.title_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _body,
                    decoration: const InputDecoration(
                      labelText: 'Notification body',
                      hintText: 'e.g. Time to hydrate! 💧',
                      prefixIcon: Icon(Icons.message_outlined),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _interval,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'Interval (minutes)',
                          prefixIcon: Icon(Icons.timer_outlined),
                          helperText: 'Minimum 1 minute',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Status chip
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Chip(
                        avatar: Icon(_scheduled ? Icons.check_circle : Icons.pause_circle,
                            color: _scheduled ? Colors.green.shade700 : Colors.red.shade700, size: 18),
                        label: Text(_scheduled ? 'Running' : 'Stopped'),
                        backgroundColor: (_scheduled ? Colors.green : Colors.red).withOpacity(0.08),
                      ),
                    ]),
                  ]),
                  const SizedBox(height: 12),
                  // Window pickers
                  Row(children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickStart,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.6)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.wb_sunny_outlined, size: 20),
                            const SizedBox(width: 12),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('From', style: TextStyle(fontSize: 12, color: Colors.black54)),
                              const SizedBox(height: 2),
                              Text(_start.format(context), style: const TextStyle(fontWeight: FontWeight.w600)),
                            ]),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _pickEnd,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.6)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.nights_stay_outlined, size: 20),
                            const SizedBox(width: 12),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('Until', style: TextStyle(fontSize: 12, color: Colors.black54)),
                              const SizedBox(height: 2),
                              Text(_end.format(context), style: const TextStyle(fontWeight: FontWeight.w600)),
                            ]),
                          ]),
                        ),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),

            const SizedBox(height: 16),

            // Start/Stop button
            stopStartBtn,

            const SizedBox(height: 12),

            // Status summary & explanation
            Text(
              _statusSummary(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Android: exact via AlarmManager (foreground, background, or terminated). '
              'iOS: scheduled within daily window while respecting OS limits.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),

            const SizedBox(height: 18),

            // Helpful tips card
            Card(
              color: Theme.of(context).cardColor,
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Tips', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text('• Use shorter intervals during testing, then increase before release.'),
                  const SizedBox(height: 6),
                  const Text('• Ensure "ignore battery optimizations" is enabled on Android for reliable scheduling.'),
                  const SizedBox(height: 6),
                  const Text('• Add privacy policy if using notification analytics or user data.'),
                ]),
              ),
            ),

            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }
}
