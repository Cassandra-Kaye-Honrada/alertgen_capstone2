import 'package:allergen/firebase_options.dart';
import 'package:allergen/screens/auth/authwrapper.dart';
import 'package:allergen/screens/emergency/emergency_screen.dart';
import 'package:allergen/screens/feature/scan_screen.dart';
import 'package:allergen/services/emergency/emergency_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await dotenv.load(fileName: ".env");

  runApp(const AlertGen());
}

class AlertGen extends StatelessWidget {
  const AlertGen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      home: ShortcutHandler(child: AuthWrapper()),
      routes: {'/scan': (context) => CameraScannerScreen()},
    );
  }
}

class ShortcutHandler extends StatefulWidget {
  final Widget child;

  const ShortcutHandler({Key? key, required this.child}) : super(key: key);

  @override
  State<ShortcutHandler> createState() => _ShortcutHandlerState();
}

class _ShortcutHandlerState extends State<ShortcutHandler> {
  static const platform = MethodChannel('com.example.allergen/shortcuts');
  final EmergencyService _emergencyService = EmergencyService();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeEmergencyService();
    platform.setMethodCallHandler(_handleMethod);
  }

  Future<void> _initializeEmergencyService() async {
    try {
      await _emergencyService.initialize();
      setState(() {
        _isInitialized = true;
      });
      print('✅ Emergency service initialized in ShortcutHandler');
    } catch (e) {
      print('❌ Error initializing emergency service: $e');
    }
  }

  Future<void> _handleMethod(MethodCall call) async {
    print(
      '📱 Received method call: ${call.method} with args: ${call.arguments}',
    );

    if (call.method == 'navigate') {
      final String route = call.arguments;
      print('🔗 Navigating to route: $route');

      // Wait for the widget tree to be built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route == '/emergency') {
          _triggerEmergency();
        } else if (route == '/scan') {
          navigatorKey.currentState?.pushNamed(route);
        }
      });
    }
  }

  Future<void> _triggerEmergency() async {
    print('🚨 Triggering emergency from shortcut');

    final context = navigatorKey.currentContext;
    if (context == null) {
      print('❌ No context available');
      return;
    }

    if (!_isInitialized) {
      print('⏳ Emergency service not initialized, initializing now...');
      await _initializeEmergencyService();
    }

    // Reload settings to get latest contacts
    await _emergencyService.forceReload();

    if (!_emergencyService.hasContacts) {
      print('⚠️ No emergency contacts available');
      if (context.mounted) {
        _emergencyService.showNoContactsDialog(context);
      }
      return;
    }

    // Check permissions
    if (!_emergencyService.smsPermissionGranted ||
        !_emergencyService.phonePermissionGranted) {
      print('⚠️ Permissions not granted');
      if (context.mounted) {
        bool granted = await _emergencyService.showPermissionDialog(context);
        if (!granted) {
          print('❌ Permissions denied by user');
          return;
        }
      }
    }

    // Navigate to emergency screen
    if (context.mounted) {
      print('✅ Navigating to EmergencyScreen');
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => EmergencyScreen(
                emergencyContacts: _emergencyService.emergencyContacts,
                emergencySettings: _emergencyService.emergencySettings,
              ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void dispose() {
    platform.setMethodCallHandler(null);
    super.dispose();
  }
}
