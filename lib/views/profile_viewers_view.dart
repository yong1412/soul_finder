import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/profile_stats_service.dart';

class ProfileViewersView extends StatelessWidget {
  ProfileViewersView({super.key});

  final ProfileStatsService _profileStatsService = ProfileStatsService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Profile Views'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<ProfileViewerEntry>>(
        stream: _profileStatsService.watchProfileViewers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load profile views:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final viewers = snapshot.data!;

          if (viewers.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      size: 64,
                      color: Colors.white30,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No profile views yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Users who open your public profile will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: viewers.length + 1,
            separatorBuilder: (context, index) =>
            const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0x223B82F6),
                        child: Icon(
                          Icons.visibility,
                          color: Color(0xFF60A5FA),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${viewers.length} unique '
                              '${viewers.length == 1 ? 'person has' : 'people have'} '
                              'viewed your profile.',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final viewer = viewers[index - 1];
              final profile = viewer.profile;
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  leading: CircleAvatar(
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
                  title: Text(
                    profile.age > 0
                        ? '${profile.name}, ${profile.age}'
                        : profile.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    profile.bio.trim().isEmpty
                        ? 'Viewed your profile'
                        : profile.bio.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white60),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Icon(
                        Icons.visibility_outlined,
                        size: 18,
                        color: Color(0xFF60A5FA),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatViewTime(viewer.viewedAt),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
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

  String _formatViewTime(DateTime? dateTime) {
    if (dateTime == null) return 'Just now';

    final viewedAt = dateTime.toLocal();
    final now = DateTime.now();
    final difference = now.difference(viewedAt);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${viewedAt.day}/${viewedAt.month}/${viewedAt.year}';
  }
}
