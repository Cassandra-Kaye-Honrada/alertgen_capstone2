import 'package:allergen/screens/models/emergency_call_state.dart';
import 'package:allergen/services/emergency/emergency_service.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../models/emergency_contact.dart';
import '../models/emergency_settings.dart';

class EmergencyScreen extends StatefulWidget {
  final List<EmergencyContact> emergencyContacts;
  final EmergencySettings emergencySettings;

  const EmergencyScreen({
    Key? key,
    required this.emergencyContacts,
    required this.emergencySettings,
  }) : super(key: key);

  @override
  _EmergencyScreenState createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with TickerProviderStateMixin {
  late AnimationController pulseController;
  late AnimationController dragController;
  late Animation<double> pulseAnimation;
  late Animation<double> dragAnimation;

  final EmergencyService emergencyService = EmergencyService();

  EmergencyCallState currentState = EmergencyCallState.idle;
  EmergencyContact? currentContact;
  int countdown = 0;

  bool isDragging = false;
  double dragDistance = 0;
  static const double _cancelThreshold = 100.0;

  late StreamSubscription stateSubscription;
  late StreamSubscription contactSubscription;
  late StreamSubscription countdownSubscription;

  @override
  void initState() {
    super.initState();
    setupAnimations();
    setupStreams();
    startEmergencyCall();
  }

  void setupAnimations() {
    pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );
    pulseAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: pulseController, curve: Curves.easeInOut),
    );
    pulseController.repeat(reverse: true);

    dragController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    dragAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: dragController, curve: Curves.easeInOut),
    );
  }

  void setupStreams() {
    stateSubscription = emergencyService.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          currentState = state;
        });

        if (state == EmergencyCallState.completed ||
            state == EmergencyCallState.cancelled) {
          navigateBack();
        }
      }
    });

    contactSubscription = emergencyService.currentContactStream.listen((
      contact,
    ) {
      if (mounted) {
        setState(() {
          currentContact = contact;
        });
      }
    });

    countdownSubscription = emergencyService.countdownStream.listen((
      countdown,
    ) {
      if (mounted) {
        setState(() {
          this.countdown = countdown;
        });
      }
    });
  }

  Future<void> startEmergencyCall() async {
    await emergencyService.startEmergencyCall(
      contacts: widget.emergencyContacts,
      settings: widget.emergencySettings,
    );
  }

  void navigateBack() {
    Timer(Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void onPanStart(DragStartDetails details) {
    if (!widget.emergencySettings.enableDragToCancel) return;
    isDragging = true;
    dragController.forward();
  }

  void onPanUpdate(DragUpdateDetails details) {
    if (!widget.emergencySettings.enableDragToCancel) return;
    setState(() {
      dragDistance += details.delta.dy;
      dragDistance = dragDistance.clamp(0.0, _cancelThreshold * 2);
    });
  }

  void onPanEnd(DragEndDetails details) {
    if (!widget.emergencySettings.enableDragToCancel) return;

    if (dragDistance >= _cancelThreshold) {
      emergencyService.cancelEmergencyCall();
    } else {
      setState(() {
        dragDistance = 0;
      });
    }

    isDragging = false;
    dragController.reverse();
  }

  String getStatusText() {
    switch (currentState) {
      case EmergencyCallState.initializing:
        return 'Initializing emergency call...';
      case EmergencyCallState.calling:
        if (currentContact != null) {
          return 'Calling ${currentContact!.name}...';
        }
        return 'Calling emergency contact...';
      case EmergencyCallState.callingEmergencyServices:
        return 'Calling ${widget.emergencySettings.emergencyServiceNumber}...';
      case EmergencyCallState.completed:
        return 'Emergency call completed';
      case EmergencyCallState.cancelled:
        return 'Emergency call cancelled';
      case EmergencyCallState.error:
        return 'Error occurred';
      default:
        return 'Calling emergency...';
    }
  }

  String getSubtitleText() {
    if (currentState == EmergencyCallState.calling &&
        currentContact != null) {
      return 'Calling ${currentContact!.name} (${currentContact!.phoneNumber})\n'
          'If no response, next contact will be called automatically.';
    }

    if (currentState == EmergencyCallState.callingEmergencyServices) {
      return 'All emergency contacts exhausted.\n'
          'Calling emergency services now.';
    }

    return 'Please stand by, we are currently requesting\n'
        'for help. Your emergency contacts and nearby\n'
        'rescue services will see your call for help.';
  }

  Color getStepColor() {
    switch (currentState) {
      case EmergencyCallState.initializing:
        return Color(0xFFFF9F40); 
      case EmergencyCallState.calling:
        return Color(0xFFFF6B6B);
      case EmergencyCallState.callingEmergencyServices:
        return Color(0xFFFF4444); 
      case EmergencyCallState.completed:
        return Color(0xFF4CAF50); 
      case EmergencyCallState.cancelled:
        return Color(0xFF757575);
      case EmergencyCallState.error:
        return Color(0xFFFF5722); 
      default:
        return Color(0xFFFF6B6B);
    }
  }

  Widget buildMainCircle() {
    return GestureDetector(
      onPanStart: onPanStart,
      onPanUpdate: onPanUpdate,
      onPanEnd: onPanEnd,
      child: Transform.translate(
        offset: Offset(0, dragDistance),
        child: AnimatedBuilder(
          animation: pulseAnimation,
          builder: (context, child) {
            return Container(
              width: 280,
              height: 280,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (int i = 0; i < 3; i++)
                    Transform.scale(
                      scale: pulseAnimation.value + (i * 0.2),
                      child: Container(
                        width: 280 - (i * 40),
                        height: 280 - (i * 40),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: getStepColor().withOpacity(0.3 - (i * 0.1)),
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          getStepColor().withOpacity(0.8),
                          getStepColor(),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: getStepColor().withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(child: buildCircleContent()),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildCircleContent() {
    if (countdown > 0) {
      return Text(
        '$countdown',
        style: TextStyle(
          color: Colors.white,
          fontSize: 48,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    if (currentState == EmergencyCallState.calling) {
      return Icon(Icons.phone, color: Colors.white, size: 48);
    }

    if (currentState == EmergencyCallState.callingEmergencyServices) {
      return Icon(Icons.local_hospital, color: Colors.white, size: 48);
    }

    if (currentState == EmergencyCallState.completed) {
      return Icon(Icons.check, color: Colors.white, size: 48);
    }

    if (currentState == EmergencyCallState.cancelled) {
      return Icon(Icons.close, color: Colors.white, size: 48);
    }

    return Icon(Icons.emergency, color: Colors.white, size: 48);
  }

  Widget buildDragToCancel() {
    if (!widget.emergencySettings.enableDragToCancel) return SizedBox.shrink();

    double opacity = (dragDistance / _cancelThreshold).clamp(0.0, 1.0);
    bool willCancel = dragDistance >= _cancelThreshold;

    return AnimatedOpacity(
      opacity: isDragging ? 1.0 : 0.3,
      duration: Duration(milliseconds: 200),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color:
              willCancel
                  ? Colors.red.withOpacity(0.8)
                  : Colors.grey.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              willCancel ? Icons.cancel : Icons.arrow_downward,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              willCancel ? 'Release to Cancel' : 'Drag down to cancel',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.grey[100],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.black54,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Emergency',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Title
              Text(
                getStatusText(),
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),

              Text(
                getSubtitleText(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  height: 1.5,
                ),
              ),

              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      buildMainCircle(),
                      SizedBox(height: 40),
                      buildDragToCancel(),
                    ],
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
    pulseController.dispose();
    dragController.dispose();
    stateSubscription.cancel();
    contactSubscription.cancel();
    countdownSubscription.cancel();
    super.dispose();
  }
}
