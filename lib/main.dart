import 'package:allergen/firebase_options.dart';
import 'package:allergen/screens/auth/authwrapper.dart';
import 'package:allergen/screens/emergency/emergency_screen.dart';
import 'package:allergen/screens/feature/scan_screen.dart';
import 'package:allergen/screens/health_environment_analytics/aqi_loader.dart';
import 'package:allergen/services/emergency/emergency_service.dart';
import 'package:allergen/services/push_notification_service.dart';
import 'package:allergen/widgets/air_quality_widget_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:home_widget/home_widget.dart';
import 'dart:async';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> requestLocationPermissions() async {
  final status = await Permission.location.request();
  if (status.isDenied) {
    await Permission.location.request();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AirQualityWidgetManager.initialize();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await dotenv.load(fileName: ".env");
  await requestLocationPermissions();

  try {
    await PushNotificationService().initialize();
  } catch (e) {
    print('Push notification initialization failed: $e');
  }

  runApp(const AlertGen());
}

class AlertGen extends StatefulWidget {
  const AlertGen({super.key});

  @override
  State<AlertGen> createState() => _AlertGenState();
}

class _AlertGenState extends State<AlertGen> {
  StreamSubscription<Uri?>? _widgetUriSubscription;

  @override
  void initState() {
    super.initState();
    _setupWidgetListener();
  }

  void _setupWidgetListener() {
    _widgetUriSubscription = HomeWidget.widgetClicked.listen((Uri? uri) {
      if (uri != null) {
        print('Widget clicked in main app: $uri');
        _handleWidgetUri(uri);
      }
    });

    HomeWidget.initiallyLaunchedFromHomeWidget().then((Uri? uri) {
      if (uri != null) {
        print('App opened from widget: $uri');
        Future.delayed(const Duration(milliseconds: 800), () {
          _handleWidgetUri(uri);
        });
      }
    });
  }

  void _handleWidgetUri(Uri uri) {
    final uriString = uri.toString();
    print('Processing widget URI: $uriString');

    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      print('Context not available or not mounted');
      return;
    }

    if (uriString.contains('airquality') || uriString.contains('refresh')) {
      print('Navigating to Air Quality screen from widget');

      Navigator.of(context).popUntil((route) => route.isFirst);

      Future.delayed(const Duration(milliseconds: 100), () {
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AirQualityLoader(),
              settings: RouteSettings(
                name: '/air_quality',
                arguments: {'timestamp': DateTime.now().millisecondsSinceEpoch},
              ),
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _widgetUriSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      home: ShortcutHandler(child: AuthWrapper()),
      routes: {
        '/scan': (context) => CameraScannerScreen(),
        '/air_quality': (context) => AirQualityLoader(),
      },
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
  final EmergencyService emergencyService = EmergencyService();
  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    initializeEmergencyService();
    platform.setMethodCallHandler(handleMethod);
  }

  Future<void> initializeEmergencyService() async {
    try {
      await emergencyService.initialize();
      setState(() {
        isInitialized = true;
      });
      print('Emergency service initialized in ShortcutHandler');
    } catch (e) {
      print('Error initializing emergency service: $e');
    }
  }

  Future<void> handleMethod(MethodCall call) async {
    print('Received method call: ${call.method} with args: ${call.arguments}');

    if (call.method == 'navigate') {
      if (call.arguments is Map) {
        final args = call.arguments as Map;
        final String route = args['route'] ?? '';
        final bool needsPermission = args['needs_permission'] ?? false;

        print('Navigating to route: $route, needsPermission: $needsPermission');

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (route == '/emergency') {
            triggerEmergency();
          } else if (route == '/scan') {
            navigatorKey.currentState?.pushNamed(route);
          } else if (route == '/air_quality') {
            triggerAirQuality(needsPermission: needsPermission);
          }
        });
      } else if (call.arguments is String) {
        final String route = call.arguments;
        print('Navigating to route: $route');

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (route == '/emergency') {
            triggerEmergency();
          } else if (route == '/scan') {
            navigatorKey.currentState?.pushNamed(route);
          } else if (route == '/air_quality') {
            triggerAirQuality(needsPermission: false);
          }
        });
      }
    }
  }

  Future<void> triggerAirQuality({bool needsPermission = false}) async {
    print(
      'Triggering air quality from widget, needsPermission: $needsPermission',
    );
    final context = navigatorKey.currentContext;

    if (context == null) {
      print('No context available');
      return;
    }

    if (needsPermission) {
      await _handleLocationPermission(context);

      try {
        await platform.invokeMethod('updateWidget');
      } catch (e) {
        print('Error updating widget: $e');
      }
    }

    if (context.mounted) {
      print('Context mounted, navigating to AirQualityLoader');
      // Clear navigation stack and push fresh screen
      Navigator.of(context).popUntil((route) => route.isFirst);

      // Small delay to ensure clean state
      Future.delayed(const Duration(milliseconds: 100), () async {
        if (context.mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AirQualityLoader(),
              settings: RouteSettings(
                name: '/air_quality',
                arguments: {'timestamp': DateTime.now().millisecondsSinceEpoch},
              ),
            ),
          );
        }
      });
    }
  }

  Future<void> _handleLocationPermission(BuildContext context) async {
    var status = await Permission.location.status;

    if (status.isGranted) {
      print('Location permission already granted');
      return;
    }

    if (status.isDenied) {
      bool shouldRequest =
          await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: Text('Location Permission'),
                  content: Text(
                    'This app needs location access to show accurate air quality data for your area.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('Grant Permission'),
                    ),
                  ],
                ),
          ) ??
          false;

      if (!shouldRequest) {
        print('User declined to grant location permission');
        return;
      }

      status = await Permission.location.request();

      if (status.isGranted) {
        print('Location permission granted');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location permission granted! Updating widget...'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (status.isPermanentlyDenied) {
        if (context.mounted) {
          showOpenSettingsDialog(context);
        }
      }
    } else if (status.isPermanentlyDenied) {
      if (context.mounted) {
        showOpenSettingsDialog(context);
      }
    }
  }

  Future<void> showOpenSettingsDialog(BuildContext context) async {
    bool shouldOpenSettings =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text('Permission Required'),
                content: Text(
                  'Location permission is required to show accurate air quality data. '
                  'Please enable it in app settings.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('Open Settings'),
                  ),
                ],
              ),
        ) ??
        false;

    if (shouldOpenSettings) {
      await openAppSettings();
    }
  }

  Future<void> triggerEmergency() async {
    print('Triggering emergency from shortcut');

    final context = navigatorKey.currentContext;
    if (context == null) {
      print('No context available');
      return;
    }

    if (!isInitialized) {
      print('Emergency service not initialized, initializing now...');
      await initializeEmergencyService();
    }

    await emergencyService.forceReload();

    if (!emergencyService.hasContacts) {
      print('No emergency contacts available');
      if (context.mounted) {
        emergencyService.showNoContactsDialog(context);
      }
      return;
    }

    if (!emergencyService.smsPermissionGranted ||
        !emergencyService.phonePermissionGranted) {
      print('Permissions not granted');
      if (context.mounted) {
        bool granted = await emergencyService.showPermissionDialog(context);
        if (!granted) {
          print('Permissions denied by user');
          return;
        }
      }
    }

    if (context.mounted) {
      print('Navigating to EmergencyScreen');
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => EmergencyScreen(
                emergencyContacts: emergencyService.emergencyContacts,
                emergencySettings: emergencyService.emergencySettings,
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
