import 'package:flutter/material.dart';

class ChatListView extends StatelessWidget {
  const ChatListView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return ListView.builder(
      itemCount: 5,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        bool isUnread = index < 2; // Make first two messages look unread

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: theme.surface,
                child: const Icon(Icons.person, color: Colors.white70),
              ),
              if (isUnread)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 14,
                    width: 14,
                    decoration: BoxDecoration(
                      color: theme.secondary, // Pink notification dot
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0F172A), width: 2),
                    ),
                  ),
                )
            ],
          ),
          title: Text(
              "Match ${index + 1}",
              style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.normal)
          ),
          subtitle: Text(
            "Hey, it looks like we are close by!",
            style: TextStyle(color: isUnread ? Colors.white : Colors.white54),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
              "2m",
              style: TextStyle(fontSize: 12, color: isUnread ? theme.secondary : Colors.white38)
          ),
          onTap: () {},
        );
      },
    );
  }
}
