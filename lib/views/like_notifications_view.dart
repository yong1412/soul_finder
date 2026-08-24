import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/match_service.dart';
import 'meet_soul_view.dart';

class LikeNotificationsView extends StatelessWidget {
  LikeNotificationsView({super.key});

  final MatchService _matchService = MatchService();

  Future<void> _likeBack(
      BuildContext context,
      LikeNotification notification,
      ) async {
    try {
      final matched = await _matchService.likeUser(notification.fromUid);
      await _matchService.markNotificationRead(notification.id);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            matched
                ? 'Mutual match created with ${notification.fromName}.'
                : 'Like sent to ${notification.fromName}.',
          ),
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  Future<void> _viewMatch(
      BuildContext context,
      LikeNotification notification,
      ) async {
    if (!notification.isRead) {
      await _matchService.markNotificationRead(notification.id);
    }
    if (!context.mounted) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MeetSoulView(
          targetUserUid: notification.fromUid,
          soulName: notification.fromName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LikeNotification>>(
      stream: _matchService.watchMyLikeNotifications(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Unable to load notifications: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final notifications = snapshot.data!;
        if (notifications.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 54,
                  color: Colors.white38,
                ),
                SizedBox(height: 12),
                Text('No Like notifications yet.'),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: notifications.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final notification = notifications[index];
            final profileImage = _decodeProfileImage(
              notification.fromProfileImageBase64,
            );

            return Card(
              color: notification.isRead
                  ? const Color(0xFF1E293B)
                  : const Color(0xFF253451),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: notification.isMatched
                          ? const Color(0xFFF43F5E)
                          : const Color(0xFF3B82F6),
                      backgroundImage: profileImage,
                      child: profileImage == null
                          ? Icon(
                        notification.isMatched
                            ? Icons.favorite
                            : Icons.person_add,
                        color: Colors.white,
                      )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.fromName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification.isMatched
                                ? 'You both liked each other.'
                                : 'Liked your profile.',
                            style: const TextStyle(color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    notification.isMatched
                        ? FilledButton.tonal(
                      onPressed: () =>
                          _viewMatch(context, notification),
                      child: const Text('View Match'),
                    )
                        : FilledButton(
                      onPressed: () =>
                          _likeBack(context, notification),
                      child: const Text('Like Back'),
                    ),
                  ],
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
}
