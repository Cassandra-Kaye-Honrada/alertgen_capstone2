import 'package:allergen/firebase_options.dart';
import 'package:allergen/screens/auth/authwrapper.dart';
import 'package:allergen/screens/emergency/emergency_screen.dart';
import 'package:allergen/screens/feature/scan_screen.dart';
import 'package:allergen/screens/health_environment_analytics/aqi_loader.dart';
import 'package:allergen/services/emergency/emergency_service.dart';
import 'package:allergen/services/push_notification_service.dart';
import 'package:allergen/widgets/air_quality_widget_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:home_widget/home_widget.dart';
import 'dart:async';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Handling background message: ${message.messageId}');
}

Future<void> requestLocationPermissions() async {
  try {
    final status = await Permission.location.request();
    if (status.isDenied) {
      await Permission.location.request();
    }
  } catch (e) {
    print('Location permission error: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    print('Flutter Error: ${details.exception}');
    print('Stack trace: ${details.stack}');
  };

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await dotenv.load(fileName: ".env");

  runApp(const AlertGen());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initializeServicesInBackground();
  });
}

Future<void> _initializeServicesInBackground() async {
  try {
    await AirQualityWidgetManager.initialize();
    await requestLocationPermissions();

    try {
      await PushNotificationService().initialize();
    } catch (e) {
      print('Notification service initialization error: $e');
    }

    print('All services initialized successfully');
  } catch (e) {
    print('Service initialization error: $e');
  }
}

class AlertGen extends StatefulWidget {
  const AlertGen({super.key});

  @override
  State<AlertGen> createState() => _AlertGenState();
}

class _AlertGenState extends State<AlertGen> {
  StreamSubscription<Uri?>? widgetUriSubscription;

  @override
  void initState() {
    super.initState();
    setupWidgetListener();
  }

  void setupWidgetListener() {
    widgetUriSubscription = HomeWidget.widgetClicked.listen((Uri? uri) {
      if (uri != null) {
        print('Widget clicked in main app: $uri');
        handleWidgetUri(uri);
      }
    });

    HomeWidget.initiallyLaunchedFromHomeWidget().then((Uri? uri) {
      if (uri != null) {
        print('App opened from widget: $uri');
        Future.delayed(const Duration(milliseconds: 800), () {
          handleWidgetUri(uri);
        });
      }
    });
  }

  void handleWidgetUri(Uri uri) {
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
    widgetUriSubscription?.cancel();
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
      if (mounted) {
        setState(() {
          isInitialized = true;
        });
        print('Emergency service initialized in ShortcutHandler');
      }
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
    if (context == null || !context.mounted) {
      print('No context available');
      return;
    }

    if (needsPermission) {
      await _handleLocationPermission(context);

      if (!context.mounted) {
        print('Context no longer mounted after permission handling');
        return;
      }

      try {
        await platform.invokeMethod('updateWidget');
      } catch (e) {
        print('Error updating widget: $e');
      }
    }

    if (!context.mounted) return;

    print('Context mounted, navigating to AirQualityLoader');
    Navigator.of(context).popUntil((route) => route.isFirst);

    await Future.delayed(const Duration(milliseconds: 100));

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
  }

  Future<void> _handleLocationPermission(BuildContext context) async {
    if (!context.mounted) return;

    var status = await Permission.location.status;

    if (status.isGranted) {
      print('Location permission already granted');
      return;
    }

    if (status.isDenied) {
      if (!context.mounted) return;

      bool shouldRequest =
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder:
                (dialogContext) => AlertDialog(
                  title: Text('Location Permission'),
                  content: Text(
                    'This app needs location access to show accurate air quality data for your area.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: Text('Grant Permission'),
                    ),
                  ],
                ),
          ) ??
          false;

      if (!shouldRequest || !context.mounted) {
        print('User declined to grant location permission');
        return;
      }

      status = await Permission.location.request();

      if (!context.mounted) return;

      if (status.isGranted) {
        print('Location permission granted');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location permission granted! Updating widget...'),
            duration: Duration(seconds: 2),
          ),
        );
      } else if (status.isPermanentlyDenied) {
        await showOpenSettingsDialog(context);
      }
    } else if (status.isPermanentlyDenied) {
      if (context.mounted) {
        await showOpenSettingsDialog(context);
      }
    }
  }

  Future<void> showOpenSettingsDialog(BuildContext context) async {
    if (!context.mounted) return;

    bool shouldOpenSettings =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder:
              (dialogContext) => AlertDialog(
                title: Text('Permission Required'),
                content: Text(
                  'Location permission is required to show accurate air quality data. '
                  'Please enable it in app settings.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
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
    if (context == null || !context.mounted) {
      print('No context available');
      return;
    }

    if (!isInitialized) {
      print('Emergency service not initialized, initializing now...');
      await initializeEmergencyService();
      if (!mounted) return;
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
        if (!granted || !context.mounted) {
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
    if (emergencyService.isEmergencyActive) {
      emergencyService.cancelEmergencyCall();
    }
    super.dispose();
  }
}
