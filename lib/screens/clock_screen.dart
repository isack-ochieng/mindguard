import 'dart:async';
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
  DateTime _dateTime = DateTime.now();
  Timer? _timer;
  String _password = '1230'; // Default password: 12:30

  @override
  void initState() {
    super.initState();
    _loadPassword();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _dateTime = DateTime.now();
      });
    });
  }

  Future<void> _loadPassword() async {
    final prefs = await SharedPreferences.getInstance();
    _password = prefs.getString('clock_password') ?? '1230';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _checkPassword(int hour, int minute) {
    final enteredPassword = '${hour.toString().padLeft(2, '0')}${minute.toString().padLeft(2, '0')}';
    
    if (enteredPassword == _password) {
      // Password correct, navigate to the real app
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      // Password incorrect, show a subtle hint or do nothing
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Time is not correct'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Analog Clock
            GestureDetector(
              onLongPress: () {
                // Show a dialog to set the password (for first time setup)
                _showPasswordSetupDialog();
              },
              onDoubleTap: () {
                // Check password based on current time
                _checkPassword(_dateTime.hour, _dateTime.minute);
              },
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: CustomPaint(
                  painter: ClockPainter(
                    _dateTime,
                    handColor: Colors.black,
                    tickColor: Colors.grey.shade400,
                    centerColor: Colors.red,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Digital Clock
            Text(
              '${_dateTime.hour.toString().padLeft(2, '0')}:${_dateTime.minute.toString().padLeft(2, '0')}:${_dateTime.second.toString().padLeft(2, '0')}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.w300,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            
            const SizedBox(height: 10),
            
            // Date
            Text(
              '${_dateTime.month.toString().padLeft(2, '0')}/${_dateTime.day.toString().padLeft(2, '0')}/${_dateTime.year}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 20,
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Subtle hint for the user
            Text(
              'Double-tap to unlock',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPasswordSetupDialog() {
    // This dialog is for the initial setup of the password
    // In a real app, this would be a more complex setup flow
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Unlock Time (Password)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Password: ${_password.substring(0, 2)}:${_password.substring(2, 4)}'),
            const SizedBox(height: 10),
            const Text('The password is the hour and minute (HHMM) you double-tap the clock.'),
            const SizedBox(height: 10),
            const Text('To change, enter a new HHMM below:'),
            TextField(
              keyboardType: TextInputType.number,
              maxLength: 4,
              onChanged: (value) {
                if (value.length == 4) {
                  final hour = int.tryParse(value.substring(0, 2)) ?? -1;
                  final minute = int.tryParse(value.substring(2, 4)) ?? -1;
                  if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
                    _password = value;
                  }
                }
              },
              decoration: const InputDecoration(
                hintText: 'e.g., 1230 for 12:30',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('clock_password', _password);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Password set to ${_password.substring(0, 2)}:${_password.substring(2, 4)}')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
