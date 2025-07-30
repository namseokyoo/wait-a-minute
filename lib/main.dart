import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/permission_screen.dart';
import 'services/camera_service.dart';
import 'services/simplified_monitor_service.dart';
import 'services/realtime_monitor_service.dart';
import 'services/permission_service.dart';
import 'services/waiting_state_service.dart';
import 'services/local_notification_service.dart';
import 'services/firebase_initialization_service.dart';

// Global notification service instance
late LocalNotificationService globalLocalNotificationService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase using the new initialization service
  final firebaseInitService = FirebaseInitializationService();
  final firebaseReady = await firebaseInitService.initializeFully();
  
  if (kDebugMode) {
    print('Firebase 전체 초기화 결과: $firebaseReady');
  }

  // Initialize unified notification service
  globalLocalNotificationService = LocalNotificationService();
  try {
    final notificationInitialized = await globalLocalNotificationService.initialize();
    if (kDebugMode) {
      print('Unified Notifications: ${notificationInitialized ? "성공" : "실패"}');
    }
  } catch (e) {
    if (kDebugMode) {
      print('Unified notification service failed: $e');
    }
  }

  runApp(const WaitAMinuteApp());
}

class WaitAMinuteApp extends StatelessWidget {
  const WaitAMinuteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core services
        ChangeNotifierProvider(create: (_) => PermissionService()),
        ChangeNotifierProvider(create: (_) => WaitingStateService()),

        // Dependent services with injection
        ChangeNotifierProvider(
          create: (context) {
            final waitingStateService = context.read<WaitingStateService>();
            final cameraService = CameraService(
              deviceName: 'CCTV 기기',
              location: '입구',
              waitingStateService: waitingStateService,
            );

            // Initialize CCTV device info
            waitingStateService.initializeCCTV(
              cameraService.deviceId,
              cameraService.location,
            );

            // Setup notification listeners
            globalLocalNotificationService.setupWaitingStateListener(
              waitingStateService,
            );

            // Setup local notification listener
            try {
              globalLocalNotificationService
                  .startListeningToWaitingStateChanges(waitingStateService);
            } catch (e) {
              if (kDebugMode) {
                print('Firebase listener setup failed: $e');
              }
            }

            return cameraService;
          },
        ),
        ChangeNotifierProvider(
          create:
              (context) => SimplifiedMonitorService(
                waitingStateService: context.read<WaitingStateService>(),
              ),
        ),
        ChangeNotifierProvider(create: (context) => RealtimeMonitorService()),
      ],
      child: MaterialApp(
        title: 'Wait A Minute',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          // Custom theme settings for the app
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.blue[800],
            foregroundColor: Colors.white,
            elevation: 4,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        home: const PermissionScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
