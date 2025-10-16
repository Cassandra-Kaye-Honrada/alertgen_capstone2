import 'package:allergen/services/emergency/emergency_service.dart';
import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';

import '../../emergency/emergency_screen.dart';
import 'moderateDetailScreen.dart';

class EmergencyListScreen extends StatefulWidget {
  @override
  _EmergencyListScreenState createState() => _EmergencyListScreenState();
}

class _EmergencyListScreenState extends State<EmergencyListScreen> {
  final List<EmergencyAction> emergencyActions = [
    EmergencyAction(1, "Assist victim to be comfortable"),
    EmergencyAction(2, "Stay in the victim, ensure rest"),
    EmergencyAction(3, "Assist with prescribed medicine"),
    EmergencyAction(4, "If reaction is caused by a chemical or liquid"),
    EmergencyAction(5, "Monitor vital signs regularly"),
  ];

  double dragPosition = 0.0;
  bool isDragging = false;
  static const double dragThreshold = 150.0;

  late EmergencyService emergencyService;
  bool isEmergencyServiceInitialized = false;

  @override
  void initState() {
    super.initState();
    initializeEmergencyService();
  }

  Future<void> initializeEmergencyService() async {
    try {
      emergencyService = EmergencyService();
      await emergencyService.initialize();
      if (mounted) {
        setState(() {
          isEmergencyServiceInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing emergency service: $e');
      emergencyService = EmergencyService();
      if (mounted) {
        setState(() {
          isEmergencyServiceInitialized = true;
        });
      }
    }
  }

  void navigateToPageView(BuildContext context, int actionNumber) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => EmergencyPageViewScreen(initialPage: actionNumber - 1),
      ),
    );
  }

  void onPanStart(DragStartDetails details) {
    setState(() {
      isDragging = true;
    });
  }

  void onPanUpdate(DragUpdateDetails details) {
    setState(() {
      if (details.delta.dy < 0) {
        dragPosition = (dragPosition - details.delta.dy).clamp(
          0.0,
          dragThreshold,
        );
      } else if (dragPosition > 0) {
        dragPosition = (dragPosition - details.delta.dy).clamp(
          0.0,
          dragThreshold,
        );
      }
    });
  }

  void onPanEnd(DragEndDetails details) async {
    setState(() {
      isDragging = false;
    });

    if (dragPosition >= dragThreshold) {
      await triggerEmergencyContact();
    }

    setState(() {
      dragPosition = 0.0;
    });
  }

  Future<void> triggerEmergencyContact() async {
    if (!isEmergencyServiceInitialized) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                SizedBox(width: 20),
                Text("Initializing emergency service..."),
              ],
            ),
          );
        },
      );

      await initializeEmergencyService();
      Navigator.of(context).pop();
    }

    try {
      await emergencyService.startEmergencyCallFromUI(context);
    } catch (e) {
      print('Error triggering emergency contact: $e');

      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("Emergency Contact Error"),
              content: Text(
                "Unable to initiate emergency contact. Please try again or contact emergency services directly.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text("OK"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    retryEmergencyContact();
                  },
                  child: Text("Retry"),
                ),
              ],
            );
          },
        );
      }
    }
  }

  Future<void> retryEmergencyContact() async {
    try {
      await emergencyService.startEmergencyCall();
    } catch (e) {
      print('Retry failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFF2F9FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: AppColors.primary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Mild to Moderate',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Actions List
            Expanded(
              child: Container(
                color: AppColors.defaultbackground,
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 20),
                    Text(
                      "ACTIONS",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 15),
                    Expanded(
                      child: ListView.builder(
                        itemCount: emergencyActions.length,
                        itemBuilder: (context, index) {
                          return buildActionItem(
                            context,
                            emergencyActions[index],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Container(
              padding: EdgeInsets.all(20),
              child: GestureDetector(
                onPanStart: onPanStart,
                onPanUpdate: onPanUpdate,
                onPanEnd: onPanEnd,
                child: AnimatedContainer(
                  duration: Duration(milliseconds: isDragging ? 0 : 300),
                  curve: Curves.easeOut,
                  transform: Matrix4.translationValues(0, -dragPosition, 0),
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color:
                        dragPosition > 0
                            ? Color(0xFFc44537).withOpacity(
                              0.9 + (dragPosition / dragThreshold) * 0.1,
                            )
                            : Color(0xFFc44537),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFc44537).withOpacity(
                          0.3 + (dragPosition / dragThreshold) * 0.2,
                        ),
                        blurRadius: 10 + (dragPosition / dragThreshold) * 5,
                        offset: Offset(
                          0,
                          4 + (dragPosition / dragThreshold) * 2,
                        ),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Progress indicator
                      if (dragPosition > 0)
                        Container(
                          margin: EdgeInsets.only(bottom: 8),
                          width: 60,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: dragPosition / dragThreshold,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Emergency icon
                          AnimatedRotation(
                            duration: Duration(milliseconds: 200),
                            turns: dragPosition > 0 ? 0.5 : 0,
                            child: Icon(
                              dragPosition >= dragThreshold
                                  ? Icons.emergency
                                  : Icons.keyboard_arrow_up,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              dragPosition >= dragThreshold
                                  ? "Release to Contact Emergency!"
                                  : "Pull to Contact Emergency Services",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),

                      // Percentage indicator
                      if (dragPosition > 0)
                        Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "${(dragPosition / dragThreshold * 100).round()}%",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (!isEmergencyServiceInitialized) ...[
                                SizedBox(width: 8),
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                      if (dragPosition > dragThreshold * 0.5)
                        Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            "Location will be shared with emergency contacts",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildActionItem(BuildContext context, EmergencyAction action) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: GestureDetector(
          onTap: () => navigateToPageView(context, action.number),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    action.number.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 15),
              Expanded(
                child: Text(
                  action.text,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[800],
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
