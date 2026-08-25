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
                    'No souls found nearby',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Try increasing your discovery radius in profile settings.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38),
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
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
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
                          '${candidate.distanceKm?.toStringAsFixed(1) ?? "?"} km away',
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${candidate.compatibilityScore.round()}%',
                    style: const TextStyle(
                      color: Color(0xFF3B82F6),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
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
}

class MapRadarView extends StatefulWidget {
  const MapRadarView({super.key});

  @override
  State<MapRadarView> createState() => _MapRadarViewState();
}

class _MapRadarViewState extends State<MapRadarView> {
  // Keeps track of the selected mode. Default is 'friends'
  Set<String> _scanMode = {'friends'};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Top Toggle Button (Friend vs Couple)
        Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 20.0),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'friends',
                label: Text('Find Friends'),
                icon: Icon(Icons.people_alt),
              ),
              ButtonSegment<String>(
                value: 'couple',
                label: Text('Find Couple'),
                icon: Icon(Icons.favorite),
              ),
            ],
            selected: _scanMode,
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                _scanMode = newSelection;
              });
            },
            style: SegmentedButton.styleFrom(
              backgroundColor: theme.surface,
              selectedBackgroundColor: _scanMode.first == 'couple'
                  ? theme.secondary.withOpacity(0.3) // Pinkish for couples
                  : theme.primary.withOpacity(0.3),  // Blueish for friends
              foregroundColor: Colors.white70,
              selectedForegroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
        ),

        // Radar takes up the remaining screen space and centers itself
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer radar ring
                    Container(
                      height: 250,
                      width: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.primary.withOpacity(0.1), width: 1),
                        color: theme.primary.withOpacity(0.05),
                      ),
                    ),
                    // Middle radar ring
                    Container(
                      height: 150,
                      width: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.secondary.withOpacity(0.3), width: 1),
                        color: theme.secondary.withOpacity(0.05),
                      ),
                    ),
                    // Inner core
                    Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [theme.primary, theme.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.primary.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        // Change icon in the middle based on mode
                        _scanMode.first == 'couple' ? Icons.favorite : Icons.location_on,
                        size: 35,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Text(
                  // Dynamically update the scanning text based on selection
                  _scanMode.first == 'couple'
                      ? "Scanning for potential matches..."
                      : "Scanning for new friends...",
                  style: const TextStyle(fontSize: 16, color: Colors.white70, letterSpacing: 1.1),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.surface,
                    foregroundColor: _scanMode.first == 'couple' ? theme.secondary : theme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () {
                    // Trigger refresh animation/logic here
                  },
                  child: const Text("Pulse Location"),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}
