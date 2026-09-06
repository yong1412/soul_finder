import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:soul_finder/services/chat/chat_service.dart';
import 'package:soul_finder/services/match/match_service.dart';
import 'package:soul_finder/views/chat/chat_conversation_view.dart';

class DirectMessagesView extends StatefulWidget {
  const DirectMessagesView({super.key});

  @override
  State<DirectMessagesView> createState() => _DirectMessagesViewState();
}

class _DirectMessagesViewState extends State<DirectMessagesView> {
  final ChatService _chatService = ChatService();
  final MatchService _matchService = MatchService();
  late final Stream<List<ChatPreview>> _directMessagesStream;

  @override
  void initState() {
    super.initState();
    _directMessagesStream = _chatService.watchChatPreviews();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatPreview>>(
      stream: _directMessagesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final chats = snapshot.data!;

        if (chats.isEmpty) {
          return _buildEmptyState(
            icon: Icons.favorite_border,
            title: 'No matches yet',
            subtitle: 'A conversation appears here after a mutual Like.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: chats.length,
          separatorBuilder: (context, index) => const Divider(
            height: 1,
            indent: 82,
            color: Colors.white10,
          ),
          itemBuilder: (context, index) {
            final chat = chats[index];
            final profileImage = _decodeProfileImage(chat.otherUserProfileImageBase64);

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              leading: StreamBuilder<MatchPairData?>(
                stream: _matchService.watchPair(chat.otherUserUid),
                builder: (context, pairSnapshot) {
                  final isOnline = pairSnapshot.data?.otherUser.isPubliclyOnline ?? false;

                  return Stack(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFF3B82F6),
                        backgroundImage: profileImage,
                        child: profileImage == null
                            ? Text(
                                _firstCharacter(chat.otherUserName),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOnline ? const Color(0xFF10B981) : Colors.white38,
                            border: Border.all(color: const Color(0xFF0F172A), width: 2),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              title: Row(
                children: [
                  Text(
                    chat.otherUserName,
                    style: TextStyle(
                      fontWeight: chat.unreadCount > 0 ? FontWeight.w800 : FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (chat.isMuted) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.notifications_off_outlined,
                      size: 15,
                      color: Colors.white38,
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                chat.lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: chat.unreadCount > 0 ? Colors.white : Colors.white60,
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatMessageTime(chat.lastMessageAt),
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  if (chat.unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF43F5E),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${chat.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    const Icon(Icons.chevron_right, color: Colors.white38),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatConversationView(
                      targetUserUid: chat.otherUserUid,
                      targetUserName: chat.otherUserName,
                    ),
                  ),
                );
              },
              onLongPress: () => _showChatOptions(chat),
            );
          },
        );
      },
    );
  }

  void _showChatOptions(ChatPreview chat) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    chat.isMuted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                    color: chat.isMuted ? const Color(0xFF38BDF8) : Colors.orangeAccent,
                  ),
                  title: Text(
                    chat.isMuted ? 'Unmute Notifications' : 'Mute Notifications',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    chat.isMuted ? 'Receive alerts for this chat' : 'Silence alerts for ${chat.otherUserName}',
                    style: const TextStyle(color: Colors.white60),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    try {
                      await _chatService.toggleMuteChat(chat.otherUserUid, !chat.isMuted);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              !chat.isMuted
                                  ? 'Muted notifications for ${chat.otherUserName}'
                                  : 'Unmuted notifications for ${chat.otherUserName}',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline, color: Color(0xFF38BDF8)),
                  title: const Text('Open Conversation', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatConversationView(
                          targetUserUid: chat.otherUserUid,
                          targetUserName: chat.otherUserName,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 60, color: Colors.white10),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white38),
            ),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white24)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Error: $error', textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
      ),
    );
  }

  String _firstCharacter(String name) {
    return name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase();
  }

  ImageProvider? _decodeProfileImage(String encodedImage) {
    if (encodedImage.isEmpty) return null;
    try {
      final base64Value = encodedImage.contains(',') ? encodedImage.substring(encodedImage.indexOf(',') + 1) : encodedImage;
      return MemoryImage(base64Decode(base64Value));
    } catch (_) {
      return null;
    }
  }

  String _formatMessageTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final localTime = dateTime.toLocal();
    final now = DateTime.now();
    if (localTime.year == now.year && localTime.month == now.month && localTime.day == now.day) {
      return "${localTime.hour}:${localTime.minute.toString().padLeft(2, '0')}";
    }
    return '${localTime.day}/${localTime.month}';
  }
}
