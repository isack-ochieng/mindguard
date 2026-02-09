import 'dart:math';
import 'package:flutter/material.dart';

class ClockPainter extends CustomPainter {
  final DateTime dateTime;
  final Color handColor;
  final Color tickColor;
  final Color centerColor;

  ClockPainter(this.dateTime, {
    this.handColor = Colors.black,
    this.tickColor = Colors.grey,
    this.centerColor = Colors.black,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double centerX = size.width / 2;
    double centerY = size.height / 2;
    Offset center = Offset(centerX, centerY);
    double radius = min(centerX, centerY);

    // Draw the clock circle
    Paint circlePaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius, circlePaint);

    // Draw the center dot
    Paint centerPaint = Paint()..color = centerColor;
    canvas.drawCircle(center, 10, centerPaint);

    // Draw the hour and minute ticks
    for (int i = 0; i < 60; i++) {
      double angle = i * 6 * pi / 180;
      double tickLength = i % 5 == 0 ? 15 : 5;
      double tickWidth = i % 5 == 0 ? 3 : 1;

      Offset start = Offset(
        centerX + radius * cos(angle),
        centerY + radius * sin(angle),
      );
      Offset end = Offset(
        centerX + (radius - tickLength) * cos(angle),
        centerY + (radius - tickLength) * sin(angle),
      );

      Paint tickPaint = Paint()
        ..color = tickColor
        ..strokeWidth = tickWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(start, end, tickPaint);
    }

    // Calculate angles for hands
    double secAngle = dateTime.second * 6 * pi / 180;
    double minAngle = (dateTime.minute + dateTime.second / 60) * 6 * pi / 180;
    double hourAngle = (dateTime.hour % 12 + dateTime.minute / 60) * 30 * pi / 180;

    // Adjust angles to start from the top (12 o'clock)
    secAngle -= pi / 2;
    minAngle -= pi / 2;
    hourAngle -= pi / 2;

    // Draw hour hand
    drawHand(canvas, center, hourAngle, radius * 0.5, 6, handColor);

    // Draw minute hand
    drawHand(canvas, center, minAngle, radius * 0.7, 4, handColor);

    // Draw second hand
    drawHand(canvas, center, secAngle, radius * 0.8, 2, Colors.red);
  }

  void drawHand(Canvas canvas, Offset center, double angle, double length, double width, Color color) {
    Offset end = Offset(
      center.dx + length * cos(angle),
      center.dy + length * sin(angle),
    );

    Paint handPaint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center, end, handPaint);
  }

  @override
  bool shouldRepaint(covariant ClockPainter oldDelegate) {
    return oldDelegate.dateTime.second != dateTime.second;
  }
}
