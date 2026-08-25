import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import 'chat_conversation_view.dart';

class ChatListView extends StatefulWidget {
  const ChatListView({super.key});

  @override
  State<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView> {
  final ChatService _chatService = ChatService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatPreview>>(
      stream: _chatService.watchChatPreviews(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load matches:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final chats = snapshot.data!;

        if (chats.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 60,
                    color: Colors.white30,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No matches yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'A conversation appears here after a mutual Like.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60),
                  ),
                ],
              ),
            ),
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
            final profileImage = _decodeProfileImage(
              chat.otherUserProfileImageBase64,
            );

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              leading: CircleAvatar(
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
              title: Text(
                chat.otherUserName,
                style: TextStyle(
                  fontWeight: chat.unreadCount > 0
                      ? FontWeight.w800
                      : FontWeight.bold,
                ),
              ),
              subtitle: Row(
                children: [
                  if (chat.lastMessageType == 'meetingProposal') ...[
                    const Icon(
                      Icons.location_on,
                      size: 14,
                      color: Color(0xFF60A5FA),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      chat.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: chat.unreadCount > 0
                            ? Colors.white
                            : Colors.white60,
                        fontWeight: chat.unreadCount > 0
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatMessageTime(chat.lastMessageAt),
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (chat.unreadCount > 0)
                    Container(
                      constraints: const BoxConstraints(minWidth: 22),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF43F5E),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        chat.unreadCount > 99
                            ? '99+'
                            : '${chat.unreadCount}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.white38,
                    ),
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
            );
          },
        );
      },
    );
  }

  String _firstCharacter(String name) {
    final trimmedName = name.trim();
    return trimmedName.isEmpty
        ? '?'
        : trimmedName.substring(0, 1).toUpperCase();
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

  String _formatMessageTime(DateTime? dateTime) {
    if (dateTime == null) return '';

    final localTime = dateTime.toLocal();
    final now = DateTime.now();
    final isToday = localTime.year == now.year &&
        localTime.month == now.month &&
        localTime.day == now.day;

    if (isToday) {
      final hour = localTime.hour.toString().padLeft(2, '0');
      final minute = localTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }

    return '${localTime.day}/${localTime.month}';
  }
}
