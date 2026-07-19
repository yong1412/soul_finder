import 'package:flutter/material.dart';

class UserDashboardView extends StatelessWidget {
  const UserDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Modern Profile Avatar with Gradient Border
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [theme.primary, theme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const CircleAvatar(
              radius: 50,
              backgroundColor: Color(0xFF1E293B),
              child: Icon(Icons.person, size: 50, color: Colors.white70),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Alex Doe, 24",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            "Looking for deep connections",
            style: TextStyle(color: theme.primary, fontSize: 16),
          ),
          const SizedBox(height: 30),

          // Floating Stats Card
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatColumn("12", "Matches", theme),
                _buildDivider(),
                _buildStatColumn("4", "Near You", theme),
                _buildDivider(),
                _buildStatColumn("89", "Views", theme),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Modern Settings Tiles
          Container(
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: theme.primary.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.radar, color: theme.primary),
                  ),
                  title: const Text("Discovery Radius"),
                  trailing: Text("5 Miles", style: TextStyle(fontWeight: FontWeight.bold, color: theme.secondary)),
                  onTap: () {},
                ),
                Divider(color: Colors.white.withOpacity(0.05), height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: theme.secondary.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.edit, color: theme.secondary),
                  ),
                  title: const Text("Edit Profile"),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String value, String label, ColorScheme theme) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withOpacity(0.1),
    );
  }
}
