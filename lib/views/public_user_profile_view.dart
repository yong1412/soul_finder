import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/interest_data.dart';
import '../services/match_service.dart';
import '../services/profile_stats_service.dart';
import '../services/report_service.dart';
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
    final isHighMatch = candidate.compatibilityScore >= 80;
    final distanceText = candidate.distanceKm == null
        ? 'Unavailable'
        : candidate.distanceKm! < 1.0
            ? '${(candidate.distanceKm! * 1000).round()} m'
            : '${candidate.distanceKm!.toStringAsFixed(1)} km';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Soul Profile'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Report User',
            icon: const Icon(Icons.flag_outlined, color: Colors.redAccent),
            onPressed: () {
              showReportUserDialog(
                context: context,
                targetUid: profile.uid,
                targetName: profile.name,
              );
            },
          ),
        ],
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
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                displayName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: profile.isOnline ? const Color(0xFF10B981) : Colors.white38,
                  boxShadow: profile.isOnline
                      ? [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.6),
                            blurRadius: 6,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
              ),
            ],
          ),
          if (profile.isSuspended) ...[
            const SizedBox(height: 10),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Account Suspended (Reported 5+ Times)',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          // Dedicated "About Me" Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'About Me',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  profile.bio.trim().isEmpty
                      ? 'Passionate about exploring new places, meeting like-minded souls, and enjoying genuine conversations.'
                      : profile.bio.trim(),
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Colors.white,
                  ),
                ),
              ],
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
                    valueColor: isHighMatch ? const Color(0xFF10B981) : null,
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
                if (profile.heightCm != null) ...[
                  const SizedBox(height: 14),
                  _InformationRow(
                    icon: Icons.height,
                    label: 'Height',
                    value: '${profile.heightCm!.toStringAsFixed(0)} cm',
                  ),
                ],
                if (profile.weightKg != null) ...[
                  const SizedBox(height: 14),
                  _InformationRow(
                    icon: Icons.monitor_weight_outlined,
                    label: 'Weight',
                    value: '${profile.weightKg!.toStringAsFixed(0)} kg',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Interests Card (Styled identically to UserDashboardView My Profile)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.interests_outlined,
                      color: Color(0xFF3B82F6),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Interests',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                profile.interests.isEmpty
                    ? const Text(
                        'No interests added yet.',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: profile.interests.map((rawInterest) {
                          final isCommon = candidate.commonInterests.any(
                            (item) => item.toLowerCase() == rawInterest.toLowerCase(),
                          );
                          final label = InterestData.getLabel(rawInterest);

                          return Chip(
                            avatar: Icon(
                              isCommon ? Icons.favorite : Icons.tag,
                              size: 14,
                              color: isCommon ? const Color(0xFFF43F5E) : const Color(0xFF38BDF8),
                            ),
                            label: Text(
                              label,
                              style: TextStyle(
                                color: isCommon ? const Color(0xFFF43F5E) : Colors.white,
                                fontWeight: isCommon ? FontWeight.bold : FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor: isCommon
                                ? const Color(0xFFF43F5E).withValues(alpha: 0.15)
                                : const Color(0xFF3B82F6).withValues(alpha: 0.12),
                            side: BorderSide(
                              color: isCommon
                                  ? const Color(0xFFF43F5E).withValues(alpha: 0.4)
                                  : const Color(0xFF3B82F6).withValues(alpha: 0.3),
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          );
                        }).toList(),
                      ),
                if (candidate.commonInterests.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    '❤️ Pink heart badges mark interests you both share in common!',
                    style: TextStyle(color: Color(0xFFF43F5E), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ),
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
    this.valueColor,
  });

  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.white,
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
