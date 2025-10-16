import 'package:allergen/services/emergency/emergency_service.dart';
import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';

import '../../emergency/emergency_screen.dart';

class SevereEmergencyPageViewScreen extends StatefulWidget {
  final int initialPage;

  SevereEmergencyPageViewScreen({required this.initialPage});

  @override
  _SevereEmergencyPageViewScreenState createState() =>
      _SevereEmergencyPageViewScreenState();
}

class _SevereEmergencyPageViewScreenState
    extends State<SevereEmergencyPageViewScreen> {
  late PageController pageController;
  int currentPage = 0;

  final List<EmergencyAction> emergencyActions = [
    EmergencyAction(1, "Symptoms"),
    EmergencyAction(2, "Lay the  victim flat"),
    EmergencyAction(3, "Recovery position"),
    EmergencyAction(4, "Position"),
    EmergencyAction(5, "Remove allergen"),
    EmergencyAction(6, "How to give EpiPen"),
    EmergencyAction(7, "How to give Anapen"),
    EmergencyAction(8, "Call for Help"),
    EmergencyAction(9, "Repeat dose"),
    EmergencyAction(10, "Asthma medication"),
  ];

  double dragPosition = 0.0;
  bool isDragging = false;
  static const double dragThreshold = 150.0;

  late EmergencyService emergencyService;
  bool isEmergencyServiceInitialized = false;

  @override
  void initState() {
    super.initState();
    currentPage = widget.initialPage;
    pageController = PageController(initialPage: widget.initialPage);
    initializeEmergencyService();
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
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

  EmergencyContent getContentForAction(int actionNumber) {
    return EmergencyContent();
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
      backgroundColor: AppColors.defaultbackground,
      appBar: AppBar(
        backgroundColor: AppColors.defaultbackground,
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
          'Anaphylaxis',
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
            // PageView
            Expanded(
              child: PageView.builder(
                controller: pageController,
                onPageChanged: (index) {
                  setState(() {
                    currentPage = index;
                  });
                },
                itemCount: emergencyActions.length,
                itemBuilder: (context, index) {
                  return buildDetailPage(emergencyActions[index]);
                },
              ),
            ),
            // Page Indicators
            Container(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(emergencyActions.length, (index) {
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          currentPage == index
                              ? AppColors.primary
                              : AppColors.lightGray,
                    ),
                  );
                }),
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

  Widget buildDetailPage(EmergencyAction action) {
    final content = getContentForAction(action.number);

    return Container(
      color: AppColors.defaultbackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
              ),
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
                        fontSize: 18,
                        color: AppColors.textBlack,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content Section
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _buildContentSection(content, action.number),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentSection(EmergencyContent content, int actionNumber) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: 20),

          Container(
            width: double.infinity,
            constraints: BoxConstraints(
              minHeight: 400,
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/anaphylaxis/act$actionNumber.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 400,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            getIllustrationIcon(actionNumber),
                            size: 60,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Action $actionNumber Image',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
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

          SizedBox(height: 20),
        ],
      ),
    );
  }

  IconData getIllustrationIcon(int actionNumber) {
    switch (actionNumber) {
      case 1:
        return Icons.warning; 
      case 2:
        return Icons.airline_seat_recline_extra;
      case 3:
        return Icons.rotate_right; 
      case 4:
        return Icons.airline_seat_legroom_extra; 
      case 5:
        return Icons.clean_hands; 
      case 6:
        return Icons.medical_services; 
      case 7:
        return Icons.medical_services; 
      case 8:
        return Icons.phone; 
      case 9:
        return Icons.repeat; 
      case 10:
        return Icons.medication; 
      default:
        return Icons.help;
    }
  }
}

class EmergencyAction {
  final int number;
  final String text;

  EmergencyAction(this.number, this.text);
}

class EmergencyContent {
  EmergencyContent();
}
