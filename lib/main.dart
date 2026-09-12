import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/storage/token_storage.dart';
import 'core/network/socket_service.dart';
import 'core/constants/api_endpoints.dart';
import 'core/services/update_service.dart';
import 'core/services/fcm_service.dart';
import 'features/auth/presentation/login_screen.dart';
import 'navigation/main_bottom_nav.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiEndpoints.autoDetectWorkingHost();
  await FcmService.initialize(navKey: MatchUpApp.navigatorKey);
  runApp(const ProviderScope(child: MatchUpApp()));
}

class MatchUpApp extends ConsumerStatefulWidget {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  const MatchUpApp({super.key});

  @override
  ConsumerState<MatchUpApp> createState() => _MatchUpAppState();
}

class _MatchUpAppState extends ConsumerState<MatchUpApp> {
  bool _isCheckingAuth = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    final token = await TokenStorage.getToken();
    if (token != null && token.isNotEmpty) {
      // Connect real-time socket gateway
      await SocketService().connect();
      // Synchronize FCM push device token
      FcmService.registerDeviceToken();
      setState(() {
        _isAuthenticated = true;
        _isCheckingAuth = false;
      });
    } else {
      setState(() {
        _isAuthenticated = false;
        _isCheckingAuth = false;
      });
    }

    // Check for app updates after auth is resolved.
    // Uses addPostFrameCallback so the widget tree is fully built and
    // the context is safe to use for showing a dialog.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        UpdateService.checkForUpdate(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentThemeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'MatchUp',
      navigatorKey: MatchUpApp.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: currentThemeMode,
      home: _isCheckingAuth
          ? const MatchUpSplashScreen()
          : _isAuthenticated
              ? const MainBottomNav()
              : const LoginScreen(),
    );
  }
}

class MatchUpSplashScreen extends StatelessWidget {
  const MatchUpSplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.favorite_rounded, size: 56, color: Color(0xFFEC407A)),
              SizedBox(height: 14),
              Text('MatchUp',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
              SizedBox(height: 6),
              Text('Connect. Match. Belong.'),
            ],
          ),
        ),
      );
}
