import 'package:flutter/material.dart';
import 'views/map_radar_view.dart'; // MOVED: MapRadarView moved to lib/views/map_radar_view.dart
import 'views/nearby_users_list_view.dart'; // MOVED: NearbyUsersListView moved to lib/views/nearby_users_list_view.dart
import 'views/chat_list_view.dart'; // MOVED: ChatListView moved to lib/views/chat_list_view.dart
import 'views/user_dashboard_view.dart'; // MOVED: UserDashboardView moved to lib/views/user_dashboard_view.dart

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
          indicatorColor: const Color(0xFF3B82F6).withOpacity(0.25),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white70),
          ),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Color(0xFF3B82F6));
            }
            return const IconThemeData(color: Colors.white54);
          }),
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const MapRadarView(), // MOVED: MapRadarView instantiation (defined in lib/views/map_radar_view.dart)
    const NearbyUsersListView(), // MOVED: NearbyUsersListView instantiation (defined in lib/views/nearby_users_list_view.dart)
    const ChatListView(), // MOVED: ChatListView instantiation (defined in lib/views/chat_list_view.dart)
    const UserDashboardView(), // MOVED: UserDashboardView instantiation (defined in lib/views/user_dashboard_view.dart)
  ];

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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        centerTitle: true,
        actions: [
          if (_selectedIndex == 3)
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.white70),
              onPressed: () {},
            )
        ],
      ),
      body: _screens[_selectedIndex],
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

// ---------------------------------------------------------
// CODE CHANGES SUMMARY:
// ---------------------------------------------------------
// REMOVED: MapRadarView class was moved to lib/views/map_radar_view.dart
// REMOVED: NearbyUsersListView class was moved to lib/views/nearby_users_list_view.dart
// REMOVED: ChatListView class was moved to lib/views/chat_list_view.dart
// REMOVED: UserDashboardView class was moved to lib/views/user_dashboard_view.dart
