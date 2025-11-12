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

  @override
  void initState() {
    super.initState();
    // Request any platform permissions we might need and synchronize UI state
    // with platform scheduling status.
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
    } catch (_) {}
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

  // Start scheduling reminders using the platform channel. Sends current
  // title/body/interval and daily window to the native side.
  Future<void> _startSchedule() async {
    final minutes = int.tryParse(_interval.text) ?? 15;
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
      // Expecting the native side to return 'scheduled' on success.
      setState(() => _scheduled = res == 'scheduled');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Running: ${_start.format(context)}–${_end.format(context)}, every ${minutes}m'),
        ),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: ${e.message}')));
    }
  }

  // Cancel any scheduled reminders on the native side and update UI state.
  Future<void> _stopSchedule() async {
    await _channel.invokeMethod('cancelExact');
    setState(() => _scheduled = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Stopped')));
  }

  @override
  void dispose() {
    // Dispose controllers to free resources.
    _title.dispose();
    _body.dispose();
    _interval.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Start/Stop button toggles scheduling based on current state.
    final btn = FilledButton(
      onPressed: _scheduled ? _stopSchedule : _startSchedule,
      child: Text(_scheduled ? 'Stop' : 'Start'),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('thristify')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Editable fields for notification title and body.
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 8),
          TextField(controller: _body, decoration: const InputDecoration(labelText: 'Body')),
          const SizedBox(height: 8),
          // Interval input and start/stop button.
          Row(children: [
            Expanded(
              child: TextField(
                controller: _interval,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Interval (minutes)',
                ),
              ),
            ),
            const SizedBox(width: 12),
            btn,
          ]),
          const SizedBox(height: 12),
          // Time pickers for daily start and end window.
          Row(
            children: [
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('From'),
                  subtitle: Text(_start.format(context)),
                  onTap: _pickStart,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Until'),
                  subtitle: Text(_end.format(context)),
                  onTap: _pickEnd,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Status display with color indicating running/stopped.
          Text(
            _scheduled ? 'Status: Running in daily window' : 'Status: Stopped',
            style: TextStyle(
              color: _scheduled ? Colors.green : Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          // Short explanation of platform behavior.
          const Text(
            'Android: exact via AlarmManager (foreground, background, or terminated). '
            'iOS: scheduled within daily window while respecting OS limits.',
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }
}
