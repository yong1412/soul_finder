import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/match_service.dart';
import '../services/profile_stats_service.dart';
import 'chat_conversation_view.dart';
import 'meet_soul_view.dart';

class PublicUserProfileView extends StatefulWidget {
  const PublicUserProfileView({
    super.key,
    required this.candidate,
  });

  final MatchCandidate candidate;

  @override
  State<PublicUserProfileView> createState() =>
      _PublicUserProfileViewState();
}

class _PublicUserProfileViewState extends State<PublicUserProfileView> {
  final MatchService _matchService = MatchService();
  final ProfileStatsService _profileStatsService = ProfileStatsService();

  bool _isProcessingLike = false;

  @override
  void initState() {
    super.initState();
    _recordProfileView();
  }

  Future<void> _recordProfileView() async {
    try {
      await _profileStatsService.recordProfileView(
        widget.candidate.profile.uid,
      );
    } catch (error) {
      // Profile viewing should still work if analytics cannot be recorded.
      debugPrint('Unable to record profile view: $error');
    }
  }

  Future<void> _handleLike({
    required bool liked,
    required bool matched,
  }) async {
    if (_isProcessingLike || matched) return;

    setState(() => _isProcessingLike = true);

    try {
      if (liked) {
        await _matchService.removeLike(widget.candidate.profile.uid);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Like removed.')),
          );
        }
        return;
      }

      final becameMatched = await _matchService.likeUser(
        widget.candidate.profile.uid,
      );

      if (!mounted) return;

      if (!becameMatched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Like sent. Waiting for a mutual Like.'),
          ),
        );
        return;
      }

      final openChat = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Row(
              children: [
                Icon(Icons.favorite, color: Color(0xFFF43F5E)),
                SizedBox(width: 10),
                Text("It's a Match!"),
              ],
            ),
            content: Text(
              'You and ${widget.candidate.profile.name} liked each other.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Later'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Open Chat'),
              ),
            ],
          );
        },
      );

      if (mounted && openChat == true) {
        _openChat();
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
    } finally {
      if (mounted) {
        setState(() => _isProcessingLike = false);
      }
    }
  }

  void _openChat() {
    final profile = widget.candidate.profile;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatConversationView(
          targetUserUid: profile.uid,
          targetUserName: profile.name,
        ),
      ),
    );
  }

  void _openMeetingPlanner() {
    final profile = widget.candidate.profile;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MeetSoulView(
          targetUserUid: profile.uid,
          soulName: profile.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final candidate = widget.candidate;
    final profile = candidate.profile;
    final profileImage = _decodeProfileImage(profile.profileImageBase64);
    final displayName = profile.age > 0
        ? '${profile.name}, ${profile.age}'
        : profile.name;
    final distanceText = candidate.distanceKm == null
        ? 'Unavailable'
        : '${candidate.distanceKm!.toStringAsFixed(1)} km';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Soul Profile'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
        children: [
          Center(
            child: Hero(
              tag: 'profile-${profile.uid}',
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF3B82F6),
                      Color(0xFF8B5CF6),
                      Color(0xFFF43F5E),
                    ],
                  ),
                ),
                child: CircleAvatar(
                  radius: 58,
                  backgroundColor: const Color(0xFF334155),
                  backgroundImage: profileImage,
                  child: profileImage == null
                      ? Text(
                    _firstCharacter(profile.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            profile.bio.trim().isEmpty
                ? 'Looking for meaningful connections'
                : profile.bio.trim(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF60A5FA),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ProfileStat(
                    value: '${candidate.compatibilityScore.round()}%',
                    label: 'Compatible',
                  ),
                ),
                const _VerticalDivider(),
                Expanded(
                  child: _ProfileStat(
                    value: distanceText,
                    label: 'Distance',
                  ),
                ),
                const _VerticalDivider(),
                Expanded(
                  child: _ProfileStat(
                    value: '${candidate.commonInterests.length}',
                    label: 'In Common',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _ProfileSection(
            title: 'About',
            child: Column(
              children: [
                _InformationRow(
                  icon: Icons.person_outline,
                  label: 'Gender',
                  value: profile.gender.trim().isEmpty
                      ? 'Not specified'
                      : profile.gender,
                ),
                const SizedBox(height: 14),
                _InformationRow(
                  icon: Icons.search,
                  label: 'Looking for',
                  value: profile.lookingFor.trim().isEmpty
                      ? 'Not specified'
                      : profile.lookingFor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ProfileSection(
            title: 'Interests',
            child: profile.interests.isEmpty
                ? const Text(
              'No interests added yet.',
              style: TextStyle(color: Colors.white60),
            )
                : Wrap(
              spacing: 9,
              runSpacing: 9,
              children: profile.interests
                  .map(
                    (interest) => Chip(
                  avatar: Icon(
                    candidate.commonInterests.any(
                          (item) =>
                      item.toLowerCase() ==
                          interest.toLowerCase(),
                    )
                        ? Icons.favorite
                        : Icons.tag,
                    size: 16,
                    color: candidate.commonInterests.any(
                          (item) =>
                      item.toLowerCase() ==
                          interest.toLowerCase(),
                    )
                        ? const Color(0xFFF43F5E)
                        : Colors.white54,
                  ),
                  label: Text(interest),
                  backgroundColor: const Color(0xFF273449),
                  side: BorderSide.none,
                ),
              )
                  .toList(),
            ),
          ),
          if (candidate.commonInterests.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'The heart icon marks an interest you both share.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          const Card(
            color: Color(0xFF1E293B),
            child: ListTile(
              leading: Icon(
                Icons.privacy_tip_outlined,
                color: Color(0xFF22C55E),
              ),
              title: Text('Privacy protected'),
              subtitle: Text(
                'Email and exact live location are not shown.',
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildActions(),
    );
  }

  Widget _buildActions() {
    final profile = widget.candidate.profile;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          border: Border(
            top: BorderSide(color: Colors.white12),
          ),
        ),
        child: StreamBuilder<bool>(
          stream: _matchService.watchMatchStatus(profile.uid),
          initialData: false,
          builder: (context, matchSnapshot) {
            final matched = matchSnapshot.data ?? false;

            return StreamBuilder<bool>(
              stream: _matchService.watchLikeStatus(profile.uid),
              initialData: false,
              builder: (context, likeSnapshot) {
                final liked = likeSnapshot.data ?? false;

                if (matched) {
                  return Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _openChat,
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Chat'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openMeetingPlanner,
                          icon: const Icon(Icons.restaurant_outlined),
                          label: const Text('Plan Meeting'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isProcessingLike
                        ? null
                        : () => _handleLike(
                      liked: liked,
                      matched: matched,
                    ),
                    icon: _isProcessingLike
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                    ),
                    label: Text(liked ? 'Remove Like' : 'Like Profile'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF43F5E),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
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

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 46,
      color: Colors.white12,
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0x223B82F6),
          child: Icon(icon, color: const Color(0xFF60A5FA), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
