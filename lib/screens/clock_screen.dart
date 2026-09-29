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
  static const _passwordKey = 'mindguard_clock_password';
  static const _setupCompleteKey = 'mindguard_clock_setup_complete';

  DateTime _now = DateTime.now();
  Timer? _timer;
  bool _ready = false;
  bool _unlocking = false;

  @override
  void initState() {
    super.initState();
    _loadState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final setupComplete = prefs.getBool(_setupCompleteKey) ?? false;

    if (!setupComplete && mounted) {
      await _showFirstInstallSetup();
    }

    if (!mounted) return;
    setState(() => _ready = true);
  }

  Future<void> _showFirstInstallSetup() async {
    final controller = TextEditingController();

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          String? error;

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Set your clock password'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose a 4-digit password. Keep it private — you will use it to unlock MindGuard.',
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, letterSpacing: 10),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '••••',
                        errorText: error,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        if (error != null) setDialogState(() => error = null);
                      },
                    ),
                  ],
                ),
                actions: [
                  FilledButton(
                    onPressed: () async {
                      final password = controller.text.trim();

                      if (!RegExp(r'^\d{4}$').hasMatch(password)) {
                        setDialogState(() => error = 'Enter exactly 4 digits.');
                        return;
                      }

                      final hour = int.parse(password.substring(0, 2));
                      final minute = int.parse(password.substring(2, 4));

                      if (hour > 23 || minute > 59) {
                        setDialogState(() => error = 'Use a valid 24-hour time, e.g. 0830.');
                        return;
                      }

                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString(_passwordKey, password);
                      await prefs.setBool(_setupCompleteKey, true);

                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Continue'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _attemptUnlock() async {
    if (!_ready || _unlocking || !mounted) return;

    final controller = TextEditingController();

    try {
      final password = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Unlock'),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 10),
              decoration: const InputDecoration(
                counterText: '',
                hintText: '••••',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => Navigator.of(context).pop(controller.text),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('Unlock'),
              ),
            ],
          );
        },
      );

      if (password == null || !mounted) return;

      final prefs = await SharedPreferences.getInstance();
      final storedPassword = prefs.getString(_passwordKey);

      if (storedPassword == null || password != storedPassword) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Incorrect password.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
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
    } finally {
      controller.dispose();
      if (mounted) setState(() => _unlocking = false);
    }
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
