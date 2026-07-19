import 'package:flutter/material.dart';

class NearbyUsersListView extends StatelessWidget {
  const NearbyUsersListView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return ListView.builder(
      itemCount: 10,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [theme.primary.withOpacity(0.7), theme.secondary.withOpacity(0.7)],
                  ),
                ),
                child: CircleAvatar(
                  backgroundColor: Colors.transparent,
                  child: Text("S${index + 1}", style: const TextStyle(color: Colors.white)),
                ),
              ),
              title: Text("Soul ${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: theme.secondary),
                  const SizedBox(width: 4),
                  Text("${(index * 0.2 + 0.1).toStringAsFixed(1)} miles away", style: const TextStyle(color: Colors.white60)),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.favorite_border),
                color: theme.secondary,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Liked Soul ${index + 1}!'),
                      backgroundColor: theme.surface,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
