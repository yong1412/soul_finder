import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

import '../models/event_hotspot.dart';
import '../services/event_hotspot_service.dart';
import '../services/match_service.dart';
import 'chat_conversation_view.dart';
import 'meet_soul_view.dart';
import 'public_user_profile_view.dart';
import 'station_map_view.dart';

class LikeNotificationsView extends StatefulWidget {
  const LikeNotificationsView({super.key});

  @override
  State<LikeNotificationsView> createState() => _LikeNotificationsViewState();
}

class _LikeNotificationsViewState extends State<LikeNotificationsView> {
  final MatchService _matchService = MatchService();
  final EventHotspotService _eventService = EventHotspotService();

  Future<void> _openUserProfile(
    LikeNotification notification,
  ) async {
    if (!notification.isRead) {
      await _matchService.markNotificationRead(notification.id);
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final candidate =
        await _matchService.getCandidateForUid(notification.fromUid);

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (!mounted) return;

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

      if (!mounted) return;

      if (matched) {
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
      if (mounted) {
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
                    _openUserProfile(notification);
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          elevation: 0,
          toolbarHeight: 0,
          bottom: const TabBar(
            indicatorColor: Color(0xFF3B82F6),
            indicatorWeight: 3,
            labelColor: Color(0xFF3B82F6),
            unselectedLabelColor: Colors.white60,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            tabs: [
              Tab(
                icon: Icon(Icons.notifications_active_outlined, size: 20),
                text: 'Likes & Activity',
              ),
              Tab(
                icon: Icon(Icons.event_available_outlined, size: 20),
                text: 'Event Hotspots',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 1. Likes Notifications Section
            _buildLikesTab(),

            // 2. Independent Event Hotspots Section
            _buildEventsTab(),
          ],
        ),
      ),
    );
  }

  /// 1. Likes Notifications Tab
  Widget _buildLikesTab() {
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
                    'When someone likes your profile, you will see them here!',
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
                onTap: () => _openUserProfile(notification),
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

  /// 2. Independent Event Hotspots Tab (100% English UI)
  Widget _buildEventsTab() {
    return ListenableBuilder(
      listenable: _eventService,
      builder: (context, _) {
        final events = _eventService.events;

        if (events.isEmpty) {
          return const Center(
            child: Text(
              'No active event hotspots right now.',
              style: TextStyle(color: Colors.white38),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            return _buildEventCard(event);
          },
        );
      },
    );
  }

  /// Build Event Hotspot Card
  Widget _buildEventCard(EventHotspot event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: event.isInterested
              ? const Color(0xFF10B981)
              : const Color(0xFF38BDF8).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Badge & Location Indicator
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department,
                          color: Color(0xFF38BDF8), size: 16),
                      SizedBox(width: 4),
                      Text(
                        'EVENT HOTSPOT',
                        style: TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Icon(
                  event.isInterested
                      ? Icons.star_rounded
                      : Icons.location_on_outlined,
                  color: event.isInterested
                      ? const Color(0xFF10B981)
                      : Colors.white38,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Event Title & Location Name (e.g. Serimas Condominium Pearl Tower)
            Text(
              event.eventTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.place, color: Color(0xFFF43F5E), size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    event.name, // "Serimas Condominium Pearl Tower"
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF1F5F9),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '📍 ${event.description}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // 📈 Incremental Metrics Board (Interested Count, Stay Time, Active Souls)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricItem(
                    icon: Icons.thumb_up_alt_outlined,
                    iconColor: const Color(0xFF38BDF8),
                    label: 'Interested',
                    value: '${event.interestedCount} souls', // 👈 Incremental Interested Count
                  ),
                  Container(
                      width: 1, height: 28, color: Colors.white10),
                  _buildMetricItem(
                    icon: Icons.timer_outlined,
                    iconColor: const Color(0xFFF59E0B),
                    label: 'Stay Time',
                    value: '${event.totalStayMinutes} mins', // 👈 Incremental Stay Duration
                  ),
                  Container(
                      width: 1, height: 28, color: Colors.white10),
                  _buildMetricItem(
                    icon: Icons.people_alt_outlined,
                    iconColor: const Color(0xFF10B981),
                    label: 'Active Now',
                    value: '${event.activeAttendees} souls',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons (Interested +1 & View Map Location)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _eventService.toggleInterested(event.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            event.isInterested
                                ? '🎉 Marked as Interested! Total interested: ${event.interestedCount}'
                                : 'Removed from interested events.',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: Icon(
                      event.isInterested
                          ? Icons.check
                          : Icons.add_reaction_outlined,
                      size: 18,
                    ),
                    label: Text(
                      event.isInterested ? 'Interested ✓' : "I'm Interested (+1)",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: event.isInterested
                          ? const Color(0xFF10B981)
                          : const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StationMapView(
                          initialTarget: LatLng(event.latitude, event.longitude),
                          targetEvent: event,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('View Location'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    side: const BorderSide(color: Color(0xFF38BDF8)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
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
