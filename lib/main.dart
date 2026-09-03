import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:media_kit/media_kit.dart';
import 'package:soul_finder/views/radar/radar_view.dart';

import 'firebase_options.dart';

import 'controllers/auth_controller.dart';
import 'controllers/radar/radar_controller.dart';
import 'services/auth_service.dart';
import 'services/channel_service.dart';
import 'services/match_service.dart';
import 'services/radar/location_service.dart';
import 'views/auth/login_view.dart';
import 'views/chat_list_view.dart';
import 'views/like_notifications_view.dart';
import 'views/nearby_users_list_view.dart';
import 'views/splash_loading_view.dart';
import 'views/user_dashboard_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthController authController;

  @override
  void initState() {
    super.initState();

    authController = AuthController(
      AuthService(),
    );

    authController.initialize();
  }

  @override
  void dispose() {
    authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Soul Finder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6),
          secondary: Color(0xFFF43F5E),
          surface: Color(0xFF1E293B),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF1E293B),
          indicatorColor: const Color(0xFF3B82F6).withValues(alpha: 0.25),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(
                  color: Color(0xFF3B82F6),
                );
              }

              return const IconThemeData(
                color: Colors.white54,
              );
            },
          ),
        ),
      ),
      home: ListenableBuilder(
        listenable: authController,
        builder: (context, child) {
          if (authController.isInitializing) {
            return const SplashLoadingView();
          }

          if (authController.currentUser == null) {
            return LoginView(
              controller: authController,
            );
          }

          return MainNavigationScreen(
            authController: authController,
          );
        },
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({
    super.key,
    required this.authController,
  });

  final AuthController authController;

  @override
  State<MainNavigationScreen> createState() {
    return _MainNavigationScreenState();
  }
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  bool _isPreloadingUserData = true;

  @override
  void initState() {
    super.initState();
    _preloadUserDataInBackground();
  }

  Future<void> _preloadUserDataInBackground() async {
    final uid = widget.authController.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      // 🚀 Preload user's visited hotspot history into memory cache BEFORE starting Radar
      await RadarController.preloadHotspotHistoryForUser(uid);
    }

    ChannelService().initializeInterestChannels().catchError((e) {
      debugPrint("Channel initialization skipped: $e");
    });

    LocationService().getCurrentLocation().catchError((e) {
      debugPrint("Location sync skipped: $e");
      return null;
    });

    if (mounted) {
      setState(() {
        _isPreloadingUserData = false;
      });
    }
  }

  List<Widget> get _screens {
    return [
      RadarView(
        authController: widget.authController,
        isRadarTabActive: _selectedIndex == 0,
      ),
      const NearbyUsersListView(),
      ChatListView(
        authController: widget.authController,
      ),
      UserDashboardView(
        controller: widget.authController,
      ),
    ];
  }

  final List<String> _titles = [
    'Radar',
    'Nearby Souls',
    'Messages',
    'My Profile',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isPreloadingUserData) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF38BDF8), strokeWidth: 3),
              const SizedBox(height: 20),
              const Text(
                'Loading Soul Finder...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pre-loading user data & hotspot history for ${widget.authController.currentUser?.name ?? "user"}...',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: [
          StreamBuilder<int>(
            stream: MatchService().watchUnreadNotificationCount(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      unreadCount > 0
                          ? Icons.notifications_active
                          : Icons.notifications_outlined,
                      color: unreadCount > 0 ? const Color(0xFFF43F5E) : null,
                    ),
                    tooltip: 'Like Notifications',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            appBar: AppBar(
                              title: const Text('Notifications'),
                              centerTitle: true,
                            ),
                            body: LikeNotificationsView(),
                          ),
                        ),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF43F5E),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.radar_outlined),
            selectedIcon: Icon(Icons.radar),
            label: 'Radar',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_alt_outlined),
            selectedIcon: Icon(Icons.people),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
