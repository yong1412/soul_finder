import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/location_service.dart';
import '../services/match_service.dart';
import 'meet_soul_view.dart';
import 'public_user_profile_view.dart';

class NearbyUsersListView extends StatefulWidget {
  const NearbyUsersListView({super.key});

  @override
  State<NearbyUsersListView> createState() =>
      _NearbyUsersListViewState();
}

class _NearbyUsersListViewState extends State<NearbyUsersListView> {
  final MatchService _matchService = MatchService();
  final LocationService _locationService = LocationService();
  String? _locationMessage;

  @override
  void initState() {
    super.initState();
    _startLocation();
  }

  Future<void> _startLocation() async {
    try {
      await _locationService.start();
      if (mounted) {
        setState(() => _locationMessage = null);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _locationMessage = error.toString());
      }
    }
  }

  @override
  void dispose() {
    _locationService.stop();
    super.dispose();
  }

  void _openMeetingPage(MatchCandidate candidate) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MeetSoulView(
          targetUserUid: candidate.profile.uid,
          soulName: candidate.profile.name,
        ),
      ),
    );
  }

  void _openProfile(MatchCandidate candidate) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PublicUserProfileView(
          candidate: candidate,
        ),
      ),
    );
  }

  Future<void> _handleLike(
      MatchCandidate candidate,
      bool alreadyLiked,
      bool alreadyMatched,
      ) async {
    try {
      if (alreadyLiked && !alreadyMatched) {
        await _matchService.removeLike(candidate.profile.uid);
        return;
      }

      if (alreadyMatched) {
        _openMeetingPage(candidate);
        return;
      }

      final matched =
      await _matchService.likeUser(candidate.profile.uid);
      if (!mounted) {
        return;
      }

      if (!matched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Like sent. Waiting for a mutual Like.')),
        );
        return;
      }

      final planMeeting = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text("It's a Match!"),
          content: Text(
            'You and ${candidate.profile.name} liked each other.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('View Match'),
            ),
          ],
        ),
      );

      if (mounted && planMeeting == true) {
        _openMeetingPage(candidate);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_locationMessage != null)
          MaterialBanner(
            content: Text(_locationMessage!),
            actions: [
              TextButton(
                onPressed: _startLocation,
                child: const Text('Retry'),
              ),
            ],
          ),
        Expanded(
          child: StreamBuilder<List<MatchCandidate>>(
            stream: _matchService.watchCandidates(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Unable to load users: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final candidates = snapshot.data!;
              if (candidates.isEmpty) {
                return const Center(
                  child: Text('No profiles are currently available.'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: candidates.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final candidate = candidates[index];
                  final profile = candidate.profile;
                  final distanceText = candidate.distanceKm == null
                      ? 'Location unavailable'
                      : '${candidate.distanceKm!.toStringAsFixed(1)} km away';
                  final profileImage =
                  _decodeProfileImage(profile.profileImageBase64);

                  return Card(
                    color: const Color(0xFF1E293B),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Colors.white10),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: Hero(
                        tag: 'profile-${profile.uid}',
                        child: CircleAvatar(
                          radius: 27,
                          backgroundColor: const Color(0xFF475569),
                          backgroundImage: profileImage,
                          child: profileImage == null
                              ? Text(
                            _firstCharacter(profile.name),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                              : null,
                        ),
                      ),
                      title: Text(
                        profile.age > 0
                            ? '${profile.name}, ${profile.age}'
                            : profile.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '$distanceText\n'
                            '${candidate.compatibilityScore.round()}% compatible',
                      ),
                      isThreeLine: true,
                      onTap: () => _openProfile(candidate),
                      trailing: StreamBuilder<bool>(
                        stream: _matchService.watchMatchStatus(profile.uid),
                        initialData: false,
                        builder: (context, matchSnapshot) {
                          final matched = matchSnapshot.data ?? false;
                          return StreamBuilder<bool>(
                            stream: _matchService.watchLikeStatus(profile.uid),
                            initialData: false,
                            builder: (context, likeSnapshot) {
                              final liked = likeSnapshot.data ?? false;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: matched
                                        ? 'View match'
                                        : 'Available after mutual match',
                                    onPressed: matched
                                        ? () => _openMeetingPage(candidate)
                                        : null,
                                    icon: Icon(
                                      Icons.restaurant,
                                      color: matched
                                          ? const Color(0xFF3B82F6)
                                          : Colors.white24,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: matched
                                        ? 'Matched'
                                        : liked
                                        ? 'Remove Like'
                                        : 'Like profile',
                                    onPressed: () => _handleLike(
                                      candidate,
                                      liked,
                                      matched,
                                    ),
                                    icon: Icon(
                                      liked || matched
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: const Color(0xFFF43F5E),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
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
