import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'controllers/auth_controller.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/match_service.dart';
import 'views/auth/login_view.dart';
import 'views/chat_list_view.dart';
import 'views/like_notifications_view.dart';
import 'views/map_radar_view.dart';
import 'views/nearby_users_list_view.dart';
import 'views/user_dashboard_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    authController = AuthController(AuthService());
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
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          elevation: 0,
        ),
      ),
      home: ListenableBuilder(
        listenable: authController,
        builder: (context, child) {
          if (authController.isInitializing) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!authController.isAuthenticated) {
            return LoginView(controller: authController);
          }
          return MainNavigationScreen(authController: authController);
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
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  final MatchService _matchService = MatchService();
  final ChatService _chatService = ChatService();

  List<Widget> get _screens => [
    const MapRadarView(),
    const NearbyUsersListView(),
    LikeNotificationsView(),
    const ChatListView(),
    UserDashboardView(controller: widget.authController),
  ];

  static const List<String> _titles = [
    'Radar',
    'Nearby Souls',
    'Likes',
    'Messages',
    'My Profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.radar_outlined),
            selectedIcon: Icon(Icons.radar),
            label: 'Radar',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_alt_outlined),
            selectedIcon: Icon(Icons.people),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: StreamBuilder<int>(
              stream: _matchService.watchUnreadNotificationCount(),
              initialData: 0,
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return Badge(
                  isLabelVisible: count > 0,
                  label: Text(count > 9 ? '9+' : '$count'),
                  child: const Icon(Icons.favorite_border),
                );
              },
            ),
            selectedIcon: const Icon(Icons.favorite),
            label: 'Likes',
          ),
          NavigationDestination(
            icon: _buildChatIcon(selected: false),
            selectedIcon: _buildChatIcon(selected: true),
            label: 'Chat',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildChatIcon({required bool selected}) {
    return StreamBuilder<int>(
      stream: _chatService.watchTotalUnreadCount(),
      initialData: 0,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        return Badge(
          isLabelVisible: count > 0,
          label: Text(count > 99 ? '99+' : '$count'),
          child: Icon(
            selected ? Icons.chat_bubble : Icons.chat_bubble_outline,
          ),
        );
      },
    );
  }
}
