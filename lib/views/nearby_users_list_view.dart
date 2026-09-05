import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/event_hotspot.dart';
import '../models/user_profile.dart';
import '../services/event_hotspot_service.dart';
import '../services/match_service.dart';
import '../widgets/marquee_text.dart';
import 'chat_conversation_view.dart';
import 'public_user_profile_view.dart';

class NearbyUsersListView extends StatefulWidget {
  const NearbyUsersListView({super.key});

  @override
  State<NearbyUsersListView> createState() => _NearbyUsersListViewState();
}

class _NearbyUsersListViewState extends State<NearbyUsersListView> {
  final MatchService _matchService = MatchService();
  final EventHotspotService _eventService = EventHotspotService();

  // Mode filter: 'ALL' (All Souls - Privacy Protected), 'RADAR' (Radar Range 200m + Event Souls)
  String _activeFilter = 'ALL';
  bool _isSwitchingMode = false;
  Timer? _autoRefreshTimer; // Timer for auto-refreshing All Souls every 3 minutes

  @override
  void initState() {
    super.initState();
    // ⏰ Auto refresh candidate souls every 3 minutes
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Stream<UserProfile?> _watchCurrentUserProfile() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid.isEmpty) {
      return Stream.value(null);
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .snapshots()
        .map((doc) => doc.exists && doc.data() != null ? UserProfile.fromJson(doc.data()!) : null)
        .handleError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: _watchCurrentUserProfile(),
      builder: (context, userSnapshot) {
        final radiusKm = userSnapshot.data?.discoveryRadius ?? 0.2;
        final radiusMeters = (radiusKm * 1000).round().clamp(50, 200);

        final isCoupleMode = userSnapshot.data?.radarMode == 'couple';
        final currentRadarMode = userSnapshot.data?.radarMode ?? 'friends';
        final themeColor = isCoupleMode
            ? const Color(0xFFF43F5E) // 🌹 Rose Red for Find Couple mode!
            : const Color(0xFF38BDF8); // 💙 Sky Blue for Find Friends mode!

        return Column(
          children: [
            // 1. Streamlined Top Filter Bar (All Souls & Dynamic Radar Range)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF0F172A),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFilterChip('ALL', 'All Souls', Icons.people_outline, themeColor),
                  const SizedBox(width: 12),
                  _buildFilterChip(
                    'RADAR',
                    'Radar Range (${radiusMeters}m)',
                    isCoupleMode ? Icons.favorite : Icons.radar,
                    themeColor,
                  ),
                ],
              ),
            ),

            // 2. Main Content View with Smooth Privacy Transition
            Expanded(
              child: _isSwitchingMode
                  ? _buildSwitchingLoadingView(themeColor)
                  : _buildSoulsView(radiusMeters, themeColor, currentRadarMode),
            ),
          ],
        );
      },
    );
  }

  /// Filter Chip with Privacy Transition & Dynamic Mode Color
  Widget _buildFilterChip(String key, String label, IconData icon, Color themeColor) {
    final isSelected = _activeFilter == key;
    return ChoiceChip(
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.white : themeColor,
      ),
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) async {
        if (selected && _activeFilter != key && !_isSwitchingMode) {
          setState(() {
            _isSwitchingMode = true;
          });

          // 🛡️ Privacy Transition Delay: Mask data briefly while switching rules
          await Future.delayed(const Duration(milliseconds: 650));

          if (mounted) {
            setState(() {
              _activeFilter = key;
              _isSwitchingMode = false;
            });
          }
        }
      },
      selectedColor: themeColor,
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? themeColor : themeColor.withValues(alpha: 0.3),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
    );
  }

  /// Privacy Loading View shown during mode transition
  Widget _buildSwitchingLoadingView(Color themeColor) {
    final isGoingToRadar = _activeFilter == 'ALL'; // currently ALL, going to RADAR
    final targetTitle = isGoingToRadar ? 'Scanning Radar Range...' : 'Loading All Souls...';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: themeColor,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            targetTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, size: 14, color: Colors.white38),
              SizedBox(width: 6),
              Text(
                'Applying privacy & distance rules',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white38,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build Souls List (All Souls with Privacy or Dynamic Radar Range including Event Souls)
  Widget _buildSoulsView(int radiusMeters, Color themeColor, String currentRadarMode) {
    final filterByRadius = _activeFilter == 'RADAR';
    final isAllSoulsMode = _activeFilter == 'ALL';

    return StreamBuilder<Set<String>>(
      stream: _matchService.watchLikedUserIds(),
      builder: (context, likedSnapshot) {
        final likedUserIds = likedSnapshot.data ?? {};

        return StreamBuilder<List<MatchCandidate>>(
          stream: _matchService.watchCandidates(
            filterByRadius: filterByRadius,
            scanMode: currentRadarMode, // 🎯 Synchronous Mode Binding!
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'Unable to load nearby souls: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return _buildSkeletonList(); // ⚡ Instant Skeleton Placeholder
            }

            var candidates = snapshot.data!;

            // 🎯 For All Souls mode: Randomly pick up to 20 candidates, rotating every 3 minutes
            if (isAllSoulsMode && candidates.isNotEmpty) {
              final timeSeed = DateTime.now().millisecondsSinceEpoch ~/ (180 * 1000); // 3-minute seed
              final shuffled = List<MatchCandidate>.of(candidates)
                ..shuffle(math.Random(timeSeed));
              candidates = shuffled.take(20).toList();
            }

            if (candidates.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_search, size: 80, color: Colors.white24),
                      const SizedBox(height: 20),
                      Text(
                        filterByRadius ? 'No souls or events in ${radiusMeters}m range' : 'No souls found yet',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        filterByRadius
                            ? 'Try switching to "All Souls" mode or move closer to active event areas.'
                            : 'Invite friends or complete your profile to discover more connections!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white38, height: 1.4),
                      ),
                      if (filterByRadius) ...[
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _activeFilter = 'ALL'; // 🚀 Instant 0ms switch!
                            });
                          },
                          icon: const Icon(Icons.public, size: 18),
                          label: const Text('Show All Souls Globally'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {});
              },
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: candidates.length,
                itemBuilder: (context, index) {
                  final candidate = candidates[index];
                  final profile = candidate.profile;
                  final isLiked = likedUserIds.contains(profile.uid);
                  final candidateEvent = _findCandidateEventHotspot(candidate);

                  return _buildCandidateCard(
                    candidate: candidate,
                    isAllSoulsMode: isAllSoulsMode,
                    isLiked: isLiked,
                    detectedEvent: candidateEvent,
                    themeColor: themeColor,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  /// Instant Skeleton Placeholder Cards while Stream loads
  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: Color(0xFF0F172A),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 130,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Helper to check if candidate is currently located at an Event Hotspot
  EventHotspot? _findCandidateEventHotspot(MatchCandidate candidate) {
    if (!candidate.profile.hasLocation) return null;
    final events = _eventService.events;
    for (final event in events) {
      final distanceMeters = Geolocator.distanceBetween(
        candidate.profile.latitude!,
        candidate.profile.longitude!,
        event.latitude,
        event.longitude,
      );
      if (distanceMeters <= math.max(event.radiusMeters, 500.0)) {
        return event;
      }
    }
    return null;
  }

  /// Get gender accent color: Male (Blue), Female (Pink/Red), Non-binary (Green), Prefer not to say (Purple)
  Color _getGenderColor(String gender) {
    final normalized = gender.trim().toLowerCase();
    if (normalized == 'male') {
      return const Color(0xFF38BDF8); // 💙 Blue for Male
    } else if (normalized == 'female') {
      return const Color(0xFFF43F5E); // 💖 Pink/Rose Red for Female
    } else if (normalized == 'non-binary' || normalized == 'non binary') {
      return const Color(0xFF10B981); // 💚 Green for Non-binary
    } else {
      return const Color(0xFF8B5CF6); // 💜 Purple for Prefer not to say / undisclosed
    }
  }

  /// Build Candidate Card with Privacy Rules in All Souls Mode & Event Badges / Distance Badges
  Widget _buildCandidateCard({
    required MatchCandidate candidate,
    required bool isAllSoulsMode,
    required bool isLiked,
    EventHotspot? detectedEvent,
    required Color themeColor,
  }) {
    final profile = candidate.profile;
    final score = candidate.compatibilityScore.round();
    final isHighMatch = candidate.compatibilityScore >= 80;
    final genderColor = _getGenderColor(profile.gender);

    final profileImage = isAllSoulsMode
        ? null // 🔒 Hide profile image in All Souls mode!
        : _decodeProfileImage(profile.profileImageBase64);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: detectedEvent != null
              ? const Color(0xFFF59E0B)
              : (isLiked
                  ? const Color(0xFFF43F5E)
                  : genderColor.withValues(alpha: 0.6)),
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (isAllSoulsMode) {
            // 🔒 In All Souls mode, profile data is restricted until a mutual match!
            _showPrivacyLockedModal(context, profile);
          } else {
            // In Radar mode, allow opening full profile
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PublicUserProfileView(candidate: candidate),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar Section (🔒 Locked/Hidden Avatar in All Souls mode)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: detectedEvent != null
                        ? const Color(0xFFF59E0B)
                        : (isHighMatch
                            ? const Color(0xFF10B981)
                            : genderColor),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: isAllSoulsMode
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF334155),
                  backgroundImage: profileImage,
                  child: isAllSoulsMode
                      ? const Icon(
                          Icons.lock_outline,
                          color: Color(0xFF38BDF8),
                          size: 24,
                        )
                      : (profileImage == null
                          ? Text(
                              _firstCharacter(profile.name),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null),
                ),
              ),
              const SizedBox(width: 14),

              // Info Section (Name + Match Badge, Gender, Event Location / Distance Badge)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: User Name & Small Match Box Badge side-by-side
                    Row(
                      children: [
                        Flexible(
                          child: MarqueeText(
                            text: profile.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // 🎯 Small Match Box Badge next to User Name
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isHighMatch
                                ? const Color(0xFF10B981).withValues(alpha: 0.18)
                                : const Color(0xFF38BDF8).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isHighMatch
                                  ? const Color(0xFF10B981).withValues(alpha: 0.5)
                                  : const Color(0xFF38BDF8).withValues(alpha: 0.35),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isHighMatch ? Icons.bolt : Icons.favorite,
                                size: 10,
                                color: isHighMatch
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF38BDF8),
                              ),
                              const SizedBox(width: 2.5),
                              Text(
                                '$score% Match',
                                style: TextStyle(
                                  color: isHighMatch
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF38BDF8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Row 2: Gender Badge & Event Location / Distance Badge
                    Row(
                      children: [
                        // Gender Badge (Compact)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: genderColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: genderColor.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            profile.gender.isEmpty ? 'Soul' : profile.gender,
                            style: TextStyle(
                              color: genderColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (detectedEvent != null)
                          // 🎯 Event Location Badge (Marquee auto-scrolling)
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_fire_department, size: 10, color: Color(0xFFF59E0B)),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: MarqueeText(
                                      text: detectedEvent.name, // e.g. "Serimas Condo • Pearl Tower"
                                      style: const TextStyle(
                                        color: Color(0xFFF59E0B),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          // 📍 Compact Distance Badge (e.g. "120m" or "1.5km" or "2km")
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: themeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: themeColor.withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on, size: 10, color: themeColor),
                                const SizedBox(width: 2),
                                Text(
                                  _formatCompactDistance(candidate.distanceKm), // 👈 e.g. "120m" or "1km"
                                  style: TextStyle(
                                    color: themeColor,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    // Row 3: Shared Interests or Event Detection Note
                    Text(
                      detectedEvent != null
                          ? '📍 Detected at ${detectedEvent.eventTitle}'
                          : '${candidate.commonInterests.length} shared interests',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Like / Matched Button Action
              StreamBuilder<bool>(
                stream: _matchService.watchMatchStatus(profile.uid),
                builder: (context, matchSnapshot) {
                  final isMatched = matchSnapshot.data ?? false;

                  if (isMatched) {
                    // Mutual match unlocked! Allow Direct Messaging
                    return FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatConversationView(
                              targetUserUid: profile.uid,
                              targetUserName: profile.name,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 14),
                      label: const Text('Chat'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    );
                  }

                  if (isLiked) {
                    // Liked by current user, waiting for reverse like
                    return OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'You liked ${profile.name}! Direct messaging will unlock once they like you back.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check, size: 14, color: Color(0xFF10B981)),
                      label: const Text('Liked'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF10B981),
                        side: const BorderSide(color: Color(0xFF10B981)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    );
                  }

                  // Like Action Button
                  return FilledButton.icon(
                    onPressed: () => _likeUserAndHandleMatch(candidate),
                    icon: const Icon(Icons.favorite, size: 14),
                    label: const Text('Like'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF43F5E),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact distance formatter: <1000m -> "120m", >=1000m -> "1km" / "1.5km"
  String _formatCompactDistance(double? distanceKm) {
    if (distanceKm == null) return 'Nearby';
    final meters = (distanceKm * 1000).round();
    if (meters < 1000) {
      return '${meters}m';
    } else {
      final km = distanceKm;
      if (km == km.roundToDouble()) {
        return '${km.toInt()}km';
      }
      return '${km.toStringAsFixed(1)}km';
    }
  }

  /// Like User and Handle Mutual Match Unlocking
  Future<void> _likeUserAndHandleMatch(MatchCandidate candidate) async {
    final profile = candidate.profile;
    try {
      final isMatched = await _matchService.likeUser(profile.uid);
      if (!mounted) return;

      if (isMatched) {
        // 🎉 Mutual Match Unlocked! Direct Message Phase
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
                'You and ${profile.name} liked each other! Direct messaging is now unlocked.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Later'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatConversationView(
                          targetUserUid: profile.uid,
                          targetUserName: profile.name,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Direct Message'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                  ),
                ),
              ],
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Liked ${profile.name}! Direct messaging unlocks when they like you back.'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  /// Modal explaining privacy rules in All Souls mode
  void _showPrivacyLockedModal(BuildContext context, UserProfile profile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: Color(0xFF0F172A),
                child: Icon(Icons.lock_outline, color: Color(0xFF38BDF8), size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                'Profile Data Locked (${profile.name})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Full profile details and direct messaging are protected in All Souls mode.\n\nLike this profile to send a connection request. When both of you like each other, direct messaging and profile details will unlock!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, height: 1.4, fontSize: 13),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                  ),
                  child: const Text('Understood'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  ImageProvider<Object>? _decodeProfileImage(String encodedImage) {
    final trimmed = encodedImage.trim();
    if (trimmed.isEmpty) return null;

    try {
      final base64Value = trimmed.contains(',')
          ? trimmed.substring(trimmed.indexOf(',') + 1)
          : trimmed;
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
