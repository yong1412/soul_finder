import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/match_service.dart';
import 'chat_conversation_view.dart';
import 'meet_soul_view.dart';
import 'public_user_profile_view.dart';

class LikeNotificationsView extends StatelessWidget {
  LikeNotificationsView({super.key});

  final MatchService _matchService = MatchService();

  Future<void> _openUserProfile(
      BuildContext context,
      LikeNotification notification,
      ) async {
    if (!notification.isRead) {
      await _matchService.markNotificationRead(notification.id);
    }

    if (!context.mounted) return;

    // Show loading dialog while fetching candidate data
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final candidate =
        await _matchService.getCandidateForUid(notification.fromUid);

    if (!context.mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (candidate != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PublicUserProfileView(candidate: candidate),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load user profile.')),
      );
    }
  }

  Future<void> _likeBack(
      BuildContext context,
      LikeNotification notification,
      ) async {
    try {
      final matched = await _matchService.likeUser(notification.fromUid);
      await _matchService.markNotificationRead(notification.id);

      if (!context.mounted) return;

      if (matched) {
        // Show Match Dialog with choices
        showDialog(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.favorite, color: Color(0xFFF43F5E)),
                  SizedBox(width: 10),
                  Text("It's a Match! 🎉"),
                ],
              ),
              content: Text(
                'You and ${notification.fromName} liked each other! Start chatting or plan a meetup.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Later'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MeetSoulView(
                          targetUserUid: notification.fromUid,
                          soulName: notification.fromName,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.place_outlined),
                  label: const Text('Meet Soul'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatConversationView(
                          targetUserUid: notification.fromUid,
                          targetUserName: notification.fromName,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Chat'),
                ),
              ],
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Liked ${notification.fromName} back!'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showMatchOptions(BuildContext context, LikeNotification notification) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF3B82F6),
                    child: Icon(Icons.chat_bubble_outline, color: Colors.white),
                  ),
                  title: Text('Chat with ${notification.fromName}'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatConversationView(
                          targetUserUid: notification.fromUid,
                          targetUserName: notification.fromName,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF43F5E),
                    child: Icon(Icons.favorite_outline, color: Colors.white),
                  ),
                  title: Text('Meet Soul with ${notification.fromName}'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MeetSoulView(
                          targetUserUid: notification.fromUid,
                          soulName: notification.fromName,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF64748B),
                    child: Icon(Icons.person_outline, color: Colors.white),
                  ),
                  title: const Text('View Profile'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _openUserProfile(context, notification);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LikeNotification>>(
      stream: _matchService.watchMyLikeNotifications(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load notifications: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final notifications = snapshot.data!;
        if (notifications.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none_outlined,
                    size: 80,
                    color: Colors.white24,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'When someone likes your profile, you will see them here to respond!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: notifications.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final notification = notifications[index];
            final profileImage = _decodeProfileImage(
              notification.fromProfileImageBase64,
            );

            return Card(
              color: notification.isRead
                  ? const Color(0xFF1E293B)
                  : const Color(0xFF233554),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: notification.isRead
                      ? Colors.transparent
                      : const Color(0xFF3B82F6).withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openUserProfile(context, notification),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: notification.isMatched
                                ? const Color(0xFFF43F5E)
                                : const Color(0xFF3B82F6),
                            backgroundImage: profileImage,
                            child: profileImage == null
                                ? Text(
                                    _firstCharacter(notification.fromName),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  )
                                : null,
                          ),
                          if (!notification.isRead)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF1E293B),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification.fromName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notification.isMatched
                                  ? '🎉 You both liked each other!'
                                  : '💖 Liked your profile',
                              style: TextStyle(
                                color: notification.isMatched
                                    ? const Color(0xFFF43F5E)
                                    : Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Tap to view profile',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      notification.isMatched
                          ? FilledButton.tonal(
                              onPressed: () =>
                                  _showMatchOptions(context, notification),
                              child: const Text('Matched'),
                            )
                          : FilledButton.icon(
                              onPressed: () =>
                                  _likeBack(context, notification),
                              icon: const Icon(Icons.favorite, size: 16),
                              label: const Text('Like Back'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFF43F5E),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  ImageProvider<Object>? _decodeProfileImage(String encodedImage) {
    final trimmedImage = encodedImage.trim();

    if (trimmedImage.isEmpty) {
      return null;
    }

    try {
      final base64Value = trimmedImage.contains(',')
          ? trimmedImage.substring(trimmedImage.indexOf(',') + 1)
          : trimmedImage;
      return MemoryImage(base64Decode(base64Value));
    } catch (_) {
      return null;
    }
  }

  String _firstCharacter(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
  }
}
