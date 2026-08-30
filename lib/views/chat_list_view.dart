import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/channel_service.dart';
import '../controllers/auth_controller.dart';
import '../models/channel.dart';
import 'chat_conversation_view.dart';
import 'channel_conversation_view.dart';

class ChatListView extends StatefulWidget {
  const ChatListView({
    super.key,
    required this.authController,
  });

  final AuthController authController;

  @override
  State<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView> {
  final ChatService _chatService = ChatService();
  final ChannelService _channelService = ChannelService();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            tabs: const [
              Tab(text: 'Direct Messages'),
              Tab(text: 'Interest Channels'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildDirectMessagesTab(),
                _buildChannelsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectMessagesTab() {
    return StreamBuilder<List<ChatPreview>>(
      stream: _chatService.watchChatPreviews(),
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
              leading: CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFF3B82F6),
                backgroundImage: profileImage,
                child: profileImage == null
                    ? Text(_firstCharacter(chat.otherUserName),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                    : null,
              ),
              title: Text(
                chat.otherUserName,
                style: TextStyle(
                  fontWeight: chat.unreadCount > 0 ? FontWeight.w800 : FontWeight.bold,
                ),
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
                      decoration: BoxDecoration(color: const Color(0xFFF43F5E), borderRadius: BorderRadius.circular(20)),
                      child: Text('${chat.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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
            );
          },
        );
      },
    );
  }

  Widget _buildChannelsTab() {
    final user = widget.authController.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<List<InterestChannel>>(
      stream: _channelService.watchMyChannels(user.interests),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final channels = snapshot.data!;
        if (channels.isEmpty) {
          return _buildEmptyState(
            icon: Icons.tag,
            title: 'No Interests Found',
            subtitle: 'Add interests to your profile to join global channels.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: channels.length,
          itemBuilder: (context, index) {
            final channel = channels[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              leading: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.tag, color: Colors.white, size: 28),
              ),
              title: Text(
                '# ${channel.name}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Text(
                channel.lastMessage ?? channel.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (channel.lastMessageAt != null)
                    Text(
                      _formatMessageTime(channel.lastMessageAt),
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  const SizedBox(height: 4),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white12),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChannelConversationView(
                      channelId: channel.id,
                      channelName: channel.name,
                      authController: widget.authController,
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

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 60, color: Colors.white10),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white38)),
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
