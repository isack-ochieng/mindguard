import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/clock_painter.dart';
import 'home_screen.dart';

class ClockScreen extends StatefulWidget {
  const ClockScreen({super.key});

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> {
  static const _unlockHourKey = 'clock_unlock_hour';
  static const _unlockMinuteKey = 'clock_unlock_minute';

  DateTime _now = DateTime.now();
  Timer? _timer;
  int _unlockHour = 12;
  int _unlockMinute = 30;

  @override
  void initState() {
    super.initState();
    _loadUnlockTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  Future<void> _loadUnlockTime() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _unlockHour = prefs.getInt(_unlockHourKey) ?? 12;
      _unlockMinute = prefs.getInt(_unlockMinuteKey) ?? 30;
    });
  }

  bool get _isUnlockTime =>
      _now.hour == _unlockHour && _now.minute == _unlockMinute;

  void _attemptUnlock() {
    if (!_isUnlockTime || !mounted) return;

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
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      body: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final diameter = math.min(
                constraints.maxWidth * 0.82,
                constraints.maxHeight * 0.68,
              );

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _attemptUnlock,
                child: SizedBox(
                  width: diameter,
                  height: diameter + 120,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Semantics(
                        label: 'Analog clock',
                        child: Container(
                          width: diameter,
                          height: diameter,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFF7F7F2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.45),
                                blurRadius: 28,
                                spreadRadius: 2,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: CustomPaint(
                            painter: ClockPainter(
                              _now,
                              handColor: const Color(0xFF151515),
                              tickColor: const Color(0xFF8A8A8A),
                              centerColor: const Color(0xFF151515),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        _formatTime(_now),
                        style: const TextStyle(
                          color: Color(0xFFF4F4F4),
                          fontSize: 30,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 2.2,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        _formatDate(_now),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 14,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
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
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[time.month - 1]} ${time.day}, ${time.year}';
  }
}
