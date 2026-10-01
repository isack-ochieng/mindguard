import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';

enum _ClockHand { hour, minute }

class ClockScreen extends StatefulWidget {
  const ClockScreen({super.key});

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> {
  static const _setupKey = 'mindguard_clock_setup_complete';
  static const _passwordKey = 'mindguard_clock_password';
  static const _secure = FlutterSecureStorage();
  static const _clockChannel = MethodChannel('com.contentfilter.clock');

  DateTime _now = DateTime.now();
  Timer? _timer;
  bool _ready = false;
  bool _editing = false;
  bool _setupMode = false;
  bool _unlocking = false;

  double _editHour = 12;
  double _editMinute = 0;
  _ClockHand _selected = _ClockHand.hour;
  bool _hourMoved = false;
  bool _minuteMoved = false;
  int _guideStep = 0;

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
    final configured = prefs.getBool(_setupKey) ?? false;

    if (!mounted) return;

    setState(() {
      _setupMode = !configured;
      _ready = true;
    });
  }

  void _beginEditing(Offset position, Size size) {
    if (!_ready || _editing || _unlocking) return;

    final center = Offset(size.width / 2, size.height / 2);
    if ((position - center).distance > size.width * 0.14) return;

    HapticFeedback.mediumImpact();

    setState(() {
      _editing = true;
      _selected = _ClockHand.hour;
      _editHour = (_now.hour % 12) + _now.minute / 60.0;
      _editMinute = _now.minute.toDouble();
      _hourMoved = false;
      _minuteMoved = false;
      _guideStep = 1;
    });
  }

  void _selectHand(Offset position, Size size) {
    if (!_editing) return;

    final center = Offset(size.width / 2, size.height / 2);
    final distance = (position - center).distance;
    final radius = size.width / 2;

    if (distance <= radius * 0.14) return;

    setState(() {
      _selected =
          distance < radius * 0.53 ? _ClockHand.hour : _ClockHand.minute;
    });

    HapticFeedback.selectionClick();
  }

  void _moveHand(Offset position, Size size) {
    if (!_editing) return;

    final center = Offset(size.width / 2, size.height / 2);
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    if (distance < size.width * 0.12) return;

    var degrees = math.atan2(dx, -dy) * 180 / math.pi;
    if (degrees < 0) degrees += 360;

    setState(() {
      if (_selected == _ClockHand.hour) {
        final hour = (degrees / 30).round() % 12;
        _editHour = hour == 0 ? 12 : hour.toDouble();
        _hourMoved = true;
      } else {
        _editMinute = ((degrees / 6).round() % 60).toDouble();
        _minuteMoved = true;
      }

      if (_hourMoved && _minuteMoved) {
        _guideStep = 2;
      }
    });
  }

  Future<void> _confirm() async {
    if (!_editing || !_ready || _unlocking) return;

    if (!_hourMoved || !_minuteMoved) {
      HapticFeedback.vibrate();
      _toast('Set both hands first: inner ring = hour, outer ring = minute.');
      setState(() => _guideStep = 1);
      return;
    }

    final hour12 = _editHour.round() % 12;
    final hour = hour12 == 0 ? 12 : hour12;
    final minute = _editMinute.round() % 60;
    final password =
        hour.toString().padLeft(2, '0') +
        minute.toString().padLeft(2, '0');

    if (_setupMode) {
      await _secure.write(key: _passwordKey, value: password);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_setupKey, true);

      if (!mounted) return;

      setState(() {
        _setupMode = false;
        _editing = false;
        _guideStep = 0;
      });

      HapticFeedback.heavyImpact();
      _toast('Clock set. Long-press the centre any time to unlock.');
      return;
    }

    final stored = await _secure.read(key: _passwordKey);

    if (stored == null || stored.isEmpty) {
      setState(() {
        _editing = false;
        _setupMode = true;
      });
      _toast('Clock setup is incomplete. Set a secret time first.');
      return;
    }

    if (password != stored) {
      setState(() {
        _editing = false;
        _guideStep = 0;
      });
      HapticFeedback.vibrate();
      _toast('The clock continues normally.');
      return;
    }

    setState(() => _unlocking = true);
    HapticFeedback.heavyImpact();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _openAlarms() async {
    try {
      final ok = await _clockChannel.invokeMethod<bool>('openAlarms');
      if (ok != true) {
        _toast('Your phone could not open its alarms.');
      }
    } on PlatformException {
      _toast('Your phone could not open its alarms.');
    }
  }

  void _toast(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        ),
      );
  }

  DateTime _editingTime() {
    final hour12 = _editHour.round() % 12;
    final hour = hour12 == 0 ? 12 : hour12;
    final minute = _editMinute.round() % 60;

    return DateTime(
      _now.year,
      _now.month,
      _now.day,
      hour,
      minute,
    );
  }

  String _timeText(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
  }

  String _dateText(DateTime value) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }

  Widget _guide() {
    if (!_ready) return const SizedBox.shrink();

    String title;
    String body;
    IconData icon;

    if (_setupMode && !_editing) {
      title = 'Set your private clock time';
      body =
          'Hold the centre until the clock pauses. Then set the two hands.';
      icon = Icons.touch_app_rounded;
    } else if (_editing && _guideStep == 1) {
      title = 'Choose the two hands';
      body = _hourMoved && !_minuteMoved
          ? 'Hour set. Touch the outer ring and drag the long minute hand.'
          : !_hourMoved && _minuteMoved
              ? 'Minute set. Touch the inner ring and drag the short hour hand.'
              : 'Touch the inner ring for hours or the outer ring for minutes, then drag.';
      icon = _selected == _ClockHand.hour
          ? Icons.schedule_rounded
          : Icons.timelapse_rounded;
    } else if (_editing) {
      title = 'One tap to confirm';
      body = _setupMode
          ? 'Both hands are set. Tap the centre once to save.'
          : 'Both hands are set. Tap the centre once to unlock.';
      icon = Icons.radio_button_checked_rounded;
    } else {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Material(
        color: const Color(0xFF182333).withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF9FC4FF).withValues(alpha: 0.16),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF9FC4FF).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFFD6E5FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFFF5F0E8),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      body,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        height: 1.35,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (_editing)
                Text(
                  _guideStep == 1 ? '1/2' : '2/2',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _clock() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final diameter = math.min(
          constraints.maxWidth * 0.84,
          constraints.maxHeight * 0.66,
        );

        final size = Size(diameter, diameter);

        final painted = SizedBox(
          width: diameter,
          height: diameter,
          child: CustomPaint(
            painter: _ClockPainter(
              time: _editing ? _editingTime() : _now,
              editing: _editing,
              selected: _selected,
              hour: _editHour,
              minute: _editMinute,
            ),
          ),
        );

        if (!_editing) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPressStart: (details) {
              _beginEditing(details.localPosition, size);
            },
            child: painted,
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final center = Offset(diameter / 2, diameter / 2);

            if ((details.localPosition - center).distance <=
                diameter * 0.14) {
              _confirm();
              return;
            }

            _selectHand(details.localPosition, size);
          },
          onPanStart: (details) => _selectHand(details.localPosition, size),
          onPanUpdate: (details) => _moveHand(details.localPosition, size),
          child: painted,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleTime = _editing ? _editingTime() : _now;

    return Scaffold(
      backgroundColor: const Color(0xFF0A111A),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F0E8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.access_time_rounded,
                      color: Color(0xFF182333),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Text(
                      'Clock',
                      style: TextStyle(
                        color: Color(0xFFF5F0E8),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _openAlarms,
                    tooltip: 'Alarms',
                    icon: const Icon(
                      Icons.alarm_rounded,
                      color: Color(0xFFE8C56D),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _clock(),
                ),
              ),
            ),
            Text(
              _timeText(visibleTime),
              style: const TextStyle(
                color: Color(0xFFF5F0E8),
                fontSize: 31,
                fontWeight: FontWeight.w300,
                letterSpacing: 2.6,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _dateText(_now),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.52),
                fontSize: 14,
                letterSpacing: 0.9,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _openAlarms,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF16212E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.alarm_rounded,
                      size: 18,
                      color: Color(0xFFE8C56D),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Alarms',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _editing
                  ? 'Clock paused'
                  : 'Hold the centre to set or unlock',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.28),
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 12),
            _guide(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class _ClockPainter extends CustomPainter {
  final DateTime time;
  final bool editing;
  final _ClockHand selected;
  final double hour;
  final double minute;

  _ClockPainter({
    required this.time,
    required this.editing,
    required this.selected,
    required this.hour,
    required this.minute,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFFF5F0E8),
    );

    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..color = const Color(0xFF263142)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    final tick = Paint()..strokeCap = StrokeCap.round;

    for (var i = 0; i < 60; i++) {
      final angle = i * math.pi / 30;
      final isHour = i % 5 == 0;
      final outer = radius * 0.90;
      final inner = radius * (isHour ? 0.80 : 0.865);

      tick
        ..strokeWidth = isHour ? 2.5 : 1
        ..color = isHour
            ? const Color(0xFF303744)
            : const Color(0xFF9EA3AB);

      canvas.drawLine(
        Offset(
          center.dx + math.sin(angle) * inner,
          center.dy - math.cos(angle) * inner,
        ),
        Offset(
          center.dx + math.sin(angle) * outer,
          center.dy - math.cos(angle) * outer,
        ),
        tick,
      );
    }

    final numberStyle = TextStyle(
      color: const Color(0xFF222833),
      fontSize: radius * 0.10,
      fontWeight: FontWeight.w600,
    );

    for (var n = 1; n <= 12; n++) {
      final angle = n * math.pi / 6;
      final position = Offset(
        center.dx + math.sin(angle) * radius * 0.695,
        center.dy - math.cos(angle) * radius * 0.695,
      );

      final painter = TextPainter(
        text: TextSpan(
          text: n.toString(),
          style: numberStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      painter.paint(
        canvas,
        position - Offset(painter.width / 2, painter.height / 2),
      );
    }

    final h = editing
        ? hour
        : (time.hour % 12) +
            time.minute / 60.0 +
            time.second / 3600.0;
    final m = editing
        ? minute
        : time.minute + time.second / 60.0;

    final hourAngle = h * math.pi / 6;
    final minuteAngle = m * math.pi / 30;

    _hand(
      canvas,
      center,
      radius * 0.50,
      hourAngle,
      6,
      editing && selected == _ClockHand.hour
          ? const Color(0xFF2D6CDF)
          : const Color(0xFF171B22),
    );

    _hand(
      canvas,
      center,
      radius * 0.71,
      minuteAngle,
      3.5,
      editing && selected == _ClockHand.minute
          ? const Color(0xFF2D6CDF)
          : const Color(0xFF171B22),
    );

    if (editing) {
      final angle = selected == _ClockHand.hour ? hourAngle : minuteAngle;
      final length =
          selected == _ClockHand.hour ? radius * 0.50 : radius * 0.71;

      final endpoint = Offset(
        center.dx + math.sin(angle) * length,
        center.dy - math.cos(angle) * length,
      );

      canvas.drawCircle(
        endpoint,
        radius * 0.045,
        Paint()
          ..color = const Color(0xFF2D6CDF).withValues(alpha: 0.14),
      );

      canvas.drawCircle(
        endpoint,
        radius * 0.026,
        Paint()..color = const Color(0xFF2D6CDF),
      );
    }

    canvas.drawCircle(
      center,
      radius * 0.055,
      Paint()..color = const Color(0xFF11151B),
    );

    if (editing) {
      canvas.drawCircle(
        center,
        radius * 0.085,
        Paint()
          ..color = const Color(0xFF2D6CDF).withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }
  }

  void _hand(
    Canvas canvas,
    Offset center,
    double length,
    double angle,
    double width,
    Color color,
  ) {
    final end = Offset(
      center.dx + math.sin(angle) * length,
      center.dy - math.cos(angle) * length,
    );

    canvas.drawLine(
      center,
      end,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ClockPainter old) {
    return old.time != time ||
        old.editing != editing ||
        old.selected != selected ||
        old.hour != hour ||
        old.minute != minute;
  }
}
