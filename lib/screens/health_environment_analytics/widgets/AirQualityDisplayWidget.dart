import 'package:flutter/material.dart';
import 'dart:math' as math;

/// A display-only widget that shows air quality data without fetching
/// Use this when you already have AirQualityData from a parent widget
///
/// This widget expects AirQualityData from AirQualityWidget.dart (the main one)
class AirQualityDisplayWidget extends StatelessWidget {
  final dynamic
  airQualityData; // Using dynamic to accept any AirQualityData type
  final String location;

  const AirQualityDisplayWidget({
    Key? key,
    required this.airQualityData,
    required this.location,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Access properties dynamically to work with any AirQualityData structure
    final aqi = airQualityData.aqi as int;
    final quality = airQualityData.qualityLevel as String;
    final dominantPollutant = airQualityData.dominantPollutant as String;
    final color = airQualityData.color as Color;
    final healthRecommendation = airQualityData.healthRecommendation as String?;

    return Column(
      children: [
        // Location
        Padding(
          padding: const EdgeInsets.fromLTRB(25, 0, 25, 25),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              Text(
                location,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // White card section
        Container(
          margin: const EdgeInsets.fromLTRB(5, 0, 5, 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // AQI gauge and info
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Circular gauge
                    SizedBox(
                      width: 110,
                      height: 120,
                      child: CustomPaint(
                        painter: AQIGaugePainter(
                          aqi: aqi.toDouble(),
                          color: color,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$aqi',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF333333),
                                ),
                              ),
                              const Text(
                                'AQI',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF666666),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 24),

                    // Air quality info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Air Quality Index',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF999999),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            quality,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Dominant pollutant: $dominantPollutant',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Divider
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                color: const Color(0xFFE0E0E0),
              ),

              // Suggestion section
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Suggestion for you',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (healthRecommendation != null &&
                        healthRecommendation.isNotEmpty)
                      Text(
                        healthRecommendation,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF666666),
                          height: 1.5,
                        ),
                      )
                    else
                      Text(
                        'No specific recommendations at this time.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          height: 1.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AQIGaugePainter extends CustomPainter {
  final double aqi;
  final Color color;

  AQIGaugePainter({required this.aqi, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Background arc (light grey)
    final backgroundPaint =
        Paint()
          ..color = Colors.grey[200]!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round;

    final startAngle = math.pi * 0.65;
    final totalSweepAngle = math.pi * 1.7;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweepAngle,
      false,
      backgroundPaint,
    );

    final normalizedAqi = (aqi / 500).clamp(0.0, 1.0);
    final sweepAngle = normalizedAqi * totalSweepAngle;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final int segments = 100;
    final segmentAngle = sweepAngle / segments;

    Color getColorForAqi(double aqiValue) {
      if (aqiValue <= 100) {
        return Color.lerp(
          const Color(0xFF00E400),
          const Color(0xFFA8D96E),
          aqiValue / 100,
        )!;
      } else if (aqiValue <= 150) {
        return Color.lerp(
          const Color(0xFFA8D96E),
          const Color(0xFFFFFF00),
          (aqiValue - 100) / 50,
        )!;
      } else if (aqiValue <= 200) {
        return Color.lerp(
          const Color(0xFFFFFF00),
          const Color(0xFFFF7E00),
          (aqiValue - 150) / 50,
        )!;
      } else if (aqiValue <= 300) {
        return Color.lerp(
          const Color(0xFFFF7E00),
          const Color(0xFFFF0000),
          (aqiValue - 200) / 100,
        )!;
      } else if (aqiValue <= 400) {
        return Color.lerp(
          const Color(0xFFFF0000),
          const Color(0xFF990000),
          (aqiValue - 300) / 100,
        )!;
      } else {
        return const Color(0xFF990000);
      }
    }

    for (int i = 0; i <= segments; i++) {
      final progress = i / segments;
      final aqiAtProgress = progress * aqi;
      final segmentColor = getColorForAqi(aqiAtProgress);

      final segmentPaint =
          Paint()
            ..color = segmentColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 14
            ..strokeCap =
                (i == 0 || i == segments) ? StrokeCap.round : StrokeCap.butt;

      canvas.drawArc(
        rect,
        startAngle + (i * segmentAngle),
        segmentAngle,
        false,
        segmentPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ColorStop {
  final double position;
  final Color color;

  _ColorStop(this.position, this.color);
}
