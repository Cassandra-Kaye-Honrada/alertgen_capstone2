import 'package:allergen/services/emergency/emergency_service.dart';
import 'package:flutter/material.dart';

class EmergencyWidget extends StatefulWidget {
  final EmergencyService emergencyService;
  final bool showSettings;
  final bool showStatus;

  const EmergencyWidget({
    Key? key,
    required this.emergencyService,
    this.showSettings = true,
    this.showStatus = true,
  }) : super(key: key);

  @override
  _EmergencyWidgetState createState() => _EmergencyWidgetState();
}

class _EmergencyWidgetState extends State<EmergencyWidget> {
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    initializeService();
  }

  Future<void> initializeService() async {
    setState(() => isLoading = true);
    await widget.emergencyService.initialize();
    setState(() => isLoading = false);
  }

  @override
  void didUpdateWidget(EmergencyWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    refreshData();
  }

  Future<void> refreshData() async {
    await widget.emergencyService.forceReload();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(Icons.emergency, size: 60, color: Colors.red[600]),
                SizedBox(height: 16),
                Text(
                  'Emergency Assistant',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Quickly call emergency contacts or send alert messages',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 30),

        Container(
          height: 120,
          child: ElevatedButton(
            onPressed:
                () => widget.emergencyService.startEmergencyCallFromUI(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 8,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone, size: 40, color: Colors.white),
                SizedBox(height: 8),
                Text(
                  'EMERGENCY CALL',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Call contacts in priority order',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 16),

        Container(
          height: 80,
          child: ElevatedButton(
            onPressed:
                widget.emergencyService.hasContacts
                    ? () => widget.emergencyService.sendEmergencyMessagesFromUI(
                      context,
                    )
                    : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[600],
              disabledBackgroundColor: Colors.grey[400],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 6,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.message,
                  size: 28,
                  color:
                      widget.emergencyService.hasContacts
                          ? Colors.white
                          : Colors.grey[600],
                ),
                SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SEND EMERGENCY SMS',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color:
                            widget.emergencyService.hasContacts
                                ? Colors.white
                                : Colors.grey[600],
                      ),
                    ),
                    Text(
                      'Send alert message to all contacts',
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            widget.emergencyService.hasContacts
                                ? Colors.white70
                                : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

     
        if (widget.showSettings) ...[
          SizedBox(height: 20),
          if (!widget.emergencyService.hasContacts)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
                  SizedBox(height: 8),
                  Text(
                    'No Emergency Contacts',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Add emergency contacts to enable emergency features',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.blue[600], fontSize: 12),
                  ),
                  SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed:
                        () => widget.emergencyService.showSettings(context),
                    icon: Icon(Icons.add, size: 18),
                    label: Text('Set Up Emergency Contacts'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

}
