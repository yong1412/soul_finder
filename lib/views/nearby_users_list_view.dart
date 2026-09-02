import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/match_service.dart';
import 'public_user_profile_view.dart';

class NearbyUsersListView extends StatefulWidget {
  const NearbyUsersListView({super.key});

  @override
  State<NearbyUsersListView> createState() => _NearbyUsersListViewState();
}

class _NearbyUsersListViewState extends State<NearbyUsersListView> {
  final MatchService _matchService = MatchService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MatchCandidate>>(
      stream: _matchService.watchCandidates(),
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
          return const Center(child: CircularProgressIndicator());
        }

        final candidates = snapshot.data!;

        if (candidates.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_search, size: 80, color: Colors.white24),
                  SizedBox(height: 20),
                  Text(
                    'No souls in radar range',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Only users within your radar range (50m - 200m) appear here.\nTry increasing your discovery radius in profile settings or move around.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: candidates.length,
          itemBuilder: (context, index) {
            final candidate = candidates[index];
            final profile = candidate.profile;
            final profileImage = _decodeProfileImage(profile.profileImageBase64);

            final score = candidate.compatibilityScore.round();
            final isHighMatch = candidate.compatibilityScore >= 80;

            final badgeColor = isHighMatch
                ? const Color(0xFF10B981) // Emerald green for high match (>= 80%)
                : const Color(0xFF3B82F6); // Standard blue for regular match

            final badgeBgColor = isHighMatch
                ? const Color(0xFF10B981).withValues(alpha: 0.2)
                : const Color(0xFF3B82F6).withValues(alpha: 0.15);

            final badgeBorderColor = isHighMatch
                ? const Color(0xFF10B981).withValues(alpha: 0.6)
                : const Color(0xFF3B82F6).withValues(alpha: 0.3);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isHighMatch
                          ? const Color(0xFF10B981).withValues(alpha: 0.7)
                          : const Color(0xFF3B82F6).withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFF334155),
                    backgroundImage: profileImage,
                    child: profileImage == null
                        ? Text(
                            _firstCharacter(profile.name),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
                title: Text(
                  '${profile.name}, ${profile.age}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: Color(0xFF60A5FA)),
                        const SizedBox(width: 4),
                        Text(
                          _formatDistance(candidate.distanceKm),
                          style: const TextStyle(color: Colors.white60),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${candidate.commonInterests.length} shared interests',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeBgColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeBorderColor),
                    boxShadow: isHighMatch
                        ? [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.3),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isHighMatch) ...[
                        const Icon(
                          Icons.bolt,
                          size: 14,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 2),
                      ],
                      Text(
                        '$score%',
                        style: TextStyle(
                          color: badgeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PublicUserProfileView(candidate: candidate),
                    ),
                  );
                },
              ),
            );
          },
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

  String _formatDistance(double? distanceKm) {
    if (distanceKm == null) return 'Distance unavailable';
    if (distanceKm < 1.0) {
      final meters = (distanceKm * 1000).round();
      return '$meters m away';
    }
    return '${distanceKm.toStringAsFixed(1)} km away';
  }
}
