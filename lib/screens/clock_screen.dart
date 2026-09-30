import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';

class ClockScreen extends StatefulWidget {
  const ClockScreen({super.key});

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> {
  static const _setupCompleteKey = 'mindguard_clock_setup_complete';
  static const _securePasswordKey = 'mindguard_clock_password';
  static const _secureStorage = FlutterSecureStorage();

  DateTime _now = DateTime.now();
  Timer? _timer;
  bool _ready = false;
  bool _editing = false;
  bool _setupMode = false;
  bool _unlocking = false;

  double _editHour = 12;
  double _editMinute = 0;

  @override
  void initState() {
    super.initState();
    _loadState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _editing) return;
      setState(() => _now = DateTime.now());
    });
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final setupComplete = prefs.getBool(_setupCompleteKey) ?? false;

    if (!setupComplete && mounted) {
      await _showFirstInstallGuide();
      if (!mounted) return;
      setState(() {
        _setupMode = true;
        _editing = false;
      });
    }

    if (!mounted) return;
    setState(() => _ready = true);
  }

  Future<void> _showFirstInstallGuide() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Welcome'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MindGuard looks like an ordinary clock on purpose.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 14),
            Text('To set or unlock it:'),
            SizedBox(height: 8),
            Text('1. Long-press the small centre of the clock.'),
            Text('2. The clock will pause.'),
            Text('3. Move the hands to your secret time.'),
            Text('4. Tap the centre again to confirm.'),
            SizedBox(height: 14),
            Text('Choose a time you can remember, but that does not look obvious.'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Set my clock'),
          ),
        ],
      ),
    );
  }

  void _beginEditing(Offset localPosition, Size size) {
    if (!_ready || _editing || _unlocking) return;

    final center = Offset(size.width / 2, size.height / 2);
    final distance = (localPosition - center).distance;
    if (distance > size.width * 0.15) return;

    setState(() {
      _editing = true;
      _editHour = (_now.hour % 12) + _now.minute / 60.0;
      _editMinute = _now.minute.toDouble();
    });
  }

  void _updateHand(Offset localPosition, Size size) {
    if (!_editing) return;

    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    if (distance < size.width * 0.12) return;

    var angle = math.atan2(dx, -dy) * 180 / math.pi;
    if (angle < 0) angle += 360;

    // Inner zone moves the short hour hand; outer zone moves the long minute hand.
    setState(() {
      if (distance < size.width * 0.42) {
        _editHour = angle / 30.0;
      } else {
        _editMinute = (angle / 6).roundToDouble();
      }
    });
  }

  Future<void> _confirmHands() async {
    if (!_editing || !_ready || _unlocking) return;

    final minute = _editMinute.round() % 60;
    final hour12 = _editHour.round() % 12;
    final selected = hour12 == 0 ? 12 : hour12;
    final password = selected.toString().padLeft(2, '0') +
        minute.toString().padLeft(2, '0');

    if (_setupMode) {
      await _secureStorage.write(key: _securePasswordKey, value: password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_setupCompleteKey, true);

      if (!mounted) return;
      setState(() {
        _setupMode = false;
        _editing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your clock password has been set.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final storedPassword = await _secureStorage.read(key: _securePasswordKey);
    if (storedPassword == null) return;
    if (!mounted) return;

    if (password != storedPassword) {
      setState(() => _editing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The clock continues normally.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _unlocking = true);

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayTime = _editing ? _dateTimeFromHands() : _now;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final diameter = math.min(
                constraints.maxWidth * 0.84,
                constraints.maxHeight * 0.62,
              );

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Builder(
                    builder: (clockContext) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onLongPressStart: (details) {
                        _beginEditing(
                          details.localPosition,
                          Size(diameter, diameter),
                        );
                      },
                      onTapUp: (details) {
                        if (!_editing) return;
                        final center = Offset(diameter / 2, diameter / 2);
                        if ((details.localPosition - center).distance <=
                            diameter * 0.15) {
                          _confirmHands();
                        }
                      },
                      // Use the long-press movement recognizer so hand dragging
                      // continues after the central long-press without competing
                      // with a separate pan recognizer.
                      onLongPressMoveUpdate: (details) {
                        if (!_editing) return;
                        _updateHand(
                          details.localPosition,
                          Size(diameter, diameter),
                        );
                      },
                      child: SizedBox(
                        width: diameter,
                        height: diameter,
                        child: CustomPaint(
                          painter: _PolishedClockPainter(
                            time: displayTime,
                            editing: _editing,
                            hourHand: _editHour,
                            minuteHand: _editMinute,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    _formatTime(displayTime),
                    style: const TextStyle(
                      color: Color(0xFFF5F5F0),
                      fontSize: 30,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 2.4,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _formatDate(_now),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.48),
                      fontSize: 14,
                      letterSpacing: 1.0,
                    ),
                  ),
                  if (_editing) ...[
                    const SizedBox(height: 18),
                    Text(
                      _setupMode
                          ? 'Set your secret time'
                          : 'Set the hands to your secret time',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 13,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  DateTime _dateTimeFromHands() {
    final hour = _editHour.round() % 12;
    final minute = _editMinute.round() % 60;
    return DateTime(_now.year, _now.month, _now.day, hour, minute);
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  String _formatDate(DateTime time) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[time.month - 1]} ${time.day}, ${time.year}';
  }
}

class _PolishedClockPainter extends CustomPainter {
  final DateTime time;
  final bool editing;
  final double hourHand;
  final double minuteHand;

  _PolishedClockPainter({
    required this.time,
    required this.editing,
    required this.hourHand,
    required this.minuteHand,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFFF7F7F2));

    final rim = Paint()
      ..color = const Color(0xFF202020)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 1, rim);

    final tickPaint = Paint()..strokeCap = StrokeCap.round;

    for (var i = 0; i < 60; i++) {
      final angle = i * math.pi / 30;
      final isHour = i % 5 == 0;
      final outer = radius * 0.91;
      final inner = radius * (isHour ? 0.82 : 0.87);

      final start = Offset(
        center.dx + math.sin(angle) * inner,
        center.dy - math.cos(angle) * inner,
      );
      final end = Offset(
        center.dx + math.sin(angle) * outer,
        center.dy - math.cos(angle) * outer,
      );

      tickPaint
        ..strokeWidth = isHour ? 2.4 : 1.0
        ..color = isHour ? const Color(0xFF303030) : const Color(0xFF9A9A9A);

      canvas.drawLine(start, end, tickPaint);
    }

    final numberStyle = TextStyle(
      color: const Color(0xFF202020),
      fontSize: radius * 0.105,
      fontWeight: FontWeight.w500,
    );

    for (var number = 1; number <= 12; number++) {
      final angle = number * math.pi / 6;
      final position = Offset(
        center.dx + math.sin(angle) * radius * 0.69,
        center.dy - math.cos(angle) * radius * 0.69,
      );

      final painter = TextPainter(
        text: TextSpan(text: number.toString(), style: numberStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      painter.paint(
        canvas,
        position - Offset(painter.width / 2, painter.height / 2),
      );
    }

    final h = editing
        ? hourHand
        : (time.hour % 12) + time.minute / 60.0 + time.second / 3600.0;
    final m = editing ? minuteHand : time.minute + time.second / 60.0;

    // Minute hand first, hour hand second. The shorter hour hand stays
    // visually dominant at the centre and never creates a tangled crossing.
    _drawHand(canvas, center, radius * 0.70, m * math.pi / 30, 3.0);
    _drawHand(canvas, center, radius * 0.49, h * math.pi / 6, 5.0);

    canvas.drawCircle(
      center,
      radius * 0.055,
      Paint()..color = const Color(0xFF111111),
    );

    if (editing) {
      canvas.drawCircle(
        center,
        radius * 0.085,
        Paint()
          ..color = const Color(0xFF111111).withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _drawHand(
    Canvas canvas,
    Offset center,
    double length,
    double angle,
    double width,
  ) {
    final end = Offset(
      center.dx + math.sin(angle) * length,
      center.dy - math.cos(angle) * length,
    );

    final paint = Paint()
      ..color = const Color(0xFF111111)
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center, end, paint);
  }

  @override
  bool shouldRepaint(covariant _PolishedClockPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.editing != editing ||
        oldDelegate.hourHand != hourHand ||
        oldDelegate.minuteHand != minuteHand;
  }
}
